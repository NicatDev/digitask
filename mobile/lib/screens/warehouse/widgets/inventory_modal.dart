import 'package:flutter/material.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/models/product.dart';

class InventoryModal extends StatefulWidget {
  final Product product;

  const InventoryModal({super.key, required this.product});

  @override
  State<InventoryModal> createState() => _InventoryModalState();
}

class _InventoryModalState extends State<InventoryModal> {
  List<dynamic> _inventory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchInventory();
  }

  Future<void> _fetchInventory() async {
    try {
      final response = await ApiClient().dio.get(
        '/warehouse/inventory/',
        queryParameters: {'product': widget.product.id},
      );
      if (response.statusCode == 200) {
        setState(() {
          final data = response.data;
          if (data is Map && data.containsKey('results')) {
            _inventory = data['results'];
          } else if (data is List) {
            _inventory = data;
          }
           _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Inventory: ${widget.product.name}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          const Divider(height: 0),
          SizedBox(
            height: 300,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _inventory.isEmpty
                    ? const Center(child: Text('No stock in any warehouse'))
                    : ListView.separated(
                        itemCount: _inventory.length,
                        separatorBuilder: (_, __) => const Divider(height: 0),
                        itemBuilder: (ctx, index) {
                          final item = _inventory[index];
                          final qty = double.tryParse(item['quantity'].toString()) ?? 0.0;
                          
                          // Skip 0 quantity items if preferred, but user might want to see 0 records too.
                          // Usually inventory records exist even if 0.
                          
                          return ListTile(
                            title: Text(item['warehouse_name'] ?? 'Warehouse', style: const TextStyle(fontWeight: FontWeight.w500)),
                            trailing: Text(
                              '${qty.toStringAsFixed(2)} ${widget.product.unit}',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: qty > 0 ? Colors.green : Colors.grey),
                            ),
                          );
                        },
                      ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(
                  '${widget.product.totalStock.toStringAsFixed(2)} ${widget.product.unit}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
