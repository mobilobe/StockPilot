import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory/services/firestore_app_data.dart';
import 'package:inventory/models/inventory_item.dart';
import 'package:inventory/models/inventory_order_item.dart';
import 'package:inventory/models/order.dart';
import 'package:inventory/models/sale.dart';
import 'package:inventory/models/sale_line_item.dart';

void main() {
  test(
    'saves new inventory, orders, and sales as separate Firestore documents',
    () async {
      final firestore = FakeFirebaseFirestore();
      final store = FirestoreAppDataStore(
        firestore: firestore,
        userIdProvider: () => 'user-a',
      );
      final item = InventoryItem(
        'Widget',
        10,
        4,
        1,
        'WIDGET-01',
        'inv-1',
        <Order>[],
        <Sale>[
          Sale(
            id: 'sale-1',
            date: DateTime(2026, 1, 1),
            price: 15,
            profit: 5,
            quantity: 1,
            priceBreakdown: <SaleLineItem>[
              SaleLineItem(quantity: 1, unitPrice: 10, source: 'Initial Price'),
            ],
          ),
        ],
        'Catalog',
      );
      final order = Order(
        DateTime(2026, 1, 2),
        <InventoryOrderItem>[InventoryOrderItem(item, 2, 10, 10, 2)],
        0,
        0,
        20,
        'Catalog',
        id: 'order-1',
        isInputTransfer: true,
        transferSourceItemId: 'source-1',
        transferDestinationItemId: 'inv-1',
        transferSourceVariant: 'Blue',
        transferDestinationVariant: 'Large',
        transferUnitCost: 7.5,
        transferQuantity: 2,
        transferFifoBreakdown: <Map<String, dynamic>>[
          <String, dynamic>{'quantity': 2, 'unitCost': 7.5},
        ],
      );

      await store.save(
        inventory: <InventoryItem>[item],
        orders: <Order>[order],
        sales: item.salesList,
        previousQuantities: <String, InventoryQuantitySnapshot>{},
      );

      final user = firestore.collection('users').doc('user-a');
      final inventory = await user.collection('inventory').doc('inv-1').get();
      final orders = await user.collection('orders').get();
      final sales = await user.collection('sales').get();
      expect(inventory.exists, isTrue);
      expect(inventory.data()!.containsKey('salesList'), isFalse);
      expect(orders.docs, hasLength(1));
      expect(sales.docs, hasLength(1));
      expect(sales.docs.single.data()['inventoryItemId'], 'inv-1');

      final loaded = await store.load();
      expect(loaded.inventory, hasLength(1));
      expect(loaded.orders, hasLength(1));
      expect(loaded.orders.single.inventoryList, hasLength(1));
      expect(
        loaded.orders.single.inventoryList.single.inventoryItem.id,
        'inv-1',
      );
      expect(loaded.inventory.single.orderList, hasLength(1));
      expect(loaded.inventory.single.orderList.single.id, 'order-1');
      expect(loaded.orders.single.isInputTransfer, isTrue);
      expect(loaded.orders.single.transferSourceItemId, 'source-1');
      expect(loaded.orders.single.transferDestinationVariant, 'Large');
      expect(loaded.orders.single.transferUnitCost, 7.5);
      expect(loaded.orders.single.transferFifoBreakdown, hasLength(1));
      expect(loaded.sales, hasLength(1));
      expect(loaded.inventory.single.salesList.single.id, 'sale-1');
    },
  );

  test('keeps large quantity updates within Firestore batch limits', () async {
    final firestore = FakeFirebaseFirestore();
    final store = FirestoreAppDataStore(
      firestore: firestore,
      userIdProvider: () => 'user-a',
    );
    final items = List<InventoryItem>.generate(
      300,
      (index) => InventoryItem(
        'Widget $index',
        10,
        4,
        1,
        'WIDGET-$index',
        'inv-$index',
        <Order>[],
        <Sale>[],
        'Catalog',
      ),
    );
    final previousQuantities = <String, InventoryQuantitySnapshot>{
      for (final item in items)
        item.id: const InventoryQuantitySnapshot(
          inventoryCount: 3,
          soldCount: 1,
          variantStock: <String, int>{},
        ),
    };

    for (final item in items) {
      await firestore
          .collection('users')
          .doc('user-a')
          .collection('inventory')
          .doc(item.id)
          .set(<String, Object?>{
            'inventoryCount': 3,
            'soldCount': 1,
            'variantStock': <String, int>{},
          });
    }

    await store.save(
      inventory: items,
      orders: <Order>[],
      sales: <Sale>[],
      previousQuantities: previousQuantities,
    );

    expect(
      (await firestore
              .collection('users')
              .doc('user-a')
              .collection('inventory')
              .get())
          .docs,
      hasLength(300),
    );
  });

  test('updates existing inventory in one Firestore write', () async {
    final firestore = FakeFirebaseFirestore();
    final store = FirestoreAppDataStore(
      firestore: firestore,
      userIdProvider: () => 'user-a',
    );
    final item = InventoryItem(
      'Widget',
      12,
      7,
      2,
      'WIDGET-01',
      'inv-1',
      <Order>[],
      <Sale>[],
      'Catalog',
    );
    await firestore
        .collection('users')
        .doc('user-a')
        .collection('inventory')
        .doc(item.id)
        .set(<String, Object?>{
          'inventoryCount': 5,
          'soldCount': 1,
          'variantStock': <String, int>{},
        });

    await store.save(
      inventory: <InventoryItem>[item],
      orders: <Order>[],
      sales: <Sale>[],
      previousQuantities: <String, InventoryQuantitySnapshot>{
        item.id: const InventoryQuantitySnapshot(
          inventoryCount: 5,
          soldCount: 1,
          variantStock: <String, int>{},
        ),
      },
    );

    final saved = await firestore
        .collection('users')
        .doc('user-a')
        .collection('inventory')
        .doc(item.id)
        .get();
    expect(saved.data()!['inventoryCount'], 7);
    expect(saved.data()!['soldCount'], 2);
    expect(saved.data()!['price'], 12);
  });

  test('deletes records removed from the current app state', () async {
    final firestore = FakeFirebaseFirestore();
    final store = FirestoreAppDataStore(
      firestore: firestore,
      userIdProvider: () => 'user-a',
    );
    final user = firestore.collection('users').doc('user-a');
    await user
        .collection('inventory')
        .doc('stale-item')
        .set(<String, Object?>{});
    await user.collection('orders').doc('stale-order').set(<String, Object?>{});
    await user.collection('sales').doc('stale-sale').set(<String, Object?>{});

    await store.save(
      inventory: <InventoryItem>[],
      orders: <Order>[],
      sales: <Sale>[],
      previousQuantities: <String, InventoryQuantitySnapshot>{},
    );

    expect((await user.collection('inventory').get()).docs, isEmpty);
    expect((await user.collection('orders').get()).docs, isEmpty);
    expect((await user.collection('sales').get()).docs, isEmpty);
  });

  test(
    'loads legacy inventoryList order lines for signed-in exports',
    () async {
      final firestore = FakeFirebaseFirestore();
      await firestore
          .collection('users')
          .doc('user-a')
          .collection('inventory')
          .doc('inv-1')
          .set(<String, Object?>{
            'name': 'Widget',
            'sku': 'WIDGET-01',
            'price': 10,
            'inventoryCount': 4,
            'soldCount': 0,
            'folder': 'Catalog',
          });
      await firestore
          .collection('users')
          .doc('user-a')
          .collection('orders')
          .doc('order-legacy')
          .set(<String, Object?>{
            'date': '2026-01-02T00:00:00.000',
            'shipping': 0,
            'fees': 0,
            'totalOrderPrice': 20,
            'folder': 'Catalog',
            'inventoryList': <Map<String, Object?>>[
              <String, Object?>{
                'inventoryItemId': 'inv-1',
                'name': 'Widget',
                'sku': 'WIDGET-01',
                'quantity': 2,
                'price': 10,
                'shippedPrice': 10,
                'currentQuantity': 2,
              },
            ],
          });

      final loaded = await FirestoreAppDataStore(
        firestore: firestore,
        userIdProvider: () => 'user-a',
      ).load();

      expect(loaded.orders, hasLength(1));
      expect(loaded.orders.single.inventoryList, hasLength(1));
      expect(loaded.inventory.single.orderList, hasLength(1));
    },
  );
}
