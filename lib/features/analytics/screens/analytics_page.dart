import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:inventory/models/inventory_item.dart';
import 'package:inventory/models/sale.dart';
import 'package:inventory/models/order.dart';

/// Timeframes used for graphing analytics
enum AnalyticsTimeFrame {
  allTime,
  daily,
  weekToDate,
  weekly,
  monthToDate,
  monthly,
  quarterly,
  yearly,
  custom,
}

/// Metric displayed by the analytics chart.
enum AnalyticsGraphType { revenue, profit, expenses, inventory, inventoryValue }

class _TimeSeriesPoint {
  final DateTime date;
  final double value;

  const _TimeSeriesPoint({required this.date, required this.value});
}

/// Values on-hand units from oldest remaining order batches
/// Grabs unit price
double calculateFifoValueForQuantity(InventoryItem item, int quantity) {
  if (quantity <= 0) {
    return 0.0;
  }

  final batches = <({DateTime date, double unitCost, int currentQty})>[];
  for (final order in item.orderList) {
    for (final orderItem in order.inventoryList) {
      if (orderItem.inventoryItem.id == item.id &&
          orderItem.currentQuantity > 0) {
        batches.add((
          date: order.date,
          unitCost: orderItem.shippedPrice,
          currentQty: orderItem.currentQuantity,
        ));
      }
    }
  }

  batches.sort((a, b) => a.date.compareTo(b.date));

  double value = 0.0;
  var remaining = quantity;

  for (final batch in batches) {
    if (remaining <= 0) {
      break;
    }

    final usedQty = remaining < batch.currentQty ? remaining : batch.currentQty;
    value += usedQty * batch.unitCost;
    remaining -= usedQty;
  }

  if (remaining > 0) {
    value += remaining * item.price;
  }

  return value.isFinite ? value : 0.0;
}

/// Sums FIFO stock value across all inventory items to calculate total inventory value
double calculateFifoInventoryValue(List<InventoryItem> items) {
  return items.fold(
    0.0,
    (sum, item) =>
        sum + calculateFifoValueForQuantity(item, item.inventoryCount),
  );
}

class AnalyticsPage extends StatefulWidget {
  final List<InventoryItem> inventoryList;
  final List<Sale> saleList;
  final List<Order> orderList;

  const AnalyticsPage({
    required this.inventoryList,
    required this.saleList,
    required this.orderList,
    super.key,
  });

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

/// Chart filters and recalculates analytics when inputs and filters change.
class _AnalyticsPageState extends State<AnalyticsPage> {
  AnalyticsTimeFrame selectedTimeFrame = AnalyticsTimeFrame.monthly;
  AnalyticsGraphType selectedGraphType = AnalyticsGraphType.revenue;
  DateTimeRange? customDateRange;
  int _periodOffset = 0;

