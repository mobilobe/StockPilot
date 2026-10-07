import 'package:hive/hive.dart';
import 'package:inventory/models/inventory_order_item.dart';

part 'sale_line_item.g.dart';

@HiveType(typeId: 2)
class SaleLineItem {
  @HiveField(0)
  int quantity;

  @HiveField(1)
  double unitPrice;

  @HiveField(2)
  String source;

  @HiveField(3)
  InventoryOrderItem? orderItem;

  SaleLineItem({
    required this.quantity,
    required this.unitPrice,
    required this.source,
    this.orderItem,
  });
}
