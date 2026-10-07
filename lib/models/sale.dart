import 'dart:math';

import 'package:hive/hive.dart';
import 'package:inventory/models/sale_line_item.dart';

part 'sale.g.dart';

@HiveType(typeId: 3)
class Sale {
  final String id;

  @HiveField(0)
  DateTime date;

  @HiveField(1)
  double price;

  @HiveField(2)
  double profit;

  @HiveField(3)
  int quantity;

  @HiveField(4)
  List<SaleLineItem> priceBreakdown;

  Sale({
    required this.date,
    required this.price,
    required this.profit,
    required this.quantity,
    required this.priceBreakdown,
    String? id,
  }) : id =
           id ??
           'sale_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1 << 20)}';
}
