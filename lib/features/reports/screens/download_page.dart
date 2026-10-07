import 'dart:io';
import 'dart:math';

import 'package:excel/excel.dart' as ex;
import 'package:file_saver/file_saver.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory/models/inventory_order_item.dart';
import 'package:inventory/models/inventory_item.dart';
import 'package:inventory/models/sale_line_item.dart';
import 'package:inventory/models/sale.dart';
import 'package:inventory/models/order.dart';
import 'package:path_provider/path_provider.dart';

class DownloadPage extends StatefulWidget {
  final List<InventoryItem> inventoryList;
  final List<Sale> saleList;
  final List<Order> orderList;
  final void Function(List<InventoryItem>, List<Order>)? onInventoryImported;

  const DownloadPage({
    required this.inventoryList,
    required this.saleList,
    required this.orderList,
    this.onInventoryImported,
    super.key,
  });

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  final Set<_ExportType> _activeExports = <_ExportType>{};
  bool _isImporting = false;

  @override
  Widget build(BuildContext context) {
    final exports = <_ExportOption>[
      const _ExportOption(
        type: _ExportType.saleHistory,
        title: 'Sale History',
        subtitle:
            'Export all recorded sales transactions including quantity, date, and amount.',
        icon: Icons.point_of_sale_outlined,
      ),
      const _ExportOption(
        type: _ExportType.orderHistory,
        title: 'Order History',
        subtitle:
            'Export incoming order logs with item details, quantity, and order dates.',
        icon: Icons.local_shipping_outlined,
      ),
      const _ExportOption(
        type: _ExportType.inventorySnapshot,
        title: 'Inventory Stock & Sales Snapshot',
        subtitle:
            'Export all inventory items with current stock levels and total sales performance.',
        icon: Icons.inventory_2_outlined,
      ),
      const _ExportOption(
        type: _ExportType.quarterlyReports,
        title: 'Quarterly Reports',
        subtitle:
            'Export quarterly summaries including revenue, COGS, inventory value, and profit.',
        icon: Icons.bar_chart_outlined,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF2C3E50),
        title: const Text(
          'Download Data',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF27AE60).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.grid_on_outlined,
                        color: Color(0xFF27AE60),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Export as Excel (.xlsx)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Choose a dataset below to generate and save an Excel file.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF66717A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ...exports.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ExportCard(
                    option: item,
                    isExporting: _activeExports.contains(item.type),
                    onDownload: () => _handleDownload(item.type),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8E44AD).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.upload_file_outlined,
                        color: Color(0xFF8E44AD),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Import from Excel (.xlsx)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Select an exported workbook to import inventory, sales summaries, and order/input-transfer records.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF66717A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _ImportCard(
                isImporting: _isImporting,
                canImport: widget.onInventoryImported != null,
                onImport: _handleImport,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleDownload(_ExportType type) async {
    if (_activeExports.contains(type)) {
      return;
    }

    setState(() {
      _activeExports.add(type);
    });

    try {
      final workbook = ex.Excel.createExcel();
      late final String filePrefix;

      switch (type) {
        case _ExportType.saleHistory:
          _buildSaleHistorySheet(workbook);
          filePrefix = 'sale_history';
          break;
        case _ExportType.orderHistory:
          _buildOrderHistorySheet(workbook);
          filePrefix = 'order_history';
          break;
        case _ExportType.inventorySnapshot:
          _buildInventorySnapshotSheet(workbook);
          filePrefix = 'inventory_snapshot';
          break;
        case _ExportType.quarterlyReports:
          _buildQuarterlyReportsSheet(workbook);
          filePrefix = 'quarterly_reports';
          break;
      }

      final bytes = workbook.encode();
      if (bytes == null) {
        throw Exception('Unable to generate Excel file.');
      }

      final filePath = await _saveBytesToFile(bytes, filePrefix: filePrefix);
      if (filePath == null) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Export cancelled.'),
            backgroundColor: Color(0xFF66717A),
          ),
        );
        return;
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Excel downloaded: $filePath. It may take a few minutes before this file can be imported again.',
          ),
          backgroundColor: const Color(0xFF27AE60),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $error'),
          backgroundColor: const Color(0xFFE74C3C),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _activeExports.remove(type);
        });
      }
    }
  }

  Future<String?> _saveBytesToFile(
    List<int> bytes, {
    required String filePrefix,
  }) async {
    final timestamp = _formatTimestamp(DateTime.now());
    final baseName = '$filePrefix-$timestamp';
    final fileBytes = Uint8List.fromList(bytes);

    if (kIsWeb) {
      await FileSaver.instance.saveFile(
        name: baseName,
        bytes: fileBytes,
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );
      return '$baseName.xlsx';
    }

    if (Platform.isAndroid) {
      const platform = MethodChannel(
        'app.ScaleStackLabs.StockPilot/file_saver',
      );
      try {
        final result = await platform.invokeMethod('saveFileWithPicker', {
          'fileName': '$baseName.xlsx',
          'bytes': fileBytes,
          'mimeType':
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        });
        return result as String?;
      } on PlatformException catch (e) {
        debugPrint('Error saving file on Android: ${e.message}');
        rethrow;
      }
    }

    if (Platform.isIOS) {
      try {
        final path = await FileSaver.instance.saveAs(
          name: baseName,
          bytes: fileBytes,
          fileExtension: 'xlsx',
          mimeType: MimeType.microsoftExcel,
        );
        return path;
      } catch (e) {
        debugPrint('Error saving file on iOS: $e');
        rethrow;
      }
    }

    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      try {
        final location = await getSaveLocation(
          suggestedName: '$baseName.xlsx',
          acceptedTypeGroups: const [
            XTypeGroup(label: 'Excel Workbook', extensions: ['xlsx']),
          ],
        );

        if (location == null) {
          return null;
        }

        var filePath = location.path;
        if (!filePath.toLowerCase().endsWith('.xlsx')) {
          filePath = '$filePath.xlsx';
        }

        final file = File(filePath);
        await file.writeAsBytes(bytes, flush: true);
        return file.path;
      } catch (e) {
        debugPrint('Error saving file: $e');
      }
    }

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$baseName.xlsx');
    await file.writeAsBytes(fileBytes, flush: true);
    return file.path;
  }

  void _buildSaleHistorySheet(ex.Excel workbook) {
    final sheet = workbook['Sale History'];
    _writeRow(sheet, 0, const [
      'No.',
      'Date',
      'Quantity',
      'Revenue',
      'Profit',
      'COGS',
      'Breakdown Lines',
    ]);

    for (var index = 0; index < widget.saleList.length; index++) {
      final sale = widget.saleList[index];
      final cogs = sale.price - sale.profit;
      _writeRow(sheet, index + 1, [
        '${index + 1}',
        _formatDateTime(sale.date),
        '${sale.quantity}',
        sale.price.toStringAsFixed(2),
        sale.profit.toStringAsFixed(2),
        cogs.toStringAsFixed(2),
        '${sale.priceBreakdown.length}',
      ]);
    }
  }

  void _buildOrderHistorySheet(ex.Excel workbook) {
    final sheet = workbook['Order History'];
    _writeRow(sheet, 0, const [
      'Order No.',
      'Date',
      'Item Name',
      'SKU',
      'Quantity',
      'Unit Cost',
      'Line Cost',
      'Shipping',
      'Fees',
      'Order Total',
    ]);

    var rowIndex = 1;
    final orders = _ordersForExport();
    for (var orderIndex = 0; orderIndex < orders.length; orderIndex++) {
      final order = orders[orderIndex];

      if (order.inventoryList.isEmpty) {
        _writeRow(sheet, rowIndex, [
          '${orderIndex + 1}',
          _formatDateTime(order.date),
          'No Items',
          '-',
          '0',
          '0.00',
          '0.00',
          order.shipping.toStringAsFixed(2),
          order.fees.toStringAsFixed(2),
          order.totalOrderPrice.toStringAsFixed(2),
        ]);
        rowIndex++;
        continue;
      }

      for (final item in order.inventoryList) {
        final unitCost = item.shippedPrice;
        final lineCost = unitCost * item.quantity;
        _writeRow(sheet, rowIndex, [
          '${orderIndex + 1}',
          _formatDateTime(order.date),
          item.inventoryItem.name,
          item.inventoryItem.sku,
          '${item.quantity}',
          unitCost.toStringAsFixed(2),
          lineCost.toStringAsFixed(2),
          order.shipping.toStringAsFixed(2),
          order.fees.toStringAsFixed(2),
          order.totalOrderPrice.toStringAsFixed(2),
        ]);
        rowIndex++;
      }
    }
  }

  void _buildInventorySnapshotSheet(ex.Excel workbook) {
    final inventorySheet = workbook['Inventory Items'];
    _writeRow(inventorySheet, 0, const [
      'Item ID',
      'Item Name',
      'SKU',
      'Folder',
      'Current Stock',
      'Sold Units',
      'Unit Price',
      'Stock Value',
      'Sales Count',
      'Revenue From Sales',
      'Profit From Sales',
      'Orders Count',
      'Has Variants',
    ]);

    for (var index = 0; index < widget.inventoryList.length; index++) {
      final item = widget.inventoryList[index];
      final revenue = item.salesList.fold<double>(
        0,
        (total, sale) => total + sale.price,
      );
      final profit = item.salesList.fold<double>(
        0,
        (total, sale) => total + sale.profit,
      );
      final stockValue = _fifoItemValue(item);

      _writeRow(inventorySheet, index + 1, [
        item.id,
        item.name,
        item.sku,
        item.folder,
        '${item.inventoryCount}',
        '${item.soldCount}',
        item.price.toStringAsFixed(2),
        stockValue.toStringAsFixed(2),
        '${item.salesList.length}',
        revenue.toStringAsFixed(2),
        profit.toStringAsFixed(2),
        '${item.orderList.length}',
        item.hasVariants ? 'Yes' : 'No',
      ]);
    }

    final salesSheet = workbook['Sale Details'];
    _writeRow(salesSheet, 0, const [
      'Item ID',
      'Item Name',
      'Sale Date',
      'Quantity Sold',
      'Total Price',
      'Total Profit',
      'COGS',
      'Breakdown Lines',
      'Sale ID',
    ]);

    var salesRowIndex = 1;
    for (final item in widget.inventoryList) {
      for (final sale in item.salesList) {
        final cogs = sale.price - sale.profit;
        _writeRow(salesSheet, salesRowIndex, [
          item.id,
          item.name,
          _formatDateTime(sale.date),
          '${sale.quantity}',
          sale.price.toStringAsFixed(2),
          sale.profit.toStringAsFixed(2),
          cogs.toStringAsFixed(2),
          '${sale.priceBreakdown.length}',
          sale.id,
        ]);
        salesRowIndex++;
      }
    }

    final saleLineSheet = workbook['Sale Line Items'];
    _writeRow(saleLineSheet, 0, const [
      'Item ID',
      'Item Name',
      'Sale Date',
      'Line Quantity',
      'Line Unit Price',
      'Line Source',
      'Sale ID',
    ]);

    var saleLineRowIndex = 1;
    for (final item in widget.inventoryList) {
      for (final sale in item.salesList) {
        for (final lineItem in sale.priceBreakdown) {
          _writeRow(saleLineSheet, saleLineRowIndex, [
            item.id,
            item.name,
            _formatDateTime(sale.date),
            '${lineItem.quantity}',
            lineItem.unitPrice.toStringAsFixed(2),
            lineItem.source,
            sale.id,
          ]);
          saleLineRowIndex++;
        }
      }
    }

    final ordersSheet = workbook['Order Details'];
    _writeRow(ordersSheet, 0, const [
      'Item ID',
      'Item Name',
      'Order Date',
      'Quantity Ordered',
      'Unit Cost',
      'Line Cost',
      'Order Shipping',
      'Order Fees',
      'Order Total',
      'Folder',
      'Is Input/Transfer',
      'Order ID',
    ]);

    var ordersRowIndex = 1;
    for (final order in _ordersForExport().where(
      (order) => !order.isInputTransfer,
    )) {
      for (final orderItem in order.inventoryList) {
        final item = orderItem.inventoryItem;
        final lineCost = orderItem.quantity * orderItem.shippedPrice;
        _writeRow(ordersSheet, ordersRowIndex, [
          item.id,
          item.name,
          _formatDateTime(order.date),
          '${orderItem.quantity}',
          orderItem.shippedPrice.toStringAsFixed(2),
          lineCost.toStringAsFixed(2),
          order.shipping.toStringAsFixed(2),
          order.fees.toStringAsFixed(2),
          order.totalOrderPrice.toStringAsFixed(2),
          order.folder,
          'No',
          order.id,
        ]);
        ordersRowIndex++;
      }
    }

    final transfersSheet = workbook['Transfer Details'];
    _writeRow(transfersSheet, 0, const [
      'Transfer Date',
      'Source Item ID',
      'Source Item Name',
      'Source Variant',
      'Dest Item ID',
      'Dest Item Name',
      'Dest Variant',
      'Quantity',
      'Unit Cost',
      'Total Cost',
      'Shipping',
      'Fees',
      'Order Total',
    ]);

    var transfersRowIndex = 1;
    for (final order in _ordersForExport().where(
      (order) => order.isInputTransfer,
    )) {
      _writeRow(transfersSheet, transfersRowIndex, [
        _formatDateTime(order.date),
        order.transferSourceItemId ?? '',
        order.transferSourceItemName ?? '',
        order.transferSourceVariant ?? '',
        order.transferDestinationItemId ?? '',
        order.transferDestinationItemName ?? '',
        order.transferDestinationVariant ?? '',
        '${order.transferQuantity ?? 0}',
        (order.transferUnitCost ?? 0.0).toStringAsFixed(2),
        ((order.transferQuantity ?? 0) * (order.transferUnitCost ?? 0.0))
            .toStringAsFixed(2),
        order.shipping.toStringAsFixed(2),
        order.fees.toStringAsFixed(2),
        order.totalOrderPrice.toStringAsFixed(2),
      ]);
      transfersRowIndex++;
    }

    final hasAnyVariants = widget.inventoryList.any((item) => item.hasVariants);
    if (hasAnyVariants) {
      final variantsSheet = workbook['Variant Stock'];
      _writeRow(variantsSheet, 0, const [
        'Item ID',
        'Item Name',
        'Variant Value',
        'Variant Stock',
      ]);

      var variantsRowIndex = 1;
      for (final item in widget.inventoryList) {
        if (item.hasVariants) {
          for (final variantValue in item.variantValues) {
            final stock = item.variantStock[variantValue] ?? 0;
            _writeRow(variantsSheet, variantsRowIndex, [
              item.id,
              item.name,
              variantValue,
              '$stock',
            ]);
            variantsRowIndex++;
          }
        }
      }
    }
  }

  List<Order> _ordersForExport() {
    final orders = <Order>[];
    final seenIds = <String>{};

    void addOrder(Order order) {
      if (seenIds.add(order.id)) {
        orders.add(order);
      }
    }

    for (final order in widget.orderList) {
      addOrder(order);
    }
    for (final item in widget.inventoryList) {
      for (final order in item.orderList) {
        addOrder(order);
      }
    }
    return orders;
  }

  void _buildQuarterlyReportsSheet(ex.Excel workbook) {
    final sheet = workbook['Quarterly Reports'];
    _writeRow(sheet, 0, const [
      'Quarter',
      'Sales Count',
      'Orders Count',
      'Units Sold',
      'Revenue',
      'COGS',
      'Profit',
      'Order Costs',
    ]);

    final periods = _buildQuarterPeriods(widget.saleList, widget.orderList);
    for (var index = 0; index < periods.length; index++) {
      final period = periods[index];
      final sales = widget.saleList
          .where((sale) => _isInRange(sale.date, period.start, period.end))
          .toList();
      final orders = widget.orderList
          .where((order) => _isInRange(order.date, period.start, period.end))
          .toList();

      final revenue = sales.fold<double>(
        0,
        (total, sale) => total + sale.price,
      );
      final profit = sales.fold<double>(
        0,
        (total, sale) => total + sale.profit,
      );
      final cogs = revenue - profit;
      final unitsSold = sales.fold<int>(
        0,
        (total, sale) => total + sale.quantity,
      );
      final orderCosts = orders.fold<double>(
        0,
        (total, order) => total + order.totalOrderPrice,
      );

      _writeRow(sheet, index + 1, [
        period.label,
        '${sales.length}',
        '${orders.length}',
        '$unitsSold',
        revenue.toStringAsFixed(2),
        cogs.toStringAsFixed(2),
        profit.toStringAsFixed(2),
        orderCosts.toStringAsFixed(2),
      ]);
    }
  }

  double _fifoItemValue(InventoryItem item) {
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
    int batchTotal = 0;
    for (final batch in batches) {
      value += batch.currentQty * batch.unitCost;
      batchTotal += batch.currentQty;
    }

    final excess = item.inventoryCount - batchTotal;
    if (excess > 0) {
      value += excess * item.price;
    }

    return value.isFinite ? value : 0.0;
  }

  void _writeRow(ex.Sheet sheet, int rowIndex, List<String> values) {
    for (var columnIndex = 0; columnIndex < values.length; columnIndex++) {
      final cell = sheet.cell(
        ex.CellIndex.indexByColumnRow(
          columnIndex: columnIndex,
          rowIndex: rowIndex,
        ),
      );
      cell.value = ex.TextCellValue(values[columnIndex]);
    }
  }

  List<_QuarterPeriod> _buildQuarterPeriods(
    List<Sale> sales,
    List<Order> orders,
  ) {
    final dates = <DateTime>[
      ...sales.map((sale) => sale.date),
      ...orders.map((order) => order.date),
    ];

    if (dates.isEmpty) {
      final now = DateTime.now();
      final quarter = ((now.month - 1) ~/ 3) + 1;
      final startMonth = (quarter - 1) * 3 + 1;
      final start = DateTime(now.year, startMonth, 1);
      final end = DateTime(now.year, startMonth + 3, 1);
      return [
        _QuarterPeriod(
          year: now.year,
          quarter: quarter,
          start: start,
          end: end,
        ),
      ];
    }

    dates.sort();
    if (dates.isEmpty) return [];

    final first = dates.first;
    final last = dates.last;

    var year = first.year;
    var quarter = ((first.month - 1) ~/ 3) + 1;

    final periods = <_QuarterPeriod>[];
    while (year < last.year ||
        (year == last.year && quarter <= ((last.month - 1) ~/ 3) + 1)) {
      final startMonth = (quarter - 1) * 3 + 1;
      final start = DateTime(year, startMonth, 1);
      final end = DateTime(year, startMonth + 3, 1);

      periods.add(
        _QuarterPeriod(year: year, quarter: quarter, start: start, end: end),
      );

      quarter++;
      if (quarter > 4) {
        quarter = 1;
        year++;
      }
    }

    return periods;
  }

  bool _isInRange(DateTime date, DateTime start, DateTime end) {
    return !date.isBefore(start) && date.isBefore(end);
  }

  String _formatDateTime(DateTime dateTime) {
    final year = dateTime.year.toString().padLeft(4, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }

  String _formatTimestamp(DateTime dateTime) {
    final year = dateTime.year.toString().padLeft(4, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final second = dateTime.second.toString().padLeft(2, '0');
    return '$year$month$day-$hour$minute$second';
  }

  Future<void> _handleImport() async {
    if (_isImporting) return;

    setState(() {
      _isImporting = true;
    });

    try {
      const typeGroup = XTypeGroup(
        label: 'Excel Workbook',
        extensions: ['xlsx'],
        mimeTypes: [
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ],
        uniformTypeIdentifiers: [
          'org.openxmlformats.spreadsheetml.sheet',
          'com.microsoft.excel.xlsx',
        ],
      );

      var file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file == null && (Platform.isIOS || Platform.isAndroid)) {
        file = await openFile();
      }

      if (file == null) {
        return;
      }

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Selected file is empty (0 B). Please export again and retry.',
            ),
            backgroundColor: Color(0xFFE67E22),
          ),
        );
        return;
      }

      final workbook = ex.Excel.decodeBytes(bytes);

      ex.Sheet? inventorySheet;
      ex.Sheet? salesDetailSheet;
      ex.Sheet? saleLineItemsSheet;
      ex.Sheet? orderDetailSheet;
      ex.Sheet? orderHistorySheet;
      ex.Sheet? transferDetailSheet;
      ex.Sheet? variantStockSheet;

      for (final sheetName in workbook.sheets.keys) {
        final normalized = sheetName.toLowerCase();
        if (normalized.contains('inventory items') ||
            normalized.contains('inventory snapshot')) {
          inventorySheet = workbook.sheets[sheetName];
        } else if (normalized.contains('sale details')) {
          salesDetailSheet = workbook.sheets[sheetName];
        } else if (normalized.contains('sale line items')) {
          saleLineItemsSheet = workbook.sheets[sheetName];
        } else if (normalized.contains('order details') ||
            (normalized.contains('order') && !normalized.contains('history'))) {
          orderDetailSheet = workbook.sheets[sheetName];
        } else if (normalized.contains('order history')) {
          orderHistorySheet = workbook.sheets[sheetName];
        } else if (normalized.contains('transfer')) {
          transferDetailSheet = workbook.sheets[sheetName];
        } else if (normalized.contains('variant')) {
          variantStockSheet = workbook.sheets[sheetName];
        }
      }

      if (inventorySheet == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No inventory sheet found. Export an "Inventory Stock & Sales Snapshot" first.',
            ),
            backgroundColor: Color(0xFFE74C3C),
          ),
        );
        return;
      }

      final existingNames = widget.inventoryList
          .map((item) => item.name.toLowerCase().trim())
          .toSet();
      final existingSkus = widget.inventoryList
          .map((item) => item.sku.toLowerCase().trim())
          .where((sku) => sku.isNotEmpty)
          .toSet();

      final allItemsByName = <String, InventoryItem>{
        for (final item in widget.inventoryList)
          item.name.toLowerCase().trim(): item,
      };
      final allItemsBySku = <String, InventoryItem>{
        for (final item in widget.inventoryList)
          if (item.sku.trim().isNotEmpty) item.sku.toLowerCase().trim(): item,
      };
      final allItemsById = <String, InventoryItem>{
        for (final item in widget.inventoryList) item.id: item,
      };

      final newItems = <InventoryItem>[];
      final newItemsById = <String, InventoryItem>{};
      int skippedCount = 0;

      final hasItemIdColumn =
          _cellString(
            inventorySheet.row(0),
            0,
          ).toLowerCase().contains('item id') ||
          _cellString(inventorySheet.row(0), 0).toLowerCase().contains('id');

      for (var rowIndex = 1; rowIndex < inventorySheet.maxRows; rowIndex++) {
        final row = inventorySheet.row(rowIndex);

        String itemId;
        String name;
        String sku;
        String folder;
        int stock;
        int soldCount;
        double price;
        bool hasVariants = false;

        if (hasItemIdColumn) {
          itemId = _cellString(row, 0).trim();
          name = _cellString(row, 1).trim();
          sku = _cellString(row, 2).trim();
          folder = _cellString(row, 3);
          stock = _cellInt(row, 4);
          soldCount = _cellInt(row, 5);
          price = _cellDouble(row, 6);
          final hasVariantsStr = _cellString(row, 12).toLowerCase();
          hasVariants = hasVariantsStr == 'yes' || hasVariantsStr == 'true';
        } else {
          name = _cellString(row, 0).trim();
          sku = _cellString(row, 1).trim();
          folder = _cellString(row, 2);
          stock = _cellInt(row, 3);
          soldCount = _cellInt(row, 4);
          price = _cellDouble(row, 5);
          itemId =
              'inv_${DateTime.now().microsecondsSinceEpoch}_${rowIndex}_${Random().nextInt(1 << 30)}';
        }

        if (name.isEmpty) continue;

        final nameKey = name.toLowerCase();
        final skuKey = sku.toLowerCase();

        if (existingNames.contains(nameKey) ||
            (skuKey.isNotEmpty && existingSkus.contains(skuKey))) {
          final existingItem =
              allItemsById[itemId] ??
              (skuKey.isNotEmpty ? allItemsBySku[skuKey] : null) ??
              allItemsByName[nameKey];
          if (existingItem != null && itemId.isNotEmpty) {
            allItemsById[itemId] = existingItem;
          }
          skippedCount++;
          continue;
        }

        final inventoryItem = InventoryItem(
          name,
          price,
          stock,
          soldCount,
          sku,
          itemId,
          [],
          [],
          folder.isEmpty ? 'Uncategorized' : folder,
          hasVariants: hasVariants,
        );

        newItems.add(inventoryItem);
        newItemsById[itemId] = inventoryItem;
        allItemsById[itemId] = inventoryItem;

        existingNames.add(nameKey);
        if (skuKey.isNotEmpty) {
          existingSkus.add(skuKey);
        }

        allItemsByName[nameKey] = inventoryItem;
        if (skuKey.isNotEmpty) {
          allItemsBySku[skuKey] = inventoryItem;
        }
      }

      final saleLinesByKey = <String, List<SaleLineItem>>{};
      if (saleLineItemsSheet != null && saleLineItemsSheet.maxRows > 1) {
        for (
          var rowIndex = 1;
          rowIndex < saleLineItemsSheet.maxRows;
          rowIndex++
        ) {
          final row = saleLineItemsSheet.row(rowIndex);
          if (row.isEmpty) continue;

          final itemId = _cellString(row, 0);
          final dateStr = _cellString(row, 2);
          final quantity = _cellInt(row, 3);
          final unitPrice = _cellDouble(row, 4);
          final source = _cellString(row, 5);
          final saleId = _cellString(row, 6);

          if (itemId.isEmpty) continue;

          final key = saleId.isEmpty
              ? '$itemId|date:$dateStr'
              : '$itemId|id:$saleId';
          saleLinesByKey
              .putIfAbsent(key, () => [])
              .add(
                SaleLineItem(
                  quantity: quantity,
                  unitPrice: unitPrice,
                  source: source.isEmpty ? 'Imported' : source,
                ),
              );
        }
      }

      if (salesDetailSheet != null && salesDetailSheet.maxRows > 1) {
        for (
          var rowIndex = 1;
          rowIndex < salesDetailSheet.maxRows;
          rowIndex++
        ) {
          final row = salesDetailSheet.row(rowIndex);
          if (row.isEmpty) continue;

          final itemId = _cellString(row, 0);
          final dateStr = _cellString(row, 2);
          final date = _parseSheetDate(dateStr);
          final quantity = _cellInt(row, 3);
          final totalPrice = _cellDouble(row, 4);
          final totalProfit = _cellDouble(row, 5);
          final saleId = _cellString(row, 8);

          if (itemId.isEmpty) continue;

          final item = newItemsById[itemId] ?? allItemsById[itemId];
          if (item == null) continue;

          final idKey = '$itemId|id:$saleId';
          final dateKey = '$itemId|date:$dateStr';
          var lineItems = saleId.isEmpty
              ? saleLinesByKey[dateKey]
              : saleLinesByKey[idKey];

          if (lineItems == null || lineItems.isEmpty) {
            final cogs = totalPrice - totalProfit;
            final unitCost = quantity > 0 ? (cogs / quantity) : 0.0;
            lineItems = [
              SaleLineItem(
                quantity: quantity,
                unitPrice: unitCost,
                source: 'Imported',
              ),
            ];
          }

          final sale = Sale(
            date: date,
            price: totalPrice,
            profit: totalProfit,
            quantity: quantity,
            priceBreakdown: lineItems,
            id: saleId.isEmpty ? null : saleId,
          );

          item.salesList.add(sale);
        }
      }

      final importedOrders = <Order>[];
      if (orderDetailSheet != null && orderDetailSheet.maxRows > 1) {
        final parsedOrders = _parseDetailedOrders(
          sheet: orderDetailSheet,
          allItemsById: allItemsById,
          existingOrders: widget.orderList,
        );
        importedOrders.addAll(parsedOrders);

        for (final order in parsedOrders) {
          for (final orderItem in order.inventoryList) {
            if (!orderItem.inventoryItem.orderList.contains(order)) {
              orderItem.inventoryItem.orderList.add(order);
            }
          }
        }
      }

      if (orderHistorySheet != null && orderHistorySheet.maxRows > 1) {
        final parsedOrders = _parseOrderHistory(
          sheet: orderHistorySheet,
          allItemsByName: allItemsByName,
          allItemsBySku: allItemsBySku,
          existingOrders: [...widget.orderList, ...importedOrders],
        );
        importedOrders.addAll(parsedOrders);
        for (final order in parsedOrders) {
          for (final orderItem in order.inventoryList) {
            if (!orderItem.inventoryItem.orderList.contains(order)) {
              orderItem.inventoryItem.orderList.add(order);
            }
          }
        }
      }

      if (transferDetailSheet != null && transferDetailSheet.maxRows > 1) {
        final transferOrders = _parseTransferDetails(
          sheet: transferDetailSheet,
          allItemsById: allItemsById,
          existingOrders: [...widget.orderList, ...importedOrders],
        );
        importedOrders.addAll(transferOrders);

        for (final order in transferOrders) {
          final destItem = allItemsById[order.transferDestinationItemId];
          if (destItem != null && !destItem.orderList.contains(order)) {
            destItem.orderList.add(order);
          }
        }
      }

      var skippedVariantCount = 0;
      if (variantStockSheet != null && variantStockSheet.maxRows > 1) {
        for (
          var rowIndex = 1;
          rowIndex < variantStockSheet.maxRows;
          rowIndex++
        ) {
          final row = variantStockSheet.row(rowIndex);
          if (row.isEmpty) continue;

          final itemId = _cellString(row, 0);
          final variantValue = _cellString(row, 2);
          final variantStock = _cellInt(row, 3);

          if (itemId.isEmpty || variantValue.isEmpty) {
            skippedVariantCount++;
            continue;
          }

          final item = newItemsById[itemId] ?? allItemsById[itemId];
          if (item == null) {
            skippedVariantCount++;
            continue;
          }

          if (!item.hasVariants) {
            skippedVariantCount++;
            continue;
          }

          if (!item.variantValues.contains(variantValue)) {
            item.variantValues.add(variantValue);
          }
          item.variantStock[variantValue] = variantStock;
        }

        if (skippedVariantCount > 0 && mounted) {
          debugPrint(
            'Warning: Skipped $skippedVariantCount variant stock entries (item not found or no variants enabled)',
          );
        }
      }

      if (newItems.isEmpty && importedOrders.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              skippedCount > 0
                  ? 'No new data to import — all matching items already exist.'
                  : 'No valid import rows found in the spreadsheet.',
            ),
            backgroundColor: const Color(0xFFE67E22),
          ),
        );
        return;
      }

      if (!mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => _ImportConfirmDialog(
          newItems: newItems,
          newOrders: importedOrders,
          skippedCount: skippedCount,
        ),
      );

      if (confirmed != true) return;

      widget.onInventoryImported!(newItems, importedOrders);

      if (!mounted) return;

      var importedSalesCount = 0;
      for (final item in newItems) {
        importedSalesCount += item.salesList.length;
      }

      final variantWarning = skippedVariantCount > 0
          ? ' Note: $skippedVariantCount variant entries were skipped.'
          : '';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imported ${newItems.length} item(s), '
            '$importedSalesCount sale record(s), and ${importedOrders.length} order/input-transfer record(s).'
            '${skippedCount > 0 ? ' ($skippedCount duplicate(s) skipped)' : ''}'
            '$variantWarning',
          ),
          backgroundColor: const Color(0xFF27AE60),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Import failed: $error'),
          backgroundColor: const Color(0xFFE74C3C),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  String _cellString(List<ex.Data?> row, int col) {
    if (col >= row.length || col < 0) return '';
    final cell = row[col];
    if (cell == null) return '';
    final val = cell.value;
    if (val == null) return '';
    return val.toString().trim();
  }

  int _cellInt(List<ex.Data?> row, int col) {
    final raw = _cellString(row, col);
    if (raw.isEmpty) return 0;
    final parsed = int.tryParse(raw);
    if (parsed != null) return parsed;
    final doubleVal = double.tryParse(raw);
    return doubleVal?.toInt() ?? 0;
  }

  double _cellDouble(List<ex.Data?> row, int col) {
    final raw = _cellString(row, col);
    if (raw.isEmpty) return 0.0;
    final normalized = raw.replaceAll(',', '');
    return double.tryParse(normalized) ?? 0.0;
  }

  DateTime _parseSheetDate(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return DateTime.now();
    }

    final iso = DateTime.tryParse(value);
    if (iso != null) {
      return iso;
    }

    final parts = value.split(' ');
    final datePart = parts.isNotEmpty ? parts[0] : '';
    final dateSegments = datePart.split('-');
    if (dateSegments.length == 3) {
      final year = int.tryParse(dateSegments[0]);
      final month = int.tryParse(dateSegments[1]);
      final day = int.tryParse(dateSegments[2]);

      var hour = 0;
      var minute = 0;
      if (parts.length > 1) {
        final timeParts = parts[1].split(':');
        if (timeParts.isNotEmpty) {
          hour = int.tryParse(timeParts[0]) ?? 0;
        }
        if (timeParts.length > 1) {
          minute = int.tryParse(timeParts[1]) ?? 0;
        }
      }

      if (year != null && month != null && day != null) {
        return DateTime(year, month, day, hour, minute);
      }
    }

    return DateTime.now();
  }

  String _orderSignature(Order order) {
    final lineSignatures =
        order.inventoryList
            .map(
              (line) =>
                  '${line.inventoryItem.id}:${line.quantity}:${line.shippedPrice.toStringAsFixed(4)}',
            )
            .toList()
          ..sort();

    return '${order.date.toIso8601String()}|'
        '${order.shipping.toStringAsFixed(4)}|'
        '${order.fees.toStringAsFixed(4)}|'
        '${order.totalOrderPrice.toStringAsFixed(4)}|'
        '${order.folder}|'
        '${order.isInputTransfer}|'
        '${lineSignatures.join(',')}';
  }

  List<Order> _parseDetailedOrders({
    required ex.Sheet sheet,
    required Map<String, InventoryItem> allItemsById,
    required List<Order> existingOrders,
  }) {
    if (sheet.maxRows <= 1) return [];

    final groupedOrders = <String, _DetailedOrderDraft>{};
    final folderMismatchWarnings = <String>{};

    for (var rowIndex = 1; rowIndex < sheet.maxRows; rowIndex++) {
      final row = sheet.row(rowIndex);
      if (row.isEmpty) continue;

      final itemId = _cellString(row, 0);
      final dateStr = _cellString(row, 2);
      final date = _parseSheetDate(dateStr);
      final quantity = _cellInt(row, 3);
      final unitCost = _cellDouble(row, 4);
      final shipping = _cellDouble(row, 6);
      final fees = _cellDouble(row, 7);
      final orderTotal = _cellDouble(row, 8);
      final folder = _cellString(row, 9);
      final isInputTransferStr = _cellString(row, 10).toLowerCase();
      final orderId = _cellString(row, 11);
      final isInputTransfer =
          isInputTransferStr == 'yes' || isInputTransferStr == 'true';

      if (isInputTransfer) continue;

      if (itemId.isEmpty) continue;

      final item = allItemsById[itemId];
      if (item == null) continue;

      final normalizedFolder = folder.isEmpty ? 'Imported' : folder;
      final key = orderId.isEmpty
          ? 'legacy|${date.toIso8601String()}|$shipping|$fees|$orderTotal|$normalizedFolder'
          : 'id:$orderId';
      final draft = groupedOrders.putIfAbsent(
        key,
        () => _DetailedOrderDraft(
          id: orderId.isEmpty ? null : orderId,
          date: date,
          shipping: shipping,
          fees: fees,
          orderTotal: orderTotal,
          folder: normalizedFolder,
        ),
      );

      if (draft.folder != normalizedFolder &&
          !folderMismatchWarnings.contains(key)) {
        folderMismatchWarnings.add(key);
        debugPrint(
          'Warning: Order rows with same date/costs have different folders',
        );
      }

      draft.lines.add(
        InventoryOrderItem(item, quantity, unitCost, unitCost, quantity),
      );
    }

    final existingSignatures = existingOrders.map(_orderSignature).toSet();
    final newOrders = <Order>[];

    for (final draft in groupedOrders.values) {
      final order = Order(
        draft.date,
        draft.lines,
        draft.shipping,
        draft.fees,
        draft.orderTotal,
        draft.folder,
        id: draft.id,
      );

      final signature = _orderSignature(order);
      if (!existingSignatures.contains(signature)) {
        existingSignatures.add(signature);
        newOrders.add(order);
      }
    }

    return newOrders;
  }

  List<Order> _parseOrderHistory({
    required ex.Sheet sheet,
    required Map<String, InventoryItem> allItemsByName,
    required Map<String, InventoryItem> allItemsBySku,
    required List<Order> existingOrders,
  }) {
    final drafts = <String, _DetailedOrderDraft>{};
    for (var rowIndex = 1; rowIndex < sheet.maxRows; rowIndex++) {
      final row = sheet.row(rowIndex);
      if (row.isEmpty) continue;

      final orderNumber = _cellString(row, 0);
      final date = _parseSheetDate(_cellString(row, 1));
      final name = _cellString(row, 2).trim().toLowerCase();
      final sku = _cellString(row, 3).trim().toLowerCase();
      final item =
          (sku.isNotEmpty ? allItemsBySku[sku] : null) ?? allItemsByName[name];
      if (item == null) continue;

      final shipping = _cellDouble(row, 7);
      final fees = _cellDouble(row, 8);
      final total = _cellDouble(row, 9);
      final key = '$orderNumber|${date.toIso8601String()}';
      final draft = drafts.putIfAbsent(
        key,
        () => _DetailedOrderDraft(
          id: null,
          date: date,
          shipping: shipping,
          fees: fees,
          orderTotal: total,
          folder: 'Imported',
        ),
      );
      draft.lines.add(
        InventoryOrderItem(
          item,
          _cellInt(row, 4),
          _cellDouble(row, 5),
          _cellDouble(row, 5),
          _cellInt(row, 4),
        ),
      );
    }

    final existingSignatures = existingOrders.map(_orderSignature).toSet();
    final newOrders = <Order>[];
    for (final draft in drafts.values) {
      final order = Order(
        draft.date,
        draft.lines,
        draft.shipping,
        draft.fees,
        draft.orderTotal,
        draft.folder,
      );
      if (existingSignatures.add(_orderSignature(order))) {
        newOrders.add(order);
      }
    }
    return newOrders;
  }

  List<Order> _parseTransferDetails({
    required ex.Sheet sheet,
    required Map<String, InventoryItem> allItemsById,
    required List<Order> existingOrders,
  }) {
    if (sheet.maxRows <= 1) return [];

    final existingSignatures = existingOrders.map(_orderSignature).toSet();
    final newOrders = <Order>[];

    for (var rowIndex = 1; rowIndex < sheet.maxRows; rowIndex++) {
      final row = sheet.row(rowIndex);
      if (row.isEmpty) continue;

      final dateStr = _cellString(row, 0);
      final date = _parseSheetDate(dateStr);
      final sourceItemId = _cellString(row, 1);
      final sourceItemName = _cellString(row, 2);
      final sourceVariant = _cellString(row, 3);
      final destItemId = _cellString(row, 4);
      final destItemName = _cellString(row, 5);
      final destVariant = _cellString(row, 6);
      final quantity = _cellInt(row, 7);
      final unitCost = _cellDouble(row, 8);
      final shipping = _cellDouble(row, 10);
      final fees = _cellDouble(row, 11);
      final orderTotal = _cellDouble(row, 12);

      final order = Order(
        date,
        [],
        shipping,
        fees,
        orderTotal,
        'Imported',
        isInputTransfer: true,
        transferSourceItemId: sourceItemId.isEmpty ? null : sourceItemId,
        transferSourceItemName: sourceItemName.isEmpty ? null : sourceItemName,
        transferSourceVariant: sourceVariant.isEmpty ? null : sourceVariant,
        transferDestinationItemId: destItemId.isEmpty ? null : destItemId,
        transferDestinationItemName: destItemName.isEmpty ? null : destItemName,
        transferDestinationVariant: destVariant.isEmpty ? null : destVariant,
        transferQuantity: quantity,
        transferUnitCost: unitCost,
      );

      final signature = _orderSignature(order);
      if (!existingSignatures.contains(signature)) {
        existingSignatures.add(signature);
        newOrders.add(order);
      }
    }

    return newOrders;
  }
}

