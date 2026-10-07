import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:inventory/services/hive_data.dart';
import 'package:inventory/services/hive_firestore_migration_service.dart';
import 'package:inventory/services/migration_state_store.dart';
import 'package:inventory/models/inventory_item.dart';
import 'package:inventory/models/order.dart';
import 'package:inventory/models/sale.dart';
import 'package:inventory/models/sale_line_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory hiveDirectory;
  late Box<dynamic> hiveBox;
  late HiveService hiveService;

  InventoryItem item(int index, {String? id}) => InventoryItem(
    'Item $index',
    10,
    index + 1,
    0,
    'SKU-$index',
    id ?? 'inv-$index',
    <Order>[],
    <Sale>[],
    'Catalog',
  );

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('inventory_test_');
    Hive.init(hiveDirectory.path);
    hiveBox = await Hive.openBox<dynamic>('data');
    hiveService = HiveService();
  });

  setUp(() async {
    await hiveBox.clear();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDownAll(() async {
    await hiveBox.close();
    await hiveDirectory.delete(recursive: true);
  });

  test('migrates Hive inventory and retains local records', () async {
    final firestore = FakeFirebaseFirestore();
    final items = <InventoryItem>[item(1), item(2)];
    items.first.salesList.add(
      Sale(
        date: DateTime(2026, 1, 1),
        price: 10,
        profit: 5,
        quantity: 1,
        priceBreakdown: <SaleLineItem>[],
        id: 'sale-1',
      ),
    );
    await hiveService.saveInventoryItems(items);

    final result = await HiveFirestoreMigrationService(
      firestore: firestore,
      hiveService: hiveService,
    ).migrateInventory('user-a');

    expect(result, MigrationResult.verified);
    expect(await MigrationStateStore.hasMigrated('user-a'), isTrue);
    expect(
      hiveService.getInventoryItems().map((item) => item.sku),
      orderedEquals(<String>['SKU-1', 'SKU-2']),
    );

    final inventory = await firestore
        .collection('users')
        .doc('user-a')
        .collection('inventory')
        .get();
    expect(inventory.docs, hasLength(2));
    expect(inventory.docs.first.data()['sku'], 'SKU-1');
    expect(inventory.docs.first.data().containsKey('salesList'), isFalse);
    final sales = await firestore
        .collection('users')
        .doc('user-a')
        .collection('sales')
        .get();
    expect(sales.docs, hasLength(1));
    expect(sales.docs.single.data()['inventoryItemId'], 'inv-1');
  });

  test('does not repeat a completed migration for the same user', () async {
    final firestore = FakeFirebaseFirestore();
    await hiveService.saveInventoryItems(<InventoryItem>[item(1)]);
    final migration = HiveFirestoreMigrationService(
      firestore: firestore,
      hiveService: hiveService,
    );

    expect(
      await migration.migrateInventory('user-a'),
      MigrationResult.verified,
    );
    final reference = firestore
        .collection('users')
        .doc('user-a')
        .collection('inventory')
        .doc('inv-1');
    await reference.set(<String, Object?>{
      'sentinel': true,
    }, SetOptions(merge: true));

    expect(
      await migration.migrateInventory('user-a'),
      MigrationResult.verified,
    );
    expect((await reference.get()).data()!['sentinel'], isTrue);
  });

  test('adopts existing cloud inventory when local storage is empty', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore
        .collection('users')
        .doc('user-a')
        .collection('inventory')
        .doc('cloud-item')
        .set(<String, Object?>{'name': 'Cloud item'});

    final result = await HiveFirestoreMigrationService(
      firestore: firestore,
      hiveService: hiveService,
    ).migrateInventory('user-a');

    expect(result, MigrationResult.verified);
    expect(await MigrationStateStore.hasMigrated('user-a'), isTrue);
    expect(
      (await firestore
              .collection('users')
              .doc('user-a')
              .collection('inventory')
              .get())
          .docs,
      hasLength(1),
    );
  });

  test(
    'does not write or mark migration complete when validation fails',
    () async {
      final firestore = FakeFirebaseFirestore();
      await hiveService.saveInventoryItems(<InventoryItem>[item(1, id: '')]);

      final result = await HiveFirestoreMigrationService(
        firestore: firestore,
        hiveService: hiveService,
      ).migrateInventory('user-a');

      expect(result, MigrationResult.incomplete);
      expect(await MigrationStateStore.hasMigrated('user-a'), isFalse);
      expect(
        (await firestore
                .collection('users')
                .doc('user-a')
                .collection('inventory')
                .get())
            .docs,
        isEmpty,
      );
    },
  );

  test(
    'migrates 1,000 items without exceeding Firestore batch limits',
    () async {
      final firestore = FakeFirebaseFirestore();
      await hiveService.saveInventoryItems(
        List<InventoryItem>.generate(1000, (index) => item(index)),
      );

      final result = await HiveFirestoreMigrationService(
        firestore: firestore,
        hiveService: hiveService,
      ).migrateInventory('user-a');

      expect(result, MigrationResult.verified);
      expect(
        (await firestore
                .collection('users')
                .doc('user-a')
                .collection('inventory')
                .get())
            .docs,
        hasLength(1000),
      );
    },
  );
}
