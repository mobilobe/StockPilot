import 'package:flutter/material.dart';
import 'package:inventory/services/hive_firestore_migration_service.dart';
import 'package:inventory/features/backup_sync/screens/backup_sync_page.dart';
import 'package:inventory/features/reports/screens/download_page.dart';
import 'package:inventory/models/inventory_item.dart';
import 'package:inventory/models/sale.dart';
import 'package:inventory/models/order.dart';

class QuarterlyReportsPage extends StatelessWidget {
  final List<InventoryItem> inventoryList;
  final List<Sale> saleList;
  final List<Order> orderList;
  final void Function(List<InventoryItem>, List<Order>)? onInventoryImported;

  const QuarterlyReportsPage({
    required this.inventoryList,
    required this.saleList,
    required this.orderList,
    this.onInventoryImported,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final quarters = _buildQuarterPeriods(saleList, orderList);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF2C3E50),
        title: const Text(
          'Quarterly Reports',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            tooltip: 'Back up and sync inventory',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BackupSyncPage(
                    onMigrationVerified: (userId) async {
                      final result = await HiveFirestoreMigrationService()
                          .migrateInventory(userId);
                      return result == MigrationResult.verified;
                    },
                  ),
                ),
              );
            },
            icon: const Icon(Icons.cloud_sync_outlined, color: Colors.white),
          ),
          IconButton(
            tooltip: 'Download Reports',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DownloadPage(
                    inventoryList: inventoryList,
                    saleList: saleList,
                    orderList: orderList,
                    onInventoryImported: onInventoryImported,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.download_outlined, color: Colors.white),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: quarters.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final quarter = quarters[index];
              return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _QuarterlyReportDetailPage(
                          quarter: quarter,
                          inventoryList: inventoryList,
                          saleList: saleList,
                          orderList: orderList,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFE0E0E0),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.description_outlined,
                          color: Color(0xFF3498DB),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            quarter.label,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: Color(0xFF99A3AC),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _QuarterlyReportDetailPage extends StatelessWidget {
  final _QuarterPeriod quarter;
  final List<InventoryItem> inventoryList;
  final List<Sale> saleList;
  final List<Order> orderList;

  const _QuarterlyReportDetailPage({
    required this.quarter,
    required this.inventoryList,
    required this.saleList,
    required this.orderList,
  });

  @override
  Widget build(BuildContext context) {
    final report = _buildQuarterReport(
      quarter: quarter,
      inventoryList: inventoryList,
      saleList: saleList,
      orderList: orderList,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF2C3E50),
        title: Text(quarter.label, style: const TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryHeader(report),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth >= 980
                        ? 4
                        : constraints.maxWidth >= 680
                        ? 3
                        : 2;

                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 2.25,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _metricTile(
                          'Revenue',
                          '\$${report.revenue.toStringAsFixed(2)}',
                        ),
                        _metricTile(
                          'Cost of Goods Sold',
                          '\$${report.cogs.toStringAsFixed(2)}',
                        ),
                        _metricTile(
                          'Starting Inventory',
                          '${report.startingInventory} units',
                        ),
                        _metricTile(
                          'Ending Inventory',
                          '${report.endingInventory} units',
                        ),
                        _metricTile(
                          'Starting Inventory Value',
                          '\$${report.startingInventoryValue.toStringAsFixed(2)}',
                        ),
                        _metricTile(
                          'Ending Inventory Value',
                          '\$${report.endingInventoryValue.toStringAsFixed(2)}',
                        ),
                        _metricTile(
                          'Total Inventory Value Change',
                          '${report.inventoryValueChange >= 0 ? '+' : ''}\$${report.inventoryValueChange.toStringAsFixed(2)}',
                        ),
                        _metricTile(
                          'Profit',
                          '\$${report.profit.toStringAsFixed(2)}',
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                _buildDropdownSection(
                  context: context,
                  title: 'Sales Made',
                  child: report.sales.isEmpty
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFE0E0E0),
                              width: 1,
                            ),
                          ),
                          child: const Text(
                            'No sales in this quarter.',
                            style: TextStyle(
                              color: Color(0xFF99A3AC),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        )
                      : Column(
                          children: report.sales.map((sale) {
                            final hasBreakdown = sale.priceBreakdown.isNotEmpty;

                            return Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE0E0E0),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF2C3E50,
                                    ).withValues(alpha: 0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Theme(
                                data: Theme.of(context).copyWith(
                                  dividerColor: Colors.transparent,
                                  splashColor: Colors.transparent,
                                  highlightColor: Colors.transparent,
                                ),
                                child: ExpansionTile(
                                  tilePadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 6,
                                  ),
                                  childrenPadding: const EdgeInsets.fromLTRB(
                                    14,
                                    0,
                                    14,
                                    12,
                                  ),
                                  iconColor: const Color(0xFF3498DB),
                                  collapsedIconColor: const Color(0xFF99A3AC),
                                  title: Row(
                                    children: [
                                      Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF3498DB,
                                          ).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.point_of_sale_outlined,
                                          size: 16,
                                          color: Color(0xFF3498DB),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        _formatDate(sale.date),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF2C3E50),
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        _saleChip('${sale.quantity} units'),
                                        _saleChip(
                                          '\$${sale.price.toStringAsFixed(2)}',
                                        ),
                                        _saleChip(
                                          'Profit \$${sale.profit.toStringAsFixed(2)}',
                                          accent: true,
                                        ),
                                      ],
                                    ),
                                  ),
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFD),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: const Color(0xFFE6ECF2),
                                          width: 1,
                                        ),
                                      ),
                                      child: !hasBreakdown
                                          ? const Align(
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                'No line-item breakdown available.',
                                                style: TextStyle(
                                                  color: Color(0xFF99A3AC),
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            )
                                          : Column(
                                              children: [
                                                const Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        'Source',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: Color(
                                                            0xFF99A3AC,
                                                          ),
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                    ),
                                                    Text(
                                                      'Qty × Price',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Color(
                                                          0xFF99A3AC,
                                                        ),
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                    SizedBox(width: 10),
                                                    Text(
                                                      'Subtotal',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Color(
                                                          0xFF99A3AC,
                                                        ),
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                ...sale.priceBreakdown.map((
                                                  lineItem,
                                                ) {
                                                  final subtotal =
                                                      lineItem.quantity *
                                                      lineItem.unitPrice;

                                                  return Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          bottom: 8,
                                                        ),
                                                    child: Row(
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            lineItem.source,
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 12,
                                                                  color: Color(
                                                                    0xFF2C3E50,
                                                                  ),
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                          ),
                                                        ),
                                                        Text(
                                                          '${lineItem.quantity} × \$${lineItem.unitPrice.toStringAsFixed(2)}',
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 12,
                                                                color: Color(
                                                                  0xFF99A3AC,
                                                                ),
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          width: 10,
                                                        ),
                                                        Text(
                                                          '\$${subtotal.toStringAsFixed(2)}',
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 12,
                                                                color: Color(
                                                                  0xFF3498DB,
                                                                ),
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                }),
                                              ],
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                ),
                const SizedBox(height: 12),
                _buildDropdownSection(
                  context: context,
                  title: 'All Orders Made',
                  child: report.orders.isEmpty
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFE0E0E0),
                              width: 1,
                            ),
                          ),
                          child: const Text(
                            'No orders in this quarter.',
                            style: TextStyle(
                              color: Color(0xFF99A3AC),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        )
                      : Column(
                          children: report.orders.map((order) {
                            final totalUnits = order.inventoryList.fold<int>(
                              0,
                              (sum, item) => sum + item.quantity,
                            );
                            return Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE0E0E0),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _formatDate(order.date),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF2C3E50),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '$totalUnits units',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF99A3AC),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '\$${order.totalOrderPrice.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFFE74C3C),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryHeader(_QuarterReport report) {
    final isPositive = report.profit >= 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF3498DB).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.assessment_outlined,
              color: Color(0xFF3498DB),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Quarter Financial Snapshot',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2C3E50),
              ),
            ),
          ),
          Text(
            '${isPositive ? '+' : ''}\$${report.profit.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isPositive
                  ? const Color(0xFF1E9E59)
                  : const Color(0xFFE74C3C),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricTile(String title, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF99A3AC),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF2C3E50),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _saleChip(String text, {bool accent = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent
            ? const Color(0xFF3498DB).withValues(alpha: 0.12)
            : const Color(0xFFF1F4F8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: accent ? const Color(0xFF3498DB) : const Color(0xFF6F7D8B),
        ),
      ),
    );
  }

  Widget _buildDropdownSection({
    required BuildContext context,
    required String title,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          collapsedIconColor: const Color(0xFF99A3AC),
          iconColor: const Color(0xFF3498DB),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          children: [child],
        ),
      ),
    );
  }
}

