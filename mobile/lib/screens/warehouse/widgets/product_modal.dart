import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  late TextEditingController _sizeController;
  late TextEditingController _weightController;
  late TextEditingController _portCountController;
  late TextEditingController _priceController;
  late TextEditingController _minQtyController;
  late TextEditingController _maxQtyController;
  late TextEditingController _descController;
  String _unit = 'pcs';
  bool _hasSerialNumber = false;
  int? _categoryId;
  Map<String, dynamic> _categoryDataValues = {};

  // Controllers for text-type custom fields
  final Map<String, TextEditingController> _fieldControllers = {};

  bool _isSubmitting = false;
  bool _loadingCategories = true;
  List<dynamic> _categories = [];
  List<dynamic> _categoryFields = [];

  final List<Map<String, String>> _units = [
    {'value': 'pcs', 'label': 'Ədəd (pcs)'},
    {'value': 'kg', 'label': 'Kiloqram (kg)'},
    {'value': 'g', 'label': 'Qram (g)'},
    {'value': 'l', 'label': 'Litr (l)'},
    {'value': 'm', 'label': 'Metr (m)'},
    {'value': 'box', 'label': 'Qutu'},
    {'value': 'set', 'label': 'Dəst'},
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p?.name ?? '');
    _brandController = TextEditingController(text: p?.brand ?? '');
    _modelController = TextEditingController(text: p?.model ?? '');
    _sizeController = TextEditingController(text: p?.size ?? '');
    _weightController = TextEditingController(text: p?.weight ?? '');
    _portCountController = TextEditingController(text: p?.portCount?.toString() ?? '');
    _priceController = TextEditingController(text: p?.price?.toString() ?? '');
    _minQtyController = TextEditingController(text: p?.minQuantity?.toString() ?? '');
    _maxQtyController = TextEditingController(text: p?.maxQuantity?.toString() ?? '');
    _descController = TextEditingController(text: p?.description ?? '');
    _unit = p?.unit ?? 'pcs';
    _hasSerialNumber = p?.hasSerialNumber ?? false;
    _categoryId = p?.category;
    _categoryDataValues = Map<String, dynamic>.from(p?.categoryData ?? {});
    _fetchCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _sizeController.dispose();
    _weightController.dispose();
    _portCountController.dispose();
    _priceController.dispose();
    _minQtyController.dispose();
    _maxQtyController.dispose();
    _descController.dispose();
    for (final c in _fieldControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchCategories() async {
    try {
      final res = await ApiClient().dio.get('/warehouse/categories/', queryParameters: {'page_size': 100});
      if (mounted) {
        setState(() {
          final data = res.data;
          _categories = (data is Map && data.containsKey('results')) ? data['results'] : (data is List ? data : []);
          _loadingCategories = false;
          if (_categoryId != null) {
            _loadCategoryFields(_categoryId!);
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingCategories = false);
    }
  }

  void _loadCategoryFields(int catId) {
    final cat = _categories.firstWhere((c) => c['id'] == catId, orElse: () => null);
    if (cat != null) {
      final fields = List<dynamic>.from(cat['fields_list'] ?? []);
      // Create controllers for text/number fields
      for (final f in _fieldControllers.values) {
        f.dispose();
      }
      _fieldControllers.clear();
      for (final field in fields) {
        final name = field['name'] ?? '';
        final type = field['field_type'] ?? 'string';
        if (type == 'string' || type == 'number') {
          _fieldControllers[name] = TextEditingController(
            text: _categoryDataValues[name]?.toString() ?? '',
          );
        }
      }
      setState(() {
        _categoryFields = fields;
      });
    } else {
      setState(() => _categoryFields = []);
    }
  }

  void _collectFieldValues() {
    for (final field in _categoryFields) {
      final name = field['name'] ?? '';
      final type = field['field_type'] ?? 'string';
      if (type == 'string') {
        final val = _fieldControllers[name]?.text.trim() ?? '';
        if (val.isNotEmpty) _categoryDataValues[name] = val;
      } else if (type == 'number') {
        final val = _fieldControllers[name]?.text.trim() ?? '';
        if (val.isNotEmpty) _categoryDataValues[name] = num.tryParse(val) ?? val;
      }
      // boolean and date are already set via onChanged
    }
  }

  Future<void> _pickDate(String fieldName) async {
    final current = _categoryDataValues[fieldName]?.toString() ?? '';
    DateTime initial = DateTime.now();
    if (current.isNotEmpty) {
      try {
        initial = DateTime.parse(current);
      } catch (_) {}
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _categoryDataValues[fieldName] = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _collectFieldValues();
    setState(() => _isSubmitting = true);

    try {
      final Map<String, dynamic> data = {
        'name': _nameController.text.trim(),
        'unit': _unit,
        'brand': _brandController.text.trim(),
        'model': _modelController.text.trim(),
        'has_serial_number': _hasSerialNumber,
        'size': _sizeController.text.trim(),
        'weight': _weightController.text.trim(),
        'description': _descController.text.trim(),
        'is_active': widget.product?.isActive ?? true,
      };

      data['category'] = _categoryId;
      data['category_data'] = _categoryDataValues;
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
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.product == null ? 'Məhsul yaradıldı' : 'Məhsul yeniləndi')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Əməliyyat uğursuz oldu')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildCategoryField(Map<String, dynamic> field) {
    final fieldName = field['name'] ?? '';
    final fieldType = field['field_type'] ?? 'string';

    if (fieldType == 'boolean') {
      return CheckboxListTile(
        value: _categoryDataValues[fieldName] == true,
        onChanged: (val) => setState(() => _categoryDataValues[fieldName] = val ?? false),
        title: Text(fieldName),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
      );
    }

    if (fieldType == 'date') {
      final dateVal = _categoryDataValues[fieldName]?.toString() ?? '';
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: () => _pickDate(fieldName),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: fieldName,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              suffixIcon: const Icon(Icons.calendar_today),
            ),
            child: Text(
              dateVal.isNotEmpty ? dateVal : 'Tarix seçin',
              style: TextStyle(color: dateVal.isNotEmpty ? Colors.black : Colors.grey),
            ),
          ),
        ),
      );
    }

    // string or number
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _fieldControllers[fieldName],
        decoration: InputDecoration(labelText: fieldName, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
        keyboardType: fieldType == 'number' ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      ),
    );
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
                  Text(widget.product == null ? 'Yeni Məhsul' : 'Məhsulu Düzəlt', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Ad *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                validator: (val) => val?.isEmpty == true ? 'Zəruridir' : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _unit,
                decoration: InputDecoration(labelText: 'Vahid *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                items: _units.map((u) => DropdownMenuItem(value: u['value'], child: Text(u['label']!))).toList(),
                onChanged: (val) => setState(() => _unit = val!),
              ),
              const SizedBox(height: 16),

              // Category dropdown
              _loadingCategories
                  ? const LinearProgressIndicator()
                  : DropdownButtonFormField<int?>(
                      value: _categoryId,
                      decoration: InputDecoration(labelText: 'Kateqoriya', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('Seçilməyib')),
                        ..._categories.map((c) => DropdownMenuItem<int?>(value: c['id'], child: Text(c['name'] ?? ''))),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _categoryId = val;
                          _categoryDataValues = {};
                        });
                        if (val != null) {
                          _loadCategoryFields(val);
                        } else {
                          setState(() => _categoryFields = []);
                        }
                      },
                    ),
              const SizedBox(height: 16),

              // Has Serial Number checkbox
              CheckboxListTile(
                value: _hasSerialNumber,
                onChanged: (val) => setState(() => _hasSerialNumber = val ?? false),
                title: const Text('Serial nömrəli məhsul'),
                subtitle: const Text('Hər ədəd üçün ayrıca serial nömrə izlənir', style: TextStyle(fontSize: 12)),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(child: TextFormField(controller: _brandController, decoration: InputDecoration(labelText: 'Brend', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(controller: _modelController, decoration: InputDecoration(labelText: 'Model', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(child: TextFormField(controller: _sizeController, decoration: InputDecoration(labelText: 'Ölçü', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(controller: _weightController, decoration: InputDecoration(labelText: 'Çəki', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(child: TextFormField(controller: _portCountController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Port sayı', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(controller: _priceController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Qiymət', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(child: TextFormField(controller: _minQtyController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Min stok', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(controller: _maxQtyController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Max stok', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descController,
                maxLines: 3,
                decoration: InputDecoration(labelText: 'Təsvir', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),

              // Dynamic category fields
              if (_categoryFields.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(),
                const Text('Kateqoriya Sahələri', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                ..._categoryFields.map((field) => _buildCategoryField(field)),
              ],

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: _isSubmitting ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(widget.product == null ? 'Yarat' : 'Yenilə', style: const TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
