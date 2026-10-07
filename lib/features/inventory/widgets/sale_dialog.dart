import 'package:flutter/material.dart';
import 'package:inventory/models/inventory_item.dart';
import 'package:inventory/models/inventory_order_item.dart';
import 'package:inventory/models/sale.dart';
import 'package:inventory/models/sale_line_item.dart';
import 'package:inventory/models/order.dart';

/// Validates a sale, consumes FIFO stock layers, and updates item quantities.
class SaleDialog extends StatefulWidget {
  final InventoryItem inventoryItem;
  final Function(InventoryItem) onSellItem;

  const SaleDialog({
    required this.inventoryItem,
    required this.onSellItem,
    super.key,
  });

  @override
  State<SaleDialog> createState() => _SaleDialogState();
}

/// Owns sale inputs and computes the cost basis before creating a sale record.
class _SaleDialogState extends State<SaleDialog> {
  late TextEditingController _salePriceController;
  late TextEditingController _quantityController;
  late DateTime _selectedDate;
  final _formKey = GlobalKey<FormState>();
  String? _selectedVariant;

  @override
  void initState() {
    super.initState();
    _salePriceController = TextEditingController();
    _quantityController = TextEditingController(text: '1');
    _selectedDate = DateTime.now();
    if (widget.inventoryItem.hasVariants &&
        widget.inventoryItem.variantValues.isNotEmpty) {
      _selectedVariant = widget.inventoryItem.variantValues.first;
    }
  }

  @override
  void dispose() {
    _salePriceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  /// Opens a date picker for selecting the sale date.
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  /// Calculates FIFO price breakdown for a sale using oldest orders first.
  /// Returns a list of SaleLineItem showing quantity and price for each source.
  /// Uses order items in chronological order (oldest first), then initial price.
  /// Stores references to order items for later quantity reduction.
  List<SaleLineItem> calculateFIFOPriceBreakdown(
    InventoryItem item,
    int quantityToSell,
    String? selectedVariant,
  ) {
    List<SaleLineItem> breakdown = [];
    int remainingQuantity = quantityToSell;
    List<Order> sortedOrders = List.from(item.orderList);
    sortedOrders.sort((a, b) => a.date.compareTo(b.date));
    for (Order order in sortedOrders) {
      if (remainingQuantity <= 0) break;
      for (InventoryOrderItem orderItem in order.inventoryList) {
        if (orderItem.inventoryItem.id == item.id && remainingQuantity > 0) {
          if (item.hasVariants &&
              orderItem.selectedVariant != null &&
              orderItem.selectedVariant != selectedVariant) {
            continue;
          }

          int availableQuantity = orderItem.currentQuantity;

          if (availableQuantity > 0) {
            int quantityToUseHere = availableQuantity < remainingQuantity
                ? availableQuantity
                : remainingQuantity;

            final orderDate =
                '${order.date.year}-${order.date.month.toString().padLeft(2, '0')}-${order.date.day.toString().padLeft(2, '0')}';

            breakdown.add(
              SaleLineItem(
                quantity: quantityToUseHere,
                unitPrice: orderItem.shippedPrice,
                source: item.hasVariants
                    ? 'Order - $orderDate (${orderItem.selectedVariant ?? selectedVariant ?? 'N/A'})'
                    : 'Order - $orderDate',
                orderItem: orderItem,
              ),
            );

            remainingQuantity -= quantityToUseHere;
          }
          break;
        }
      }
    }

    if (remainingQuantity > 0) {
      breakdown.add(
        SaleLineItem(
          quantity: remainingQuantity,
          unitPrice: item.price,
          source: (item.hasVariants && selectedVariant != null)
              ? 'Initial Price ($selectedVariant)'
              : 'Initial Price',
          orderItem: null,
        ),
      );
    }

    return breakdown;
  }

  double calculateTotalCostBasis(List<SaleLineItem> breakdown) {
    return breakdown.fold<double>(
      0.0,
      (sum, line) => sum + (line.quantity * line.unitPrice),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Record Sale',
        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.inventoryItem.hasVariants) ...[
                DropdownButtonFormField<String>(
                  initialValue: _selectedVariant,
                  decoration: InputDecoration(
                    labelText: 'Variant',
                    prefixIcon: const Icon(
                      Icons.tune,
                      color: Color(0xFF3498DB),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  items: widget.inventoryItem.variantValues
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
                const SizedBox(height: 12),
              ],
              // Sale price input field with decimal validation
              TextFormField(
                controller: _salePriceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Sale Price',
                  prefixIcon: const Icon(
                    Icons.attach_money,
                    color: Color(0xFF3498DB),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter sale price';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid price';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _quantityController,
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
                  helperText:
                      'Available: ${widget.inventoryItem.hasVariants ? (widget.inventoryItem.variantStock[_selectedVariant] ?? 0) : widget.inventoryItem.inventoryCount} units',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter quantity';
                  }
                  final qty = int.tryParse(value);
                  if (qty == null) {
                    return 'Please enter a valid quantity';
                  }
                  if (qty <= 0) {
                    return 'Quantity must be greater than 0';
                  }
                  // Prevent overselling - validate against available stock
                  final available = widget.inventoryItem.hasVariants
                      ? (widget.inventoryItem.variantStock[_selectedVariant] ??
                            0)
                      : widget.inventoryItem.inventoryCount;
                  if (qty > available) {
                    return 'Not enough stock (available: $available)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => _selectDate(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFFE0E0E0),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Sale Date',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF99A3AC),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF2C3E50),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const Icon(
                        Icons.calendar_today,
                        color: Color(0xFF3498DB),
                      ),
                    ],
                  ),
                ),
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
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final salePrice = double.parse(_salePriceController.text);
              final quantity = int.parse(_quantityController.text);
              final item = widget.inventoryItem;

              if (item.hasVariants && _selectedVariant == null) {
                return;
              }

              final priceBreakdown = calculateFIFOPriceBreakdown(
                item,
                quantity,
                _selectedVariant,
              );
              final totalCostBasis = calculateTotalCostBasis(priceBreakdown);
              final totalSellingPrice = salePrice * quantity;
              final profit = totalSellingPrice - totalCostBasis;

              Sale sale = Sale(
                date: _selectedDate,
                price: totalSellingPrice,
                profit: profit,
                quantity: quantity,
                priceBreakdown: priceBreakdown,
              );

              for (SaleLineItem lineItem in priceBreakdown) {
                if (lineItem.orderItem != null) {
                  lineItem.orderItem!.currentQuantity -= lineItem.quantity;
                }
              }

              // Update inventory dynamically: increment sold, decrement stock
              item.soldCount += quantity;
              item.inventoryCount -= quantity;
              if (item.hasVariants && _selectedVariant != null) {
                final current = item.variantStock[_selectedVariant] ?? 0;
                item.variantStock[_selectedVariant!] = current - quantity;
              }
              item.salesList.add(sale);
              widget.onSellItem(item);
              Navigator.pop(context);
            }
          },
          child: const Text('Confirm Sale'),
        ),
      ],
    );
  }
}
