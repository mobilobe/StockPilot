import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory/features/inventory/screens/add_sale_page.dart';
import 'package:inventory/models/inventory_item.dart';
import 'package:inventory/models/inventory_order_item.dart';
import 'package:inventory/models/order.dart';
import 'package:inventory/services/sale_calculator.dart';

InventoryItem _widget({int stock = 5}) {
  final item = InventoryItem(
    'Widget',
    25.0,
    stock,
    0,
    'SKU-1',
    'item-1',
    [],
    [],
    'General',
  );
  item.orderList.add(
    Order(
      DateTime(2024, 1, 1),
      [InventoryOrderItem(item, 3, 10.0, 10.0, 3)],
      0,
      0,
      0,
      'General',
    ),
  );
  return item;
}

void main() {
  test('recordSale consumes FIFO layers and updates stock', () {
    final item = _widget();

    final sale = recordSale(
      item: item,
      quantity: 4,
      unitSalePrice: 30,
      date: DateTime(2024, 2, 1),
    );

    // 3 units at the 10.0 order cost + 1 unit at the 25.0 initial price.
    expect(sale.price, 120);
    expect(sale.profit, 120 - (3 * 10 + 25));
    expect(item.inventoryCount, 1);
    expect(item.soldCount, 4);
    expect(item.salesList, [sale]);
    expect(item.orderList.single.inventoryList.single.currentQuantity, 0);
  });

  testWidgets('Add Sale page records a sale picked from the catalog list', (
    tester,
  ) async {
    final item = _widget();
    var saved = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddSalePage(
                  inventoryList: [item],
                  onSaleAdded: () => saved = true,
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Record Sale'));
    await tester.pump();
    expect(find.text('Please add at least one item to the sale'), findsOne);
    expect(saved, isFalse);

    await tester.tap(find.text('Add Item'));
    await tester.pumpAndSettle();
    expect(find.text('Create New Item'), findsNothing);
    await tester.tap(find.text('Widget'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '30');
    await tester.enterText(fields.at(1), '9');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.text('Not enough stock (available: 5)'), findsOne);

    await tester.enterText(fields.at(1), '2');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.text('Total: \$60.00'), findsOne);

    await tester.tap(find.text('Record Sale'));
    await tester.pumpAndSettle();

    expect(saved, isTrue);
    expect(item.soldCount, 2);
    expect(item.inventoryCount, 3);
    expect(item.salesList.single.price, 60);
  });
}
