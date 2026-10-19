import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:inventory/models/inventory_item.dart';
import 'package:inventory/models/inventory_order_item.dart';
import 'package:inventory/models/order.dart' as inventory_order;
import 'package:inventory/models/sale.dart';
import 'package:inventory/models/sale_line_item.dart';

class FirestoreAppData {
  const FirestoreAppData({
    required this.inventory,
    required this.orders,
    required this.sales,
  });

  final List<InventoryItem> inventory;
  final List<inventory_order.Order> orders;
  final List<Sale> sales;
}

class FirestoreAppDataStore {
  static const _maxBatchOperations = 200;

  FirestoreAppDataStore({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    String? Function()? userIdProvider,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth,
       _userIdProvider = userIdProvider;

  final FirebaseFirestore _firestore;
  final FirebaseAuth? _auth;
  final String? Function()? _userIdProvider;

  String? get _userId =>
      _userIdProvider?.call() ??
      (_auth ?? FirebaseAuth.instance).currentUser?.uid;

  Future<void> save({
    required List<InventoryItem> inventory,
    required List<inventory_order.Order> orders,
    required List<Sale> sales,
    required Map<String, InventoryQuantitySnapshot> previousQuantities,
  }) async {
    final userId = _userId;
    if (userId == null) {
      throw StateError('Synced mode requires a signed-in user.');
    }

    final user = _firestore.collection('users').doc(userId);
    final writes = <void Function(WriteBatch)>[];
    final existingSnapshots = await Future.wait([
      user.collection('inventory').get(),
      user.collection('orders').get(),
      user.collection('sales').get(),
    ]);
    final existingInventoryIds = existingSnapshots[0].docs
        .map((document) => document.id)
        .toSet();
    final existingOrderIds = existingSnapshots[1].docs
        .map((document) => document.id)
        .toSet();
    final existingSaleIds = existingSnapshots[2].docs
        .map((document) => document.id)
        .toSet();
    final inventoryIds = inventory.map((item) => item.id).toSet();
    final orderIds = orders.map((order) => order.id).toSet();
    final saleIds = sales.map((sale) => sale.id).toSet();
    final saleOwnerIds = <String, String>{
      for (final item in inventory)
        for (final sale in item.salesList) sale.id: item.id,
    };
    for (final item in inventory) {
      final reference = user.collection('inventory').doc(item.id);
      final previous = previousQuantities[item.id];
      if (previous == null) {
        writes.add((batch) => batch.set(reference, _inventoryWriteData(item)));
        continue;
      }

      final updateData = <Object, Object?>{
        ..._inventoryWriteData(item, includeQuantities: false),
      };
      final inventoryDelta = item.inventoryCount - previous.inventoryCount;
      final soldDelta = item.soldCount - previous.soldCount;
      if (inventoryDelta != 0) {
        updateData['inventoryCount'] = FieldValue.increment(inventoryDelta);
      }
      if (soldDelta != 0) {
        updateData['soldCount'] = FieldValue.increment(soldDelta);
      }
      final variantNames = <String>{
        ...previous.variantStock.keys,
        ...item.variantStock.keys,
      };
      for (final variant in variantNames) {
        final delta =
            (item.variantStock[variant] ?? 0) -
            (previous.variantStock[variant] ?? 0);
        if (delta != 0) {
          updateData[FieldPath(<String>['variantStock', variant])] =
              FieldValue.increment(delta);
        }
      }
      writes.add((batch) => batch.update(reference, updateData));
    }

    for (final order in orders) {
      writes.add(
        (batch) => batch.set(
          user.collection('orders').doc(order.id),
          _orderWriteData(order),
        ),
      );
    }
    for (final sale in sales) {
      writes.add(
        (batch) => batch.set(
          user.collection('sales').doc(sale.id),
          _saleWriteData(sale, inventoryItemId: saleOwnerIds[sale.id]),
        ),
      );
    }

    for (final documentId in existingInventoryIds.difference(inventoryIds)) {
      writes.add(
        (batch) => batch.delete(user.collection('inventory').doc(documentId)),
      );
    }
    for (final documentId in existingOrderIds.difference(orderIds)) {
      writes.add(
        (batch) => batch.delete(user.collection('orders').doc(documentId)),
      );
    }
    for (final documentId in existingSaleIds.difference(saleIds)) {
      writes.add(
        (batch) => batch.delete(user.collection('sales').doc(documentId)),
      );
    }

    for (var start = 0; start < writes.length; start += _maxBatchOperations) {
      final batch = _firestore.batch();
      final end = (start + _maxBatchOperations).clamp(0, writes.length);
      for (final write in writes.sublist(start, end)) {
        write(batch);
      }
      await batch.commit();
    }
  }

  Future<FirestoreAppData> load() async {
    final userId = _userId;
    if (userId == null) {
      throw StateError('Synced mode requires a signed-in user.');
    }

    final user = _firestore.collection('users').doc(userId);

    final snapshots = await Future.wait([
      user.collection('inventory').get(),
      user.collection('orders').get(),
      user.collection('sales').get(),
    ]);
    final inventory = snapshots[0].docs
        .where((document) => document.data()['deletedAt'] == null)
        .map((document) => _inventoryFromMap(document.id, document.data()))
        .toList();
    final byId = <String, InventoryItem>{
      for (final item in inventory) item.id: item,
    };
    final orders = snapshots[1].docs
        .map((document) => _orderFromMap(document.id, document.data(), byId))
        .whereType<inventory_order.Order>()
        .toList();
    for (final order in orders) {
      for (final orderItem in order.inventoryList) {
        if (!orderItem.inventoryItem.orderList.contains(order)) {
          orderItem.inventoryItem.orderList.add(order);
        }
      }
    }
    final salesByInventoryId = <String, List<Sale>>{};
    final standaloneSales = <Sale>[];
    for (final document in snapshots[2].docs) {
      final sale = _saleFromMap(document.id, document.data());
      standaloneSales.add(sale);
      final inventoryItemId = document.data()['inventoryItemId']?.toString();
      if (inventoryItemId != null && byId.containsKey(inventoryItemId)) {
        salesByInventoryId.putIfAbsent(inventoryItemId, () => []).add(sale);
      }
    }
    for (final entry in salesByInventoryId.entries) {
      byId[entry.key]!.salesList = entry.value;
    }
    final legacySales = inventory
        .where((item) => !salesByInventoryId.containsKey(item.id))
        .expand((item) => item.salesList);

    return FirestoreAppData(
      inventory: inventory,
      orders: orders,
      sales: [...standaloneSales, ...legacySales],
    );
  }

  InventoryItem _inventoryFromMap(String id, Map<String, dynamic> data) {
    return InventoryItem(
      (data['name'] ?? '').toString(),
      _asDouble(data['price']),
      _asInt(data['inventoryCount']),
      _asInt(data['soldCount']),
      (data['sku'] ?? '').toString(),
      id,
      <inventory_order.Order>[],
      _salesFromList(data['salesList']),
      (data['folder'] ?? 'Uncategorized').toString(),
      hasVariants: data['hasVariants'] == true,
      variantValues: _asList(
        data['variantValues'],
      ).map((value) => value.toString()).toList(),
      variantStock: _asMap(
        data['variantStock'],
      ).map((key, value) => MapEntry(key, _asInt(value))),
    );
  }

  Map<String, Object?> _inventoryWriteData(
    InventoryItem item, {
    bool includeQuantities = true,
  }) {
    return <String, Object?>{
      'name': item.name,
      'price': item.price,
      'sku': item.sku,
      'folder': item.folder,
      'hasVariants': item.hasVariants,
      'variantValues': item.variantValues,
      'lastModified': FieldValue.serverTimestamp(),
      'updatedBy': 'app',
      if (includeQuantities) 'inventoryCount': item.inventoryCount,
      if (includeQuantities) 'soldCount': item.soldCount,
      if (includeQuantities) 'variantStock': item.variantStock,
    };
  }

  Map<String, Object?> _orderWriteData(inventory_order.Order order) {
    return <String, Object?>{
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
      'inventoryItems': order.inventoryList
          .map(
            (item) => <String, Object?>{
              'inventoryItemId': item.inventoryItem.id,
              'name': item.inventoryItem.name,
              'sku': item.inventoryItem.sku,
              'quantity': item.quantity,
              'price': item.price,
              'shippedPrice': item.shippedPrice,
              'currentQuantity': item.currentQuantity,
              'selectedVariant': item.selectedVariant,
            },
          )
          .toList(),
      'lastModified': FieldValue.serverTimestamp(),
      'updatedBy': 'app',
    };
  }

  Map<String, Object?> _saleWriteData(Sale sale, {String? inventoryItemId}) =>
      <String, Object?>{
        'date': sale.date.toIso8601String(),
        'price': sale.price,
        'profit': sale.profit,
        'quantity': sale.quantity,
        'inventoryItemId': ?inventoryItemId,
        'priceBreakdown': sale.priceBreakdown
            .map(
              (line) => <String, Object?>{
                'quantity': line.quantity,
                'unitPrice': line.unitPrice,
                'source': line.source,
              },
            )
            .toList(),
        'lastModified': FieldValue.serverTimestamp(),
        'updatedBy': 'app',
      };

  inventory_order.Order? _orderFromMap(
    String id,
    Map<String, dynamic> data,
    Map<String, InventoryItem> inventoryById,
  ) {
    final lines = <InventoryOrderItem>[];
    final rawInventoryItems = data['inventoryItems'] ?? data['inventoryList'];
    final inventoryBySku = <String, InventoryItem>{
      for (final item in inventoryById.values)
        if (item.sku.trim().isNotEmpty) item.sku.trim().toLowerCase(): item,
    };
    final inventoryByName = <String, InventoryItem>{
      for (final item in inventoryById.values)
        item.name.trim().toLowerCase(): item,
    };
    for (final rawLine in _asList(rawInventoryItems)) {
      if (rawLine is! Map) continue;
      final itemId = (rawLine['inventoryItemId'] ?? '').toString();
      final sku = (rawLine['sku'] ?? '').toString().trim().toLowerCase();
      final name = (rawLine['name'] ?? '').toString().trim().toLowerCase();
      final item =
          inventoryById[itemId] ?? inventoryBySku[sku] ?? inventoryByName[name];
      if (item == null) continue;
      lines.add(
        InventoryOrderItem(
          item,
          _asInt(rawLine['quantity']),
          _asDouble(rawLine['price']),
          _asDouble(rawLine['shippedPrice']),
          _asInt(rawLine['currentQuantity']),
          selectedVariant: rawLine['selectedVariant']?.toString(),
        ),
      );
    }
    return inventory_order.Order(
      DateTime.tryParse((data['date'] ?? '').toString()) ?? DateTime.now(),
      lines,
      _asDouble(data['shipping']),
      _asDouble(data['fees']),
      _asDouble(data['totalOrderPrice']),
      (data['folder'] ?? 'Uncategorized').toString(),
      id: id,
      isInputTransfer: data['isInputTransfer'] == true,
      transferSourceItemId: data['transferSourceItemId']?.toString(),
      transferDestinationItemId: data['transferDestinationItemId']?.toString(),
      transferSourceItemName: data['transferSourceItemName']?.toString(),
      transferDestinationItemName: data['transferDestinationItemName']
          ?.toString(),
      transferSourceVariant: data['transferSourceVariant']?.toString(),
      transferDestinationVariant: data['transferDestinationVariant']
          ?.toString(),
      transferUnitCost: data['transferUnitCost'] == null
          ? null
          : _asDouble(data['transferUnitCost']),
      transferQuantity: data['transferQuantity'] == null
          ? null
          : _asInt(data['transferQuantity']),
      transferFifoBreakdown: _asList(data['transferFifoBreakdown'])
          .whereType<Map>()
          .map(
            (entry) =>
                entry.map((key, value) => MapEntry(key.toString(), value)),
          )
          .toList(),
    );
  }

  List<Sale> _salesFromList(dynamic value) => _asList(value)
      .whereType<Map>()
      .map((sale) => _saleFromMap((sale['id'] ?? '').toString(), sale))
      .toList();

  Sale _saleFromMap(String id, Map<dynamic, dynamic> data) {
    return Sale(
      id: id.isEmpty ? null : id,
      date:
          DateTime.tryParse((data['date'] ?? '').toString()) ?? DateTime.now(),
      price: _asDouble(data['price']),
      profit: _asDouble(data['profit']),
      quantity: _asInt(data['quantity']),
      priceBreakdown: _asList(data['priceBreakdown'])
          .whereType<Map>()
          .map(
            (line) => SaleLineItem(
              quantity: _asInt(line['quantity']),
              unitPrice: _asDouble(line['unitPrice']),
              source: (line['source'] ?? '').toString(),
            ),
          )
          .toList(),
    );
  }

  List<dynamic> _asList(dynamic value) => value is List ? value : const [];
  Map<String, dynamic> _asMap(dynamic value) => value is Map
      ? value.map((key, entry) => MapEntry(key.toString(), entry))
      : <String, dynamic>{};
  int _asInt(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  double _asDouble(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
}

class InventoryQuantitySnapshot {
  const InventoryQuantitySnapshot({
    required this.inventoryCount,
    required this.soldCount,
    required this.variantStock,
  });

  factory InventoryQuantitySnapshot.fromItem(InventoryItem item) {
    return InventoryQuantitySnapshot(
      inventoryCount: item.inventoryCount,
      soldCount: item.soldCount,
      variantStock: Map<String, int>.from(item.variantStock),
    );
  }

  final int inventoryCount;
  final int soldCount;
  final Map<String, int> variantStock;
}
