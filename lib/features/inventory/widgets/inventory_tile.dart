import 'package:flutter/material.dart';
import 'package:inventory/features/inventory/widgets/inventory_information_tile.dart';
import 'package:inventory/features/inventory/widgets/inventory_manage_tile.dart';
import 'package:inventory/models/inventory_item.dart';
import 'package:inventory/models/order.dart';

/// Animates an item card and selects its read-only or management presentation
class InventoryTile extends StatefulWidget {
  final InventoryItem inventoryItem;
  final bool isInformationMode;
  final Function(InventoryItem) onSellItem;
  final Function(InventoryItem) onUpdateInventory;
  final Function(InventoryItem) onDeleteInventory;
  final Function(Order)? onCreateTransferOrder;
  final List<InventoryItem> allInventoryItems;
  final List<Order> allOrders;

  const InventoryTile({
    required this.inventoryItem,
    required this.isInformationMode,
    required this.onSellItem,
    required this.onUpdateInventory,
    required this.onDeleteInventory,
    required this.allInventoryItems,
    required this.allOrders,
    this.onCreateTransferOrder,
    super.key,
  });

  @override
  State<InventoryTile> createState() => _InventoryTileState();
}

class _InventoryTileState extends State<InventoryTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    if (_isExpanded) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.grey[50]!],
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: GestureDetector(
                onTap: _toggleExpanded,
                // Switch between information view and management view
                child: widget.isInformationMode
                    ? InventoryInformationTile(
                        item: widget.inventoryItem,
                        allInventoryItems: widget.allInventoryItems,
                        allOrders: widget.allOrders,
                        onUpdateInventory: widget.onUpdateInventory,
                        onDeleteInventory: widget.onDeleteInventory,
                        onCreateTransferOrder: widget.onCreateTransferOrder,
                      )
                    : InventoryManageTile(
                        item: widget.inventoryItem,
                        allInventoryItems: widget.allInventoryItems,
                        allOrders: widget.allOrders,
                        onSellItem: widget.onSellItem,
                        onUpdateInventory: widget.onUpdateInventory,
                        onDeleteInventory: widget.onDeleteInventory,
                        onCreateTransferOrder: widget.onCreateTransferOrder,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