class _DetailedOrderDraft {
  final String? id;
  final DateTime date;
  final double shipping;
  final double fees;
  final double orderTotal;
  final String folder;
  final List<InventoryOrderItem> lines = <InventoryOrderItem>[];

  _DetailedOrderDraft({
    required this.id,
    required this.date,
    required this.shipping,
    required this.fees,
    required this.orderTotal,
    required this.folder,
  });
}

class _ImportConfirmDialog extends StatelessWidget {
  final List<InventoryItem> newItems;
  final List<Order> newOrders;
  final int skippedCount;

  const _ImportConfirmDialog({
    required this.newItems,
    required this.newOrders,
    required this.skippedCount,
  });

  @override
  Widget build(BuildContext context) {
    const previewMax = 5;
    final preview = newItems.take(previewMax).toList();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Import Inventory Items',
        style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF2C3E50)),
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${newItems.length} new item(s) and ${newOrders.length} order/input-transfer record(s) will be added.'
              '${skippedCount > 0 ? ' $skippedCount duplicate(s) will be skipped.' : ''}',
              style: const TextStyle(fontSize: 14, color: Color(0xFF66717A)),
            ),
            const SizedBox(height: 12),
            ...preview.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(
                      Icons.inventory_2_outlined,
                      size: 16,
                      color: Color(0xFF8E44AD),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF2C3E50),
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      'Qty: ${item.inventoryCount}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF66717A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (newItems.length > previewMax)
              Text(
                '...and ${newItems.length - previewMax} more.',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF66717A),
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Color(0xFF66717A)),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8E44AD),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 0,
          ),
          child: const Text('Import'),
        ),
      ],
    );
  }
}