class _QuarterPeriod {
  final int year;
  final int quarter;
  final DateTime start;
  final DateTime endExclusive;

  _QuarterPeriod({
    required this.year,
    required this.quarter,
    required this.start,
    required this.endExclusive,
  });

  String get label => 'Q$quarter $year Report';
}

class _QuarterReport {
  final double revenue;
  final double cogs;
  final int startingInventory;
  final int endingInventory;
  final double startingInventoryValue;
  final double endingInventoryValue;
  final double inventoryValueChange;
  final double profit;
  final List<Sale> sales;
  final List<Order> orders;

  _QuarterReport({
    required this.revenue,
    required this.cogs,
    required this.startingInventory,
    required this.endingInventory,
    required this.startingInventoryValue,
    required this.endingInventoryValue,
    required this.inventoryValueChange,
    required this.profit,
    required this.sales,
    required this.orders,
  });
}

List<_QuarterPeriod> _buildQuarterPeriods(
  List<Sale> sales,
  List<Order> orders,
) {
  final now = DateTime.now();
  final allDates = [
    ...sales.map((sale) => sale.date),
    ...orders.map((order) => order.date),
    now,
  ];

  final minDate = allDates.reduce(
    (min, date) => date.isBefore(min) ? date : min,
  );
  final maxDate = allDates.reduce(
    (max, date) => date.isAfter(max) ? date : max,
  );

  DateTime quarterStart(DateTime date) {
    final month = ((date.month - 1) ~/ 3) * 3 + 1;
    return DateTime(date.year, month, 1);
  }

  final start = quarterStart(minDate);
  final end = quarterStart(maxDate);

  final periods = <_QuarterPeriod>[];
  DateTime cursor = start;
  while (!cursor.isAfter(end)) {
    final quarter = ((cursor.month - 1) ~/ 3) + 1;
    periods.add(
      _QuarterPeriod(
        year: cursor.year,
        quarter: quarter,
        start: cursor,
        endExclusive: DateTime(cursor.year, cursor.month + 3, 1),
      ),
    );
    cursor = DateTime(cursor.year, cursor.month + 3, 1);
  }

  return periods.reversed.toList();
}

