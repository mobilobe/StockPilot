import 'dart:math';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:inventory/models/inventory_item.dart';
import 'package:inventory/models/inventory_order_item.dart';
import 'package:inventory/models/sale.dart';
import 'package:inventory/models/sale_line_item.dart';
import 'package:inventory/models/order.dart';

class HiveService {
  static final HiveService _instance = HiveService._internal();
  late final Box<dynamic> _box;
  List<InventoryItem>? _cachedInventoryItems;

  static const _inventoryKey = 'INVENTORYITEMLIST';
  static const _salesKey = 'SALESLIST';
  static const _ordersKey = 'ORDERSLIST';
  static const _folderColorsKey = 'FOLDERCOLORS';
  static const _folderMetaKey = 'FOLDERMETA';

  factory HiveService() {
    return _instance;
  }

  HiveService._internal() {
    _box = Hive.box('data');
  }

  String generateUniqueInventoryItemId() {
    final existingIds = getInventoryItems().map((item) => item.id).toSet();
    var candidate = '';
    do {
      candidate =
          'inv_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1 << 20)}';
    } while (existingIds.contains(candidate));
    return candidate;
  }

  Future<void> saveInventoryItems(List<InventoryItem> items) async {
    final serializedItems = items
        .map(
          (item) => <String, dynamic>{
            'name': item.name,
            'price': item.price,
            'inventoryCount': item.inventoryCount,
            'soldCount': item.soldCount,
            'sku': item.sku,
            'id': item.id,
            'folder': item.folder,
            'hasVariants': item.hasVariants,
            'variantValues': item.variantValues,
            'variantStock': item.variantStock,
            'salesList': item.salesList.map(_saleToMap).toList(),
          },
        )
        .toList();

    await _box.put(_inventoryKey, serializedItems);
    _cachedInventoryItems = items;
  }

  List<InventoryItem> getInventoryItems() {
    final value = _box.get(_inventoryKey);
    if (value is! List) {
      _cachedInventoryItems = <InventoryItem>[];
      return <InventoryItem>[];
    }

    if (value.isNotEmpty && value.first is InventoryItem) {
      final items = value.cast<InventoryItem>();
      _cachedInventoryItems = items;
      return items;
    }

    final items = <InventoryItem>[];
    for (final rawItem in value) {
      if (rawItem is! Map) continue;

      final sales = _salesFromRaw(rawItem['salesList']);
      items.add(
        InventoryItem(
          (rawItem['name'] ?? '').toString(),
          _toDouble(rawItem['price']),
          _toInt(rawItem['inventoryCount']),
          _toInt(rawItem['soldCount']),
          (rawItem['sku'] ?? '').toString(),
          (rawItem['id'] ?? '').toString(),
          <Order>[],
          sales,
          (rawItem['folder'] ?? 'Uncategorized').toString(),
          hasVariants: rawItem['hasVariants'] == true,
          variantValues: ((rawItem['variantValues'] as List?) ?? const [])
              .map((value) => value.toString())
              .toList(),
          variantStock:
              ((rawItem['variantStock'] as Map?) ?? const <dynamic, dynamic>{})
                  .map(
                    (key, value) => MapEntry(
                      key.toString(),
                      value is num ? value.toInt() : _toInt(value),
                    ),
                  ),
        ),
      );
    }

    _cachedInventoryItems = items;
    return items;
  }

  Future<void> addInventoryItem(InventoryItem item) async {
    final items = getInventoryItems();
    items.add(item);
    await saveInventoryItems(items);
  }

  Future<void> deleteInventoryItem(String itemId) async {
    final items = getInventoryItems();
    items.removeWhere((item) => item.id == itemId);
    await saveInventoryItems(items);
  }

  Map<String, int> getFolderColors() {
    final value = _box.get(_folderColorsKey);
    if (value is! Map) {
      return <String, int>{};
    }

    final colors = <String, int>{};
    value.forEach((key, rawColorValue) {
      if (key == null || rawColorValue == null) {
        return;
      }

      colors[key.toString()] = _toInt(rawColorValue);
    });
    return colors;
  }

  Map<String, dynamic> getFolderMeta() {
    final value = _box.get(_folderMetaKey);
    if (value is! Map) {
      return <String, dynamic>{};
    }

    final meta = <String, dynamic>{};
    value.forEach((key, raw) {
      if (key == null) return;
      meta[key.toString()] = raw;
    });
    return meta;
  }

