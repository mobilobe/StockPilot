import 'package:hive/hive.dart';
import 'package:inventory/models/inventory_item.dart';

part 'inventory_order_item.g.dart';

@HiveType(typeId: 1)
class InventoryOrderItem {
  @HiveField(0)
  InventoryItem inventoryItem;

  @HiveField(1)
  int quantity;

  @HiveField(2)
  double price;

  @HiveField(3)
  double shippedPrice;

  @HiveField(4)
  int currentQuantity;

  @HiveField(5)
  String? selectedVariant;

  InventoryOrderItem(
    this.inventoryItem,
    this.quantity,
    this.price,
    this.shippedPrice,
    this.currentQuantity, {
    this.selectedVariant,
  });
}
