import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:inventory/services/hive_data.dart';
import 'package:inventory/services/migration_state_store.dart';
import 'package:inventory/models/inventory_item.dart';
import 'package:inventory/models/order.dart' as inventory_order;
import 'package:inventory/models/sale.dart';

enum MigrationResult { verified, incomplete }

class HiveFirestoreMigrationService {
  HiveFirestoreMigrationService({
    FirebaseFirestore? firestore,
    HiveService? hiveService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _hiveService = hiveService ?? HiveService();

  static const _batchSize = 400;

  final FirebaseFirestore _firestore;
  final HiveService _hiveService;

  Future<MigrationResult> migrateInventory(String userId) async {
    if (await MigrationStateStore.hasMigrated(userId)) {
      return MigrationResult.verified;
    }

    final inventoryItems = List<InventoryItem>.from(
      _hiveService.getInventoryItems(),
    );
    final orders = List<inventory_order.Order>.from(_hiveService.getOrders());
    final sales = _collectSales(inventoryItems, _hiveService.getSales());
    final checksum = _inventoryChecksum(inventoryItems);
    final inventory = _firestore
        .collection('users')
        .doc(userId)
        .collection('inventory');

    try {
      final hasLocalData =
          inventoryItems.isNotEmpty ||
          orders.isNotEmpty ||
          sales.isNotEmpty ||
          _hiveService.getFolderColors().isNotEmpty ||
          _hiveService.getFolderMeta().isNotEmpty;
      if (!hasLocalData && (await inventory.get()).docs.isNotEmpty) {
        await MigrationStateStore.setMigrated(userId, true);
        return MigrationResult.verified;
      }

      for (var start = 0; start < inventoryItems.length; start += _batchSize) {
        final end = (start + _batchSize).clamp(0, inventoryItems.length);
        final batch = _firestore.batch();

        for (final item in inventoryItems.sublist(start, end)) {
          if (item.id.trim().isEmpty) {
            throw FormatException('Inventory items require a non-empty ID.');
          }
          batch.set(inventory.doc(item.id), _itemToFirestore(item));
        }

        await batch.commit();
      }

      await _writeOrders(userId, orders);
      await _writeSales(userId, sales);
      await _writeFolderSettings(userId);

      final remoteInventory = await inventory.get();
      final missingInventoryIds = inventoryItems
          .map((item) => item.id)
          .where(
            (id) => !remoteInventory.docs.any((document) => document.id == id),
          )
          .toList();
      final remoteOrders = await _firestore
          .collection('users')
          .doc(userId)
          .collection('orders')
          .get();
      final missingOrderIds = orders
          .map((order) => order.id)
          .where(
            (id) => !remoteOrders.docs.any((document) => document.id == id),
          )
          .toList();
      final remoteSales = await _firestore
          .collection('users')
          .doc(userId)
          .collection('sales')
          .get();
      final missingSaleIds = sales
          .map((record) => record.sale.id)
          .where((id) => !remoteSales.docs.any((document) => document.id == id))
          .toList();
      if (missingInventoryIds.isNotEmpty ||
          missingOrderIds.isNotEmpty ||
          missingSaleIds.isNotEmpty) {
        debugPrint(
          'Migration verification failed for $userId: '
          'missing inventory=${missingInventoryIds.length}, '
          'orders=${missingOrderIds.length}, sales=${missingSaleIds.length}, '
          'checksum=$checksum',
        );
        await MigrationStateStore.setMigrated(userId, false);
        return MigrationResult.incomplete;
      }

      await MigrationStateStore.setMigrated(userId, true);
      return MigrationResult.verified;
    } catch (error, stackTrace) {
      debugPrint('Inventory migration failed for $userId: $error\n$stackTrace');
      await MigrationStateStore.setMigrated(userId, false);
      return MigrationResult.incomplete;
    }
  }

  Future<void> _writeOrders(
    String userId,
    List<inventory_order.Order> orders,
  ) async {
    final collection = _firestore
        .collection('users')
        .doc(userId)
        .collection('orders');
    for (var start = 0; start < orders.length; start += _batchSize) {
      final end = (start + _batchSize).clamp(0, orders.length);
      final batch = _firestore.batch();
      for (final order in orders.sublist(start, end)) {
        batch.set(collection.doc(order.id), <String, Object?>{
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
          'updatedBy': 'migration',
        });
      }
      await batch.commit();
    }
  }

  Future<void> _writeSales(
    String userId,
    List<({Sale sale, String? inventoryItemId})> sales,
  ) async {
    final collection = _firestore
        .collection('users')
        .doc(userId)
        .collection('sales');
    for (var start = 0; start < sales.length; start += _batchSize) {
      final end = (start + _batchSize).clamp(0, sales.length);
      final batch = _firestore.batch();
      for (final record in sales.sublist(start, end)) {
        batch.set(
          collection.doc(record.sale.id),
          _saleToFirestore(record.sale, record.inventoryItemId),
        );
      }
      await batch.commit();
    }
  }

  Future<void> _writeFolderSettings(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('settings')
        .doc('folders')
        .set(<String, Object?>{
          'colors': _hiveService.getFolderColors(),
          'metadata': _hiveService.getFolderMeta(),
          'lastModified': FieldValue.serverTimestamp(),
          'updatedBy': 'migration',
        });
  }

  Map<String, Object?> _itemToFirestore(InventoryItem item) {
    return <String, Object?>{
      'name': item.name,
      'price': item.price,
      'inventoryCount': item.inventoryCount,
      'soldCount': item.soldCount,
      'sku': item.sku,
      'folder': item.folder,
      'hasVariants': item.hasVariants,
      'variantValues': item.variantValues,
      'variantStock': item.variantStock,
      'lastModified': FieldValue.serverTimestamp(),
      'updatedBy': 'migration',
    };
  }

  Map<String, Object?> _saleToFirestore(Sale sale, String? inventoryItemId) {
    return <String, Object?>{
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
      'updatedBy': 'migration',
    };
  }

  List<({Sale sale, String? inventoryItemId})> _collectSales(
    List<InventoryItem> inventoryItems,
    List<Sale> hiveSales,
  ) {
    final records = <({Sale sale, String? inventoryItemId})>[];
    final seenIds = <String>{};
    for (final item in inventoryItems) {
      for (final sale in item.salesList) {
        if (seenIds.add(sale.id)) {
          records.add((sale: sale, inventoryItemId: item.id));
        }
      }
    }
    for (final sale in hiveSales) {
      if (seenIds.add(sale.id)) {
        records.add((sale: sale, inventoryItemId: null));
      }
    }
    return records;
  }

  int _inventoryChecksum(List<InventoryItem> items) {
    return items.fold(
      0,
      (checksum, item) =>
          checksum +
          item.id.codeUnits.fold(0, (codeUnitSum, unit) => codeUnitSum + unit),
    );
  }
}
