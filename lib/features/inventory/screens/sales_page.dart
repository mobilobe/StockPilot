import 'package:flutter/material.dart';
import 'package:inventory/models/inventory_item.dart';
import 'package:inventory/models/sale.dart';
import 'package:inventory/models/sale_line_item.dart';

/// Lists sale records and lets users correct or remove a recorded transaction.
class SalesPage extends StatefulWidget {
  final List<InventoryItem> inventoryList;
  final VoidCallback onDataChanged;

  const SalesPage({
    required this.inventoryList,
    required this.onDataChanged,
    super.key,
  });

  @override
  State<SalesPage> createState() => _SalesPageState();
}

/// Filters sale records and applies edits back to their owning inventory item.
class _SalesPageState extends State<SalesPage> {
  String _searchQuery = '';

  InputDecoration _saleFieldDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      prefixIcon: Icon(icon, size: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF3498DB), width: 1.5),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }

  List<_SalesRecord> _allSalesRecords() {
    final records = <_SalesRecord>[];

    for (final item in widget.inventoryList) {
      for (final sale in item.salesList) {
        records.add(_SalesRecord(item: item, sale: sale));
      }
    }

    records.sort((a, b) => b.sale.date.compareTo(a.sale.date));
    return records;
  }

  List<_SalesRecord> _filteredSalesRecords() {
    final records = _allSalesRecords();
    final normalizedQuery = _searchQuery.trim().toLowerCase();

    if (normalizedQuery.isEmpty) {
      return records;
    }

    return records.where((record) {
      final formattedDate = _formatDate(record.sale.date);
      return record.item.name.toLowerCase().contains(normalizedQuery) ||
          record.item.sku.toLowerCase().contains(normalizedQuery) ||
          formattedDate.contains(normalizedQuery);
    }).toList();
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _extractSaleVariants(InventoryItem item, Sale sale) {
    // Older/imported sales may only encode the variant in their source text.
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
      if (item.hasVariants && item.variantValues.length == 1) {
        final onlyVariant = item.variantValues.first.trim();
        if (onlyVariant.isNotEmpty) {
          return onlyVariant;
        }
      }
      return 'N/A';
    }

    final sorted = variants.toList()..sort();
    return sorted.join(', ');
  }

  String? _singleVariantFromSale(InventoryItem item, Sale sale) {
    final variantsText = _extractSaleVariants(item, sale);
    if (variantsText == 'N/A' || variantsText.contains(',')) {
      return null;
    }
    return variantsText.trim();
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
      r'^edited\s+sale\s*[-:]\s*(.+)$',
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

  Future<void> _showEditSaleDialog(_SalesRecord record) async {
    final item = record.item;
    final sale = record.sale;
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
    String? selectedVariant = _singleVariantFromSale(item, sale);

    if (item.hasVariants &&
        selectedVariant == null &&
        item.variantValues.length == 1) {
      selectedVariant = item.variantValues.first;
    }

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

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Edit Sale'),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sale Details',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => pickDate(dialogContext, setDialogState),
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(_formatDate(selectedDate)),
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      side: const BorderSide(
                        color: Color(0xFFE0E0E0),
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      foregroundColor: const Color(0xFF2C3E50),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  decoration: _saleFieldDecoration(
                    'Quantity',
                    Icons.inventory_2,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: revenueController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _saleFieldDecoration(
                    'Revenue',
                    Icons.attach_money,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: profitController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _saleFieldDecoration('Profit', Icons.trending_up),
                ),
                if (item.hasVariants) ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedVariant,
                    decoration: _saleFieldDecoration(
                      'Variant',
                      Icons.category_outlined,
                    ),
                    items: item.variantValues
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
            SizedBox(
              width: double.infinity,
              child: Row(
                children: [
                  TextButton(
                    onPressed: () async {
                      final shouldDelete = await showDialog<bool>(
                        context: dialogContext,
                        builder: (confirmContext) => AlertDialog(
                          title: const Text('Delete Sale'),
                          content: const Text(
                            'Are you sure you want to delete this sale?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(confirmContext, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () =>
                                  Navigator.pop(confirmContext, true),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFE74C3C),
                              ),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );

                      if (shouldDelete != true) {
                        return;
                      }

                      final oldVariant = _singleVariantFromSale(item, sale);

                      setState(() {
                        item.salesList.remove(sale);

                        item.soldCount -= oldQuantity;
                        if (item.soldCount < 0) {
                          item.soldCount = 0;
                        }

                        item.inventoryCount += oldQuantity;

                        if (item.hasVariants && oldVariant != null) {
                          final current = item.variantStock[oldVariant] ?? 0;
                          item.variantStock[oldVariant] = current + oldQuantity;
                        }
                      });

                      if (!dialogContext.mounted) {
                        return;
                      }
                      widget.onDataChanged();
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
                  const Spacer(),
                  FilledButton(
                    onPressed: () {
                      final newQuantity = int.tryParse(
                        quantityController.text.trim(),
                      );
                      final newRevenue = double.tryParse(
                        revenueController.text.trim(),
                      );
                      final newProfit = double.tryParse(
                        profitController.text.trim(),
                      );

                      if (newQuantity == null || newQuantity <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Enter a valid quantity greater than 0',
                            ),
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

                      if (item.hasVariants && selectedVariant == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Select a variant'),
                            backgroundColor: Color(0xFFE74C3C),
                          ),
                        );
                        return;
                      }

                      final oldVariant = _singleVariantFromSale(item, sale);
                      // Only the change in quantity affects aggregate stock counts.
                      final quantityDelta = newQuantity - oldQuantity;

                      if (quantityDelta > 0) {
                        if (item.hasVariants) {
                          final targetVariant = selectedVariant!;
                          final currentTargetStock =
                              item.variantStock[targetVariant] ?? 0;
                          final availableAfterRollback =
                              targetVariant == oldVariant
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
                          if (item.inventoryCount < quantityDelta) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Not enough stock for this quantity',
                                ),
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
                          (item.hasVariants && selectedVariant != oldVariant);

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
                          item.soldCount += quantityDelta;
                          item.inventoryCount -= quantityDelta;
                        }

                        if (item.hasVariants) {
                          final targetVariant = selectedVariant!;

                          if (oldVariant != null) {
                            // Restore the old variant's stock in full, then
                            // deduct the new quantity from the target variant.
                            item.variantStock[oldVariant] =
                                (item.variantStock[oldVariant] ?? 0) +
                                oldQuantity;
                            item.variantStock[targetVariant] =
                                (item.variantStock[targetVariant] ?? 0) -
                                newQuantity;
                          } else if (quantityDelta != 0) {
                            // Old variant is unknown (e.g. imported sale).
                            // Only adjust by the quantity delta to avoid
                            // double-deducting stock that was already taken
                            // when the original sale was recorded.
                            item.variantStock[targetVariant] =
                                (item.variantStock[targetVariant] ?? 0) -
                                quantityDelta;
                          }
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

                      widget.onDataChanged();
                      Navigator.pop(dialogContext);
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    quantityController.dispose();
    revenueController.dispose();
    profitController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredRecords = _filteredSalesRecords();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF2C3E50),
        title: const Text('Sales', style: TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by item name, SKU, or date',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFF3498DB),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: Color(0xFFE0E0E0),
                        width: 1,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: Color(0xFFE0E0E0),
                        width: 1,
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
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${filteredRecords.length} sales',
                    style: const TextStyle(
                      color: Color(0xFF99A3AC),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: filteredRecords.isEmpty
                      ? Center(
                          child: Text(
                            _searchQuery.trim().isEmpty
                                ? 'No sales found'
                                : 'No sales match your search',
                            style: const TextStyle(
                              color: Color(0xFF99A3AC),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: filteredRecords.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final record = filteredRecords[index];
                            final sale = record.sale;
                            final item = record.item;
                            final saleVariants = _extractSaleVariants(
                              item,
                              sale,
                            );
                            final variantLabel = saleVariants == 'N/A'
                                ? 'Unknown'
                                : saleVariants;

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFFE0E0E0),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.name,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF2C3E50),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(left: 4),
                                        child: IconButton(
                                          onPressed: () =>
                                              _showEditSaleDialog(record),
                                          icon: const Icon(
                                            Icons.edit_outlined,
                                            size: 16,
                                          ),
                                          tooltip: 'Edit Sale',
                                          color: const Color(0xFF99A3AC),
                                          visualDensity: VisualDensity.compact,
                                          constraints: const BoxConstraints(
                                            minWidth: 28,
                                            minHeight: 28,
                                          ),
                                          padding: EdgeInsets.zero,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    'SKU: ${item.sku}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF99A3AC),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Date: ${_formatDate(sale.date)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF66717A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.hasVariants
                                        ? 'Qty: ${sale.quantity} • Variant: $variantLabel • Revenue: \$${sale.price.toStringAsFixed(2)} • Profit: \$${sale.profit.toStringAsFixed(2)}'
                                        : 'Qty: ${sale.quantity} • Revenue: \$${sale.price.toStringAsFixed(2)} • Profit: \$${sale.profit.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF66717A),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Keeps a sale paired with its owning item for edits and variant lookups.
class _SalesRecord {
  final InventoryItem item;
  final Sale sale;

  const _SalesRecord({required this.item, required this.sale});
}
