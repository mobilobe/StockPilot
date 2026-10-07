import 'package:flutter/material.dart';
import 'package:inventory/features/inventory/screens/edit_inventory_page.dart';
import 'package:inventory/models/inventory_item.dart';
import 'package:inventory/models/order.dart';

/// Shows item identity and counts; tapping its name opens the edit screen.
class InventoryInformationTile extends StatelessWidget {
  final InventoryItem item;
  final List<InventoryItem> allInventoryItems;
  final List<Order> allOrders;
  final Function(InventoryItem) onUpdateInventory;
  final Function(InventoryItem) onDeleteInventory;
  final Function(Order)? onCreateTransferOrder;

  const InventoryInformationTile({
    required this.item,
    required this.allInventoryItems,
    required this.allOrders,
    required this.onUpdateInventory,
    required this.onDeleteInventory,
    this.onCreateTransferOrder,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
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
              const SizedBox(height: 4),
              Text(
                'SKU: ${item.sku}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 56,
          child: Column(
            children: [
              Text(
                '${item.inventoryCount}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF3498DB),
                ),
              ),
              Text(
                'Stock',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 56,
          child: Column(
            children: [
              Text(
                '${item.soldCount}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
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
      ],
    );
  }
}
