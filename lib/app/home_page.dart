import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:inventory/core/data_mode.dart';
import 'package:inventory/services/firebase_initializer.dart';
import 'package:inventory/services/firestore_app_data.dart';
import 'package:inventory/services/hive_firestore_migration_service.dart';
import 'package:inventory/services/migration_state_store.dart';
import 'package:inventory/services/hive_data.dart';
import 'package:inventory/features/analytics/screens/analytics_page.dart';
import 'package:inventory/features/inventory/screens/catalog_page.dart';
import 'package:inventory/features/reports/screens/quarterly_reports_page.dart';
import 'package:inventory/features/orders/screens/order_page.dart';
import 'package:inventory/models/inventory_item.dart';
import 'package:inventory/models/sale.dart';
import 'package:inventory/models/order.dart';
import 'package:inventory/core/firebase_platform.dart';

/// Owns the app-wide inventory, sales, and order state shared by feature pages.
/// Chooses Hive or Firestore as the current persistence source.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

/// Loads app data and passes mutation callbacks down to the feature screens
class _HomePageState extends State<HomePage> {
  final HiveService _hiveService = HiveService();
  FirestoreAppDataStore? _firestoreStore;
  Map<String, InventoryQuantitySnapshot> _syncedQuantities =
      <String, InventoryQuantitySnapshot>{};
  bool _isSaving = false;
  bool _saveQueued = false;

  List<Sale> saleList = [];
  List<InventoryItem> inventoryList = [];
  List<Order> orderList = [];

  /// Current tab: Catalog, Orders, Analytics, or Reports.
  int pageIndex = 0;

  @override
  void initState() {
    super.initState();
    DataModeStore.changes.addListener(_reloadDataForModeChange);
    _reloadDataForModeChange();
    _retryIncompleteMigration();
  }

  @override
  void dispose() {
    DataModeStore.changes.removeListener(_reloadDataForModeChange);
    super.dispose();
  }

  void _reloadDataForModeChange() {
    _loadData().catchError((Object error, StackTrace stackTrace) {
      debugPrint('App data load failed: $error\n$stackTrace');
    });
  }

  Future<FirestoreAppDataStore> _getFirestoreStore() async {
    await FirebaseInitializer.ensureInitialized();
    return _firestoreStore ??= FirestoreAppDataStore();
  }

