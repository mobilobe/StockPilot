import 'dart:math';

import 'package:hive/hive.dart';
import 'package:inventory/models/inventory_order_item.dart';

part 'order.g.dart';

@HiveType(typeId: 4)
class Order {
  final String id;

  @HiveField(0)
  DateTime date;

  @HiveField(1)
  List<InventoryOrderItem> inventoryList;

  @HiveField(2)
  double shipping;

  @HiveField(3)
  double fees;

  @HiveField(4)
  double totalOrderPrice;

  @HiveField(5)
  String folder;

  bool isInputTransfer;
  String? transferSourceItemId;
  String? transferDestinationItemId;
  String? transferSourceItemName;
  String? transferDestinationItemName;
  String? transferSourceVariant;
  String? transferDestinationVariant;
  double? transferUnitCost;
  int? transferQuantity;
  List<Map<String, dynamic>> transferFifoBreakdown;

  Order(
    this.date,
    this.inventoryList,
    this.shipping,
    this.fees,
    this.totalOrderPrice,
    this.folder, {
    this.isInputTransfer = false,
    this.transferSourceItemId,
    this.transferDestinationItemId,
    this.transferSourceItemName,
    this.transferDestinationItemName,
    this.transferSourceVariant,
    this.transferDestinationVariant,
    this.transferUnitCost,
    this.transferQuantity,
    List<Map<String, dynamic>>? transferFifoBreakdown,
    String? id,
  }) : transferFifoBreakdown =
           transferFifoBreakdown ?? <Map<String, dynamic>>[],
       id =
           id ??
           'order_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1 << 20)}';
}
