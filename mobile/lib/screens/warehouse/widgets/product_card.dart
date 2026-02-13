import 'package:flutter/material.dart';
import 'package:mobile/models/product.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onStockAction;
  final VoidCallback onInventoryClick;

  const ProductCard({
    super.key,
    required this.product,
    required this.onEdit,
    required this.onDelete,
    required this.onStockAction,
    required this.onInventoryClick,
  });

  @override
  Widget build(BuildContext context) {
    Color stockColor = Colors.green;
    String stockStatus = 'Normal';

    if (product.minQuantity != null && product.totalStock < product.minQuantity!) {
      stockColor = Colors.orange;
      stockStatus = 'Low Stock';
    } else if (product.maxQuantity != null && product.totalStock > product.maxQuantity!) {
      stockColor = Colors.orange; // Using orange for overstock as per requirement (or red if preferred, sticking to orange/yellow)
      stockStatus = 'Over Stock';
    }

    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      if (product.brand != null || product.model != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${product.brand ?? ''} ${product.model ?? ''}'.trim(),
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                        ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: onInventoryClick,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: stockColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: stockColor.withOpacity(0.5)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          product.totalStock.toStringAsFixed(2),
                          style: TextStyle(color: stockColor, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          product.unit,
                          style: TextStyle(color: stockColor, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Details
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                if (product.serialNumber?.isNotEmpty == true)
                  _buildDetailItem(Icons.qr_code, 'SN:', product.serialNumber!),
                if (product.price != null)
                  _buildDetailItem(Icons.attach_money, 'Price:', '${product.price!.toStringAsFixed(2)} ₼'),
                if (product.size?.isNotEmpty == true)
                  _buildDetailItem(Icons.aspect_ratio, 'Size:', product.size!),
                if (product.weight?.isNotEmpty == true)
                  _buildDetailItem(Icons.scale, 'Weight:', product.weight!),
                if (product.portCount != null)
                  _buildDetailItem(Icons.lan, 'Ports:', product.portCount.toString()),
              ],
            ),
            
            const Divider(height: 24),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Active Status
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: product.isActive ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    product.isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      color: product.isActive ? Colors.green.shade700 : Colors.red.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: onStockAction,
                      icon: const Icon(Icons.swap_horiz, size: 18),
                      label: const Text('Stock'),
                      style: TextButton.styleFrom(foregroundColor: Colors.blue),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.orange, size: 20),
                      onPressed: onEdit,
                      tooltip: 'Edit',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                      onPressed: onDelete,
                      tooltip: 'Delete',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Text('$label ', style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
