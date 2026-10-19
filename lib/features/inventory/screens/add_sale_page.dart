import 'package:flutter/material.dart';
import 'package:inventory/features/inventory/screens/select_inventory_order_items_page.dart';
import 'package:inventory/features/inventory/widgets/sale_item_dialog.dart';
import 'package:inventory/models/inventory_item.dart';
import 'package:inventory/services/sale_calculator.dart';

/// Builds a sale from one or more inventory items, then records it with FIFO
/// cost layers and updated stock once the form is submitted.
class AddSalePage extends StatefulWidget {
  final List<InventoryItem> inventoryList;
  final VoidCallback onSaleAdded;

  const AddSalePage({
    required this.inventoryList,
    required this.onSaleAdded,
    super.key,
  });

  @override
  State<AddSalePage> createState() => _AddSalePageState();
}

class _AddSalePageState extends State<AddSalePage> {
  final List<SaleDraftItem> _draftItems = [];
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  double get _saleTotal =>
      _draftItems.fold(0.0, (sum, line) => sum + line.total);

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _addItemToSale() async {
    final result = await Navigator.push<SelectInventoryOrderItemsResult>(
      context,
      MaterialPageRoute(
        builder: (context) => SelectInventoryOrderItemsPage(
          inventoryList: widget.inventoryList,
          allowCreateNew: false,
          showStock: true,
        ),
      ),
    );

    final item = result?.selectedItem;
    if (!mounted || item == null) return;

    showDialog(
      context: context,
      builder: (context) => SaleItemDialog(
        item: item,
        reservedQuantity: (variant) => _draftItems
            .where((line) => line.item.id == item.id && line.variant == variant)
            .fold(0, (sum, line) => sum + line.quantity),
        onAddItem: (line) => setState(() => _draftItems.add(line)),
      ),
    );
  }

  void _submit() {
    if (_draftItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one item to the sale'),
          backgroundColor: Color(0xFFE74C3C),
        ),
      );
      return;
    }

    for (final line in _draftItems) {
      recordSale(
        item: line.item,
        quantity: line.quantity,
        unitSalePrice: line.unitPrice,
        date: _selectedDate,
        variant: line.variant,
      );
    }
    widget.onSaleAdded();
    Navigator.pop(context);
  }

  String get _formattedDate =>
      '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

  Widget _buildDraftTile(int index) {
    final line = _draftItems[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF2C3E50),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'SKU: ${line.item.sku}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                if (line.variant != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Variant: ${line.variant}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${line.quantity}x \$${line.unitPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF3498DB),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '\$${line.total.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF27AE60)),
              ),
            ],
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Color(0xFFE74C3C)),
            onPressed: () => setState(() => _draftItems.removeAt(index)),
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF2C3E50),
        title: const Text('Add Sale', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sale Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: _selectDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
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
                                _formattedDate,
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
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Items in Sale',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _addItemToSale,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Item'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF27AE60),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_draftItems.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFE0E0E0),
                          width: 1,
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'No items added yet',
                          style: TextStyle(
                            color: Color(0xFF99A3AC),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    )
                  else ...[
                    for (var i = 0; i < _draftItems.length; i++)
                      _buildDraftTile(i),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Total: \$${_saleTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(
                              color: Color(0xFF3498DB),
                              width: 2,
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: Color(0xFF3498DB),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton(
                          onPressed: _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF27AE60),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text(
                            'Record Sale',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
