import 'package:flutter/material.dart';
import 'package:inventory/models/inventory_item.dart';

/// Distinguishes selecting an existing item from requesting a new one.
class SelectInventoryOrderItemsResult {
  final InventoryItem? selectedItem;
  final bool createNew;

  const SelectInventoryOrderItemsResult._({
    this.selectedItem,
    required this.createNew,
  });

  factory SelectInventoryOrderItemsResult.select(InventoryItem item) {
    return SelectInventoryOrderItemsResult._(
      selectedItem: item,
      createNew: false,
    );
  }

  factory SelectInventoryOrderItemsResult.createNew() {
    return const SelectInventoryOrderItemsResult._(createNew: true);
  }
}

/// Searches inventory and returns the selected item to an order form.
class SelectInventoryOrderItemsPage extends StatefulWidget {
  final List<InventoryItem> inventoryList;
  final bool allowCreateNew;
  final bool showStock;

  const SelectInventoryOrderItemsPage({
    required this.inventoryList,
    this.allowCreateNew = true,
    this.showStock = false,
    super.key,
  });

  @override
  State<SelectInventoryOrderItemsPage> createState() =>
      _SelectInventoryOrderItemsPageState();
}

class _SelectInventoryOrderItemsPageState
    extends State<SelectInventoryOrderItemsPage> {
  /// Holds the live query used to filter the inventory list.
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = _searchQuery.trim().toLowerCase();
    final filteredItems = widget.inventoryList.where((item) {
      if (normalizedQuery.isEmpty) {
        return true;
      }

      return item.name.toLowerCase().contains(normalizedQuery) ||
          item.sku.toLowerCase().contains(normalizedQuery) ||
          item.folder.toLowerCase().contains(normalizedQuery);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF2C3E50),
        title: const Text(
          'Select Inventory Item',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by name, SKU, or folder',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFF3498DB),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF3498DB)),
                    ),
                    fillColor: Colors.white,
                    filled: true,
                  ),
                ),
              ),
              if (widget.allowCreateNew)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(
                          context,
                          SelectInventoryOrderItemsResult.createNew(),
                        );
                      },
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Create New Item'),
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              Expanded(
                child: filteredItems.isEmpty
                    ? const Center(
                        child: Text(
                          'No inventory items found',
                          style: TextStyle(
                            color: Color(0xFF7F8C8D),
                            fontSize: 14,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: ListTile(
                              onTap: () {
                                Navigator.pop(
                                  context,
                                  SelectInventoryOrderItemsResult.select(item),
                                );
                              },
                              title: Text(
                                item.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2C3E50),
                                ),
                              ),
                              subtitle: Text(
                                widget.showStock
                                    ? 'SKU: ${item.sku} • ${item.folder} • ${item.inventoryCount} in stock'
                                    : 'SKU: ${item.sku} • ${item.folder}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: const Icon(
                                Icons.chevron_right,
                                color: Color(0xFF95A5A6),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
