import 'package:flutter/material.dart';
import 'package:inventory/services/hive_data.dart';
import 'package:inventory/features/inventory/widgets/inventory_tile.dart';
import 'package:inventory/features/inventory/widgets/sale_dialog.dart';
import 'package:inventory/features/inventory/screens/add_inventory_page.dart';
import 'package:inventory/features/inventory/screens/sales_page.dart';
import 'package:inventory/models/inventory_item.dart';
import 'package:inventory/models/sale.dart';
import 'package:inventory/models/order.dart';

/// Filters and groups inventory, then forwards item changes to app-level state.
class CatalogPage extends StatefulWidget {
  final List<InventoryItem> inventoryList;
  final List<Sale> saleList;
  final List<Order> orderList;
  final VoidCallback onDataChanged;

  const CatalogPage({
    required this.inventoryList,
    required this.saleList,
    required this.orderList,
    required this.onDataChanged,
    super.key,
  });

  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

/// Owns catalog filters and folder presentation settings for this screen.
class _CatalogPageState extends State<CatalogPage> {
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

  final HiveService _hiveService = HiveService();

  bool isInformationMode = true;
  String searchQuery = '';
  String selectedFolder = _allFoldersLabel;
  bool isFolderFilterExpanded = false;

  final Map<String, bool> _expandedFolders = <String, bool>{};
  Map<String, int> _folderColors = <String, int>{};
  Map<String, bool> _folderClosedByDefault = <String, bool>{};

  @override
  void initState() {
    super.initState();
    _folderColors = _hiveService.getFolderColors();
    final meta = _hiveService.getFolderMeta();
    _folderClosedByDefault = {
      for (final entry in meta.entries)
        entry.key:
            ((entry.value is Map && entry.value['closedByDefault'] == true) ||
            entry.value == true),
    };
  }

  void _sellItem(InventoryItem item) {
    showDialog(
      context: context,
      builder: (context) => SaleDialog(
        inventoryItem: item,
        onSellItem: (saleItem) {
          setState(() {});
          widget.onDataChanged();
        },
      ),
    );
  }

  void _updateInventoryItem(InventoryItem item) {
    setState(() {});
    widget.onDataChanged();
  }

  void _addInventoryItem(InventoryItem item) {
    setState(() {
      widget.inventoryList.add(item);
    });
    widget.onDataChanged();
  }

  void _deleteInventoryItem(InventoryItem item) {
    // Remove dependent sale/order lines as well as the catalog item itself.
    setState(() {
      widget.inventoryList.removeWhere((inventory) => inventory.id == item.id);

      final itemSales = item.salesList.toSet();
      widget.saleList.removeWhere((sale) => itemSales.contains(sale));

      for (final order in widget.orderList) {
        order.inventoryList.removeWhere(
          (orderItem) => orderItem.inventoryItem.id == item.id,
        );

        final orderItemsTotal = order.inventoryList.fold<double>(
          0.0,
          (sum, orderItem) => sum + (orderItem.price * orderItem.quantity),
        );
        order.totalOrderPrice = orderItemsTotal + order.shipping + order.fees;
      }
    });
    widget.onDataChanged();
  }

  List<InventoryItem> _getFilteredItems() {
    // Apply folder selection before search so both filters narrow the same list.
    final normalizedQuery = searchQuery.toLowerCase();

    return widget.inventoryList.where((item) {
      final isFolderMatch =
          selectedFolder == _allFoldersLabel || item.folder == selectedFolder;
      if (!isFolderMatch) {
        return false;
      }

      if (normalizedQuery.isEmpty) {
        return true;
      }

      return item.name.toLowerCase().contains(normalizedQuery) ||
          item.sku.toLowerCase().contains(normalizedQuery);
    }).toList();
  }

  List<String> _getFolders() {
    final folders = <String>{
      for (final item in widget.inventoryList)
        item.folder.trim().isEmpty ? _uncategorizedLabel : item.folder,
      ..._folderColors.keys,
    }.toList()..sort();
    return folders;
  }

  Color _colorForFolder(String folderName) {
    final savedColorValue = _folderColors[folderName];
    if (savedColorValue != null) {
      return Color(savedColorValue);
    }
    final index = folderName.hashCode.abs() % _folderPalette.length;
    return _folderPalette[index];
  }

  Future<void> _saveFolderColor(String folderName, Color color) async {
    await _hiveService.setFolderColor(
      folder: folderName,
      colorValue: color.toARGB32(),
    );
    if (!mounted) return;
    setState(() {
      _folderColors[folderName] = color.toARGB32();
    });
  }