_QuarterReport _buildQuarterReport({
  required _QuarterPeriod quarter,
  required List<InventoryItem> inventoryList,
  required List<Sale> saleList,
  required List<Order> orderList,
}) {
  final quarterSales =
      saleList
          .where(
            (sale) =>
                !sale.date.isBefore(quarter.start) &&
                sale.date.isBefore(quarter.endExclusive),
          )
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));

  final quarterOrders =
      orderList
          .where(
            (order) =>
                !order.date.isBefore(quarter.start) &&
                order.date.isBefore(quarter.endExclusive),
          )
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));

  final revenue = quarterSales.fold<double>(0, (sum, sale) => sum + sale.price);
  final profit = quarterSales.fold<double>(0, (sum, sale) => sum + sale.profit);
  final cogs = revenue - profit;

  final startingInventory = _inventoryUnitsAt(
    date: quarter.start,
    inventoryList: inventoryList,
    orderList: orderList,
  );
  final endingInventory = _inventoryUnitsAt(
    date: quarter.endExclusive,
    inventoryList: inventoryList,
    orderList: orderList,
  );
  final startingInventoryValue = _inventoryValueAt(
    date: quarter.start,
    inventoryList: inventoryList,
    orderList: orderList,
  );
  final endingInventoryValue = _inventoryValueAt(
    date: quarter.endExclusive,
    inventoryList: inventoryList,
    orderList: orderList,
  );
  final inventoryValueChange = endingInventoryValue - startingInventoryValue;

  return _QuarterReport(
    revenue: revenue,
    cogs: cogs,
    startingInventory: startingInventory,
    endingInventory: endingInventory,
    startingInventoryValue: startingInventoryValue,
    endingInventoryValue: endingInventoryValue,
    inventoryValueChange: inventoryValueChange,
    profit: profit,
    sales: quarterSales,
    orders: quarterOrders,
  );
}

