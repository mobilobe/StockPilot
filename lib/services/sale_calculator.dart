import 'package:inventory/models/inventory_item.dart';
import 'package:inventory/models/inventory_order_item.dart';
import 'package:inventory/models/order.dart';
import 'package:inventory/models/sale.dart';
import 'package:inventory/models/sale_line_item.dart';

/// Units of [item] (and [variant], when it has variants) available to sell.
int availableStock(InventoryItem item, String? variant) {
  return item.hasVariants
      ? (item.variantStock[variant] ?? 0)
      : item.inventoryCount;
}

/// Calculates the FIFO cost layers for selling [quantityToSell] units.
/// Oldest orders are consumed first, then the item's initial price.
List<SaleLineItem> calculateFifoPriceBreakdown(
  InventoryItem item,
  int quantityToSell,
  String? selectedVariant,
) {
  final breakdown = <SaleLineItem>[];
  var remainingQuantity = quantityToSell;
  final sortedOrders = List<Order>.from(item.orderList)
    ..sort((a, b) => a.date.compareTo(b.date));

  for (final order in sortedOrders) {
    if (remainingQuantity <= 0) break;
    for (final InventoryOrderItem orderItem in order.inventoryList) {
      if (orderItem.inventoryItem.id != item.id || remainingQuantity <= 0) {
        continue;
      }
      if (item.hasVariants &&
          orderItem.selectedVariant != null &&
          orderItem.selectedVariant != selectedVariant) {
        continue;
      }

      final availableQuantity = orderItem.currentQuantity;
      if (availableQuantity > 0) {
        final quantityToUseHere = availableQuantity < remainingQuantity
            ? availableQuantity
            : remainingQuantity;
        final orderDate =
            '${order.date.year}-${order.date.month.toString().padLeft(2, '0')}-${order.date.day.toString().padLeft(2, '0')}';

        breakdown.add(
          SaleLineItem(
            quantity: quantityToUseHere,
            unitPrice: orderItem.shippedPrice,
            source: item.hasVariants
                ? 'Order - $orderDate (${orderItem.selectedVariant ?? selectedVariant ?? 'N/A'})'
                : 'Order - $orderDate',
            orderItem: orderItem,
          ),
        );
        remainingQuantity -= quantityToUseHere;
      }
      break;
    }
  }

  if (remainingQuantity > 0) {
    breakdown.add(
      SaleLineItem(
        quantity: remainingQuantity,
        unitPrice: item.price,
        source: (item.hasVariants && selectedVariant != null)
            ? 'Initial Price ($selectedVariant)'
            : 'Initial Price',
        orderItem: null,
      ),
    );
  }

  return breakdown;
}

/// Records a sale on [item]: consumes FIFO layers, updates stock and sold
/// counts, and appends the new [Sale] to the item's sales list.
Sale recordSale({
  required InventoryItem item,
  required int quantity,
  required double unitSalePrice,
  required DateTime date,
  String? variant,
}) {
  final priceBreakdown = calculateFifoPriceBreakdown(item, quantity, variant);
  final totalCostBasis = priceBreakdown.fold<double>(
    0.0,
    (sum, line) => sum + (line.quantity * line.unitPrice),
  );
  final totalSellingPrice = unitSalePrice * quantity;

  final sale = Sale(
    date: date,
    price: totalSellingPrice,
    profit: totalSellingPrice - totalCostBasis,
    quantity: quantity,
    priceBreakdown: priceBreakdown,
  );

  for (final line in priceBreakdown) {
    line.orderItem?.currentQuantity -= line.quantity;
  }

  item.soldCount += quantity;
  item.inventoryCount -= quantity;
  if (item.hasVariants && variant != null) {
    item.variantStock[variant] = (item.variantStock[variant] ?? 0) - quantity;
  }
  item.salesList.add(sale);
  return sale;
}
