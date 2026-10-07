import 'package:hive/hive.dart';
import 'package:inventory/models/sale.dart';
import 'package:inventory/models/order.dart';

part 'inventory_item.g.dart';

@HiveType(typeId: 0)
class InventoryItem {
  @HiveField(0)
  String name;

  @HiveField(1)
  double price;

  @HiveField(2)
  int inventoryCount;

  @HiveField(3)
  int soldCount;

  @HiveField(4)
  String sku;

  @HiveField(5)
  String id;

  @HiveField(6)
  List<Order> orderList;

  @HiveField(7)
  List<Sale> salesList;

  @HiveField(8)
  String folder;

  @HiveField(9)
  bool hasVariants;

  @HiveField(11)
  List<String> variantValues;

  @HiveField(12)
  Map<String, int> variantStock;

  InventoryItem(
    this.name,
    this.price,
    this.inventoryCount,
    this.soldCount,
    this.sku,
    this.id,
    this.orderList,
    this.salesList,
    this.folder, {
    this.hasVariants = false,
    List<String>? variantValues,
    Map<String, int>? variantStock,
  }) : variantValues = variantValues ?? <String>[],
       variantStock = variantStock ?? <String, int>{};
}
