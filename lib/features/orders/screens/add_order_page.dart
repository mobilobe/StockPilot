import 'package:flutter/material.dart';
import 'package:inventory/features/inventory/widgets/create_new_item_dialog.dart';
import 'package:inventory/features/inventory/widgets/quantity_and_price_dialog.dart';
import 'package:inventory/features/inventory/screens/select_inventory_order_items_page.dart';
import 'package:inventory/models/order.dart';
import 'package:inventory/models/inventory_item.dart';
import 'package:inventory/models/inventory_order_item.dart';

/// Builds an order and updates stock after validating its item lines.
class AddOrderPage extends StatefulWidget {
  final List<InventoryItem> inventoryList;
  final List<String> existingFolders;
  final Function(Order) onAddOrder;

  const AddOrderPage({
    required this.inventoryList,
    required this.existingFolders,
    required this.onAddOrder,
    super.key,
  });

  @override
  State<AddOrderPage> createState() => _AddOrderPageState();
}

/// Holds draft order lines and calculates landed unit costs on submission.
class _AddOrderPageState extends State<AddOrderPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _shippingController = TextEditingController();
  final TextEditingController _feesController = TextEditingController();
  final TextEditingController _folderController = TextEditingController();
  List<String> _existingFolders = [];
  late DateTime _selectedDate;
  final List<InventoryOrderItem> _selectedItems = [];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _folderController.text = '';
    _existingFolders =
        widget.existingFolders
            .map((folder) => folder.trim())
            .where((folder) => folder.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
  }

  @override
  void dispose() {
    _shippingController.dispose();
    _feesController.dispose();
    _folderController.dispose();
    super.dispose();
  }

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

  Future<void> _addItemToOrder() async {
    final result = await Navigator.push<SelectInventoryOrderItemsResult>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            SelectInventoryOrderItemsPage(inventoryList: widget.inventoryList),
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    if (result.createNew) {
      _showCreateNewItemDialog();
      return;
    }

    if (result.selectedItem != null) {
      _showQuantityAndPriceDialog(result.selectedItem!);
    }
  }

  void _showQuantityAndPriceDialog(InventoryItem item) {
    showDialog(
      context: context,
      builder: (context) => QuantityAndPriceDialog(
        item: item,
        onAddItem: (orderItem) {
          setState(() {
            _selectedItems.add(orderItem);
          });
        },
      ),
    );
  }

  void _showCreateNewItemDialog() {
    showDialog(
      context: context,
      builder: (context) => CreateNewItemDialog(
        onCreateItem: (orderItem) {
          setState(() {
            _selectedItems.add(orderItem);
            widget.inventoryList.add(orderItem.inventoryItem);
          });
        },
      ),
    );
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      if (_selectedItems.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please add at least one item to the order'),
            backgroundColor: Color(0xFFE74C3C),
          ),
        );
        return;
      }

      final shipping =
          double.tryParse(
            _shippingController.text.trim().isEmpty
                ? '0'
                : _shippingController.text.trim(),
          ) ??
          0;
      final fees =
          double.tryParse(
            _feesController.text.trim().isEmpty
                ? '0'
                : _feesController.text.trim(),
          ) ??
          0;

      double itemsTotal = _selectedItems.fold(
        0.0,
        (sum, item) => sum + (item.price * item.quantity),
      );
      double totalPrice = itemsTotal + shipping + fees;

      int amountOfItems = _selectedItems.fold(
        0,
        (sum, item) => sum + item.quantity,
      );

      // Spread shipping and fees across units so FIFO cost includes landed cost.
      final perUnitExtraCost = amountOfItems > 0
          ? (shipping + fees) / amountOfItems
          : 0.0;

      for (int i = 0; i < _selectedItems.length; i++) {
        InventoryOrderItem item = _selectedItems[i];
        _selectedItems[i].shippedPrice = item.price + perUnitExtraCost;
      }

      final order = Order(
        _selectedDate,
        _selectedItems,
        shipping,
        fees,
        totalPrice,
        _folderController.text.trim().isEmpty
            ? 'Uncategorized'
            : _folderController.text.trim(),
      );

      for (int i = 0; i < _selectedItems.length; i++) {
        if (!_selectedItems[i].inventoryItem.orderList.contains(order)) {
          _selectedItems[i].inventoryItem.orderList.add(order);
        }
        _selectedItems[i].inventoryItem.inventoryCount +=
            _selectedItems[i].quantity;
        final orderItem = _selectedItems[i];
        if (orderItem.inventoryItem.hasVariants &&
            orderItem.selectedVariant != null) {
          final variantKey = orderItem.selectedVariant!;
          final currentVariantStock =
              orderItem.inventoryItem.variantStock[variantKey] ?? 0;
          orderItem.inventoryItem.variantStock[variantKey] =
              currentVariantStock + orderItem.quantity;
        }
      }
      widget.onAddOrder(order);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF2C3E50),
        title: const Text(
          'Create Order',
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
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Order Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Date Picker
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
                                  'Order Date',
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
                    const SizedBox(height: 16),
                    _buildFolderAutocompleteField(),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _shippingController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Shipping Cost',
                        prefixIcon: const Icon(
                          Icons.local_shipping,
                          color: Color(0xFF3498DB),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      validator: (value) {
                        if (value != null &&
                            value.trim().isNotEmpty &&
                            double.tryParse(value) == null) {
                          return 'Please enter a valid amount';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Fees
                    TextFormField(
                      controller: _feesController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Fees',
                        prefixIcon: const Icon(
                          Icons.receipt,
                          color: Color(0xFF3498DB),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      validator: (value) {
                        if (value != null &&
                            value.trim().isNotEmpty &&
                            double.tryParse(value) == null) {
                          return 'Please enter a valid amount';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    // Items Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Items in Order',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _addItemToOrder,
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
                    if (_selectedItems.isEmpty)
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
                    else
                      Column(
                        children: List.generate(_selectedItems.length, (index) {
                          final item = _selectedItems[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFE0E0E0),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.inventoryItem.name,
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
                                        'SKU: ${item.inventoryItem.sku}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      if (item.selectedVariant != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          'Variant: ${item.selectedVariant}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${item.quantity}x',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Color(0xFF3498DB),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '\$${(item.price * item.quantity).toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF27AE60),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Color(0xFFE74C3C),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _selectedItems.removeAt(index);
                                    });
                                  },
                                  iconSize: 18,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
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
                            onPressed: _submitForm,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF27AE60),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text(
                              'Create Order',
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
      ),
    );
  }

  Widget _buildFolderAutocompleteField() {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: _folderController.text),
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
        _folderController.text = selection;
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
                  Icons.create_new_folder_outlined,
                  color: Color(0xFF3498DB),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (value) {
                _folderController.text = value;
              },
            );
          },
    );
  }
}
