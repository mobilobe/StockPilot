import 'package:flutter/material.dart';
import 'package:inventory/features/inventory/screens/edit_inventory_page.dart';
import 'package:inventory/models/inventory_item.dart';
import 'package:inventory/models/order.dart';

/// Adds sell and edit actions to the inventory item's summary row.
class InventoryManageTile extends StatelessWidget {
  final InventoryItem item;
  final List<InventoryItem> allInventoryItems;
  final List<Order> allOrders;
  final Function(InventoryItem) onSellItem;
  final Function(InventoryItem) onUpdateInventory;
  final Function(InventoryItem) onDeleteInventory;
  final Function(Order)? onCreateTransferOrder;

  const InventoryManageTile({
    required this.item,
    required this.allInventoryItems,
    required this.allOrders,
    required this.onSellItem,
    required this.onUpdateInventory,
    required this.onDeleteInventory,
    this.onCreateTransferOrder,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compactSellButton = constraints.maxWidth < 340;

        Widget sellButton() {
          return Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2DBF6A), Color(0xFF28B463)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onSellItem(item),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: compactSellButton
                      ? const EdgeInsets.all(10)
                      : const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.shopping_cart,
                        color: Colors.white,
                        size: 18,
                      ),
                      if (!compactSellButton) ...[
                        const SizedBox(width: 8),
                        const Text(
                          'Sell',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditInventoryPage(
                        inventoryItem: item,
                        allInventoryItems: allInventoryItems,
                        allOrders: allOrders,
                        onUpdateInventory: onUpdateInventory,
                        onDeleteInventory: onDeleteInventory,
                        onCreateTransferOrder: onCreateTransferOrder,
                      ),
                    ),
                  );
                },
                child: Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF2C3E50),
                    decoration: TextDecoration.underline,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 64,
              child: Column(
                children: [
                  Text(
                    '${item.inventoryCount}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Color(0xFF3498DB),
                    ),
                  ),
                  Text(
                    'In Stock',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 52,
              child: Column(
                children: [
                  Text(
                    '${item.soldCount}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Color(0xFFE74C3C),
                    ),
                  ),
                  Text(
                    'Sold',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            sellButton(),
          ],
        );
      },
    );
  }
}
