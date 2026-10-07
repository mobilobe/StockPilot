import 'package:flutter/material.dart';
import 'package:inventory/services/hive_data.dart';
import 'package:inventory/features/inventory/screens/select_inventory_order_items_page.dart';
import 'package:inventory/models/inventory_item.dart';
import 'package:inventory/models/inventory_order_item.dart';
import 'package:inventory/models/order.dart';
import 'package:inventory/models/sale.dart';
import 'package:inventory/models/sale_line_item.dart';

/// Edits an existing item and coordinates its related orders and sale history.
class EditInventoryPage extends StatefulWidget {
  final InventoryItem inventoryItem;
  final List<InventoryItem>? allInventoryItems;
  final List<Order>? allOrders;
  final Function(InventoryItem) onUpdateInventory;
  final Function(InventoryItem) onDeleteInventory;
  final Function(Order)? onCreateTransferOrder;

  const EditInventoryPage({
    required this.inventoryItem,
    this.allInventoryItems,
    this.allOrders,
    required this.onUpdateInventory,
    required this.onDeleteInventory,
    this.onCreateTransferOrder,
    super.key,
  });

  @override
  State<EditInventoryPage> createState() => _EditInventoryPageState();
}

/// Owns editable form state and reconciles item history when fields change.
class _EditInventoryPageState extends State<EditInventoryPage> {
  static const double _contentMaxWidth = 1100;
  static const bool _showUnknownVariantBadge = true;
  final HiveService _hiveService = HiveService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _skuController;
  late TextEditingController _folderController;
  late TextEditingController _inventoryCountController;
  late TextEditingController _soldCountController;
  final TextEditingController _variantValueController = TextEditingController();
  List<String> _existingFolders = [];
  late bool _hasVariants;
  late List<String> _variantValues;
  final Map<String, TextEditingController> _variantStockControllers =
      <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.inventoryItem.name);
    _priceController = TextEditingController(
      text: widget.inventoryItem.price.toString(),
    );
    _skuController = TextEditingController(text: widget.inventoryItem.sku);
    _folderController = TextEditingController(
      text: widget.inventoryItem.folder,
    );
    _inventoryCountController = TextEditingController(
      text: widget.inventoryItem.inventoryCount.toString(),
    );
    _soldCountController = TextEditingController(
      text: widget.inventoryItem.soldCount.toString(),
    );
    _hasVariants = widget.inventoryItem.hasVariants;
    _variantValues = List<String>.from(widget.inventoryItem.variantValues);
    for (final variant in _variantValues) {
      _variantStockControllers[variant] = TextEditingController(
        text: (widget.inventoryItem.variantStock[variant] ?? 0).toString(),
      );
    }
    _existingFolders = <String>{
      ..._hiveService
          .getInventoryItems()
          .map((item) => item.folder.trim())
          .where((folder) => folder.isNotEmpty),
      ..._hiveService.getFolderColors().keys,
    }.toList()..sort();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _skuController.dispose();
    _folderController.dispose();
    _inventoryCountController.dispose();
    _soldCountController.dispose();
    _variantValueController.dispose();
    for (final controller in _variantStockControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      if (_hasVariants && _variantValues.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Add at least one variant value'),
            backgroundColor: Color(0xFFE74C3C),
          ),
        );
        return;
      }

      final variantStock = <String, int>{};
      if (_hasVariants) {
        for (final variant in _variantValues) {
          final controller = _variantStockControllers[variant];
          final stock = int.tryParse(controller?.text ?? '');
          if (stock == null || stock < 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Enter valid stock for variant "$variant"'),
                backgroundColor: const Color(0xFFE74C3C),
              ),
            );
            return;
          }
          variantStock[variant] = stock;
        }
      }

      // Update the shared model in place; the parent callback persists it.
      widget.inventoryItem.name = _nameController.text;
      widget.inventoryItem.price = double.parse(_priceController.text);
      widget.inventoryItem.sku = _skuController.text;
      widget.inventoryItem.folder = _folderController.text.trim().isEmpty
          ? 'Uncategorized'
          : _folderController.text.trim();
      widget.inventoryItem.hasVariants = _hasVariants;
      widget.inventoryItem.variantValues = _hasVariants
          ? List<String>.from(_variantValues)
          : <String>[];
      widget.inventoryItem.variantStock = _hasVariants
          ? variantStock
          : <String, int>{};
      widget.inventoryItem.inventoryCount = _hasVariants
          ? variantStock.values.fold<int>(0, (sum, value) => sum + value)
          : int.tryParse(_inventoryCountController.text.trim()) ?? 0;
      widget.inventoryItem.soldCount = _hasVariants
          ? widget.inventoryItem.soldCount
          : int.tryParse(_soldCountController.text.trim()) ?? 0;

      widget.onUpdateInventory(widget.inventoryItem);
      Navigator.pop(context);
    }
  }

  void _addVariantValue() {
    final value = _variantValueController.text.trim();
    if (value.isEmpty) {
      return;
    }

    final exists = _variantValues.any(
      (variant) => variant.toLowerCase() == value.toLowerCase(),
    );
    if (exists) {
      return;
    }

    setState(() {
      _variantValues.add(value);
      _variantStockControllers[value] = TextEditingController(text: '0');
      _variantValueController.clear();
    });
  }

  void _removeVariantValue(String value) {
    setState(() {
      _variantValues.remove(value);
      _variantStockControllers.remove(value)?.dispose();
    });
  }

  Future<void> _editVariantValue(String currentValue) async {
    final controller = TextEditingController(text: currentValue);

    final updatedValue = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text('Edit Variant Value'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Variant Value',
            hintText: 'e.g. Small, Red, V6',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext, controller.text.trim());
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    final trimmedValue = updatedValue?.trim() ?? '';
    if (trimmedValue.isEmpty || trimmedValue == currentValue) {
      return;
    }

    final alreadyExists = _variantValues.any(
      (variant) =>
          variant.toLowerCase() == trimmedValue.toLowerCase() &&
          variant != currentValue,
    );

    if (alreadyExists) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Variant value already exists'),
          backgroundColor: Color(0xFFE74C3C),
        ),
      );
      return;
    }

    // Move the stock controller with its label so the quantity is preserved.
    setState(() {
      final index = _variantValues.indexOf(currentValue);
      if (index == -1) {
        return;
      }

      final stockController = _variantStockControllers.remove(currentValue);
      _variantValues[index] = trimmedValue;
      _variantStockControllers[trimmedValue] =
          stockController ?? TextEditingController(text: '0');
    });
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Item'),
        content: const Text(
          'Delete this inventory item? This removes only this item and its sales entries.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              widget.onDeleteInventory(widget.inventoryItem);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE74C3C),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final regularOrders = widget.inventoryItem.orderList
        .where((order) => !order.isInputTransfer)
        .toList();
    final inputTransfers = _inputTransfersForItem();

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF2C3E50),
        title: const Text('Edit Item', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            onPressed: _showUseAsInputDialog,
            icon: const Icon(Icons.swap_horiz, color: Colors.white),
            tooltip: 'Use as Input',
          ),
          IconButton(
            onPressed: _confirmDelete,
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            tooltip: 'Delete Item',
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Item Details',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildTextField(
                            _nameController,
                            'Item Name',
                            Icons.label,
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(_skuController, 'SKU', Icons.tag),
                          const SizedBox(height: 16),
                          _buildFolderAutocompleteField(),
                          const SizedBox(height: 16),
                          _buildTextField(
                            _priceController,
                            'Price',
                            Icons.attach_money,
                            inputType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            isPrice: true,
                          ),

                          const SizedBox(height: 24),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Has Variants',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2C3E50),
                              ),
                            ),
                            value: _hasVariants,
                            onChanged: (value) {
                              setState(() {
                                _hasVariants = value;
                                if (!value) {
                                  _variantValueController.clear();
                                  for (final controller
                                      in _variantStockControllers.values) {
                                    controller.dispose();
                                  }
                                  _variantStockControllers.clear();
                                  _variantValues.clear();
                                }
                              });
                            },
                          ),
                          if (_hasVariants) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _variantValueController,
                                    decoration: InputDecoration(
                                      labelText: 'Variant Value',
                                      hintText: 'e.g. Small, Red, V6',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    onFieldSubmitted: (_) => _addVariantValue(),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilledButton(
                                  onPressed: _addVariantValue,
                                  child: const Text('Add'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_variantValues.isNotEmpty)
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _variantValues
                                    .map(
                                      (value) => InkWell(
                                        borderRadius: BorderRadius.circular(16),
                                        onTap: () => _editVariantValue(value),
                                        child: Chip(
                                          label: Text(value),
                                          onDeleted: () =>
                                              _removeVariantValue(value),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                          ],

                          const SizedBox(height: 24),
                          const Text(
                            'Inventory',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (!_hasVariants)
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    _inventoryCountController,
                                    'In Stock',
                                    Icons.inventory_2,
                                    inputType: TextInputType.number,
                                    allowEmpty: true,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildTextField(
                                    _soldCountController,
                                    'Sold',
                                    Icons.shopping_bag,
                                    inputType: TextInputType.number,
                                    allowEmpty: true,
                                  ),
                                ),
                              ],
                            )
                          else
                            Column(
                              children: _variantValues
                                  .map(
                                    (variant) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: TextFormField(
                                        controller:
                                            _variantStockControllers[variant],
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: 'Stock for $variant',
                                          prefixIcon: const Icon(
                                            Icons.inventory_2,
                                            color: Color(0xFF3498DB),
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                        validator: (value) {
                                          if (_hasVariants) {
                                            final parsed = int.tryParse(
                                              value ?? '',
                                            );
                                            if (parsed == null || parsed < 0) {
                                              return 'Enter valid stock';
                                            }
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),

                          const SizedBox(height: 32),
                          _buildHistoryDropdown(
                            title: 'Order History',
                            child: regularOrders.isEmpty
                                ? _emptyHistoryMessage(
                                    'No orders for this item',
                                  )
                                : Column(
                                    children: List.generate(regularOrders.length, (
                                      index,
                                    ) {
                                      final order = regularOrders[index];
                                      final orderDate = order.date;
                                      final formattedDate =
                                          '${orderDate.year}-${orderDate.month.toString().padLeft(2, '0')}-${orderDate.day.toString().padLeft(2, '0')}';

                                      final matchingOrderItems = order
                                          .inventoryList
                                          .where(
                                            (item) =>
                                                item.inventoryItem.id ==
                                                widget.inventoryItem.id,
                                          )
                                          .toList();

                                      final quantity = matchingOrderItems.fold(
                                        0,
                                        (sum, item) => sum + item.quantity,
                                      );
                                      final totalLineValue = matchingOrderItems
                                          .fold<double>(
                                            0,
                                            (sum, item) =>
                                                sum +
                                                (item.shippedPrice *
                                                    item.quantity),
                                          );
                                      final price = quantity > 0
                                          ? totalLineValue / quantity
                                          : 0.0;
                                      final orderVariants =
                                          _extractOrderVariants(
                                            matchingOrderItems,
                                          );

                                      return Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFE0E0E0),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Order - $formattedDate',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                      color: Color(0xFF2C3E50),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Total: \$${order.totalOrderPrice.toStringAsFixed(2)}',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Color(0xFF99A3AC),
                                                    ),
                                                  ),
                                                  if (widget
                                                      .inventoryItem
                                                      .hasVariants) ...[
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      'Variant: $orderVariants',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: Color(
                                                          0xFF99A3AC,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  '$quantity units',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                    color: Color(0xFF3498DB),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Price: \$${price.toStringAsFixed(2)}/unit',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Color(0xFF99A3AC),
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Total: \$${(price * quantity).toStringAsFixed(2)}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                    color: Color(0xFF27AE60),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ),
                          ),

                          const SizedBox(height: 16),
                          _buildHistoryDropdown(
                            title: 'Input History',
                            child: inputTransfers.isEmpty
                                ? _emptyHistoryMessage(
                                    'No input transfers for this item',
                                  )
                                : Column(
                                    children: List.generate(inputTransfers.length, (
                                      index,
                                    ) {
                                      final transfer = inputTransfers[index];
                                      final transferDate = transfer.date;
                                      final formattedDate =
                                          '${transferDate.year}-${transferDate.month.toString().padLeft(2, '0')}-${transferDate.day.toString().padLeft(2, '0')}';
                                      final isSource =
                                          transfer.transferSourceItemId ==
                                          widget.inventoryItem.id;
                                      final counterpartName = isSource
                                          ? (transfer
                                                    .transferDestinationItemName ??
                                                'Unknown item')
                                          : (transfer.transferSourceItemName ??
                                                'Unknown item');
                                      final variant = isSource
                                          ? transfer.transferSourceVariant
                                          : transfer.transferDestinationVariant;
                                      final transferQuantity =
                                          transfer.transferQuantity ??
                                          transfer.inventoryList.fold<int>(
                                            0,
                                            (sum, line) => sum + line.quantity,
                                          );
                                      final totalValue =
                                          transfer.transferUnitCost == null
                                          ? (transfer.totalOrderPrice)
                                          : transfer.transferUnitCost! *
                                                transferQuantity;

                                      return Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFE0E0E0),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    isSource
                                                        ? 'Used as Input - $formattedDate'
                                                        : 'Received Input - $formattedDate',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                      color: Color(0xFF2C3E50),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    isSource
                                                        ? 'Converted to: $counterpartName'
                                                        : 'Converted from: $counterpartName',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Color(0xFF99A3AC),
                                                    ),
                                                  ),
                                                  if ((variant ?? '')
                                                      .trim()
                                                      .isNotEmpty)
                                                    Text(
                                                      'Variant: $variant',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: Color(
                                                          0xFF99A3AC,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  '$transferQuantity units',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                    color: isSource
                                                        ? const Color(
                                                            0xFFE67E22,
                                                          )
                                                        : const Color(
                                                            0xFF27AE60,
                                                          ),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                if (transfer.transferUnitCost !=
                                                    null)
                                                  Text(
                                                    'Cost: \$${transfer.transferUnitCost!.toStringAsFixed(2)}/unit',
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: Color(0xFF99A3AC),
                                                    ),
                                                  ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Total: \$${totalValue.toStringAsFixed(2)}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                    color: Color(0xFF3498DB),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ),
                          ),

                          const SizedBox(height: 16),
                          _buildHistoryDropdown(
                            title: 'Sales History',
                            child: widget.inventoryItem.salesList.isEmpty
                                ? _emptyHistoryMessage(
                                    'No sales recorded for this item',
                                  )
                                : Column(
                                    children: List.generate(widget.inventoryItem.salesList.length, (
                                      index,
                                    ) {
                                      final sale =
                                          widget.inventoryItem.salesList[index];
                                      final saleDate = sale.date;
                                      final formattedDate =
                                          '${saleDate.year}-${saleDate.month.toString().padLeft(2, '0')}-${saleDate.day.toString().padLeft(2, '0')}';

                                      final saleVariants = _extractSaleVariants(
                                        sale,
                                      );
                                      final hasUnknownVariant =
                                          _hasUnknownSaleVariant(sale);
                                      final displayVariant = hasUnknownVariant
                                          ? 'Unknown'
                                          : saleVariants;

                                      return Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFE0E0E0),
                                            width: 1,
                                          ),
                                        ),
                                        child: ExpansionTile(
                                          tilePadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 2,
                                              ),
                                          childrenPadding:
                                              const EdgeInsets.fromLTRB(
                                                12,
                                                0,
                                                12,
                                                12,
                                              ),
                                          iconColor: const Color(0xFF3498DB),
                                          collapsedIconColor: const Color(
                                            0xFF99A3AC,
                                          ),
                                          title: Text(
                                            'Sale - $formattedDate',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: Color(0xFF2C3E50),
                                            ),
                                          ),
                                          subtitle: Text(
                                            widget.inventoryItem.hasVariants
                                                ? 'Qty: ${sale.quantity} • Variant: $displayVariant • Revenue: \$${sale.price.toStringAsFixed(2)} • Profit: \$${sale.profit.toStringAsFixed(2)}'
                                                : 'Qty: ${sale.quantity} • Revenue: \$${sale.price.toStringAsFixed(2)} • Profit: \$${sale.profit.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF99A3AC),
                                            ),
                                          ),
                                          children: [
                                            if (_showUnknownVariantBadge &&
                                                hasUnknownVariant)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 8,
                                                ),
                                                child: Align(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0xFFE67E22,
                                                      ).withValues(alpha: 0.12),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                    ),
                                                    child: const Text(
                                                      'Unknown variant',
                                                      style: TextStyle(
                                                        color: Color(
                                                          0xFFE67E22,
                                                        ),
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: TextButton.icon(
                                                onPressed: () =>
                                                    _showEditSaleDialog(index),
                                                icon: const Icon(
                                                  Icons.edit_outlined,
                                                  size: 16,
                                                ),
                                                label: const Text('Edit Sale'),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.grey[50],
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'Cost Basis Breakdown (FIFO):',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 12,
                                                      color: Color(0xFF2C3E50),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  if (sale
                                                      .priceBreakdown
                                                      .isEmpty)
                                                    const Text(
                                                      'No line-item breakdown available.',
                                                      style: TextStyle(
                                                        color: Color(
                                                          0xFF99A3AC,
                                                        ),
                                                        fontStyle:
                                                            FontStyle.italic,
                                                        fontSize: 11,
                                                      ),
                                                    )
                                                  else
                                                    ...sale.priceBreakdown.map(
                                                      (line) => Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              bottom: 6,
                                                            ),
                                                        child: Builder(
                                                          builder: (context) {
                                                            final sourceType =
                                                                _saleLineSourceType(
                                                                  line,
                                                                );
                                                            return Row(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .spaceBetween,
                                                              children: [
                                                                Expanded(
                                                                  child: Column(
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .start,
                                                                    children: [
                                                                      Text(
                                                                        'Source: $sourceType',
                                                                        style: TextStyle(
                                                                          fontSize:
                                                                              10,
                                                                          color:
                                                                              Colors.grey[600],
                                                                          fontWeight:
                                                                              FontWeight.w600,
                                                                        ),
                                                                      ),
                                                                      Text(
                                                                        line.source,
                                                                        style: const TextStyle(
                                                                          fontSize:
                                                                              11,
                                                                          color: Color(
                                                                            0xFF2C3E50,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                      Text(
                                                                        'Qty: ${line.quantity}',
                                                                        style: TextStyle(
                                                                          fontSize:
                                                                              10,
                                                                          color:
                                                                              Colors.grey[600],
                                                                        ),
                                                                      ),
                                                                      if (widget
                                                                          .inventoryItem
                                                                          .hasVariants)
                                                                        Text(
                                                                          'Variant: ${_extractVariantFromSaleLine(line)}',
                                                                          style: TextStyle(
                                                                            fontSize:
                                                                                10,
                                                                            color:
                                                                                Colors.grey[600],
                                                                          ),
                                                                        ),
                                                                    ],
                                                                  ),
                                                                ),
                                                                Text(
                                                                  '\$${(line.quantity * line.unitPrice).toStringAsFixed(2)}',
                                                                  style: const TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize:
                                                                        11,
                                                                    color: Color(
                                                                      0xFF3498DB,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            );
                                                          },
                                                        ),
                                                      ),
                                                    ),
                                                  const SizedBox(height: 8),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          top: 8,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      border: Border(
                                                        top: BorderSide(
                                                          color:
                                                              Colors.grey[300]!,
                                                          width: 1,
                                                        ),
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        const Text(
                                                          'Total Cost Basis:',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 11,
                                                            color: Color(
                                                              0xFF2C3E50,
                                                            ),
                                                          ),
                                                        ),
                                                        Text(
                                                          '\$${(sale.price - sale.profit).toStringAsFixed(2)}',
                                                          style:
                                                              const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 11,
                                                                color: Color(
                                                                  0xFFE74C3C,
                                                                ),
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ),
                          ),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                color: const Color(0xFFF5F7FA),
                padding: const EdgeInsets.all(24),
                child: Row(
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
                          backgroundColor: const Color(0xFF3498DB),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showEditSaleDialog(int saleIndex) async {
    final sale = widget.inventoryItem.salesList[saleIndex];
    final oldQuantity = sale.quantity;
    final quantityController = TextEditingController(
      text: sale.quantity.toString(),
    );
    final revenueController = TextEditingController(
      text: sale.price.toStringAsFixed(2),
    );
    final profitController = TextEditingController(
      text: sale.profit.toStringAsFixed(2),
    );
    DateTime selectedDate = sale.date;
    String? selectedVariant = _singleVariantFromSale(sale);

    Future<void> pickDate(
      BuildContext dialogContext,
      void Function(void Function()) setDialogState,
    ) async {
      final picked = await showDatePicker(
        context: dialogContext,
        initialDate: selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
      );

      if (picked != null) {
        setDialogState(() {
          selectedDate = picked;
        });
      }
    }

    if (widget.inventoryItem.hasVariants &&
        selectedVariant == null &&
        widget.inventoryItem.variantValues.length == 1) {
      selectedVariant = widget.inventoryItem.variantValues.first;
    }

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          scrollable: true,
          title: const Text('Edit Sale'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => pickDate(dialogContext, setDialogState),
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
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    prefixIcon: Icon(Icons.inventory_2),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: revenueController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Revenue',
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: profitController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Profit',
                    prefixIcon: Icon(Icons.trending_up),
                  ),
                ),
                if (widget.inventoryItem.hasVariants) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedVariant,
                    decoration: const InputDecoration(
                      labelText: 'Variant',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: widget.inventoryItem.variantValues
                        .map(
                          (variant) => DropdownMenuItem<String>(
                            value: variant,
                            child: Text(variant),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedVariant = value;
                      });
                    },
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  widget.inventoryItem.salesList.removeAt(saleIndex);

                  widget.inventoryItem.soldCount -= oldQuantity;
                  if (widget.inventoryItem.soldCount < 0) {
                    widget.inventoryItem.soldCount = 0;
                  }

                  widget.inventoryItem.inventoryCount += oldQuantity;

                  final oldVariant = _singleVariantFromSale(sale);
                  if (widget.inventoryItem.hasVariants && oldVariant != null) {
                    final current =
                        widget.inventoryItem.variantStock[oldVariant] ?? 0;
                    widget.inventoryItem.variantStock[oldVariant] =
                        current + oldQuantity;
                  }

                  _inventoryCountController.text = widget
                      .inventoryItem
                      .inventoryCount
                      .toString();
                  _soldCountController.text = widget.inventoryItem.soldCount
                      .toString();
                });

                Navigator.pop(dialogContext);
              },
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFE74C3C),
              ),
              child: const Text('Delete Sale'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final newQuantity = int.tryParse(
                  quantityController.text.trim(),
                );
                final newRevenue = double.tryParse(
                  revenueController.text.trim(),
                );
                final newProfit = double.tryParse(profitController.text.trim());

                if (newQuantity == null || newQuantity <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Enter a valid quantity greater than 0'),
                      backgroundColor: Color(0xFFE74C3C),
                    ),
                  );
                  return;
                }

                if (newRevenue == null || newRevenue < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Enter a valid revenue'),
                      backgroundColor: Color(0xFFE74C3C),
                    ),
                  );
                  return;
                }

                if (newProfit == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Enter a valid profit'),
                      backgroundColor: Color(0xFFE74C3C),
                    ),
                  );
                  return;
                }

                if (widget.inventoryItem.hasVariants &&
                    selectedVariant == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Select a variant'),
                      backgroundColor: Color(0xFFE74C3C),
                    ),
                  );
                  return;
                }

                final oldVariant = _singleVariantFromSale(sale);
                final quantityDelta = newQuantity - oldQuantity;

                if (quantityDelta > 0) {
                  if (widget.inventoryItem.hasVariants) {
                    final targetVariant = selectedVariant!;
                    final currentTargetStock =
                        widget.inventoryItem.variantStock[targetVariant] ?? 0;
                    final availableAfterRollback = targetVariant == oldVariant
                        ? currentTargetStock + oldQuantity
                        : currentTargetStock;

                    if (availableAfterRollback < newQuantity) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Not enough stock in variant "$targetVariant"',
                          ),
                          backgroundColor: const Color(0xFFE74C3C),
                        ),
                      );
                      return;
                    }
                  } else {
                    if (widget.inventoryItem.inventoryCount < quantityDelta) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Not enough stock for this quantity'),
                          backgroundColor: Color(0xFFE74C3C),
                        ),
                      );
                      return;
                    }
                  }
                }

                final hasDetailChanges =
                    newQuantity != oldQuantity ||
                    newRevenue != sale.price ||
                    newProfit != sale.profit ||
                    selectedDate != sale.date ||
                    (widget.inventoryItem.hasVariants &&
                        selectedVariant != oldVariant);

                if (!hasDetailChanges) {
                  Navigator.pop(dialogContext);
                  return;
                }

                setState(() {
                  sale.date = selectedDate;
                  sale.quantity = newQuantity;
                  sale.price = newRevenue;
                  sale.profit = newProfit;

                  if (quantityDelta != 0) {
                    widget.inventoryItem.soldCount += quantityDelta;
                    widget.inventoryItem.inventoryCount -= quantityDelta;

                    _inventoryCountController.text = widget
                        .inventoryItem
                        .inventoryCount
                        .toString();
                    _soldCountController.text = widget.inventoryItem.soldCount
                        .toString();
                  }

                  if (widget.inventoryItem.hasVariants) {
                    final targetVariant = selectedVariant!;

                    if (oldVariant != null) {
                      final oldCurrent =
                          widget.inventoryItem.variantStock[oldVariant] ?? 0;
                      widget.inventoryItem.variantStock[oldVariant] =
                          oldCurrent + oldQuantity;
                    }

                    final targetCurrent =
                        widget.inventoryItem.variantStock[targetVariant] ?? 0;
                    widget.inventoryItem.variantStock[targetVariant] =
                        targetCurrent - newQuantity;
                  }

                  final totalCostBasis = newRevenue - newProfit;
                  final unitCost = newQuantity > 0
                      ? totalCostBasis / newQuantity
                      : 0.0;
                  final variantSuffix = selectedVariant == null
                      ? ''
                      : ' (${selectedVariant!.trim()})';

                  sale.priceBreakdown = [
                    SaleLineItem(
                      quantity: newQuantity,
                      unitPrice: unitCost,
                      source: 'Edited Sale$variantSuffix',
                      orderItem: null,
                    ),
                  ];
                });

                Navigator.pop(dialogContext);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    quantityController.dispose();
    revenueController.dispose();
    profitController.dispose();
  }

  List<Order> _inputTransfersForItem() {
    final itemId = widget.inventoryItem.id;
    final orders = widget.allOrders ?? _hiveService.getOrders();

    final transfers = orders.where((order) {
      if (!order.isInputTransfer) {
        return false;
      }

      return order.transferSourceItemId == itemId ||
          order.transferDestinationItemId == itemId;
    }).toList();

    transfers.sort((a, b) => b.date.compareTo(a.date));
    return transfers;
  }

  List<SaleLineItem> _calculateFIFOTransferBreakdown(
    InventoryItem item,
    int quantityToTransfer,
    String? selectedVariant,
  ) {
    final breakdown = <SaleLineItem>[];
    var remainingQuantity = quantityToTransfer;

    final sortedOrders = List<Order>.from(item.orderList)
      ..sort((a, b) => a.date.compareTo(b.date));

    for (final order in sortedOrders) {
      if (remainingQuantity <= 0) break;

      for (final orderItem in order.inventoryList) {
        if (orderItem.inventoryItem.id != item.id || remainingQuantity <= 0) {
          continue;
        }

        if (item.hasVariants && orderItem.selectedVariant != selectedVariant) {
          continue;
        }

        final availableQuantity = orderItem.currentQuantity;
        if (availableQuantity <= 0) {
          continue;
        }

        final quantityToUseHere = availableQuantity < remainingQuantity
            ? availableQuantity
            : remainingQuantity;
        final orderDate =
            '${order.date.year}-${order.date.month.toString().padLeft(2, '0')}-${order.date.day.toString().padLeft(2, '0')}';

        breakdown.add(
          SaleLineItem(
            quantity: quantityToUseHere,
            unitPrice: orderItem.shippedPrice,
            source: item.hasVariants
                ? 'Transfer Source - $orderDate (${orderItem.selectedVariant ?? 'N/A'})'
                : 'Transfer Source - $orderDate',
            orderItem: orderItem,
          ),
        );

        remainingQuantity -= quantityToUseHere;
      }
    }

    if (remainingQuantity > 0) {
      breakdown.add(
        SaleLineItem(
          quantity: remainingQuantity,
          unitPrice: item.price,
          source: 'Initial Price',
          orderItem: null,
        ),
      );
    }

    return breakdown;
  }

  double _calculateTotalCostBasis(List<SaleLineItem> breakdown) {
    return breakdown.fold<double>(
      0.0,
      (sum, line) => sum + (line.quantity * line.unitPrice),
    );
  }

  DateTime? _findOrderDateForOrderItem(
    InventoryItem sourceItem,
    InventoryOrderItem orderItem,
  ) {
    for (final order in sourceItem.orderList) {
      if (order.inventoryList.contains(orderItem)) {
        return order.date;
      }
    }
    return null;
  }

  Order? _findOrderForOrderItem(
    InventoryItem sourceItem,
    InventoryOrderItem orderItem,
  ) {
    for (final order in sourceItem.orderList) {
      if (order.inventoryList.contains(orderItem)) {
        return order;
      }
    }
    return null;
  }

  String _saleLineSourceType(SaleLineItem line) {
    final orderItem = line.orderItem;
    if (orderItem == null) {
      return 'Initial';
    }

    final parentOrder = _findOrderForOrderItem(widget.inventoryItem, orderItem);
    if (parentOrder != null) {
      return parentOrder.isInputTransfer ? 'Transfer' : 'Order';
    }

    final normalizedSource = line.source.toLowerCase();
    if (normalizedSource.contains('transfer')) {
      return 'Transfer';
    }
    return 'Order';
  }

  double _estimateFifoUnitCost(
    InventoryItem item,
    int quantity,
    String? selectedVariant,
  ) {
    if (quantity <= 0) {
      return item.price;
    }

    final breakdown = _calculateFIFOTransferBreakdown(
      item,
      quantity,
      selectedVariant,
    );
    final totalCostBasis = _calculateTotalCostBasis(breakdown);
    return totalCostBasis / quantity;
  }

  Future<void> _showUseAsInputDialog() async {
    final sourceItem = widget.inventoryItem;
    final quantityController = TextEditingController(text: '1');
    final unitPriceController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    InventoryItem? targetItem;

    String? sourceVariant;
    if (sourceItem.hasVariants && sourceItem.variantValues.length == 1) {
      sourceVariant = sourceItem.variantValues.first;
    }

    String? targetVariant;

    void setEstimatedPrice(
      void Function(void Function())? setDialogState,
      int? quantity,
    ) {
      final safeQty = quantity == null || quantity <= 0 ? 1 : quantity;
      final estimated = _estimateFifoUnitCost(
        sourceItem,
        safeQty,
        sourceVariant,
      );
      if (setDialogState == null) {
        unitPriceController.text = estimated.toStringAsFixed(2);
      } else {
        setDialogState(() {
          unitPriceController.text = estimated.toStringAsFixed(2);
        });
      }
    }

    setEstimatedPrice(null, int.tryParse(quantityController.text.trim()));

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final parsedPreviewQuantity = int.tryParse(
            quantityController.text.trim(),
          );
          final previewQuantity =
              parsedPreviewQuantity == null || parsedPreviewQuantity <= 0
              ? 1
              : parsedPreviewQuantity;
          final canBuildPreview =
              !sourceItem.hasVariants || sourceVariant != null;
          final previewBreakdown = canBuildPreview
              ? _calculateFIFOTransferBreakdown(
                  sourceItem,
                  previewQuantity,
                  sourceVariant,
                )
              : <SaleLineItem>[];
          final previewTotalCost = canBuildPreview
              ? _calculateTotalCostBasis(previewBreakdown)
              : 0.0;
          final previewUnitCost = previewTotalCost / previewQuantity;

          return AlertDialog(
            scrollable: true,
            title: const Text('Use as Input'),
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
                  if (sourceItem.hasVariants) ...[
                    DropdownButtonFormField<String>(
                      initialValue: sourceVariant,
                      decoration: const InputDecoration(
                        labelText: 'From Variant',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: sourceItem.variantValues
                          .map(
                            (variant) => DropdownMenuItem<String>(
                              value: variant,
                              child: Text(variant),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          sourceVariant = value;
                        });
                        setEstimatedPrice(
                          setDialogState,
                          int.tryParse(quantityController.text.trim()),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Quantity',
                      prefixIcon: const Icon(Icons.inventory_2),
                      helperText:
                          'Available: ${sourceItem.hasVariants ? (sourceItem.variantStock[sourceVariant] ?? 0) : sourceItem.inventoryCount}',
                    ),
                    onChanged: (value) {
                      setEstimatedPrice(
                        setDialogState,
                        int.tryParse(value.trim()),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: unitPriceController,
                    readOnly: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Cost/Unit',
                      prefixIcon: Icon(Icons.attach_money),
                      helperText: 'Auto-calculated using FIFO',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                    ),
                    child: !canBuildPreview
                        ? const Text(
                            'Select a source variant to preview FIFO breakdown.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF99A3AC),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'FIFO Breakdown Preview',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Color(0xFF2C3E50),
                                ),
                              ),
                              const SizedBox(height: 6),
                              ...previewBreakdown.map(
                                (line) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${line.source} • Qty ${line.quantity} @ \$${line.unitPrice.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF2C3E50),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '\$${(line.quantity * line.unitPrice).toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF3498DB),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const Divider(height: 12),
                              Text(
                                'Quoted Cost/Unit: \$${previewUnitCost.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF27AE60),
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final result =
                            await Navigator.push<
                              SelectInventoryOrderItemsResult
                            >(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    SelectInventoryOrderItemsPage(
                                      inventoryList:
                                          (widget.allInventoryItems ??
                                                  _hiveService
                                                      .getInventoryItems())
                                              .where(
                                                (item) =>
                                                    item.id != sourceItem.id,
                                              )
                                              .toList(),
                                    ),
                              ),
                            );

                        if (!mounted || result == null || result.createNew) {
                          return;
                        }

                        if (result.selectedItem != null) {
                          setDialogState(() {
                            targetItem = result.selectedItem;
                            if (targetItem!.hasVariants &&
                                targetItem!.variantValues.length == 1) {
                              targetVariant = targetItem!.variantValues.first;
                            } else {
                              targetVariant = null;
                            }
                          });
                        }
                      },
                      icon: const Icon(Icons.swap_horiz),
                      label: Text(
                        targetItem == null
                            ? 'Choose Item to Convert To'
                            : 'Convert To: ${targetItem!.name}',
                      ),
                    ),
                  ),
                  if (targetItem != null && targetItem!.hasVariants) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: targetVariant,
                      decoration: const InputDecoration(
                        labelText: 'To Variant',
                        prefixIcon: Icon(Icons.tune),
                      ),
                      items: targetItem!.variantValues
                          .map(
                            (variant) => DropdownMenuItem<String>(
                              value: variant,
                              child: Text(variant),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          targetVariant = value;
                        });
                      },
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final quantity = int.tryParse(quantityController.text.trim());

                  if (quantity == null || quantity <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Enter a valid quantity greater than 0'),
                        backgroundColor: Color(0xFFE74C3C),
                      ),
                    );
                    return;
                  }

                  if (sourceItem.hasVariants && sourceVariant == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Select a source variant'),
                        backgroundColor: Color(0xFFE74C3C),
                      ),
                    );
                    return;
                  }

                  if (targetItem == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Choose an item to convert to'),
                        backgroundColor: Color(0xFFE74C3C),
                      ),
                    );
                    return;
                  }

                  if (targetItem!.hasVariants && targetVariant == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Select a destination variant'),
                        backgroundColor: Color(0xFFE74C3C),
                      ),
                    );
                    return;
                  }

                  final allItems =
                      widget.allInventoryItems ??
                      _hiveService.getInventoryItems();
                  var resolvedSource = sourceItem;
                  var resolvedTarget = targetItem!;
                  for (final item in allItems) {
                    if (item.id == sourceItem.id) {
                      resolvedSource = item;
                    } else if (item.id == targetItem!.id) {
                      resolvedTarget = item;
                    }
                  }

                  final available = resolvedSource.hasVariants
                      ? (resolvedSource.variantStock[sourceVariant] ?? 0)
                      : resolvedSource.inventoryCount;

                  if (quantity > available) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Not enough stock (available: $available)',
                        ),
                        backgroundColor: const Color(0xFFE74C3C),
                      ),
                    );
                    return;
                  }

                  final fifoBreakdown = _calculateFIFOTransferBreakdown(
                    resolvedSource,
                    quantity,
                    sourceVariant,
                  );
                  final fifoCost = _calculateTotalCostBasis(fifoBreakdown);
                  final fifoUnitCost = fifoCost / quantity;
                  final unitCost = fifoUnitCost;

                  for (final lineItem in fifoBreakdown) {
                    if (lineItem.orderItem != null) {
                      lineItem.orderItem!.currentQuantity -= lineItem.quantity;
                    }
                  }

                  resolvedSource.inventoryCount -= quantity;
                  if (resolvedSource.hasVariants && sourceVariant != null) {
                    final sourceCurrent =
                        resolvedSource.variantStock[sourceVariant] ?? 0;
                    resolvedSource.variantStock[sourceVariant!] =
                        sourceCurrent - quantity;
                  }

                  resolvedTarget.inventoryCount += quantity;
                  if (resolvedTarget.hasVariants && targetVariant != null) {
                    final targetCurrent =
                        resolvedTarget.variantStock[targetVariant] ?? 0;
                    resolvedTarget.variantStock[targetVariant!] =
                        targetCurrent + quantity;
                  }

                  final transferOrderItem = InventoryOrderItem(
                    resolvedTarget,
                    quantity,
                    unitCost,
                    unitCost,
                    quantity,
                    selectedVariant: targetVariant,
                  );

                  final transferOrder = Order(
                    selectedDate,
                    [transferOrderItem],
                    0,
                    0,
                    unitCost * quantity,
                    'Input Transfers',
                    isInputTransfer: true,
                    transferSourceItemId: resolvedSource.id,
                    transferDestinationItemId: resolvedTarget.id,
                    transferSourceItemName: resolvedSource.name,
                    transferDestinationItemName: resolvedTarget.name,
                    transferSourceVariant: sourceVariant,
                    transferDestinationVariant: targetVariant,
                    transferUnitCost: unitCost,
                    transferQuantity: quantity,
                    transferFifoBreakdown: fifoBreakdown
                        .map(
                          (line) => <String, dynamic>{
                            'quantity': line.quantity,
                            'unitPrice': line.unitPrice,
                            'source': line.source,
                            'selectedVariant':
                                line.orderItem?.selectedVariant ??
                                sourceVariant,
                            'orderDate': line.orderItem == null
                                ? null
                                : _findOrderDateForOrderItem(
                                    resolvedSource,
                                    line.orderItem!,
                                  )?.toIso8601String(),
                          },
                        )
                        .toList(),
                  );

                  resolvedTarget.orderList.add(transferOrder);
                  if (widget.onCreateTransferOrder != null) {
                    widget.onCreateTransferOrder!(transferOrder);
                  } else {
                    final orders = _hiveService.getOrders();
                    orders.add(transferOrder);
                    await _hiveService.saveOrders(orders);
                  }

                  widget.inventoryItem.inventoryCount =
                      resolvedSource.inventoryCount;
                  widget.inventoryItem.variantStock = Map<String, int>.from(
                    resolvedSource.variantStock,
                  );

                  setState(() {
                    _inventoryCountController.text = resolvedSource
                        .inventoryCount
                        .toString();

                    if (resolvedSource.hasVariants) {
                      for (final variant in _variantValues) {
                        final controller = _variantStockControllers[variant];
                        if (controller == null) {
                          continue;
                        }
                        controller.text =
                            (resolvedSource.variantStock[variant] ?? 0)
                                .toString();
                      }
                    }
                  });

                  widget.onUpdateInventory(resolvedSource);
                  widget.onUpdateInventory(resolvedTarget);
                  if (!dialogContext.mounted) {
                    return;
                  }
                  Navigator.pop(dialogContext);
                },
                child: const Text('Convert'),
              ),
            ],
          );
        },
      ),
    );

    quantityController.dispose();
    unitPriceController.dispose();
  }

  Widget _emptyHistoryMessage(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
      ),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(
            color: Color(0xFF99A3AC),
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryDropdown({required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          collapsedIconColor: const Color(0xFF99A3AC),
          iconColor: const Color(0xFF3498DB),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          children: [child],
        ),
      ),
    );
  }

  String _extractOrderVariants(List<InventoryOrderItem> matchingOrderItems) {
    final variants =
        matchingOrderItems
            .map((item) => item.selectedVariant?.trim())
            .whereType<String>()
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    if (variants.isEmpty) {
      if (widget.inventoryItem.hasVariants &&
          widget.inventoryItem.variantValues.length == 1) {
        final onlyVariant = widget.inventoryItem.variantValues.first.trim();
        if (onlyVariant.isNotEmpty) {
          return onlyVariant;
        }
      }
      return 'N/A';
    }

    return variants.join(', ');
  }

  String _extractSaleVariants(Sale sale) {
    final variants = <String>{};

    for (final line in sale.priceBreakdown) {
      final fromOrderItem = line.orderItem?.selectedVariant?.trim();
      if (fromOrderItem != null && fromOrderItem.isNotEmpty) {
        variants.add(fromOrderItem);
        continue;
      }

      final fromSource = _extractVariantFromSource(line.source);
      if (fromSource != null) {
        variants.add(fromSource);
      }
    }

    if (variants.isEmpty) {
      if (widget.inventoryItem.hasVariants &&
          widget.inventoryItem.variantValues.length == 1) {
        final onlyVariant = widget.inventoryItem.variantValues.first.trim();
        if (onlyVariant.isNotEmpty) {
          return onlyVariant;
        }
      }
      return 'N/A';
    }

    final sorted = variants.toList()..sort();
    return sorted.join(', ');
  }

  bool _hasUnknownSaleVariant(Sale sale) {
    if (!widget.inventoryItem.hasVariants) {
      return false;
    }

    if (widget.inventoryItem.variantValues.length <= 1) {
      return false;
    }

    return _extractSaleVariants(sale) == 'N/A';
  }

  String? _singleVariantFromSale(Sale sale) {
    final variantsText = _extractSaleVariants(sale);
    if (variantsText == 'N/A' || variantsText.contains(',')) {
      return null;
    }
    return variantsText.trim();
  }

  String _extractVariantFromSaleLine(SaleLineItem line) {
    final fromOrderItem = line.orderItem?.selectedVariant?.trim();
    if (fromOrderItem != null && fromOrderItem.isNotEmpty) {
      return fromOrderItem;
    }

    final fromSource = _extractVariantFromSource(line.source);
    if (fromSource != null) {
      return fromSource;
    }

    return 'N/A';
  }

  String? _extractVariantFromSource(String source) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final variantLabelMatch = RegExp(
      r'variant\s*:\s*(.+)$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (variantLabelMatch != null) {
      final parsed = variantLabelMatch.group(1)?.trim();
      if (parsed != null &&
          parsed.isNotEmpty &&
          parsed.toUpperCase() != 'N/A') {
        return parsed;
      }
    }

    final parenMatch = RegExp(r'\(([^()]+)\)\s*$').firstMatch(trimmed);
    if (parenMatch != null) {
      final parsed = parenMatch.group(1)?.trim();
      if (parsed != null &&
          parsed.isNotEmpty &&
          parsed.toUpperCase() != 'N/A') {
        return parsed;
      }
    }

    final datedOrderMatch = RegExp(
      r'^order\s*-\s*\d{4}-\d{2}-\d{2}\s*-\s*(.+)$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (datedOrderMatch != null) {
      final parsed = datedOrderMatch.group(1)?.trim();
      if (parsed != null &&
          parsed.isNotEmpty &&
          parsed.toUpperCase() != 'N/A') {
        return parsed;
      }
    }

    final editedSaleMatch = RegExp(
      r'^edited\s+sale\s*-\s*(.+)$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (editedSaleMatch != null) {
      final parsed = editedSaleMatch.group(1)?.trim();
      if (parsed != null &&
          parsed.isNotEmpty &&
          parsed.toUpperCase() != 'N/A') {
        return parsed;
      }
    }

    return null;
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType inputType = TextInputType.text,
    bool isPrice = false,
    bool allowEmpty = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: inputType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF3498DB)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF3498DB), width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: (value) {
        if ((value == null || value.trim().isEmpty) && !allowEmpty) {
          return 'Please enter $label';
        }
        if (isPrice &&
            value != null &&
            value.trim().isNotEmpty &&
            double.tryParse(value) == null) {
          return 'Please enter a valid price';
        }
        return null;
      },
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
                  Icons.folder_outlined,
                  color: Color(0xFF3498DB),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: Color(0xFFE0E0E0),
                    width: 2,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: Color(0xFFE0E0E0),
                    width: 2,
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
              ),
              onChanged: (value) {
                _folderController.text = value;
              },
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter Folder';
                }
                return null;
              },
            );
          },
    );
  }
}