  Future<void> saveFolderMeta(Map<String, dynamic> meta) async {
    await _box.put(_folderMetaKey, meta);
  }

  Future<void> setFolderClosedByDefault({
    required String folder,
    required bool closed,
  }) async {
    final normalized = folder.trim();
    if (normalized.isEmpty) return;
    final meta = Map<String, dynamic>.from(getFolderMeta());
    final entry = Map<String, dynamic>.from(
      meta[normalized] ?? <String, dynamic>{},
    );
    entry['closedByDefault'] = closed == true;
    meta[normalized] = entry;
    await saveFolderMeta(meta);
  }

  Future<void> removeFolderMeta(String folder) async {
    final meta = Map<String, dynamic>.from(getFolderMeta());
    meta.remove(folder);
    await saveFolderMeta(meta);
  }

  Future<void> renameFolderMeta(String oldName, String newName) async {
    final meta = Map<String, dynamic>.from(getFolderMeta());
    final normalizedOld = oldName.trim();
    final normalizedNew = newName.trim();
    if (normalizedOld.isEmpty || normalizedNew.isEmpty) return;
    if (meta.containsKey(normalizedOld)) {
      meta[normalizedNew] = meta[normalizedOld];
      meta.remove(normalizedOld);
      await saveFolderMeta(meta);
    }
  }

  Future<void> saveFolderColors(Map<String, int> colors) async {
    await _box.put(_folderColorsKey, colors);
  }

  Future<void> setFolderColor({
    required String folder,
    required int colorValue,
  }) async {
    final normalizedFolder = folder.trim();
    if (normalizedFolder.isEmpty) {
      return;
    }

    final colors = getFolderColors();
    colors[normalizedFolder] = colorValue;
    await saveFolderColors(colors);
  }

  Future<void> saveSales(List<Sale> sales) async {
    final serializedSales = sales.map(_saleToMap).toList();
    await _box.put(_salesKey, serializedSales);
  }

  List<Sale> getSales() {
    final value = _box.get(_salesKey);
    if (value is List) {
      if (value.isNotEmpty && value.first is Sale) {
        return value.cast<Sale>();
      }
      return _salesFromRaw(value);
    }

    final inventoryItems = _cachedInventoryItems ?? getInventoryItems();
    final collectedSales = <Sale>[];
    for (final item in inventoryItems) {
      collectedSales.addAll(item.salesList);
    }
    return collectedSales;
  }

  Future<void> saveOrders(List<Order> orders) async {
    final serializedOrders = orders
        .map(
          (order) => <String, dynamic>{
            'id': order.id,
            'date': order.date.toIso8601String(),
            'folder': order.folder,
            'shipping': order.shipping,
            'fees': order.fees,
            'totalOrderPrice': order.totalOrderPrice,
            'isInputTransfer': order.isInputTransfer,
            'transferSourceItemId': order.transferSourceItemId,
            'transferDestinationItemId': order.transferDestinationItemId,
            'transferSourceItemName': order.transferSourceItemName,
            'transferDestinationItemName': order.transferDestinationItemName,
            'transferSourceVariant': order.transferSourceVariant,
            'transferDestinationVariant': order.transferDestinationVariant,
            'transferUnitCost': order.transferUnitCost,
            'transferQuantity': order.transferQuantity,
            'transferFifoBreakdown': order.transferFifoBreakdown,
            'inventoryList': order.inventoryList
                .map(
                  (orderItem) => <String, dynamic>{
                    'inventoryItemId': orderItem.inventoryItem.id,
                    'quantity': orderItem.quantity,
                    'price': orderItem.price,
                    'shippedPrice': orderItem.shippedPrice,
                    'currentQuantity': orderItem.currentQuantity,
                    'selectedVariant': orderItem.selectedVariant,
                  },
                )
                .toList(),
          },
        )
        .toList();

    await _box.put(_ordersKey, serializedOrders);
  }