class _ImportCard extends StatelessWidget {
  final bool isImporting;
  final bool canImport;
  final VoidCallback onImport;

  const _ImportCard({
    required this.isImporting,
    required this.canImport,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2C3E50).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF8E44AD).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.table_chart_outlined,
                color: Color(0xFF8E44AD),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Import Inventory',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Pick an Inventory Snapshot .xlsx file to bulk-add items to your catalog. Duplicates are skipped automatically.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF66717A),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 38,
                    child: ElevatedButton.icon(
                      onPressed: (isImporting || !canImport) ? null : onImport,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8E44AD),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      icon: isImporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.upload_rounded, size: 18),
                      label: Text(
                        isImporting ? 'Importing...' : 'Select File (.xlsx)',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportCard extends StatelessWidget {
  final _ExportOption option;
  final VoidCallback onDownload;
  final bool isExporting;

  const _ExportCard({
    required this.option,
    required this.onDownload,
    required this.isExporting,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2C3E50).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF3498DB).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                option.icon,
                color: const Color(0xFF3498DB),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    option.subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF66717A),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 38,
                    child: ElevatedButton.icon(
                      onPressed: isExporting ? null : onDownload,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2C3E50),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      icon: isExporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.download_rounded, size: 18),
                      label: Text(
                        isExporting ? 'Exporting...' : 'Download (.xlsx)',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportOption {
  final _ExportType type;
  final String title;
  final String subtitle;
  final IconData icon;

  const _ExportOption({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

class _QuarterPeriod {
  final int year;
  final int quarter;
  final DateTime start;
  final DateTime end;

  const _QuarterPeriod({
    required this.year,
    required this.quarter,
    required this.start,
    required this.end,
  });

  String get label => 'Q$quarter $year';
}

enum _ExportType {
  saleHistory,
  orderHistory,
  inventorySnapshot,
  quarterlyReports,
}
