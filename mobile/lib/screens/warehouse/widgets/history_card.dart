import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HistoryCard extends StatelessWidget {
  final Map<String, dynamic> movement;
  final VoidCallback onFileClick;

  const HistoryCard({
    super.key,
    required this.movement,
    required this.onFileClick,
  });

  Color _getTypeColor(String type) {
    switch (type) {
      case 'in': return Colors.green;
      case 'out': return Colors.red;
      case 'transfer': return Colors.blue;
      case 'adjust': return Colors.orange;
      case 'return': return Colors.purple;
      default: return Colors.grey;
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'in': return 'Giriş';
      case 'out': return 'Çıxış';
      case 'transfer': return 'Transfer';
      case 'adjust': return 'Korreksiya';
      case 'return': return 'Qaytarma';
      default: return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = movement['movement_type'] ?? '';
    final date = movement['created_at'] != null 
        ? DateFormat('dd.MM.yyyy HH:mm').format(DateTime.parse(movement['created_at']))
        : '-';
    final qtyOld = double.tryParse(movement['quantity_old']?.toString() ?? '0') ?? 0.0;
    final qtyNew = double.tryParse(movement['quantity_new']?.toString() ?? '0') ?? 0.0;
    final delta = qtyNew - qtyOld;
    
    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(date, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getTypeColor(type).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _getTypeColor(type)),
                  ),
                  child: Text(
                    _getTypeLabel(type),
                    style: TextStyle(color: _getTypeColor(type), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              movement['product_name'] ?? 'Unknown Product',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.warehouse, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    movement['warehouse_name'] ?? '-',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (movement['movement_type'] == 'transfer' && movement['to_warehouse_name'] != null)
               Padding(
                 padding: const EdgeInsets.only(top: 4.0),
                 child: Row(
                  children: [
                    const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        movement['to_warehouse_name'] ?? '-',
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                               ),
               ),

            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(movement['created_by_name'] ?? '-', style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                    if (movement['reference_no'] != null && movement['reference_no'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Ref: ${movement['reference_no']}',
                          style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
                        ),
                      ),
                  ],
                ),
                Row(
                  children: [
                    // Qty Delta
                    Text(
                      '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: delta > 0 ? Colors.green : (delta < 0 ? Colors.red : Colors.black),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.attach_file, color: Colors.blue),
                      onPressed: onFileClick,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ],
            ),
            if (movement['reason'] != null && movement['reason'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  movement['reason'],
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
