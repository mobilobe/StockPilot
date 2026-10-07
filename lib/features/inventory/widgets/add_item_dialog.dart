import 'package:flutter/material.dart';
import 'package:inventory/models/inventory_item.dart';

/// Offers an existing inventory item or hands off to the create-item flow.
class AddItemDialog extends StatefulWidget {
  final List<InventoryItem> inventoryList;
  final Function(InventoryItem) onSelectItem;
  final VoidCallback onCreateNew;

  const AddItemDialog({
    required this.inventoryList,
    required this.onSelectItem,
    required this.onCreateNew,
    super.key,
  });

  @override
  State<AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<AddItemDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Add Item to Order',
        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Dropdown to select from existing inventory
          DropdownButton<InventoryItem>(
            isExpanded: true,
            hint: const Text('Select inventory item'),
            items: widget.inventoryList.map((item) {
              return DropdownMenuItem(
                value: item,
                child: Text(
                  '${item.name} (SKU: ${item.sku})',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (selected) {
              if (selected != null) {
                Navigator.pop(context);
                widget.onSelectItem(selected);
              }
            },
          ),
          const SizedBox(height: 16),
          // Button to create a new inventory item
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onCreateNew();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF27AE60),
              foregroundColor: Colors.white,
            ),
            child: const Text('Create New Item'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