  List<Order> getOrders() {
    final inventoryItems = _cachedInventoryItems ?? getInventoryItems();
    final inventoryById = <String, InventoryItem>{
      for (final item in inventoryItems) item.id: item,
    };

    for (final item in inventoryItems) {
      item.orderList = <Order>[];
    }

    final value = _box.get(_ordersKey);
    if (value is! List) {
      return <Order>[];
    }

    if (value.isNotEmpty && value.first is Order) {
      return value.cast<Order>();
    }

    final orders = <Order>[];
    for (final rawOrder in value) {
      if (rawOrder is! Map) continue;

      final rawInventoryList = rawOrder['inventoryList'];
      final orderItems = <InventoryOrderItem>[];

      if (rawInventoryList is List) {
        for (final rawOrderItem in rawInventoryList) {
          if (rawOrderItem is! Map) continue;

          final inventoryItemId = (rawOrderItem['inventoryItemId'] ?? '')
              .toString();
          final inventoryItem = inventoryById[inventoryItemId];
          if (inventoryItem == null) continue;

          orderItems.add(
            InventoryOrderItem(
              inventoryItem,
              _toInt(rawOrderItem['quantity']),
              _toDouble(rawOrderItem['price']),
              _toDouble(rawOrderItem['shippedPrice']),
              _toInt(rawOrderItem['currentQuantity']),
              selectedVariant: rawOrderItem['selectedVariant']?.toString(),
            ),
          );
        }
      }

      final order = Order(
        id: (rawOrder['id'] ?? '').toString().isEmpty
            ? null
            : rawOrder['id'].toString(),
        DateTime.tryParse((rawOrder['date'] ?? '').toString()) ??
            DateTime.now(),
        orderItems,
        _toDouble(rawOrder['shipping']),
        _toDouble(rawOrder['fees']),
        _toDouble(rawOrder['totalOrderPrice']),
        (rawOrder['folder'] ?? 'Uncategorized').toString(),
        isInputTransfer: rawOrder['isInputTransfer'] == true,
        transferSourceItemId: rawOrder['transferSourceItemId']?.toString(),
        transferDestinationItemId: rawOrder['transferDestinationItemId']
            ?.toString(),
        transferSourceItemName: rawOrder['transferSourceItemName']?.toString(),
        transferDestinationItemName: rawOrder['transferDestinationItemName']
            ?.toString(),
        transferSourceVariant: rawOrder['transferSourceVariant']?.toString(),
        transferDestinationVariant: rawOrder['transferDestinationVariant']
            ?.toString(),
        transferUnitCost: rawOrder['transferUnitCost'] == null
            ? null
            : _toDouble(rawOrder['transferUnitCost']),
        transferQuantity: rawOrder['transferQuantity'] == null
            ? null
            : _toInt(rawOrder['transferQuantity']),
        transferFifoBreakdown:
            ((rawOrder['transferFifoBreakdown'] as List?) ?? const <dynamic>[])
                .whereType<Map>()
                .map(
                  (entry) => entry.map(
                    (key, value) => MapEntry(key.toString(), value),
                  ),
                )
                .toList(),
      );

      for (final orderItem in orderItems) {
        if (!orderItem.inventoryItem.orderList.contains(order)) {
          orderItem.inventoryItem.orderList.add(order);
        }
      }

      orders.add(order);
    }

    return orders;
  }

  Future<void> clearAll() async {
    await _box.clear();
    _cachedInventoryItems = <InventoryItem>[];
  }

  Map<String, dynamic> _saleToMap(Sale sale) {
    return <String, dynamic>{
      'id': sale.id,
      'date': sale.date.toIso8601String(),
      'price': sale.price,
      'profit': sale.profit,
      'quantity': sale.quantity,
      'priceBreakdown': sale.priceBreakdown
          .map(
            (line) => <String, dynamic>{
              'quantity': line.quantity,
              'unitPrice': line.unitPrice,
              'source': line.source,
            },
          )
          .toList(),
    };
  }

  List<Sale> _salesFromRaw(dynamic rawSales) {
    if (rawSales is! List) {
      return <Sale>[];
    }

    return rawSales.whereType<Map>().map((rawSale) {
      final rawBreakdown = rawSale['priceBreakdown'];
      final breakdown = <SaleLineItem>[];

      if (rawBreakdown is List) {
        for (final rawLine in rawBreakdown) {
          if (rawLine is! Map) continue;
          breakdown.add(
            SaleLineItem(
              quantity: _toInt(rawLine['quantity']),
              unitPrice: _toDouble(rawLine['unitPrice']),
              source: (rawLine['source'] ?? '').toString(),
              orderItem: null,
            ),
          );
        }
      }

      return Sale(
        id: (rawSale['id'] ?? '').toString().isEmpty
            ? null
            : rawSale['id'].toString(),
        date:
            DateTime.tryParse((rawSale['date'] ?? '').toString()) ??
            DateTime.now(),
        price: _toDouble(rawSale['price']),
        profit: _toDouble(rawSale['profit']),
        quantity: _toInt(rawSale['quantity']),
        priceBreakdown: breakdown,
      );
    }).toList();
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }
}
