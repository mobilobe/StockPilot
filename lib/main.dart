import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:inventory/app/app.dart';
import 'package:inventory/models/inventory_item.dart';
import 'package:inventory/models/inventory_order_item.dart';
import 'package:inventory/models/sale.dart';
import 'package:inventory/models/sale_line_item.dart';
import 'package:inventory/models/order.dart';
import 'package:inventory/services/firebase_initializer.dart';

/// Initializes local storage and platform Firebase before starting the UI.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await FirebaseInitializer.ensureInitialized();

  // Register adapters before opening the box so Hive can decode stored models.
  Hive.registerAdapter(InventoryItemAdapter());
  Hive.registerAdapter(InventoryOrderItemAdapter());
  Hive.registerAdapter(SaleLineItemAdapter());
  Hive.registerAdapter(SaleAdapter());
  Hive.registerAdapter(OrderAdapter());

  await Hive.openBox('data');

  runApp(const MainApp());
}
