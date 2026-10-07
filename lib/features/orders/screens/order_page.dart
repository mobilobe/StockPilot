import 'package:flutter/material.dart';
import 'package:inventory/features/orders/widgets/order_tile.dart';
import 'package:inventory/services/hive_data.dart';
import 'package:inventory/features/orders/screens/add_order_page.dart';
import 'package:inventory/features/orders/screens/edit_order_page.dart';
import 'package:inventory/features/inventory/screens/select_inventory_order_items_page.dart';
import 'package:inventory/models/order.dart';
import 'package:inventory/models/inventory_item.dart';
import 'package:inventory/models/inventory_order_item.dart';

/// Lists, filters, creates, edits, and removes incoming inventory orders.
class OrderPage extends StatefulWidget {
  final List<Order> orderList;
  final List<InventoryItem> inventoryList;
  final VoidCallback onDataChanged;

  const OrderPage({
    required this.orderList,
    required this.inventoryList,
    required this.onDataChanged,
    super.key,
  });

  @override
  State<OrderPage> createState() => _OrderPageState();
}

/// Owns order search, folder filters, and create/edit/delete navigation.
class _OrderPageState extends State<OrderPage> {
  static const double _contentMaxWidth = 1100;
  static const String _allFoldersLabel = 'All folders';
  static const String _uncategorizedLabel = 'Uncategorized';
  static const List<Color> _folderPalette = [
    Color(0xFF3498DB),
    Color(0xFF27AE60),
    Color(0xFFE67E22),
    Color(0xFF9B59B6),
    Color(0xFFE74C3C),
    Color(0xFF16A085),
    Color(0xFF2C3E50),
    Color(0xFFF39C12),
  ];

  String searchQuery = '';
  String selectedFolder = _allFoldersLabel;
  final List<String> _customFolders = <String>[];
  final Map<String, int> _folderColors = <String, int>{};
  Map<String, bool> _folderClosedByDefault = <String, bool>{};
  final HiveService _hiveService = HiveService();
  bool isFolderFilterExpanded = false;
  final Map<String, bool> _expandedFolders = <String, bool>{};
  bool _showInputTransfers = false;

  Color _colorForFolder(String folderName) {
    final savedColorValue = _folderColors[folderName];
    if (savedColorValue != null) {
      return Color(savedColorValue);
    }

    final index = folderName.hashCode.abs() % _folderPalette.length;
    return _folderPalette[index];
  }

  @override
  void initState() {
    super.initState();
    // Load persisted folder colors and metadata (closedByDefault)
    final colors = _hiveService.getFolderColors();
    if (colors.isNotEmpty) {
      _folderColors.addAll(colors);
    }
    final meta = _hiveService.getFolderMeta();
    _folderClosedByDefault = {
      for (final entry in meta.entries)
        entry.key:
            ((entry.value is Map && entry.value['closedByDefault'] == true) ||
            entry.value == true),
    };
  }

  List<String> _getOrderFoldersForAutofill() {
    final folders = <String>{
      for (final order in widget.orderList.where(
        (order) => !order.isInputTransfer,
      ))
        order.folder.trim().isEmpty ? _uncategorizedLabel : order.folder,
      ..._customFolders,
    }.toList()..sort();
    return folders;
  }

  void _addOrder(Order order) {
    setState(() {
      widget.orderList.add(order);
    });
    widget.onDataChanged();
  }

