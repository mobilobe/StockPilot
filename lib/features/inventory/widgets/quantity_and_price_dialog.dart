import 'package:flutter/material.dart';
import 'package:inventory/models/inventory_item.dart';
import 'package:inventory/models/inventory_order_item.dart';

/// Captures an order line's quantity, unit cost, and optional variant.
class QuantityAndPriceDialog extends StatefulWidget {
  final InventoryItem item;
  final Function(InventoryOrderItem) onAddItem;

  const QuantityAndPriceDialog({
    required this.item,
    required this.onAddItem,
    super.key,
  });

  @override
  State<QuantityAndPriceDialog> createState() => _QuantityAndPriceDialogState();
}

/// Keeps the selected order-line inputs before returning a model to the caller.
class _QuantityAndPriceDialogState extends State<QuantityAndPriceDialog> {
  late TextEditingController quantityController;
  late TextEditingController priceController;
  String? _selectedVariant;

  @override
  void initState() {
    super.initState();
    quantityController = TextEditingController(text: '1');
    priceController = TextEditingController();
    if (widget.item.hasVariants && widget.item.variantValues.isNotEmpty) {
      _selectedVariant = widget.item.variantValues.first;
    }
  }

  @override
  void dispose() {
    quantityController.dispose();
    priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Item Details',
        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.item.name,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          if (widget.item.hasVariants) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedVariant,
              decoration: InputDecoration(
                labelText: 'Variant',
                prefixIcon: const Icon(Icons.tune, color: Color(0xFF3498DB)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items: widget.item.variantValues
                  .map(
                    (value) => DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedVariant = value;
                });
              },
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Current stock: ${(widget.item.variantStock[_selectedVariant] ?? 0)}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF99A3AC)),
              ),
            ),
          ],
          const SizedBox(height: 16),
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
          const SizedBox(height: 12),
          TextFormField(
            controller: priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Price per Unit',
              prefixIcon: const Icon(
                Icons.attach_money,
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
            final quantity = int.tryParse(quantityController.text) ?? 1;
            final price = double.tryParse(priceController.text);
            if (widget.item.hasVariants) {
              if (_selectedVariant == null) {
                return;
              }
            }
            if (price != null) {
              widget.onAddItem(
                InventoryOrderItem(
                  widget.item,
                  quantity,
                  price,
                  0,
                  quantity,
                  selectedVariant: _selectedVariant,
                ),
              );
              Navigator.pop(context);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3498DB),
            foregroundColor: Colors.white,
          ),
          child: const Text('Add'),
        ),
      ],
    );
  }
}
