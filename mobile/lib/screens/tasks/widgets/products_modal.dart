import 'package:flutter/material.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:dio/dio.dart' as dio;

String _formatQty(dynamic val) {
  if (val == null) return '0';
  final num v = val is num ? val : double.tryParse(val.toString()) ?? 0;
  if (v % 1 == 0) return v.toInt().toString();
  return v.toString();
}

class ProductsModal extends StatefulWidget {
  final Map<String, dynamic> task;
  final VoidCallback onSuccess;

  const ProductsModal({super.key, required this.task, required this.onSuccess});

  @override
  State<ProductsModal> createState() => _ProductsModalState();
}

class _ProductsModalState extends State<ProductsModal> {
  List<dynamic> _taskProducts = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _refreshList();
  }

  Future<void> _refreshList() async {
    setState(() => _isLoading = true);
    try {
      final client = ApiClient().dio;
      final res = await client.get('/tasks/tasks/${widget.task['id']}/');
      if (mounted) {
        setState(() {
          _taskProducts = res.data['task_products'] ?? [];
          _isLoading = false;
        });
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteProduct(int id) async {
    try {
      final client = ApiClient().dio;
      await client.delete('/tasks/task-products/$id/');
      await _refreshList();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (_) => _AddProductDialog(
        taskId: widget.task['id'],
        onSuccess: () {
          Navigator.pop(context);
          _refreshList();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 40, height: 4, 
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              margin: const EdgeInsets.only(bottom: 20),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Products', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(onPressed: _showAddDialog, icon: const Icon(Icons.add_circle, color: Colors.green, size: 28))
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _taskProducts.isEmpty 
                    ? const Center(child: Text('No products added.'))
                    : ListView.separated(
                        itemCount: _taskProducts.length,
                        separatorBuilder: (_,__) => const Divider(),
                        itemBuilder: (context, index) {
                          final p = _taskProducts[index];
                          // p has product_name, warehouse_name, quantity, is_deducted, etc.
                          return ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8)
                              ),
                              child: const Icon(Icons.inventory_2, color: Colors.green),
                            ),
                            title: Text(p['product_name'] ?? 'Product', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${p['warehouse_name']} • Qty: ${_formatQty(p['quantity'])} ${p['product_unit'] ?? ''}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteProduct(p['id']),
                            ),
                          );
                        },
                      ),
          )
        ],
      ),
    );
  }
}

class _AddProductDialog extends StatefulWidget {
  final int taskId;
  final VoidCallback onSuccess;

  const _AddProductDialog({required this.taskId, required this.onSuccess});

  @override
  State<_AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<_AddProductDialog> {
  List<dynamic> _warehouses = [];
  List<dynamic> _inventory = []; // Items in selected warehouse
  
  bool _loadingWh = true;
  bool _loadingInv = false;
  bool _submitting = false;

  int? _selectedWhId;
  Map<String, dynamic>? _selectedItem; // The inventory item (contains product info and qty)
  final _qtyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchWarehouses();
  }

  Future<void> _fetchWarehouses() async {
    try {
      final client = ApiClient().dio;
      final res = await client.get('/warehouse/warehouses/');
      if (mounted) {
        setState(() {
          _warehouses = (res.data is Map && res.data['results'] != null) 
              ? res.data['results'] 
              : (res.data is List ? res.data : []); // Handle generic response types
          _loadingWh = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingWh = false);
    }
  }

  Future<void> _fetchInventory(int whId) async {
    setState(() {
      _loadingInv = true;
      _inventory = [];
      _selectedItem = null;
    });
    try {
      final client = ApiClient().dio;
      final res = await client.get('/warehouse/inventory/', queryParameters: {'warehouse': whId});
       if (mounted) {
        setState(() {
          _inventory = (res.data is Map && res.data['results'] != null) 
              ? res.data['results'] 
              : (res.data is List ? res.data : []);
          _loadingInv = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingInv = false);
    }
  }

  Future<void> _save() async {
    if (_selectedWhId == null || _selectedItem == null || _qtyCtrl.text.isEmpty) return;
    
    final qty = double.tryParse(_qtyCtrl.text);
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid quantity')));
      return;
    }

    final maxQty = double.tryParse(_selectedItem!['quantity'].toString()) ?? 0;
    if (qty > maxQty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Max quantity is $maxQty')));
      return;
    }

    setState(() => _submitting = true);
    try {
      final client = ApiClient().dio;
      await client.post('/tasks/task-products/', data: {
        'task': widget.taskId,
        'warehouse': _selectedWhId,
        'product': _selectedItem!['product'],
        'quantity': qty,
      });
      widget.onSuccess();
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingWh) return const Center(child: CircularProgressIndicator());

    return AlertDialog(
      title: const Text('Add Product'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Warehouse Dropdown
            DropdownButtonFormField<int>(
              decoration: const InputDecoration(labelText: 'Warehouse', border: OutlineInputBorder()),
              items: _warehouses.map((w) => DropdownMenuItem<int>(
                value: w['id'],
                child: Text(w['name'], overflow: TextOverflow.ellipsis),
              )).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedWhId = val);
                  _fetchInventory(val);
                }
              },
            ),
            const SizedBox(height: 16),
            
            // Product Dropdown (Inventory)
            if (_selectedWhId != null)
              _loadingInv 
                ? const Center(child: CircularProgressIndicator())
                : DropdownButtonFormField<Map<String, dynamic>>(
                    decoration: const InputDecoration(labelText: 'Product', border: OutlineInputBorder()),
                    isExpanded: true,
                    items: _inventory.map((item) {
                      final name = item['product_name'] ?? 'Product';
                      final qty = _formatQty(item['quantity']);
                      final unit = item['product_unit'] ?? '';
                      return DropdownMenuItem<Map<String, dynamic>>(
                        value: item,
                        child: Text('$name ($qty $unit)', overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() => _selectedItem = val);
                    },
                  ),
            
            const SizedBox(height: 16),
            
            // Quantity Input
            if (_selectedItem != null)
              TextFormField(
                controller: _qtyCtrl,
                decoration: InputDecoration(
                  labelText: 'Quantity (Max: ${_formatQty(_selectedItem!['quantity'])})', 
                  border: const OutlineInputBorder()
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _submitting ? null : _save, 
          child: _submitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Add')
        ),
      ],
    );
  }
}
