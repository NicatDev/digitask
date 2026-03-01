import 'package:flutter/material.dart';
import 'package:mobile/core/api/api_client.dart';

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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Xəta: $e')));
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
              const Text('Məhsullar', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(onPressed: _showAddDialog, icon: const Icon(Icons.add_circle, color: Colors.green, size: 28))
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _taskProducts.isEmpty 
                    ? const Center(child: Text('Məhsul əlavə olunmayıb.'))
                    : ListView.separated(
                        itemCount: _taskProducts.length,
                        separatorBuilder: (_,__) => const Divider(),
                        itemBuilder: (context, index) {
                          final p = _taskProducts[index];
                          final hasSerial = p['has_serial_number'] == true;
                          final serialNum = p['serial_number']?.toString() ?? '';
                          return ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: hasSerial ? Colors.blue.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8)
                              ),
                              child: Icon(
                                hasSerial ? Icons.qr_code : Icons.inventory_2,
                                color: hasSerial ? Colors.blue : Colors.green,
                              ),
                            ),
                            title: Text(p['product_name'] ?? 'Məhsul', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${p['warehouse_name']} • Miqdar: ${_formatQty(p['quantity'])} ${p['product_unit'] ?? ''}'),
                                if (hasSerial && serialNum.isNotEmpty)
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'SN: $serialNum',
                                      style: TextStyle(fontSize: 11, color: Colors.blue.shade700, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                              ],
                            ),
                            trailing: p['is_deducted'] == true
                                ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                                : IconButton(
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
  List<dynamic> _inventory = [];
  List<dynamic> _serialItems = [];
  
  bool _loadingWh = true;
  bool _loadingInv = false;
  bool _loadingSerials = false;
  bool _submitting = false;

  int? _selectedWhId;
  Map<String, dynamic>? _selectedItem;
  String? _selectedSerial;
  final _qtyCtrl = TextEditingController();

  bool get _isSerialProduct {
    if (_selectedItem == null) return false;
    return _selectedItem!['product_has_serial'] == true;
  }

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
              : (res.data is List ? res.data : []);
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
      _serialItems = [];
      _selectedSerial = null;
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

  Future<void> _fetchSerialItems(int productId, int warehouseId) async {
    setState(() {
      _loadingSerials = true;
      _serialItems = [];
      _selectedSerial = null;
    });
    try {
      final client = ApiClient().dio;
      final res = await client.get('/warehouse/serial-items/', queryParameters: {
        'product': productId,
        'warehouse': warehouseId,
        'page_size': 200,
      });
      if (mounted) {
        setState(() {
          final data = res.data;
          _serialItems = (data is Map && data.containsKey('results')) ? data['results'] : (data is List ? data : []);
          _loadingSerials = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingSerials = false);
    }
  }

  Future<void> _save() async {
    if (_selectedWhId == null || _selectedItem == null) return;

    if (_isSerialProduct) {
      // Serial product: need serial number
      if (_selectedSerial == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Serial nömrə seçin')));
        return;
      }
    } else {
      // Normal product: need quantity
      final qty = double.tryParse(_qtyCtrl.text);
      if (qty == null || qty <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Düzgün miqdar daxil edin')));
        return;
      }
      final maxQty = double.tryParse(_selectedItem!['quantity'].toString()) ?? 0;
      if (qty > maxQty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Maksimum miqdar: $maxQty')));
        return;
      }
    }

    setState(() => _submitting = true);
    try {
      final client = ApiClient().dio;
      final productData = <String, dynamic>{
        'product_id': _selectedItem!['product'],
        'warehouse_id': _selectedWhId,
      };

      if (_isSerialProduct) {
        productData['quantity'] = 1;
        productData['serial_number'] = _selectedSerial;
      } else {
        productData['quantity'] = double.parse(_qtyCtrl.text);
      }

      await client.post('/tasks/task-products/bulk-create/', data: {
        'task_id': widget.taskId,
        'products': [productData],
      });
      widget.onSuccess();
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Xəta: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingWh) return const Center(child: CircularProgressIndicator());

    return AlertDialog(
      title: const Text('Məhsul Əlavə Et'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Warehouse Dropdown
            DropdownButtonFormField<int>(
              decoration: const InputDecoration(labelText: 'Anbar', border: OutlineInputBorder()),
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
                    decoration: const InputDecoration(labelText: 'Məhsul', border: OutlineInputBorder()),
                    isExpanded: true,
                    items: _inventory.map((item) {
                      final name = item['product_name'] ?? 'Məhsul';
                      final qty = _formatQty(item['quantity']);
                      final unit = item['product_unit'] ?? '';
                      final hasSN = item['product_has_serial'] == true;
                      return DropdownMenuItem<Map<String, dynamic>>(
                        value: item,
                        child: Row(
                          children: [
                            if (hasSN) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(3)),
                                child: const Text('SN', style: TextStyle(fontSize: 9, color: Colors.blue, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 4),
                            ],
                            Expanded(child: Text('$name ($qty $unit)', overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedItem = val;
                        _selectedSerial = null;
                        _serialItems = [];
                      });
                      if (val != null && val['product_has_serial'] == true) {
                        _fetchSerialItems(val['product'], _selectedWhId!);
                      }
                    },
                  ),
            
            const SizedBox(height: 16),
            
            // Serial number selection for serial products
            if (_selectedItem != null && _isSerialProduct) ...[
              _loadingSerials
                  ? const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator())
                  : DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Serial Nömrə', border: OutlineInputBorder()),
                      isExpanded: true,
                      items: _serialItems.map((s) => DropdownMenuItem<String>(
                        value: s['serial_number'],
                        child: Text(s['serial_number'] ?? '', overflow: TextOverflow.ellipsis),
                      )).toList(),
                      onChanged: (val) => setState(() => _selectedSerial = val),
                    ),
            ],

            // Quantity Input for non-serial products
            if (_selectedItem != null && !_isSerialProduct)
              TextFormField(
                controller: _qtyCtrl,
                decoration: InputDecoration(
                  labelText: 'Miqdar (Max: ${_formatQty(_selectedItem!['quantity'])})', 
                  border: const OutlineInputBorder()
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Ləğv et')),
        ElevatedButton(
          onPressed: _submitting ? null : _save, 
          child: _submitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Əlavə Et')
        ),
      ],
    );
  }
}
