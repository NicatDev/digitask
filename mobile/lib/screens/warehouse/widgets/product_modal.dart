import 'package:flutter/material.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/models/product.dart';

class ProductModal extends StatefulWidget {
  final Product? product;
  final VoidCallback onSuccess;

  const ProductModal({super.key, this.product, required this.onSuccess});

  @override
  State<ProductModal> createState() => _ProductModalState();
}

class _ProductModalState extends State<ProductModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _brandController;
  late TextEditingController _modelController;
  late TextEditingController _serialController;
  late TextEditingController _sizeController;
  late TextEditingController _weightController;
  late TextEditingController _portCountController;
  late TextEditingController _priceController;
  late TextEditingController _minQtyController;
  late TextEditingController _maxQtyController;
  late TextEditingController _descController;
  String _unit = 'pcs';
  bool _isSubmitting = false;

  final List<Map<String, String>> _units = [
    {'value': 'pcs', 'label': 'Piece (pcs)'},
    {'value': 'kg', 'label': 'Kilogram (kg)'},
    {'value': 'g', 'label': 'Gram (g)'},
    {'value': 'l', 'label': 'Liter (l)'},
    {'value': 'm', 'label': 'Meter (m)'},
    {'value': 'box', 'label': 'Box'},
    {'value': 'set', 'label': 'Set'},
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p?.name ?? '');
    _brandController = TextEditingController(text: p?.brand ?? '');
    _modelController = TextEditingController(text: p?.model ?? '');
    _serialController = TextEditingController(text: p?.serialNumber ?? '');
    _sizeController = TextEditingController(text: p?.size ?? '');
    _weightController = TextEditingController(text: p?.weight ?? '');
    _portCountController = TextEditingController(text: p?.portCount?.toString() ?? '');
    _priceController = TextEditingController(text: p?.price?.toString() ?? '');
    _minQtyController = TextEditingController(text: p?.minQuantity?.toString() ?? '');
    _maxQtyController = TextEditingController(text: p?.maxQuantity?.toString() ?? '');
    _descController = TextEditingController(text: p?.description ?? '');
    _unit = p?.unit ?? 'pcs';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _serialController.dispose();
    _sizeController.dispose();
    _weightController.dispose();
    _portCountController.dispose();
    _priceController.dispose();
    _minQtyController.dispose();
    _maxQtyController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final Map<String, dynamic> data = {
        'name': _nameController.text.trim(),
        'unit': _unit,
        'brand': _brandController.text.trim(),
        'model': _modelController.text.trim(),
        'serial_number': _serialController.text.trim(),
        'size': _sizeController.text.trim(),
        'weight': _weightController.text.trim(),
        'description': _descController.text.trim(),
        'is_active': true,
      };

      if (_portCountController.text.isNotEmpty) data['port_count'] = int.tryParse(_portCountController.text);
      if (_priceController.text.isNotEmpty) data['price'] = double.tryParse(_priceController.text);
      if (_minQtyController.text.isNotEmpty) data['min_quantity'] = double.tryParse(_minQtyController.text);
      if (_maxQtyController.text.isNotEmpty) data['max_quantity'] = double.tryParse(_maxQtyController.text);

      final dio = ApiClient().dio;
      final response = widget.product == null
          ? await dio.post('/warehouse/products/', data: data)
          : await dio.patch('/warehouse/products/${widget.product!.id}/', data: data);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          Navigator.pop(context);
          widget.onSuccess();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.product == null ? 'Product created' : 'Product updated')));
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
                  Text(widget.product == null ? 'New Product' : 'Edit Product', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 20),
              
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Name *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                validator: (val) => val?.isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              
              DropdownButtonFormField<String>(
                value: _unit,
                decoration: InputDecoration(labelText: 'Unit *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                items: _units.map((u) => DropdownMenuItem(value: u['value'], child: Text(u['label']!))).toList(),
                onChanged: (val) => setState(() => _unit = val!),
              ),
               const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(child: TextFormField(controller: _brandController, decoration: InputDecoration(labelText: 'Brand', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(controller: _modelController, decoration: InputDecoration(labelText: 'Model', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(controller: _serialController, decoration: InputDecoration(labelText: 'Serial Number', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(child: TextFormField(controller: _sizeController, decoration: InputDecoration(labelText: 'Size', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(controller: _weightController, decoration: InputDecoration(labelText: 'Weight', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(child: TextFormField(controller: _portCountController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Ports', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(controller: _priceController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Price', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(child: TextFormField(controller: _minQtyController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Min Qty', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(controller: _maxQtyController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Max Qty', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descController,
                maxLines: 3,
                decoration: InputDecoration(labelText: 'Description', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: _isSubmitting ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(widget.product == null ? 'Create Product' : 'Update Product', style: const TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
