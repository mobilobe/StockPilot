import 'package:flutter_test/flutter_test.dart';
import 'package:inventory/features/analytics/screens/analytics_page.dart';
import 'package:inventory/models/inventory_item.dart';
import 'package:inventory/models/inventory_order_item.dart';
import 'package:inventory/models/order.dart';

void main() {
  group('FIFO inventory valuation', () {
    test('uses shipped cost before fallback price for remaining stock', () {
      final item = InventoryItem(
        'Widget',
        25.0,
        5,
        0,
        'SKU-1',
        'item-1',
        [],
        [],
        'General',
      );

      final firstOrder = Order(
        DateTime(2024, 1, 1),
        [InventoryOrderItem(item, 3, 10.0, 10.0, 3)],
        0,
        0,
        0,
        'General',
      );

      final secondOrder = Order(
        DateTime(2024, 1, 10),
        [InventoryOrderItem(item, 4, 12.0, 12.0, 4)],
        0,
        0,
        0,
        'General',
      );

      item.orderList.addAll([firstOrder, secondOrder]);
      item.inventoryCount = 5;

      expect(calculateFifoValueForQuantity(item, 5), 10.0 * 3 + 12.0 * 2);
    });

    test('sums each item value using FIFO cost basis', () {
      final itemA = InventoryItem(
        'A',
        20.0,
        2,
        0,
        'A-1',
        'a',
        [],
        [],
        'General',
      );
      final itemB = InventoryItem(
        'B',
        30.0,
        1,
        0,
        'B-1',
        'b',
        [],
        [],
        'General',
      );

      final orderA = Order(
        DateTime(2024, 2, 1),
        [InventoryOrderItem(itemA, 2, 8.0, 8.0, 2)],
        0,
        0,
        0,
        'General',
      );
      itemA.orderList.add(orderA);

      final orderB = Order(
        DateTime(2024, 2, 5),
        [InventoryOrderItem(itemB, 3, 14.0, 14.0, 3)],
        0,
        0,
        0,
        'General',
      );
      itemB.orderList.add(orderB);
      itemB.inventoryCount = 1;

      expect(calculateFifoInventoryValue([itemA, itemB]), 8.0 * 2 + 14.0 * 1);
    });
  });
}
