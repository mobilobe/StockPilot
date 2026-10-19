import 'package:flutter/material.dart';
import 'package:inventory/models/inventory_item.dart';
import 'package:inventory/services/sale_calculator.dart';

/// One pending line of a sale before it is recorded against inventory.
class SaleDraftItem {
  final InventoryItem item;
  final String? variant;
  final int quantity;
  final double unitPrice;

  const SaleDraftItem({
    required this.item,
    required this.variant,
    required this.quantity,
    required this.unitPrice,
  });

  double get total => unitPrice * quantity;
}

/// Captures a sale line's variant, quantity, and unit sale price.
class SaleItemDialog extends StatefulWidget {
  final InventoryItem item;

  /// Units of each variant already used by other lines in the draft sale.
  final int Function(String? variant) reservedQuantity;
  final void Function(SaleDraftItem) onAddItem;

  const SaleItemDialog({
    required this.item,
    required this.reservedQuantity,
    required this.onAddItem,
    super.key,
  });

  @override
  State<SaleItemDialog> createState() => _SaleItemDialogState();
}

class _SaleItemDialogState extends State<SaleItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController(text: '1');
  final _priceController = TextEditingController();
  String? _selectedVariant;

  @override
  void initState() {
    super.initState();
    if (widget.item.hasVariants && widget.item.variantValues.isNotEmpty) {
      _selectedVariant = widget.item.variantValues.first;
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  int get _available =>
      availableStock(widget.item, _selectedVariant) -
      widget.reservedQuantity(_selectedVariant);

  InputDecoration _decoration(
    String label,
    IconData icon, {
    String? helperText,
  }) {
    return InputDecoration(
      labelText: label,
      helperText: helperText,
      prefixIcon: Icon(icon, color: const Color(0xFF3498DB)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (widget.item.hasVariants && _selectedVariant == null) return;

    widget.onAddItem(
      SaleDraftItem(
        item: widget.item,
        variant: _selectedVariant,
        quantity: int.parse(_quantityController.text.trim()),
        unitPrice: double.parse(_priceController.text.trim()),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Sale Item Details',
        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
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
              const SizedBox(height: 16),
              if (widget.item.hasVariants) ...[
                DropdownButtonFormField<String>(
                  initialValue: _selectedVariant,
                  decoration: _decoration('Variant', Icons.tune),
                  items: widget.item.variantValues
                      .map(
                        (value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _selectedVariant = value),
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: _decoration(
                  'Sale Price (per unit)',
                  Icons.attach_money,
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return 'Please enter sale price';
                  final price = double.tryParse(text);
                  if (price == null || price < 0) {
                    return 'Please enter a valid price';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: _decoration(
                  'Quantity',
                  Icons.inventory_2,
                  helperText: 'Available: $_available units',
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return 'Please enter quantity';
                  final qty = int.tryParse(text);
                  if (qty == null) return 'Please enter a valid quantity';
                  if (qty <= 0) return 'Quantity must be greater than 0';
                  if (qty > _available) {
                    return 'Not enough stock (available: $_available)';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Color(0xFF3498DB)),
          ),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}