int _inventoryUnitsAt({
  required DateTime date,
  required List<InventoryItem> inventoryList,
  required List<Order> orderList,
}) {
  final quantitiesAtDate = _inventoryQuantitiesAt(
    date: date,
    inventoryList: inventoryList,
    orderList: orderList,
  );

  return quantitiesAtDate.values.fold<int>(0, (sum, qty) => sum + qty);
}

double _inventoryValueAt({
  required DateTime date,
  required List<InventoryItem> inventoryList,
  required List<Order> orderList,
}) {
  final quantitiesAtDate = _inventoryQuantitiesAt(
    date: date,
    inventoryList: inventoryList,
    orderList: orderList,
  );

  final itemPriceById = <String, double>{
    for (final item in inventoryList) item.id: item.price,
  };

  return quantitiesAtDate.entries.fold<double>(0, (sum, entry) {
    final unitPrice = itemPriceById[entry.key] ?? 0;
    return sum + (entry.value * unitPrice);
  });
}

Map<String, int> _inventoryQuantitiesAt({
  required DateTime date,
  required List<InventoryItem> inventoryList,
  required List<Order> orderList,
}) {
  DateTime day(DateTime value) => DateTime(value.year, value.month, value.day);

  final baseQtyByItem = <String, int>{
    for (final item in inventoryList) item.id: item.inventoryCount,
  };

  final totalShippedByItem = <String, int>{};
  for (final order in orderList) {
    for (final orderItem in order.inventoryList) {
      final id = orderItem.inventoryItem.id;
      totalShippedByItem[id] =
          (totalShippedByItem[id] ?? 0) + orderItem.quantity;
    }
  }

  final totalSoldByItem = <String, int>{};
  for (final item in inventoryList) {
    for (final sale in item.salesList) {
      totalSoldByItem[item.id] =
          (totalSoldByItem[item.id] ?? 0) + sale.quantity;
    }
  }

  for (final item in inventoryList) {
    baseQtyByItem[item.id] =
        item.inventoryCount -
        (totalShippedByItem[item.id] ?? 0) +
        (totalSoldByItem[item.id] ?? 0);
  }

  final dailyDeltaByItem = <DateTime, Map<String, int>>{};

  for (final order in orderList) {
    final orderDay = day(order.date);
    final byItem = dailyDeltaByItem.putIfAbsent(orderDay, () => {});
    for (final orderItem in order.inventoryList) {
      final id = orderItem.inventoryItem.id;
      byItem[id] = (byItem[id] ?? 0) + orderItem.quantity;
    }
  }

  for (final item in inventoryList) {
    for (final sale in item.salesList) {
      final saleDay = day(sale.date);
      final byItem = dailyDeltaByItem.putIfAbsent(saleDay, () => {});
      byItem[item.id] = (byItem[item.id] ?? 0) - sale.quantity;
    }
  }

  final qtyAtDate = Map<String, int>.from(baseQtyByItem);
  final targetDay = day(date);
  final allDays = dailyDeltaByItem.keys.toList()..sort();

  for (final changeDay in allDays) {
    if (!changeDay.isBefore(targetDay)) {
      break;
    }
    final deltas = dailyDeltaByItem[changeDay]!;
    deltas.forEach((id, delta) {
      qtyAtDate[id] = (qtyAtDate[id] ?? 0) + delta;
    });
  }

  return qtyAtDate;
}

String _formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$month/$day/${date.year}';
}
