import 'package:flutter/material.dart';

class WarehouseCard extends StatelessWidget {
  final Map<String, dynamic> warehouse;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onLocation;

  const WarehouseCard({super.key, required this.warehouse, this.onEdit, this.onDelete, this.onLocation});

  @override
  Widget build(BuildContext context) {
    final bool isActive = warehouse['is_active'] ?? false;
    final bool hasLocation = onLocation != null;

    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
                        child: Text('#${warehouse['id']}', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(warehouse['name'] ?? 'Adsız', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: isActive ? Colors.green.shade50 : Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
                  child: Text(isActive ? 'Aktiv' : 'Deaktiv', style: TextStyle(color: isActive ? Colors.green.shade700 : Colors.red.shade700, fontWeight: FontWeight.w500, fontSize: 12)),
                ),
              ],
            ),
            const Divider(height: 24),
            
            // Info Rows
            _buildInfoRow(Icons.location_city, 'Region', warehouse['region_name'] ?? '-'),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.place, 'Ünvan', warehouse['address']?.isNotEmpty == true ? warehouse['address'] : '-'),
            if (warehouse['note']?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              _buildInfoRow(Icons.notes, 'Qeyd', warehouse['note']),
            ],
            
            const Divider(height: 24),
            
            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(Icons.location_on, color: hasLocation ? Colors.blue : Colors.grey.shade300),
                  onPressed: onLocation,
                  tooltip: 'Məkana bax',
                ),
                IconButton(
                  icon: Icon(Icons.edit, color: onEdit != null ? Colors.orange : Colors.grey),
                  onPressed: onEdit,
                  tooltip: 'Redaktə',
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: onDelete != null ? Colors.red : Colors.grey),
                  onPressed: onDelete,
                  tooltip: 'Sil',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text(value, style: const TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }
}