  late double totalRevenue;
  late double totalProfit;
  late double totalExpenses;
  late int totalInventoryCount;
  late double inventoryValue;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    customDateRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: now,
    );
    _calculateMetrics();
  }

  @override
  void didUpdateWidget(covariant AnalyticsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.inventoryList != widget.inventoryList ||
        oldWidget.saleList != widget.saleList ||
        oldWidget.orderList != widget.orderList) {
      _calculateMetrics();
    }
  }

  void _calculateMetrics() {
    final filteredSales = _getFilteredSales();
    final filteredOrders = _getFilteredOrders();

    // Calculate total revenue from selected timeframe
    totalRevenue = filteredSales.fold(
      0.0,
      (sum, sale) => sum + (sale.price.isFinite ? sale.price : 0.0),
    );

    // Calculate total profit from selected timeframe
    totalProfit = filteredSales.fold(
      0.0,
      (sum, sale) => sum + (sale.profit.isFinite ? sale.profit : 0.0),
    );

    // Calculate total expenses from orders in selected timeframe
    totalExpenses = filteredOrders.fold(
      0.0,
      (sum, order) =>
          sum + (order.totalOrderPrice.isFinite ? order.totalOrderPrice : 0.0),
    );

    // Calculate total inventory count
    totalInventoryCount = widget.inventoryList.fold(
      0,
      (sum, item) => sum + (item.inventoryCount >= 0 ? item.inventoryCount : 0),
    );

    // Calculate inventory value using FIFO costing.
    // Order batches are valued at their shipped cost, and any remaining units
    // fall back to the item default price.
    inventoryValue = calculateFifoInventoryValue(widget.inventoryList);
  }

  DateTime _startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  ({DateTime start, DateTime endExclusive}) _resolveSelectedRange() {
    // Half-open ranges include the start and exclude the next period's boundary.
    final now = DateTime.now();
    final endExclusive = _startOfDay(now).add(const Duration(days: 1));

    switch (selectedTimeFrame) {
      case AnalyticsTimeFrame.allTime:
        final allDates = [
          ...widget.inventoryList
              .expand((item) => item.salesList)
              .map((sale) => sale.date),
          ...widget.orderList.map((order) => order.date),
        ];
        final earliestDate = allDates.isEmpty
            ? DateTime(2000, 1, 1)
            : allDates.reduce(
                (earliest, date) => date.isBefore(earliest) ? date : earliest,
              );
        return (start: _startOfDay(earliestDate), endExclusive: endExclusive);
      case AnalyticsTimeFrame.daily:
        // Daily shows a single day based on offset
        final targetDay = _startOfDay(
          now.subtract(Duration(days: _periodOffset)),
        );
        return (
          start: targetDay,
          endExclusive: targetDay.add(const Duration(days: 1)),
        );
      case AnalyticsTimeFrame.weekToDate:
        // Week to Date: From Sunday of the target week to the last day of that week (or today)
        final referenceDate = now.subtract(Duration(days: _periodOffset * 7));
        final daysFromSunday = referenceDate.weekday % 7;
        final weekStart = _startOfDay(
          referenceDate.subtract(Duration(days: daysFromSunday)),
        );
        final weekEnd = weekStart.add(const Duration(days: 7));
        // If viewing current week (offset 0), end at today; otherwise end at Saturday
        final actualEnd = _periodOffset == 0 ? endExclusive : weekEnd;
        return (start: weekStart, endExclusive: actualEnd);
      case AnalyticsTimeFrame.weekly:
        // Weekly: Rolling 7 days based on offset
        final endDay = _startOfDay(now.subtract(Duration(days: _periodOffset)));
        final startDay = endDay.subtract(const Duration(days: 6));
        return (
          start: startDay,
          endExclusive: endDay.add(const Duration(days: 1)),
        );
      case AnalyticsTimeFrame.monthToDate:
        final targetMonth = DateTime(now.year, now.month - _periodOffset, 1);
        return (
          start: targetMonth,
          endExclusive: _periodOffset == 0
              ? endExclusive
              : DateTime(targetMonth.year, targetMonth.month + 1, 1),
        );
      case AnalyticsTimeFrame.monthly:
        // Monthly: Rolling 30 days based on offset
        final endDay = _startOfDay(now.subtract(Duration(days: _periodOffset)));
        final startDay = endDay.subtract(const Duration(days: 29));
        return (
          start: startDay,
          endExclusive: endDay.add(const Duration(days: 1)),
        );
      case AnalyticsTimeFrame.quarterly:
        final currentQuarter = ((now.month - 1) ~/ 3);
        final targetQuarter = currentQuarter - _periodOffset;
        final targetYear = now.year + (targetQuarter ~/ 4);
        final normalizedQuarter = targetQuarter % 4;
        final quarterStartMonth = normalizedQuarter * 3 + 1;
        final quarterStart = DateTime(targetYear, quarterStartMonth, 1);
        final quarterEnd = DateTime(targetYear, quarterStartMonth + 3, 1);
        return (
          start: quarterStart,
          endExclusive: _periodOffset == 0 ? endExclusive : quarterEnd,
        );
      case AnalyticsTimeFrame.yearly:
        final targetYear = now.year - _periodOffset;
        final yearStart = DateTime(targetYear, 1, 1);
        // If it's the current year, go to today; otherwise show full year
        final yearEnd = targetYear == now.year
            ? endExclusive
            : DateTime(targetYear + 1, 1, 1);
        return (start: yearStart, endExclusive: yearEnd);
      case AnalyticsTimeFrame.custom:
        final selectedRange =
            customDateRange ??
            DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
        return (
          start: _startOfDay(selectedRange.start),
          endExclusive: _startOfDay(
            selectedRange.end,
          ).add(const Duration(days: 1)),
        );
    }
  }

  bool _isInSelectedRange(DateTime date) {
    final range = _resolveSelectedRange();
    return !date.isBefore(range.start) && date.isBefore(range.endExclusive);
  }

  List<Sale> _getFilteredSales() {
    return widget.inventoryList
        .expand((item) => item.salesList)
        .where((sale) => _isInSelectedRange(sale.date))
        .toList();
  }

  List<Order> _getFilteredOrders() {
    return widget.orderList
        .where((order) => _isInSelectedRange(order.date))
        .toList();
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final initialRange =
        customDateRange ??
        DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);

    final pickedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: initialRange,
    );

    if (!mounted || pickedRange == null) {
      return;
    }

    setState(() {
      selectedTimeFrame = AnalyticsTimeFrame.custom;
      customDateRange = pickedRange;
      _calculateMetrics();
    });
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$month/$day/${date.year}';
  }

  String _selectedRangeLabel() {
    if (selectedTimeFrame == AnalyticsTimeFrame.allTime) {
      return 'All records';
    }

    final range = _resolveSelectedRange();
    final displayEnd = range.endExclusive.subtract(const Duration(days: 1));
    return '${_formatDate(range.start)} - ${_formatDate(displayEnd)}';
  }

  String _timeFrameLabel(AnalyticsTimeFrame timeFrame) {
    switch (timeFrame) {
      case AnalyticsTimeFrame.allTime:
        return 'All Time';
      case AnalyticsTimeFrame.daily:
        return 'Daily';
      case AnalyticsTimeFrame.weekToDate:
        return 'Week to Date';
      case AnalyticsTimeFrame.weekly:
        return 'Weekly';
      case AnalyticsTimeFrame.monthToDate:
        return 'Month to Date';
      case AnalyticsTimeFrame.monthly:
        return 'Monthly';
      case AnalyticsTimeFrame.quarterly:
        return 'Quarterly';
      case AnalyticsTimeFrame.yearly:
        return 'Yearly';
      case AnalyticsTimeFrame.custom:
        return 'Custom';
    }
  }

  void _setTimeFrame(AnalyticsTimeFrame timeFrame) {
    if (timeFrame == AnalyticsTimeFrame.custom) {
      _pickCustomRange();
      return;
    }

    setState(() {
      selectedTimeFrame = timeFrame;
      _periodOffset = 0; // Reset offset when changing time frame
      _calculateMetrics();
    });
  }

  bool _canNavigateTimeFrame() {
    return selectedTimeFrame == AnalyticsTimeFrame.daily ||
        selectedTimeFrame == AnalyticsTimeFrame.weekToDate ||
        selectedTimeFrame == AnalyticsTimeFrame.weekly ||
        selectedTimeFrame == AnalyticsTimeFrame.monthToDate ||
        selectedTimeFrame == AnalyticsTimeFrame.monthly ||
        selectedTimeFrame == AnalyticsTimeFrame.quarterly ||
        selectedTimeFrame == AnalyticsTimeFrame.yearly;
  }

  void _navigatePeriod(int direction) {
    setState(() {
      // Different timeframes navigate by different increments
      switch (selectedTimeFrame) {
        case AnalyticsTimeFrame.daily:
          _periodOffset -= direction;
          break;
        case AnalyticsTimeFrame.weekToDate:
          _periodOffset -= direction;
          break;
        case AnalyticsTimeFrame.weekly:
          _periodOffset -= direction * 7;
          break;
        case AnalyticsTimeFrame.monthToDate:
          _periodOffset -= direction;
          break;
        case AnalyticsTimeFrame.monthly:
          _periodOffset -= direction * 30;
          break;
        case AnalyticsTimeFrame.quarterly:
          _periodOffset -= direction;
          break;
        case AnalyticsTimeFrame.yearly:
          _periodOffset -= direction;
          break;
        default:
          _periodOffset -= direction;
      }
      if (_periodOffset < 0) _periodOffset = 0;
      _calculateMetrics();
    });
  }

  DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);

  int _daysBetween(DateTime start, DateTime endInclusive) {
    return _day(endInclusive).difference(_day(start)).inDays + 1;
  }

  List<DateTime> _generateDateBuckets() {
    final range = _resolveSelectedRange();
    final endInclusive = range.endExclusive.subtract(const Duration(days: 1));
    final totalDays = _daysBetween(range.start, endInclusive);

    return List.generate(
      totalDays,
      (index) => _day(range.start.add(Duration(days: index))),
    );
  }

  String _shortDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$month/$day';
  }

  Map<DateTime, double> _dailyRevenueByDate(
    DateTime start,
    DateTime endExclusive,
  ) {
    final daily = <DateTime, double>{};
    for (final item in widget.inventoryList) {
      for (final sale in item.salesList) {
        if (sale.date.isBefore(start) || !sale.date.isBefore(endExclusive)) {
          continue;
        }
        final day = _day(sale.date);
        daily[day] = (daily[day] ?? 0) + sale.price;
      }
    }
    return daily;
  }

  Map<DateTime, double> _dailyProfitByDate(
    DateTime start,
    DateTime endExclusive,
  ) {
    final daily = <DateTime, double>{};
    for (final item in widget.inventoryList) {
      for (final sale in item.salesList) {
        if (sale.date.isBefore(start) || !sale.date.isBefore(endExclusive)) {
          continue;
        }
        final day = _day(sale.date);
        daily[day] = (daily[day] ?? 0) + sale.profit;
      }
    }
    return daily;
  }

  Map<DateTime, double> _dailyExpensesByDate(
    DateTime start,
    DateTime endExclusive,
  ) {
    final daily = <DateTime, double>{};
    for (final order in widget.orderList) {
      if (order.date.isBefore(start) || !order.date.isBefore(endExclusive)) {
        continue;
      }
      final day = _day(order.date);
      daily[day] = (daily[day] ?? 0) + order.totalOrderPrice;
    }
    return daily;
  }

  List<_TimeSeriesPoint> _buildCumulativeSeries(
    Map<DateTime, double> dailyValues,
  ) {
    final buckets = _generateDateBuckets();
    double cumulative = 0;
    return buckets.map((date) {
      cumulative += dailyValues[date] ?? 0;
      return _TimeSeriesPoint(date: date, value: cumulative);
    }).toList();
  }

  List<_TimeSeriesPoint> _buildInventorySeries({required bool valueMode}) {
    final range = _resolveSelectedRange();
    final buckets = _generateDateBuckets();

    final baseQtyByItem = <String, int>{};
    for (final item in widget.inventoryList) {
      baseQtyByItem[item.id] = item.inventoryCount;
    }

    final totalShippedByItem = <String, int>{};
    for (final order in widget.orderList) {
      for (final orderItem in order.inventoryList) {
        final id = orderItem.inventoryItem.id;
        totalShippedByItem[id] =
            (totalShippedByItem[id] ?? 0) + orderItem.quantity;
      }
    }

    final totalSoldByItem = <String, int>{};
    for (final item in widget.inventoryList) {
      for (final sale in item.salesList) {
        totalSoldByItem[item.id] =
            (totalSoldByItem[item.id] ?? 0) + sale.quantity;
      }
    }

    for (final item in widget.inventoryList) {
      baseQtyByItem[item.id] =
          item.inventoryCount -
          (totalShippedByItem[item.id] ?? 0) +
          (totalSoldByItem[item.id] ?? 0);
    }

    final dailyDeltaByItem = <DateTime, Map<String, int>>{};

    for (final order in widget.orderList) {
      final day = _day(order.date);
      final byItem = dailyDeltaByItem.putIfAbsent(day, () => {});
      for (final orderItem in order.inventoryList) {
        final id = orderItem.inventoryItem.id;
        byItem[id] = (byItem[id] ?? 0) + orderItem.quantity;
      }
    }

    for (final item in widget.inventoryList) {
      for (final sale in item.salesList) {
        final day = _day(sale.date);
        final byItem = dailyDeltaByItem.putIfAbsent(day, () => {});
        byItem[item.id] = (byItem[item.id] ?? 0) - sale.quantity;
      }
    }

    final allDays = dailyDeltaByItem.keys.toList()..sort();
    final qtyAtStart = Map<String, int>.from(baseQtyByItem);

    for (final day in allDays) {
      if (!day.isBefore(range.start)) {
        break;
      }
      final deltaByItem = dailyDeltaByItem[day]!;
      deltaByItem.forEach((id, delta) {
        qtyAtStart[id] = (qtyAtStart[id] ?? 0) + delta;
      });
    }

    final points = <_TimeSeriesPoint>[];
    for (final day in buckets) {
      final deltaByItem = dailyDeltaByItem[day];
      if (deltaByItem != null) {
        deltaByItem.forEach((id, delta) {
          qtyAtStart[id] = (qtyAtStart[id] ?? 0) + delta;
        });
      }

      if (valueMode) {
        double totalValue = 0;
        for (final item in widget.inventoryList) {
          final remainingQty = qtyAtStart[item.id] ?? 0;
          totalValue += calculateFifoValueForQuantity(item, remainingQty);
        }
        points.add(_TimeSeriesPoint(date: day, value: totalValue));
      } else {
        int totalQty = 0;
        qtyAtStart.forEach((_, qty) {
          totalQty += qty;
        });
        points.add(_TimeSeriesPoint(date: day, value: totalQty.toDouble()));
      }
    }

    return points;
  }

  List<_TimeSeriesPoint> _selectedGraphSeries() {
    final range = _resolveSelectedRange();

    switch (selectedGraphType) {
      case AnalyticsGraphType.revenue:
        return _buildCumulativeSeries(
          _dailyRevenueByDate(range.start, range.endExclusive),
        );
      case AnalyticsGraphType.profit:
        return _buildCumulativeSeries(
          _dailyProfitByDate(range.start, range.endExclusive),
        );
      case AnalyticsGraphType.expenses:
        return _buildCumulativeSeries(
          _dailyExpensesByDate(range.start, range.endExclusive),
        );
      case AnalyticsGraphType.inventory:
        return _buildInventorySeries(valueMode: false);
      case AnalyticsGraphType.inventoryValue:
        return _buildInventorySeries(valueMode: true);
    }
  }

  String _graphLabel(AnalyticsGraphType graphType) {
    switch (graphType) {
      case AnalyticsGraphType.revenue:
        return 'Revenue';
      case AnalyticsGraphType.profit:
        return 'Profit';
      case AnalyticsGraphType.expenses:
        return 'Expenses';
      case AnalyticsGraphType.inventory:
        return 'Inventory';
      case AnalyticsGraphType.inventoryValue:
        return 'Inventory Value';
    }
  }

  Color _graphColor(AnalyticsGraphType graphType) {
    switch (graphType) {
      case AnalyticsGraphType.revenue:
        return const Color(0xFF27AE60);
      case AnalyticsGraphType.profit:
        return const Color(0xFF3498DB);
      case AnalyticsGraphType.expenses:
        return const Color(0xFFE74C3C);
      case AnalyticsGraphType.inventory:
        return const Color(0xFFF39C12);
      case AnalyticsGraphType.inventoryValue:
        return const Color(0xFF9B59B6);
    }
  }

  bool _isCurrencyGraph(AnalyticsGraphType graphType) {
    return graphType != AnalyticsGraphType.inventory;
  }

  Widget _buildGraphSection() {
    final points = _selectedGraphSeries();
    if (points.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
        ),
        child: const Center(
          child: Text(
            'No data available',
            style: TextStyle(
              color: Color(0xFF99A3AC),
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    final color = _graphColor(selectedGraphType);
    final isCurrency = _isCurrencyGraph(selectedGraphType);
    final spots = List.generate(points.length, (index) {
      final raw = points[index].value;
      final y = isCurrency ? (raw * 100).round() / 100.0 : raw;
      return FlSpot(index.toDouble(), y);
    });

    final maxY = spots.fold<double>(0, (max, spot) {
      return spot.y > max ? spot.y : max;
    });
    final rawInterval = maxY <= 0
        ? 1.0
        : (maxY / 5).clamp(1.0, double.infinity).toDouble();
    final interval = isCurrency
        ? (rawInterval * 100).round() / 100.0
        : rawInterval;
    final isDenseXAxis = points.length > 18;
    final targetLabelCount = isDenseXAxis ? 3 : 6;
    final labelStep = (points.length / targetLabelCount).ceil().clamp(
      1,
      points.length,
    );
    final bottomReservedSize = isDenseXAxis ? 60.0 : 34.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
      ),
      child: SizedBox(
        height: 320,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: true,
              horizontalInterval: interval,
              getDrawingHorizontalLine: (value) {
                return FlLine(color: const Color(0xFFE0E0E0), strokeWidth: 1);
              },
              getDrawingVerticalLine: (value) {
                return FlLine(color: const Color(0xFFE0E0E0), strokeWidth: 1);
              },
            ),
            titlesData: FlTitlesData(
              show: true,
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: bottomReservedSize,
                  interval: labelStep.toDouble(),
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= points.length) {
                      return const SizedBox.shrink();
                    }

                    final isBoundary =
                        index == 0 ||
                        index == points.length - 1 ||
                        index % labelStep == 0;
                    if (!isBoundary) {
                      return const SizedBox.shrink();
                    }

                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      space: 6,
                      child: Transform.rotate(
                        angle: isDenseXAxis ? -0.7 : 0,
                        child: Text(
                          _shortDate(points[index].date),
                          style: const TextStyle(
                            color: Color(0xFF99A3AC),
                            fontSize: 11,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: interval,
                  reservedSize: 58,
                  getTitlesWidget: (value, meta) {
                    final label = _isCurrencyGraph(selectedGraphType)
                        ? '\$${value.toStringAsFixed(2)}'
                        : value.toStringAsFixed(0);
                    return Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFF99A3AC),
                        fontSize: 11,
                      ),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(
              show: true,
              border: const Border(
                bottom: BorderSide(color: Color(0xFFE0E0E0), width: 1),
                left: BorderSide(color: Color(0xFFE0E0E0), width: 1),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.7)],
                ),
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.25),
                      color.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
            minX: 0,
            maxX: (points.length - 1).toDouble(),
            minY: 0,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF2C3E50),
        title: const Text('Analytics', style: TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timeframe selector
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFE0E0E0),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.date_range_outlined,
                          size: 18,
                          color: Color(0xFF99A3AC),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _timeFrameLabel(selectedTimeFrame),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF2C3E50),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        PopupMenuButton<AnalyticsTimeFrame>(
                          onSelected: _setTimeFrame,
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: AnalyticsTimeFrame.allTime,
                              child: Text('All Time'),
                            ),
                            const PopupMenuItem(
                              value: AnalyticsTimeFrame.daily,
                              child: Text('Daily'),
                            ),
                            const PopupMenuItem(
                              value: AnalyticsTimeFrame.weekToDate,
                              child: Text('Week to Date'),
                            ),
                            const PopupMenuItem(
                              value: AnalyticsTimeFrame.weekly,
                              child: Text('Weekly'),
                            ),
                            const PopupMenuItem(
                              value: AnalyticsTimeFrame.monthToDate,
                              child: Text('Month to Date'),
                            ),
                            const PopupMenuItem(
                              value: AnalyticsTimeFrame.monthly,
                              child: Text('Monthly'),
                            ),
                            const PopupMenuItem(
                              value: AnalyticsTimeFrame.quarterly,
                              child: Text('Quarterly'),
                            ),
                            const PopupMenuItem(
                              value: AnalyticsTimeFrame.yearly,
                              child: Text('Yearly'),
                            ),
                            const PopupMenuItem(
                              value: AnalyticsTimeFrame.custom,
                              child: Text('Custom'),
                            ),
                          ],
                          child: const Row(
                            children: [
                              Text(
                                'Change',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF3498DB),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.expand_more,
                                size: 16,
                                color: Color(0xFF3498DB),
                              ),
                            ],
                          ),
                        ),
                        if (selectedTimeFrame == AnalyticsTimeFrame.custom)
                          IconButton(
                            onPressed: _pickCustomRange,
                            icon: const Icon(
                              Icons.edit_calendar_outlined,
                              size: 18,
                              color: Color(0xFF99A3AC),
                            ),
                            splashRadius: 18,
                            tooltip: 'Change custom range',
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        _selectedRangeLabel(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF99A3AC),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_canNavigateTimeFrame()) ...[
                        const Spacer(),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => _navigatePeriod(-1),
                              icon: const Icon(Icons.arrow_back_ios, size: 16),
                              color: const Color(0xFF3498DB),
                              splashRadius: 20,
                              tooltip: 'Previous period',
                              padding: const EdgeInsets.all(8),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: _periodOffset > 0
                                  ? () => _navigatePeriod(1)
                                  : null,
                              icon: const Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                              ),
                              color: _periodOffset > 0
                                  ? const Color(0xFF3498DB)
                                  : const Color(0xFFCCCCCC),
                              splashRadius: 20,
                              tooltip: 'Next period',
                              padding: const EdgeInsets.all(8),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Key Metrics Section
                  const Text(
                    'Key Metrics',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          title: 'Revenue',
                          value: '\$${totalRevenue.toStringAsFixed(2)}',
                          icon: Icons.trending_up,
                          backgroundColor: const Color(0xFF27AE60),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricCard(
                          title: 'Profit',
                          value: '\$${totalProfit.toStringAsFixed(2)}',
                          icon: Icons.monetization_on,
                          backgroundColor: const Color(0xFF3498DB),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          title: 'Expenses',
                          value: '\$${totalExpenses.toStringAsFixed(2)}',
                          icon: Icons.receipt,
                          backgroundColor: const Color(0xFFE74C3C),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricCard(
                          title: 'Inventory Items',
                          value: totalInventoryCount.toString(),
                          icon: Icons.inventory_2,
                          backgroundColor: const Color(0xFFF39C12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildMetricCard(
                    title: 'Inventory Value',
                    value: '\$${inventoryValue.toStringAsFixed(2)}',
                    icon: Icons.assessment,
                    backgroundColor: const Color(0xFF9B59B6),
                  ),
                  const SizedBox(height: 32),

                  Row(
                    children: [
                      const Text(
                        'Graph',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFFE0E0E0),
                              width: 1,
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<AnalyticsGraphType>(
                              value: selectedGraphType,
                              isExpanded: true,
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() {
                                  selectedGraphType = value;
                                });
                              },
                              items: AnalyticsGraphType.values
                                  .map(
                                    (graph) => DropdownMenuItem(
                                      value: graph,
                                      child: Text(_graphLabel(graph)),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${_graphLabel(selectedGraphType)} Trend',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildGraphSection(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color backgroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [backgroundColor, backgroundColor.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Icon(icon, color: Colors.white, size: 24),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
