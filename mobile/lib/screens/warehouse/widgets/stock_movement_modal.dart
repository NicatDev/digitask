import 'package:flutter/material.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/models/product.dart';

class StockMovementModal extends StatefulWidget {
  final Product product;
  final VoidCallback onSuccess;

  const StockMovementModal({super.key, required this.product, required this.onSuccess});

  @override
  State<StockMovementModal> createState() => _StockMovementModalState();
}

class _StockMovementModalState extends State<StockMovementModal> {
  final _formKey = GlobalKey<FormState>();
  String _movementType = 'in';
  int? _warehouseId;
  int? _toWarehouseId;
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _returnedByController = TextEditingController();
  
  List<dynamic> _warehouses = [];
  bool _isLoading = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchWarehouses();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _referenceController.dispose();
    _reasonController.dispose();
    _returnedByController.dispose();
    super.dispose();
  }

  Future<void> _fetchWarehouses() async {
    setState(() => _isLoading = true);
    try {
      // Fetch all active warehouses for selection
      final response = await ApiClient().dio.get('/warehouse/warehouses/', queryParameters: {'is_active': true, 'page_size': 100});
      if (response.statusCode == 200) {
        setState(() {
          final data = response.data;
          if (data is Map && data.containsKey('results')) {
            _warehouses = data['results'];
          } else if (data is List) {
            _warehouses = data;
          }
        });
      }
    } catch (e) {
      // ignore
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_warehouseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a warehouse')));
      return;
    }
    if (_movementType == 'transfer' && _toWarehouseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a target warehouse')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final data = {
        'product_id': widget.product.id,
        'warehouse_id': _warehouseId,
        'movement_type': _movementType,
        'quantity': double.parse(_quantityController.text),
        'reference_no': _referenceController.text.trim(),
        'reason': _reasonController.text.trim(),
      };

      if (_movementType == 'transfer') {
        data['to_warehouse_id'] = _toWarehouseId;
      }
      if (_movementType == 'return') {
        data['returned_by'] = _returnedByController.text.trim();
      }

      final response = await ApiClient().dio.post('/warehouse/movements/adjust/', data: data);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          Navigator.pop(context);
          widget.onSuccess();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Operation successful')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Operation failed')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Stock Operation: ${widget.product.name}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 20),
              
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else ...[
                DropdownButtonFormField<String>(
                  value: _movementType,
                  decoration: InputDecoration(labelText: 'Type *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  items: const [
                    DropdownMenuItem(value: 'in', child: Text('Import (In)')),
                    DropdownMenuItem(value: 'out', child: Text('Export (Out)')),
                    DropdownMenuItem(value: 'transfer', child: Text('Transfer')),
                    DropdownMenuItem(value: 'return', child: Text('Return')),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _movementType = val!;
                      _toWarehouseId = null;
                      _returnedByController.clear();
                    });
                  },
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<int>(
                  value: _warehouseId,
                  decoration: InputDecoration(labelText: _movementType == 'transfer' ? 'Source Warehouse *' : 'Warehouse *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  items: _warehouses.map((w) => DropdownMenuItem<int>(value: w['id'], child: Text(w['name']))).toList(),
                  onChanged: (val) => setState(() => _warehouseId = val),
                 validator: (val) => val == null ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                if (_movementType == 'transfer') ...[
                  DropdownButtonFormField<int>(
                    value: _toWarehouseId,
                    decoration: InputDecoration(labelText: 'Target Warehouse *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    items: _warehouses.where((w) => w['id'] != _warehouseId).map((w) => DropdownMenuItem<int>(value: w['id'], child: Text(w['name']))).toList(),
                    onChanged: (val) => setState(() => _toWarehouseId = val),
                    validator: (val) => val == null ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                ],

                if (_movementType == 'return') ...[
                  TextFormField(
                    controller: _returnedByController,
                    decoration: InputDecoration(labelText: 'Returned By', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                  const SizedBox(height: 16),
                ],

                TextFormField(
                  controller: _quantityController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'Quantity * (${widget.product.unit})', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Required';
                    if (double.tryParse(val) == null) return 'Invalid number';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _referenceController,
                  decoration: InputDecoration(labelText: 'Reference / Document No', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _reasonController,
                  maxLines: 2,
                  decoration: InputDecoration(labelText: 'Reason / Note', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: _isSubmitting 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                      : const Text('Submit Operation', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