  void _deleteOrder(int index) {
    final orderToDelete = widget.orderList[index];

    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Delete Order',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C3E50),
          ),
        ),
        content: const Text(
          'Would you like to reduce inventory for affected items?',
          style: TextStyle(color: Color(0xFF2C3E50)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                for (var inventoryItem in widget.inventoryList) {
                  inventoryItem.orderList.removeWhere(
                    (order) => order == orderToDelete,
                  );
                }
                widget.orderList.removeAt(index);
              });
              widget.onDataChanged();
            },
            child: const Text('No', style: TextStyle(color: Color(0xFF3498DB))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Delete and reduce inventory
              setState(() {
                // Reduce inventory and remove order from all affected items
                for (var orderItem in orderToDelete.inventoryList) {
                  final inventoryItem = orderItem.inventoryItem;
                  // Reduce inventory count by the shipped quantity
                  inventoryItem.inventoryCount -= orderItem.quantity;
                  if (inventoryItem.inventoryCount < 0) {
                    inventoryItem.inventoryCount = 0;
                  }
                  // Remove order from item's list
                  inventoryItem.orderList.removeWhere(
                    (order) => order == orderToDelete,
                  );
                }
                widget.orderList.removeAt(index);
              });
              widget.onDataChanged();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE74C3C),
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  void _editOrder(Order order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditOrderPage(
          order: order,
          inventoryList: widget.inventoryList,
          existingFolders: _getOrderFoldersForAutofill(),
          onUpdateOrder: (updatedOrder) {
            setState(() {});
            widget.onDataChanged();
          },
        ),
      ),
    );
  }

  void _openAddOrderPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddOrderPage(
          inventoryList: widget.inventoryList,
          existingFolders: _getOrderFoldersForAutofill(),
          onAddOrder: _addOrder,
        ),
      ),
    );
  }

  void _showCreateFolderDialog() {
    final controller = TextEditingController();
    Color selectedColor = _folderPalette.isNotEmpty
        ? _folderPalette.first
        : const Color(0xFF3498DB);
    bool closedByDefault = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Create Folder'),
          content: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Folder name',
                        hintText: 'e.g. Priority Orders',
                      ),
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: closedByDefault,
                      onChanged: (v) {
                        setDialogState(() {
                          closedByDefault = v == true;
                        });
                      },
                      title: const Text('Closed by default'),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _folderPalette
                          .map(
                            (paletteColor) => InkWell(
                              onTap: () {
                                setDialogState(() {
                                  selectedColor = paletteColor;
                                });
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: paletteColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: selectedColor == paletteColor
                                        ? const Color(0xFF2C3E50)
                                        : Colors.white,
                                    width: selectedColor == paletteColor
                                        ? 2
                                        : 1,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                controller.dispose();
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final folderName = controller.text.trim();
                if (folderName.isEmpty) return;

                Navigator.pop(dialogContext);

                if (!_customFolders.contains(folderName)) {
                  setState(() {
                    _customFolders.add(folderName);
                    _customFolders.sort();
                  });
                }

                await _hiveService.setFolderColor(
                  folder: folderName,
                  colorValue: selectedColor.toARGB32(),
                );
                await _hiveService.setFolderClosedByDefault(
                  folder: folderName,
                  closed: closedByDefault,
                );

                setState(() {
                  _folderColors[folderName] = selectedColor.toARGB32();
                  _folderClosedByDefault[folderName] = closedByDefault;
                  selectedFolder = folderName;
                });
                controller.dispose();
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  List<String> _getFolders() {
    final folders = <String>{
      for (final order in widget.orderList.where(
        (order) => !order.isInputTransfer,
      ))
        order.folder.trim().isEmpty ? _uncategorizedLabel : order.folder,
      ..._customFolders,
    }.toList()..sort();
    return folders;
  }

  Future<bool> _showEditFolderDialog(String folderName) async {
    if (folderName == _uncategorizedLabel) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uncategorized folder cannot be edited')),
      );
      return false;
    }

    final controller = TextEditingController(text: folderName);
    Color selectedColor = _colorForFolder(folderName);

    final didSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Folder'),
          content: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Folder name',
                      ),
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: _folderClosedByDefault[folderName] ?? false,
                      onChanged: (v) {
                        setDialogState(() {
                          _folderClosedByDefault[folderName] = v == true;
                        });
                      },
                      title: const Text('Closed by default'),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _folderPalette
                          .map(
                            (paletteColor) => InkWell(
                              onTap: () {
                                setDialogState(() {
                                  selectedColor = paletteColor;
                                });
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: paletteColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: selectedColor == paletteColor
                                        ? const Color(0xFF2C3E50)
                                        : Colors.white,
                                    width: selectedColor == paletteColor
                                        ? 2
                                        : 1,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                controller.dispose();
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final shouldDelete = await _showDeleteFolderConfirmation(
                  folderName,
                );
                if (!shouldDelete) return;

                final deleted = await _deleteFolder(folderName);
                if (deleted) {
                  if (!dialogContext.mounted) return;
                  widget.onDataChanged();
                  Navigator.pop(dialogContext, true);
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFE74C3C),
              ),
              child: const Text('Delete'),
            ),
            FilledButton(
              onPressed: () async {
                final updatedName = controller.text.trim();
                if (updatedName.isEmpty) return;

                // Capture old meta
                final oldMeta = _folderClosedByDefault.remove(folderName);

                setState(() {
                  final index = _customFolders.indexOf(folderName);
                  if (index != -1) {
                    _customFolders[index] = updatedName;
                    _customFolders.sort();
                  } else if (!_customFolders.contains(updatedName)) {
                    _customFolders.add(updatedName);
                    _customFolders.sort();
                  }

                  for (final order in widget.orderList.where(
                    (order) => !order.isInputTransfer,
                  )) {
                    final orderFolder = order.folder.trim().isEmpty
                        ? _uncategorizedLabel
                        : order.folder;
                    if (orderFolder == folderName) {
                      order.folder = updatedName;
                    }
                  }

                  _folderColors.remove(folderName);
                  _folderColors[updatedName] = selectedColor.toARGB32();

                  if (selectedFolder == folderName) {
                    selectedFolder = updatedName;
                  }

                  final wasExpanded = _expandedFolders.remove(folderName);
                  if (wasExpanded != null) {
                    _expandedFolders[updatedName] = wasExpanded;
                  }

                  if (oldMeta != null) {
                    _folderClosedByDefault[updatedName] = oldMeta;
                  }
                });

                await _hiveService.saveFolderColors(_folderColors);
                if (oldMeta != null) {
                  await _hiveService.renameFolderMeta(folderName, updatedName);
                }
                await _hiveService.setFolderClosedByDefault(
                  folder: updatedName,
                  closed: _folderClosedByDefault[updatedName] ?? false,
                );

                if (!dialogContext.mounted) return;
                widget.onDataChanged();
                controller.dispose();
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    return didSave ?? false;
  }

  Future<bool> _showDeleteFolderConfirmation(String folderName) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Folder'),
        content: Text(
          'Delete "$folderName"? Orders in this folder will move to Uncategorized.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE74C3C),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    return shouldDelete ?? false;
  }

  Future<bool> _deleteFolder(String folderName) async {
    if (folderName == _uncategorizedLabel) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uncategorized folder cannot be deleted')),
      );
      return false;
    }

    setState(() {
      for (final order in widget.orderList.where(
        (order) => !order.isInputTransfer,
      )) {
        final orderFolder = order.folder.trim().isEmpty
            ? _uncategorizedLabel
            : order.folder;
        if (orderFolder == folderName) {
          order.folder = _uncategorizedLabel;
        }
      }

      _customFolders.remove(folderName);
      _folderColors.remove(folderName);

      if (selectedFolder == folderName) {
        selectedFolder = _allFoldersLabel;
      }

      _expandedFolders.remove(folderName);
    });
    await _hiveService.saveFolderColors(_folderColors);
    await _hiveService.removeFolderMeta(folderName);
    widget.onDataChanged();
    return true;
  }

  List<Order> _getFilteredOrders() {
    final normalizedQuery = searchQuery.trim().toLowerCase();

    return widget.orderList.where((order) {
      if (order.isInputTransfer) {
        return false;
      }

      final orderDate = order.date;
      final formattedDate =
          '${orderDate.year}-${orderDate.month.toString().padLeft(2, '0')}-${orderDate.day.toString().padLeft(2, '0')}';

      final hasSearchMatch =
          normalizedQuery.isEmpty ||
          formattedDate.toLowerCase().contains(normalizedQuery);
      if (!hasSearchMatch) {
        return false;
      }

      if (selectedFolder == _allFoldersLabel) {
        return true;
      }

      final orderFolder = order.folder.trim().isEmpty
          ? _uncategorizedLabel
          : order.folder;
      return orderFolder == selectedFolder;
    }).toList();
  }

  List<Order> _getFilteredInputTransfers() {
    final normalizedQuery = searchQuery.trim().toLowerCase();

    return widget.orderList.where((order) {
      if (!order.isInputTransfer) {
        return false;
      }

      final orderDate = order.date;
      final formattedDate =
          '${orderDate.year}-${orderDate.month.toString().padLeft(2, '0')}-${orderDate.day.toString().padLeft(2, '0')}';

      if (normalizedQuery.isEmpty) {
        return true;
      }

      return formattedDate.toLowerCase().contains(normalizedQuery) ||
          (order.transferSourceItemName ?? '').toLowerCase().contains(
            normalizedQuery,
          ) ||
          (order.transferDestinationItemName ?? '').toLowerCase().contains(
            normalizedQuery,
          );
    }).toList();
  }

  String _getOrderGroupName(Order order) {
    return order.folder.trim().isEmpty ? _uncategorizedLabel : order.folder;
  }

  bool _isSameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  bool _isNearlyEqual(double left, double right) {
    return (left - right).abs() < 0.0001;
  }

  InventoryItem? _findInventoryItemById(String? itemId) {
    if (itemId == null || itemId.trim().isEmpty) {
      return null;
    }

    for (final item in widget.inventoryList) {
      if (item.id == itemId) {
        return item;
      }
    }

    return null;
  }

  List<
    ({
      int quantity,
      double unitPrice,
      InventoryOrderItem? orderItem,
      DateTime? orderDate,
      String source,
      String? selectedVariant,
    })
  >
  _calculateTransferFifoBreakdown(
    InventoryItem sourceItem,
    int quantityToTransfer,
    String? sourceVariant,
  ) {
    final breakdown =
        <
          ({
            int quantity,
            double unitPrice,
            InventoryOrderItem? orderItem,
            DateTime? orderDate,
            String source,
            String? selectedVariant,
          })
        >[];

    var remainingQuantity = quantityToTransfer;

    final sortedOrders =
        sourceItem.orderList.where((order) => !order.isInputTransfer).toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    for (final order in sortedOrders) {
      if (remainingQuantity <= 0) {
        break;
      }

      for (final orderItem in order.inventoryList) {
        if (remainingQuantity <= 0) {
          break;
        }

        if (orderItem.inventoryItem.id != sourceItem.id) {
          continue;
        }

        if (sourceItem.hasVariants &&
            orderItem.selectedVariant != sourceVariant) {
          continue;
        }

        final available = orderItem.currentQuantity;
        if (available <= 0) {
          continue;
        }

        final used = available < remainingQuantity
            ? available
            : remainingQuantity;
        breakdown.add((
          quantity: used,
          unitPrice: orderItem.shippedPrice,
          orderItem: orderItem,
          orderDate: order.date,
          source:
              'Transfer Source - ${order.date.year}-${order.date.month.toString().padLeft(2, '0')}-${order.date.day.toString().padLeft(2, '0')}',
          selectedVariant: orderItem.selectedVariant ?? sourceVariant,
        ));

        remainingQuantity -= used;
      }
    }

    if (remainingQuantity > 0) {
      breakdown.add((
        quantity: remainingQuantity,
        unitPrice: sourceItem.price,
        orderItem: null,
        orderDate: null,
        source: 'Initial Price',
        selectedVariant: sourceVariant,
      ));
    }

    return breakdown;
  }

  List<Map<String, dynamic>> _encodeTransferFifoBreakdown(
    List<
      ({
        int quantity,
        double unitPrice,
        InventoryOrderItem? orderItem,
        DateTime? orderDate,
        String source,
        String? selectedVariant,
      })
    >
    breakdown,
  ) {
    return breakdown
        .map(
          (line) => <String, dynamic>{
            'quantity': line.quantity,
            'unitPrice': line.unitPrice,
            'source': line.source,
            'selectedVariant': line.selectedVariant,
            'orderDate': line.orderDate?.toIso8601String(),
          },
        )
        .toList();
  }

  void _rollbackTransferEffects(
    Order transfer,
    InventoryItem sourceItem,
    InventoryItem destinationItem,
  ) {
    final quantity =
        transfer.transferQuantity ??
        transfer.inventoryList.fold<int>(0, (sum, line) => sum + line.quantity);

    destinationItem.inventoryCount -= quantity;
    if (destinationItem.inventoryCount < 0) {
      destinationItem.inventoryCount = 0;
    }

    final destinationVariant =
        transfer.transferDestinationVariant ??
        (transfer.inventoryList.isNotEmpty
            ? transfer.inventoryList.first.selectedVariant
            : null);

    if (destinationItem.hasVariants && destinationVariant != null) {
      final current = destinationItem.variantStock[destinationVariant] ?? 0;
      destinationItem.variantStock[destinationVariant] = (current - quantity)
          .clamp(0, 1 << 30)
          .toInt();
    }

    sourceItem.inventoryCount += quantity;
    if (sourceItem.hasVariants && transfer.transferSourceVariant != null) {
      final sourceVariant = transfer.transferSourceVariant!;
      final current = sourceItem.variantStock[sourceVariant] ?? 0;
      sourceItem.variantStock[sourceVariant] = current + quantity;
    }

    _restoreTransferFifoLots(transfer, sourceItem);
  }

  void _restoreTransferFifoLots(Order transfer, InventoryItem sourceItem) {
    for (final rawEntry in transfer.transferFifoBreakdown) {
      final quantity = (rawEntry['quantity'] is num)
          ? (rawEntry['quantity'] as num).toInt()
          : int.tryParse('${rawEntry['quantity']}') ?? 0;
      if (quantity <= 0) {
        continue;
      }

      final rawOrderDate = rawEntry['orderDate']?.toString();
      if (rawOrderDate == null || rawOrderDate.trim().isEmpty) {
        continue;
      }

      final orderDate = DateTime.tryParse(rawOrderDate);
      if (orderDate == null) {
        continue;
      }

      final selectedVariant = rawEntry['selectedVariant']?.toString();
      final targetUnitPrice = (rawEntry['unitPrice'] is num)
          ? (rawEntry['unitPrice'] as num).toDouble()
          : double.tryParse('${rawEntry['unitPrice']}') ?? 0.0;

      final matchingOrders = sourceItem.orderList.where((order) {
        if (order.isInputTransfer) {
          return false;
        }
        return _isSameDay(order.date, orderDate);
      });

      InventoryOrderItem? matchedOrderItem;
      for (final order in matchingOrders) {
        for (final lineItem in order.inventoryList) {
          final sameItem = lineItem.inventoryItem.id == sourceItem.id;
          if (!sameItem) {
            continue;
          }

          final variantMatches =
              (selectedVariant == null || selectedVariant.trim().isEmpty)
              ? true
              : lineItem.selectedVariant == selectedVariant;

          if (!variantMatches) {
            continue;
          }

          if (_isNearlyEqual(lineItem.shippedPrice, targetUnitPrice)) {
            matchedOrderItem = lineItem;
            break;
          }
        }

        if (matchedOrderItem != null) {
          break;
        }
      }

      if (matchedOrderItem != null) {
        matchedOrderItem.currentQuantity += quantity;
      }
    }
  }

  void _deleteInputTransfer(Order transfer) {
    final sourceItem = _findInventoryItemById(transfer.transferSourceItemId);
    final destinationItem = _findInventoryItemById(
      transfer.transferDestinationItemId,
    );

    setState(() {
      if (sourceItem != null && destinationItem != null) {
        _rollbackTransferEffects(transfer, sourceItem, destinationItem);
      }

      for (final item in widget.inventoryList) {
        item.orderList.removeWhere((order) => order == transfer);
      }

      widget.orderList.removeWhere((order) => order == transfer);
    });

    widget.onDataChanged();
  }

  Future<void> _confirmDeleteInputTransfer(Order transfer) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Input Transfer'),
        content: const Text(
          'Delete this transfer and restore source stock + FIFO lots?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE74C3C),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      _deleteInputTransfer(transfer);
    }
  }

  Future<void> _showEditInputTransferDialog(Order transfer) async {
    final sourceItem = _findInventoryItemById(transfer.transferSourceItemId);
    final currentDestinationItem = _findInventoryItemById(
      transfer.transferDestinationItemId,
    );
    final previousQuantity =
        transfer.transferQuantity ??
        transfer.inventoryList.fold<int>(0, (sum, line) => sum + line.quantity);

    if (sourceItem == null || currentDestinationItem == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to edit transfer: source or destination missing',
            ),
            backgroundColor: Color(0xFFE74C3C),
          ),
        );
      }
      return;
    }

    final quantityController = TextEditingController(
      text: previousQuantity.toString(),
    );
    final costController = TextEditingController(
      text:
          (transfer.transferUnitCost ??
                  (transfer.transferQuantity == null ||
                          transfer.transferQuantity == 0
                      ? 0.0
                      : transfer.totalOrderPrice / transfer.transferQuantity!))
              .toStringAsFixed(2),
    );
    var selectedDate = transfer.date;
    var selectedDestinationItem = currentDestinationItem;
    String? selectedDestinationVariant =
        transfer.transferDestinationVariant ??
        (transfer.inventoryList.isNotEmpty
            ? transfer.inventoryList.first.selectedVariant
            : null);

    if (selectedDestinationItem.hasVariants &&
        selectedDestinationVariant == null &&
        selectedDestinationItem.variantValues.length == 1) {
      selectedDestinationVariant = selectedDestinationItem.variantValues.first;
    }

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Edit Input Transfer'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );

                    if (!dialogContext.mounted) {
                      return;
                    }

                    if (picked != null) {
                      setDialogState(() {
                        selectedDate = picked;
                      });
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.white,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 18,
                          color: Color(0xFF3498DB),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Quantity',
                    prefixIcon: const Icon(Icons.inventory_2),
                    helperText:
                        'Available after rollback: ${sourceItem.hasVariants ? (sourceItem.variantStock[transfer.transferSourceVariant] ?? 0) + previousQuantity : sourceItem.inventoryCount + previousQuantity}',
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final result =
                          await Navigator.push<SelectInventoryOrderItemsResult>(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  SelectInventoryOrderItemsPage(
                                    inventoryList: widget.inventoryList
                                        .where(
                                          (item) => item.id != sourceItem.id,
                                        )
                                        .toList(),
                                  ),
                            ),
                          );

                      if (!mounted || !dialogContext.mounted) {
                        return;
                      }

                      if (result == null || result.createNew) {
                        return;
                      }

                      if (result.selectedItem != null) {
                        setDialogState(() {
                          selectedDestinationItem = result.selectedItem!;

                          if (selectedDestinationItem.hasVariants) {
                            if (selectedDestinationItem.variantValues.contains(
                              selectedDestinationVariant,
                            )) {
                              return;
                            }

                            if (selectedDestinationItem.variantValues.length ==
                                1) {
                              selectedDestinationVariant =
                                  selectedDestinationItem.variantValues.first;
                            } else {
                              selectedDestinationVariant = null;
                            }
                          } else {
                            selectedDestinationVariant = null;
                          }
                        });
                      }
                    },
                    icon: const Icon(Icons.swap_horiz),
                    label: Text('To Item: ${selectedDestinationItem.name}'),
                  ),
                ),
                if (selectedDestinationItem.hasVariants) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedDestinationVariant,
                    decoration: const InputDecoration(
                      labelText: 'To Variant',
                      prefixIcon: Icon(Icons.tune),
                    ),
                    items: selectedDestinationItem.variantValues
                        .map(
                          (variant) => DropdownMenuItem<String>(
                            value: variant,
                            child: Text(variant),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedDestinationVariant = value;
                      });
                    },
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: costController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Cost/Unit',
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                FocusScope.of(dialogContext).unfocus();
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final updatedQuantity = int.tryParse(
                  quantityController.text.trim(),
                );
                final updatedCost = double.tryParse(costController.text.trim());
                if (updatedQuantity == null || updatedQuantity <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Enter a valid quantity greater than 0'),
                      backgroundColor: Color(0xFFE74C3C),
                    ),
                  );
                  return;
                }

                if (updatedCost == null || updatedCost < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Enter a valid cost per unit'),
                      backgroundColor: Color(0xFFE74C3C),
                    ),
                  );
                  return;
                }

                if (selectedDestinationItem.hasVariants &&
                    selectedDestinationVariant == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Select a destination variant'),
                      backgroundColor: Color(0xFFE74C3C),
                    ),
                  );
                  return;
                }

                final sourceAvailableAfterRollback = sourceItem.hasVariants
                    ? (sourceItem.variantStock[transfer
                                  .transferSourceVariant] ??
                              0) +
                          previousQuantity
                    : sourceItem.inventoryCount + previousQuantity;

                if (updatedQuantity > sourceAvailableAfterRollback) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Not enough source stock (available: $sourceAvailableAfterRollback)',
                      ),
                      backgroundColor: const Color(0xFFE74C3C),
                    ),
                  );
                  return;
                }

                setState(() {
                  _rollbackTransferEffects(
                    transfer,
                    sourceItem,
                    currentDestinationItem,
                  );

                  final fifoBreakdown = _calculateTransferFifoBreakdown(
                    sourceItem,
                    updatedQuantity,
                    transfer.transferSourceVariant,
                  );

                  final fifoTotalCost = fifoBreakdown.fold<double>(
                    0.0,
                    (sum, line) => sum + (line.quantity * line.unitPrice),
                  );

                  final chosenUnitCost = updatedCost;

                  for (final line in fifoBreakdown) {
                    if (line.orderItem != null) {
                      line.orderItem!.currentQuantity -= line.quantity;
                    }
                  }

                  sourceItem.inventoryCount -= updatedQuantity;
                  if (sourceItem.hasVariants &&
                      transfer.transferSourceVariant != null) {
                    final sourceVariant = transfer.transferSourceVariant!;
                    final current = sourceItem.variantStock[sourceVariant] ?? 0;
                    sourceItem.variantStock[sourceVariant] =
                        current - updatedQuantity;
                  }

                  selectedDestinationItem.inventoryCount += updatedQuantity;
                  final destinationVariant = selectedDestinationVariant;
                  if (selectedDestinationItem.hasVariants &&
                      destinationVariant != null) {
                    final current =
                        selectedDestinationItem
                            .variantStock[destinationVariant] ??
                        0;
                    selectedDestinationItem.variantStock[destinationVariant] =
                        current + updatedQuantity;
                  }

                  for (final item in widget.inventoryList) {
                    item.orderList.removeWhere((order) => order == transfer);
                  }

                  transfer.date = selectedDate;
                  transfer.transferQuantity = updatedQuantity;
                  transfer.transferUnitCost = chosenUnitCost;
                  transfer.totalOrderPrice = chosenUnitCost * updatedQuantity;
                  transfer.transferDestinationItemId =
                      selectedDestinationItem.id;
                  transfer.transferDestinationItemName =
                      selectedDestinationItem.name;
                  transfer.transferDestinationVariant =
                      selectedDestinationVariant;
                  transfer.transferFifoBreakdown = _encodeTransferFifoBreakdown(
                    fifoBreakdown,
                  );

                  if (transfer.inventoryList.isEmpty) {
                    transfer.inventoryList.add(
                      InventoryOrderItem(
                        selectedDestinationItem,
                        updatedQuantity,
                        chosenUnitCost,
                        chosenUnitCost,
                        updatedQuantity,
                        selectedVariant: selectedDestinationVariant,
                      ),
                    );
                  } else {
                    for (final line in transfer.inventoryList) {
                      line.inventoryItem = selectedDestinationItem;
                      line.quantity = updatedQuantity;
                      line.price = chosenUnitCost;
                      line.shippedPrice = chosenUnitCost;
                      line.currentQuantity = updatedQuantity;
                      line.selectedVariant = selectedDestinationVariant;
                    }
                  }

                  selectedDestinationItem.orderList.add(transfer);

                  if (_isNearlyEqual(chosenUnitCost, 0.0) &&
                      !_isNearlyEqual(fifoTotalCost, 0.0)) {
                    final inferred = fifoTotalCost / updatedQuantity;
                    transfer.transferUnitCost = inferred;
                    transfer.totalOrderPrice = inferred * updatedQuantity;
                    for (final line in transfer.inventoryList) {
                      line.price = inferred;
                      line.shippedPrice = inferred;
                    }
                  }
                });

                widget.onDataChanged();
                Navigator.pop(dialogContext);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    quantityController.dispose();
    costController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredOrders = _getFilteredOrders();
    final filteredInputTransfers = _getFilteredInputTransfers();
    final folderOptions = _getFolders();
    final standardOrders = widget.orderList
        .where((order) => !order.isInputTransfer)
        .toList();

    if (selectedFolder != _allFoldersLabel &&
        selectedFolder != _uncategorizedLabel &&
        !folderOptions.contains(selectedFolder)) {
      selectedFolder = _allFoldersLabel;
    }

    final groupedOrders = <String, List<Order>>{};
    for (final order in filteredOrders) {
      final groupName = _getOrderGroupName(order);
      groupedOrders.putIfAbsent(groupName, () => <Order>[]).add(order);
    }
    final groupedFolderNames = groupedOrders.keys.toList()..sort();
    for (final folderName in groupedFolderNames) {
      _expandedFolders.putIfAbsent(folderName, () => true);
    }

    final groupedOrderEntries =
        <({bool isHeader, String folderName, Order? order})>[];
    for (final folderName in groupedFolderNames) {
      groupedOrderEntries.add((
        isHeader: true,
        folderName: folderName,
        order: null,
      ));

      if (_expandedFolders[folderName] ?? true) {
        for (final order in groupedOrders[folderName] ?? const <Order>[]) {
          groupedOrderEntries.add((
            isHeader: false,
            folderName: folderName,
            order: order,
          ));
        }
      }
    }

    double totalShippingValue = standardOrders.fold(
      0.0,
      (sum, order) => sum + order.totalOrderPrice,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            elevation: 0,
            backgroundColor: const Color(0xFF2C3E50),
            pinned: true,
            expandedHeight: 140,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2C3E50), Color(0xFF34495E)],
                  ),
                ),
              ),
              title: const Text(
                'Orders',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              centerTitle: false,
              titlePadding: const EdgeInsets.only(left: 24, bottom: 16),
            ),
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stats Bar
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE0E0E0),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _showInputTransfers
                                        ? '${widget.orderList.where((order) => order.isInputTransfer).length}'
                                        : '${standardOrders.length}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: Color(0xFF3498DB),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _showInputTransfers
                                        ? 'Input Transfers'
                                        : 'Orders',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF99A3AC),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE0E0E0),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _showInputTransfers
                                        ? '${filteredInputTransfers.fold<int>(0, (sum, order) => sum + (order.transferQuantity ?? 0))}'
                                        : '\$${totalShippingValue.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: Color(0xFF27AE60),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _showInputTransfers
                                        ? 'Units in View'
                                        : 'Total Value',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF99A3AC),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFE0E0E0),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: () {
                                  setState(() {
                                    _showInputTransfers = false;
                                  });
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: _showInputTransfers
                                      ? const Color(0xFFEAEFF4)
                                      : const Color(0xFF3498DB),
                                  foregroundColor: _showInputTransfers
                                      ? const Color(0xFF2C3E50)
                                      : Colors.white,
                                  elevation: 0,
                                ),
                                child: const Text('Orders'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton(
                                onPressed: () {
                                  setState(() {
                                    _showInputTransfers = true;
                                    selectedFolder = _allFoldersLabel;
                                  });
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: _showInputTransfers
                                      ? const Color(0xFF3498DB)
                                      : const Color(0xFFEAEFF4),
                                  foregroundColor: _showInputTransfers
                                      ? Colors.white
                                      : const Color(0xFF2C3E50),
                                  elevation: 0,
                                ),
                                child: const Text('Input'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Action bar
                      if (!_showInputTransfers)
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFFE0E0E0),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final isCompact = constraints.maxWidth < 460;

                                  final addFolderButton = Material(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(8),
                                    child: InkWell(
                                      onTap: _showCreateFolderDialog,
                                      borderRadius: BorderRadius.circular(8),
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 9,
                                          vertical: 8,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.create_new_folder_outlined,
                                              size: 18,
                                              color: Color(0xFF99A3AC),
                                            ),
                                            SizedBox(width: 3),
                                            Text(
                                              'Add Folder',
                                              style: TextStyle(
                                                color: Color(0xFF2C3E50),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );

                                  final addItemButton = Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF3498DB),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: _openAddOrderPage,
                                        borderRadius: BorderRadius.circular(8),
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 9,
                                            vertical: 8,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.add,
                                                color: Colors.white,
                                                size: 18,
                                              ),
                                              SizedBox(width: 3),
                                              Text(
                                                'Add Item',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );

                                  final actionButtons = Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [addFolderButton, addItemButton],
                                  );

                                  if (isCompact) {
                                    return Align(
                                      alignment: Alignment.centerLeft,
                                      child: actionButtons,
                                    );
                                  }

                                  return Align(
                                    alignment: Alignment.centerRight,
                                    child: actionButtons,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 24),
                      // Collapsible folder/search filters
                      Column(
                        children: [
                          InkWell(
                            onTap: () {
                              setState(() {
                                isFolderFilterExpanded =
                                    !isFolderFilterExpanded;
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  const Text(
                                    'Filter',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF99A3AC),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (!_showInputTransfers) ...[
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color:
                                            selectedFolder == _allFoldersLabel
                                            ? const Color(0xFFCBD5E1)
                                            : _colorForFolder(selectedFolder),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Expanded(
                                    child: Text(
                                      _showInputTransfers
                                          ? 'Input Transfers'
                                          : selectedFolder,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF2C3E50),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    isFolderFilterExpanded
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                    size: 20,
                                    color: const Color(0xFF99A3AC),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (isFolderFilterExpanded) ...[
                            const SizedBox(height: 6),
                            TextField(
                              onChanged: (value) {
                                setState(() {
                                  searchQuery = value;
                                });
                              },
                              decoration: InputDecoration(
                                hintText: _showInputTransfers
                                    ? 'Search by date or item'
                                    : 'Search by date',
                                prefixIcon: const Icon(
                                  Icons.search,
                                  color: Color(0xFF3498DB),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE0E0E0),
                                    width: 1,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE0E0E0),
                                    width: 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF3498DB),
                                    width: 2,
                                  ),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (!_showInputTransfers)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFE0E0E0),
                                    width: 1,
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: selectedFolder,
                                    isExpanded: true,
                                    iconSize: 18,
                                    items: [
                                      const DropdownMenuItem<String>(
                                        value: _allFoldersLabel,
                                        child: Text(_allFoldersLabel),
                                      ),
                                      const DropdownMenuItem<String>(
                                        value: _uncategorizedLabel,
                                        child: Text(_uncategorizedLabel),
                                      ),
                                      ...folderOptions
                                          .where(
                                            (folder) =>
                                                folder != _uncategorizedLabel,
                                          )
                                          .map(
                                            (folder) =>
                                                DropdownMenuItem<String>(
                                                  value: folder,
                                                  child: Text(folder),
                                                ),
                                          ),
                                    ],
                                    onChanged: (value) {
                                      if (value == null) {
                                        return;
                                      }
                                      setState(() {
                                        selectedFolder = value;
                                      });
                                    },
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_showInputTransfers && filteredInputTransfers.isEmpty)
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48.0),
                  child: Column(
                    children: [
                      Icon(
                        searchQuery.isEmpty
                            ? Icons.swap_horiz
                            : Icons.search_off_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        searchQuery.isEmpty
                            ? 'No input transfers yet'
                            : 'No input transfers found',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_showInputTransfers)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final transfer = filteredInputTransfers[index];
                  final transferDate = transfer.date;
                  final formattedDate =
                      '${transferDate.year}-${transferDate.month.toString().padLeft(2, '0')}-${transferDate.day.toString().padLeft(2, '0')}';
                  final quantity =
                      transfer.transferQuantity ??
                      transfer.inventoryList.fold<int>(
                        0,
                        (sum, item) => sum + item.quantity,
                      );
                  final unitCost = transfer.transferUnitCost;

                  return Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: _contentMaxWidth,
                      ),
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 14),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFEAF4FD),
                            child: Icon(
                              Icons.swap_horiz,
                              color: Color(0xFF3498DB),
                            ),
                          ),
                          title: Text(
                            '${transfer.transferSourceItemName ?? 'Unknown'} → ${transfer.transferDestinationItemName ?? 'Unknown'}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                          subtitle: Text(
                            'Date: $formattedDate • Qty: $quantity${unitCost == null ? '' : ' • Cost: \$${unitCost.toStringAsFixed(2)}/unit'}',
                            style: const TextStyle(
                              color: Color(0xFF99A3AC),
                              fontSize: 12,
                            ),
                          ),
                          trailing: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '\$${transfer.totalOrderPrice.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Color(0xFF27AE60),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _showEditInputTransferDialog(transfer);
                                    return;
                                  }
                                  if (value == 'delete') {
                                    _confirmDeleteInputTransfer(transfer);
                                  }
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem<String>(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                  PopupMenuItem<String>(
                                    value: 'delete',
                                    child: Text('Delete'),
                                  ),
                                ],
                                child: const Icon(
                                  Icons.more_horiz,
                                  color: Color(0xFF99A3AC),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }, childCount: filteredInputTransfers.length),
              ),
            )
          else if (filteredOrders.isEmpty)
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48.0),
                  child: Column(
                    children: [
                      Icon(
                        searchQuery.isEmpty
                            ? Icons.local_shipping_outlined
                            : Icons.search_off_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        searchQuery.isEmpty
                            ? 'No orders yet'
                            : 'No orders found',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final entry = groupedOrderEntries[index];
                  if (entry.isHeader) {
                    final folderName = entry.folderName;
                    final folderColor = _colorForFolder(folderName);
                    return InkWell(
                      onTap: () {
                        _showEditFolderDialog(folderName);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: folderColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: folderColor.withValues(alpha: 0.28),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.folder, size: 16, color: folderColor),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  folderName,
                                  style: const TextStyle(
                                    color: Color(0xFF2C3E50),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                '${groupedOrders[folderName]!.length} orders',
                                style: const TextStyle(
                                  color: Color(0xFF99A3AC),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 6),
                              SizedBox(
                                width: 40,
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _expandedFolders[folderName] =
                                          !(_expandedFolders[folderName] ??
                                              true);
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Padding(
                                    padding: const EdgeInsets.all(2),
                                    child: Icon(
                                      (_expandedFolders[folderName] ?? true)
                                          ? Icons.expand_less
                                          : Icons.expand_more,
                                      size: 18,
                                      color: const Color(0xFF99A3AC),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  final order = entry.order!;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        OrderTile(
                          order: order,
                          onDelete: () {
                            final originalIndex = widget.orderList.indexOf(
                              order,
                            );
                            if (originalIndex != -1) {
                              _deleteOrder(originalIndex);
                            }
                          },
                          onEdit: () {
                            _editOrder(order);
                          },
                        ),
                        Positioned(
                          top: 8,
                          right: 10,
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFF99A3AC),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }, childCount: groupedOrderEntries.length),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}
