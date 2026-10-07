import 'package:flutter/material.dart';
import 'package:inventory/services/hive_data.dart';
import 'package:inventory/models/inventory_item.dart';
import 'package:inventory/models/inventory_order_item.dart';

/// Creates an inventory item directly from the order-entry flow.
class CreateNewItemDialog extends StatefulWidget {
  final Function(InventoryOrderItem) onCreateItem;

  const CreateNewItemDialog({required this.onCreateItem, super.key});

  @override
  State<CreateNewItemDialog> createState() => _CreateNewItemDialogState();
}

/// Holds the item fields until the order flow accepts the new item
class _CreateNewItemDialogState extends State<CreateNewItemDialog> {
  final HiveService _hiveService = HiveService();
  late TextEditingController nameController;
  late TextEditingController skuController;
  late TextEditingController folderController;
  late TextEditingController priceController;
  late TextEditingController quantityController;
  List<String> _existingFolders = [];

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController();
    skuController = TextEditingController();
    folderController = TextEditingController(text: 'Uncategorized');
    priceController = TextEditingController();
    quantityController = TextEditingController(text: '1');
    _existingFolders =
        _hiveService
            .getInventoryItems()
            .map((item) => item.folder.trim())
            .where((folder) => folder.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
  }

  @override
  void dispose() {
    nameController.dispose();
    skuController.dispose();
    folderController.dispose();
    priceController.dispose();
    quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Create New Item',
        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: 'Item Name',
              prefixIcon: const Icon(Icons.label, color: Color(0xFF3498DB)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: skuController,
            decoration: InputDecoration(
              labelText: 'SKU',
              prefixIcon: const Icon(Icons.tag, color: Color(0xFF3498DB)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Autocomplete<String>(
            initialValue: TextEditingValue(text: folderController.text),
            optionsBuilder: (textEditingValue) {
              final query = textEditingValue.text.trim().toLowerCase();
              if (query.isEmpty) {
                return _existingFolders;
              }

              return _existingFolders.where(
                (folder) => folder.toLowerCase().contains(query),
              );
            },
            onSelected: (selection) {
              folderController.text = selection;
            },
            fieldViewBuilder:
                (context, textEditingController, focusNode, onFieldSubmitted) {
                  return TextFormField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: 'Folder',
                      hintText: 'Assign folder',
                      prefixIcon: const Icon(
                        Icons.folder_outlined,
                        color: Color(0xFF3498DB),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (value) {
                      folderController.text = value;
                    },
                  );
                },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Price',
              prefixIcon: const Icon(
                Icons.attach_money,
                color: Color(0xFF3498DB),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: quantityController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Quantity',
              prefixIcon: const Icon(
                Icons.inventory_2,
                color: Color(0xFF3498DB),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final name = nameController.text;
            final sku = skuController.text;
            final folder = folderController.text.trim();
            final price = double.tryParse(priceController.text) ?? 0.0;
            final quantity = int.tryParse(quantityController.text) ?? 1;

            if (name.isNotEmpty && sku.isNotEmpty) {
              final newItem = InventoryItem(
                name,
                price,
                0,
                0,
                sku,
                _hiveService.generateUniqueInventoryItemId(),
                [],
                [],
                folder.isEmpty ? 'Uncategorized' : folder,
              );

              widget.onCreateItem(
                InventoryOrderItem(newItem, quantity, price, price, quantity),
              );
              Navigator.pop(context);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF27AE60),
            foregroundColor: Colors.white,
          ),
          child: const Text('Create'),
        ),
      ],
    );
  }
}