  /// Retries only the migration tied to the account that previously opted in.
  Future<void> _retryIncompleteMigration() async {
    if (!supportsFirebaseAuthentication ||
        await DataModeStore.get() != DataMode.guestHiveOnly) {
      return;
    }

    final pendingUserId = await MigrationStateStore.getPendingUserId();
    if (pendingUserId == null) {
      return;
    }

    try {
      await FirebaseInitializer.ensureInitialized();
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.uid != pendingUserId) {
        return;
      }

      final result = await HiveFirestoreMigrationService().migrateInventory(
        user.uid,
      );
      if (result == MigrationResult.verified) {
        await _hiveService.clearAll();
        await DataModeStore.set(DataMode.syncedFirestore);
        await MigrationStateStore.clearPendingUserId();
      }
    } catch (_) {
      // Keep local data active
    }
  }

  Future<void> _loadData() async {
    // Guest mode reads Hive; a verified signed-in session reads Firestore.
    final dataMode = await DataModeStore.get();
    late List<InventoryItem> loadedInventory;
    late List<Sale> loadedSales;
    late List<Order> loadedOrders;

    if (!supportsFirebaseAuthentication) {
      loadedInventory = _hiveService.getInventoryItems();
      loadedSales = _hiveService.getSales();
      loadedOrders = _hiveService.getOrders();
    } else {
      await FirebaseInitializer.ensureInitialized();
      final signedInUser = FirebaseAuth.instance.currentUser;
      if (signedInUser == null) {
        if (dataMode == DataMode.syncedFirestore) {
          await _hiveService.clearAll();
          await DataModeStore.set(DataMode.guestHiveOnly);
        }
        loadedInventory = _hiveService.getInventoryItems();
        loadedSales = _hiveService.getSales();
        loadedOrders = _hiveService.getOrders();
      } else if (dataMode != DataMode.syncedFirestore ||
          !await MigrationStateStore.hasMigrated(signedInUser.uid)) {
        throw StateError('Signed-in users must complete Firebase sync first.');
      } else {
        final cloudData = await (await _getFirestoreStore()).load();
        loadedInventory = cloudData.inventory;
        loadedSales = cloudData.sales;
        loadedOrders = cloudData.orders;
        _syncedQuantities = {
          for (final item in loadedInventory)
            item.id: InventoryQuantitySnapshot.fromItem(item),
        };
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      inventoryList = [...loadedInventory];
      saleList = loadedSales.isNotEmpty
          ? [...loadedSales]
          : [..._collectSalesFromInventory(loadedInventory)];
      orderList = [...loadedOrders];
    });
  }

  Future<void> _saveData() async {
    _saveQueued = true;
    if (_isSaving) {
      return;
    }

    _isSaving = true;
    try {
      while (_saveQueued) {
        _saveQueued = false;

        final updatedInventory = [...inventoryList];
        final updatedSales = _collectSalesFromInventory(updatedInventory);

        if (mounted) {
          setState(() {
            inventoryList = updatedInventory;
            saleList = [...updatedSales];
            orderList = [...orderList];
          });
        } else {
          inventoryList = updatedInventory;
          saleList = [...updatedSales];
          orderList = [...orderList];
        }

        final signedInUser = FirebaseAuth.instance.currentUser;
        final useFirestore =
            signedInUser != null &&
            await DataModeStore.get() == DataMode.syncedFirestore;
        if (useFirestore) {
          await (await _getFirestoreStore()).save(
            inventory: inventoryList,
            orders: orderList,
            sales: saleList,
            previousQuantities: _syncedQuantities,
          );
          _syncedQuantities = {
            for (final item in inventoryList)
              item.id: InventoryQuantitySnapshot.fromItem(item),
          };
        } else {
          await _hiveService.saveInventoryItems(inventoryList);
          await _hiveService.saveSales(saleList);
          await _hiveService.saveOrders(orderList);
        }
      }
    } catch (error, stackTrace) {
      debugPrint('App data save failed: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save cloud changes. Please try again.'),
          ),
        );
      }
    } finally {
      _isSaving = false;
    }
  }

  List<Sale> _collectSalesFromInventory(List<InventoryItem> items) {
    // Inventory items own their sale history, so this function adds all sales to an app-wide list
    final collectedSales = <Sale>[];
    for (final item in items) {
      collectedSales.addAll(item.salesList);
    }
    return collectedSales;
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      CatalogPage(
        inventoryList: inventoryList,
        saleList: saleList,
        orderList: orderList,
        onDataChanged: () {
          _saveData();
        },
      ),
      OrderPage(
        orderList: orderList,
        inventoryList: inventoryList,
        onDataChanged: () {
          _saveData();
        },
      ),
      AnalyticsPage(
        inventoryList: inventoryList,
        saleList: saleList,
        orderList: orderList,
      ),
      QuarterlyReportsPage(
        inventoryList: inventoryList,
        saleList: saleList,
        orderList: orderList,
        onInventoryImported: (importedItems, importedOrders) {
          setState(() {
            inventoryList = [...inventoryList, ...importedItems];
            orderList = [...orderList, ...importedOrders];
            saleList = _collectSalesFromInventory(inventoryList);
          });
          _saveData();
        },
      ),
    ];

    return Scaffold(
      body: pages[pageIndex],
      bottomNavigationBar: BottomNavigationBar(
        onTap: (value) {
          setState(() {
            pageIndex = value;
          });
        },
        currentIndex: pageIndex,
        items: const <BottomNavigationBarItem>[
          // Catalog tab: view and manage inventory
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2),
            label: 'Catalog',
          ),
          // Orders tab: manage incoming orders
          BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping_outlined),
            activeIcon: Icon(Icons.local_shipping),
            label: 'Orders',
          ),
          // Analytics tab: view sales and inventory analytics
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics_outlined),
            activeIcon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
          // Reports tab: quarterly reports and spreadsheets
          BottomNavigationBarItem(
            icon: Icon(Icons.file_copy_outlined),
            activeIcon: Icon(Icons.file_copy),
            label: 'Reports',
          ),
        ],
      ),
    );
  }
}
