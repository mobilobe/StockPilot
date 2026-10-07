import 'package:flutter/material.dart';
import 'package:inventory/services/hive_data.dart';
import 'package:inventory/models/inventory_item.dart';

/// Collects a new item's details and returns the model to the catalog owner
class AddInventoryPage extends StatefulWidget {
  final Function(InventoryItem) onAddInventory;
  final String? initialFolder;

  const AddInventoryPage({
    required this.onAddInventory,
    this.initialFolder,
    super.key,
  });

  @override
  State<AddInventoryPage> createState() => _AddInventoryPageState();
}

/// Owns form controllers and variant entries for a new item.
class _AddInventoryPageState extends State<AddInventoryPage> {
  final HiveService _hiveService = HiveService();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _skuController = TextEditingController();
  final TextEditingController _folderController = TextEditingController();
  final TextEditingController _inventoryCountController =
      TextEditingController();
  final TextEditingController _soldCountController = TextEditingController();
  final TextEditingController _variantValueController = TextEditingController();
  List<String> _existingFolders = [];
  bool _hasVariants = false;
  final List<String> _variantValues = <String>[];
  final Map<String, TextEditingController> _variantStockControllers =
      <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    _folderController.text = widget.initialFolder ?? '';
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

      final price = double.parse(_priceController.text);
      final itemId = _hiveService.generateUniqueInventoryItemId();

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

      // Variant stock is the source of truth for total stock when variants exist.
      final inventoryCount = _hasVariants
          ? variantStock.values.fold<int>(0, (sum, value) => sum + value)
          : int.tryParse(_inventoryCountController.text.trim()) ?? 0;

      final soldCount = _hasVariants
          ? 0
          : int.tryParse(_soldCountController.text.trim()) ?? 0;

      final newItem = InventoryItem(
        _nameController.text,
        price,
        inventoryCount,
        soldCount,
        _skuController.text,
        itemId,
        [],
        [],
        _folderController.text.trim().isEmpty
            ? 'Uncategorized'
            : _folderController.text.trim(),
        hasVariants: _hasVariants,
        variantValues: _hasVariants ? List<String>.from(_variantValues) : [],
        variantStock: _hasVariants ? variantStock : <String, int>{},
      );

      widget.onAddInventory(newItem);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF2C3E50),
        title: const Text(
          'Add New Item',
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
                      'Item Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildTextField(_nameController, 'Item Name', Icons.label),
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
                                (value) => Chip(
                                  label: Text(value),
                                  onDeleted: () => _removeVariantValue(value),
                                ),
                              )
                              .toList(),
                        ),
                    ],
                    const SizedBox(height: 24),
                    const Text(
                      'Initial Inventory',
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
                                padding: const EdgeInsets.only(bottom: 12),
                                child: TextFormField(
                                  controller: _variantStockControllers[variant],
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Stock for $variant',
                                    prefixIcon: const Icon(
                                      Icons.inventory_2,
                                      color: Color(0xFF3498DB),
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (_hasVariants) {
                                      final parsed = int.tryParse(value ?? '');
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
                              backgroundColor: const Color(0xFF3498DB),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text(
                              'Add Item',
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
            );
          },
    );
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
}