  void _showCreateFolderDialog() {
    final controller = TextEditingController();
    Color selectedColor = _folderPalette.first;
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
                        hintText: 'e.g. Electronics',
                      ),
                    ),
                    const SizedBox(height: 8),
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
                    const SizedBox(height: 12),
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
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final folderName = controller.text.trim();
                if (folderName.isEmpty) return;

                Navigator.pop(dialogContext);
                await _saveFolderColor(folderName, selectedColor);
                await _hiveService.setFolderClosedByDefault(
                  folder: folderName,
                  closed: closedByDefault,
                );
                setState(() {
                  _folderClosedByDefault[folderName] = closedByDefault;
                  selectedFolder = folderName;
                });
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
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
                    const SizedBox(height: 8),
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
                    const SizedBox(height: 12),
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
              onPressed: () => Navigator.pop(dialogContext, false),
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

                final updatedColors = Map<String, int>.from(_folderColors);
                updatedColors.remove(folderName);
                updatedColors[updatedName] = selectedColor.toARGB32();

                // Capture any existing meta to migrate after state update
                final oldMeta = _folderClosedByDefault.remove(folderName);

                setState(() {
                  for (final item in widget.inventoryList) {
                    final itemFolder = item.folder.trim().isEmpty
                        ? _uncategorizedLabel
                        : item.folder;
                    if (itemFolder == folderName) {
                      item.folder = updatedName;
                    }
                  }

                  _folderColors = updatedColors;

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

                await _hiveService.saveFolderColors(updatedColors);
                if (oldMeta != null) {
                  await _hiveService.renameFolderMeta(folderName, updatedName);
                }
                await _hiveService.setFolderClosedByDefault(
                  folder: updatedName,
                  closed: _folderClosedByDefault[updatedName] ?? false,
                );
                if (!dialogContext.mounted) return;
                widget.onDataChanged();
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
          'Delete "$folderName"? Items in this folder will move to Uncategorized.',
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

    // Folder deletion keeps items by moving them to the default folder.
    setState(() {
      for (final item in widget.inventoryList) {
        final itemFolder = item.folder.trim().isEmpty
            ? _uncategorizedLabel
            : item.folder;
        if (itemFolder == folderName) {
          item.folder = _uncategorizedLabel;
        }
      }

      _folderColors.remove(folderName);

      if (selectedFolder == folderName) {
        selectedFolder = _allFoldersLabel;
      }

      _expandedFolders.remove(folderName);
    });

    await _hiveService.saveFolderColors(_folderColors);
    await _hiveService.removeFolderMeta(folderName);
    if (!mounted) return false;
    widget.onDataChanged();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _getFilteredItems();
    final folderOptions = _getFolders();

    if (selectedFolder != _allFoldersLabel &&
        !folderOptions.contains(selectedFolder)) {
      selectedFolder = _allFoldersLabel;
    }

    final groupedItems = <String, List<InventoryItem>>{};
    for (final item in filteredItems) {
      final folder = item.folder.trim().isEmpty
          ? _uncategorizedLabel
          : item.folder;
      groupedItems.putIfAbsent(folder, () => <InventoryItem>[]).add(item);
    }

    final groupedFolderNames = groupedItems.keys.toList()..sort();
    for (final folderName in groupedFolderNames) {
      final closedDefault = _folderClosedByDefault[folderName] ?? false;
      _expandedFolders.putIfAbsent(folderName, () => !closedDefault);
    }

    final totalStock = widget.inventoryList.fold(
      0,
      (sum, item) => sum + item.inventoryCount,
    );
    final totalItems = widget.inventoryList.length;

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
                'Catalog',
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
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isCompact = constraints.maxWidth < 330;

                          Widget buildSummaryCard({
                            required String value,
                            required String label,
                            required Color valueColor,
                          }) {
                            return Container(
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
                                    value,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: valueColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    label,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF99A3AC),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          if (isCompact) {
                            return Column(
                              children: [
                                buildSummaryCard(
                                  value: '$totalItems',
                                  label: 'SKUs',
                                  valueColor: const Color(0xFF3498DB),
                                ),
                                const SizedBox(height: 12),
                                buildSummaryCard(
                                  value: '$totalStock',
                                  label: 'In Stock',
                                  valueColor: const Color(0xFF27AE60),
                                ),
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(
                                child: buildSummaryCard(
                                  value: '$totalItems',
                                  label: 'SKUs',
                                  valueColor: const Color(0xFF3498DB),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: buildSummaryCard(
                                  value: '$totalStock',
                                  label: 'In Stock',
                                  valueColor: const Color(0xFF27AE60),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFE0E0E0),
                            width: 1,
                          ),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isCompact = constraints.maxWidth < 390;

                            final modeToggle = ToggleButtons(
                              isSelected: [
                                isInformationMode,
                                !isInformationMode,
                              ],
                              onPressed: (index) {
                                setState(() {
                                  isInformationMode = index == 0;
                                });
                              },
                              borderRadius: BorderRadius.circular(8),
                              constraints: const BoxConstraints(
                                minHeight: 32,
                                minWidth: 72,
                              ),
                              selectedColor: Colors.white,
                              fillColor: const Color(0xFF3498DB),
                              color: const Color(0xFF99A3AC),
                              borderColor: const Color(0xFFE0E0E0),
                              selectedBorderColor: const Color(0xFF3498DB),
                              children: const [
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 10),
                                  child: Text(
                                    'Info',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 10),
                                  child: Text(
                                    'Manage',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            );

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
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => AddInventoryPage(
                                          onAddInventory: _addInventoryItem,
                                          initialFolder:
                                              selectedFolder == _allFoldersLabel
                                              ? null
                                              : selectedFolder,
                                        ),
                                      ),
                                    );
                                  },
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

                            final salesButton = Material(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => SalesPage(
                                        inventoryList: widget.inventoryList,
                                        onDataChanged: widget.onDataChanged,
                                      ),
                                    ),
                                  );
                                },
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
                                        Icons.point_of_sale_outlined,
                                        size: 18,
                                        color: Color(0xFF99A3AC),
                                      ),
                                      SizedBox(width: 3),
                                      Text(
                                        'Sales',
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

                            final actionButtons = Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                addFolderButton,

                                salesButton,
                                addItemButton,
                              ],
                            );

                            if (isCompact) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      const Text(
                                        'Mode',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF99A3AC),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      modeToggle,
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: actionButtons,
                                  ),
                                ],
                              );
                            }

                            return Row(
                              children: [
                                const Text(
                                  'Mode',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF99A3AC),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                modeToggle,
                                const Spacer(),
                                Flexible(
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: actionButtons,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
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
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: selectedFolder == _allFoldersLabel
                                          ? const Color(0xFFCBD5E1)
                                          : _colorForFolder(selectedFolder),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      selectedFolder,
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
                                hintText: 'Search by name or SKU',
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
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
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
                                          ...folderOptions.map(
                                            (folder) =>
                                                DropdownMenuItem<String>(
                                                  value: folder,
                                                  child: Text(folder),
                                                ),
                                          ),
                                        ],
                                        onChanged: (value) {
                                          if (value == null) return;
                                          setState(() {
                                            selectedFolder = value;
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (filteredItems.isEmpty)
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 48,
                  ),
                  child: Column(
                    children: [
                      Icon(
                        searchQuery.isEmpty
                            ? Icons.inventory_2_outlined
                            : Icons.search_off_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        searchQuery.isEmpty
                            ? selectedFolder == _allFoldersLabel
                                  ? 'No inventory items yet'
                                  : 'No items in "$selectedFolder"'
                            : 'No items found',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final folderName = groupedFolderNames[index];
                  return Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: _contentMaxWidth,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
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
                                  color: _colorForFolder(
                                    folderName,
                                  ).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _colorForFolder(
                                      folderName,
                                    ).withValues(alpha: 0.28),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.folder,
                                      size: 16,
                                      color: _colorForFolder(folderName),
                                    ),
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
                                      '${groupedItems[folderName]!.length} items',
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
                                            (_expandedFolders[folderName] ??
                                                    true)
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
                          ),
                          if (_expandedFolders[folderName] ?? true)
                            ...groupedItems[folderName]!.map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    InventoryTile(
                                      inventoryItem: item,
                                      allInventoryItems: widget.inventoryList,
                                      allOrders: widget.orderList,
                                      isInformationMode: isInformationMode,
                                      onSellItem: _sellItem,
                                      onUpdateInventory: _updateInventoryItem,
                                      onDeleteInventory: _deleteInventoryItem,
                                      onCreateTransferOrder: (transferOrder) {
                                        setState(() {
                                          widget.orderList.add(transferOrder);
                                        });
                                        widget.onDataChanged();
                                      },
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 10,
                                      child: Container(
                                        width: 7,
                                        height: 7,
                                        decoration: BoxDecoration(
                                          color: _colorForFolder(
                                            folderName,
                                          ).withValues(alpha: 0.75),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }, childCount: groupedFolderNames.length),
              ),
            ),
        ],
      ),
    );
  }
}
