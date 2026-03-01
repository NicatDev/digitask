import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
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
  final TextEditingController _serialInputController = TextEditingController();

  List<dynamic> _warehouses = [];
  List<dynamic> _serialItems = []; // For selecting existing serial items
  String? _selectedSerial;
  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _serialLoading = false;

  bool get _isSerial => widget.product.hasSerialNumber;

  // Movement types that need to SELECT an existing serial (out, transfer, korreksiya−)
  bool get _needsSerialSelect => _isSerial && (_movementType == 'out' || _movementType == 'transfer' || _movementType == 'adjust_decrease');
  // Movement types that need to INPUT a new serial (in, return, korreksiya+)
  bool get _needsSerialInput => _isSerial && (_movementType == 'in' || _movementType == 'return' || _movementType == 'adjust_increase');

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
    _serialInputController.dispose();
    super.dispose();
  }

  Future<void> _fetchWarehouses() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiClient().dio.get('/warehouse/warehouses/', queryParameters: {'is_active': true, 'page_size': 100});
      if (response.statusCode == 200) {
        setState(() {
          final data = response.data;
          _warehouses = (data is Map && data.containsKey('results')) ? data['results'] : (data is List ? data : []);
        });
      }
    } catch (e) {
      // ignore
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchSerialItems(int warehouseId) async {
    setState(() {
      _serialLoading = true;
      _serialItems = [];
      _selectedSerial = null;
    });
    try {
      final res = await ApiClient().dio.get('/warehouse/serial-items/', queryParameters: {
        'product': widget.product.id,
        'warehouse': warehouseId,
        'page_size': 200,
      });
      if (mounted) {
        setState(() {
          final data = res.data;
          _serialItems = (data is Map && data.containsKey('results')) ? data['results'] : (data is List ? data : []);
          _serialLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _serialLoading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_warehouseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Anbar seçin')));
      return;
    }
    if (_movementType == 'transfer' && _toWarehouseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hədəf anbar seçin')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final data = <String, dynamic>{
        'product_id': widget.product.id,
        'warehouse_id': _warehouseId,
        'reference_no': _referenceController.text.trim(),
        'reason': _reasonController.text.trim(),
      };

      String endpoint;
      String actualMovementType = _movementType;

      if (_isSerial) {
        // Serial product → /serial-adjust/
        endpoint = '/warehouse/movements/serial-adjust/';

        if (_needsSerialSelect) {
          if (_selectedSerial == null) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Serial nömrə seçin')));
            setState(() => _isSubmitting = false);
            return;
          }
          data['serial_number'] = _selectedSerial;
        } else {
          final sn = _serialInputController.text.trim();
          if (sn.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Serial nömrə daxil edin')));
            setState(() => _isSubmitting = false);
            return;
          }
          data['serial_number'] = sn;
        }

        // Map korreksiya to adjust + direction
        if (_movementType == 'adjust_increase') {
          actualMovementType = 'adjust';
          data['adjust_direction'] = 'increase';
        } else if (_movementType == 'adjust_decrease') {
          actualMovementType = 'adjust';
          data['adjust_direction'] = 'decrease';
        }
      } else {
        // Normal product → /adjust/
        endpoint = '/warehouse/movements/adjust/';
        data['quantity'] = double.parse(_quantityController.text);

        if (_movementType == 'adjust_increase') {
          actualMovementType = 'adjust';
          data['adjust_direction'] = 'increase';
        } else if (_movementType == 'adjust_decrease') {
          actualMovementType = 'adjust';
          data['adjust_direction'] = 'decrease';
        }
      }

      data['movement_type'] = actualMovementType;

      if (_movementType == 'transfer') {
        data['to_warehouse_id'] = _toWarehouseId;
      }
      if (_movementType == 'return') {
        data['returned_by'] = _returnedByController.text.trim();
      }

      final response = await ApiClient().dio.post(endpoint, data: data);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          Navigator.pop(context);
          widget.onSuccess();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Əməliyyat uğurlu oldu')));
        }
      }
    } catch (e) {
      if (mounted) {
        String msg = 'Əməliyyat uğursuz oldu';
        if (e is DioException && e.response?.data is Map) {
          msg = (e.response!.data as Map)['error']?.toString() ?? msg;
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stock: ${widget.product.name}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_isSerial)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
                            child: const Text('Serial nömrəli', style: TextStyle(color: Colors.blue, fontSize: 11)),
                          ),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 20),

              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else ...[
                // Movement type
                DropdownButtonFormField<String>(
                  value: _movementType,
                  decoration: InputDecoration(labelText: 'Əməliyyat Növü *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  items: const [
                    DropdownMenuItem(value: 'in', child: Text('Giriş (Import)')),
                    DropdownMenuItem(value: 'out', child: Text('Çıxış (Export)')),
                    DropdownMenuItem(value: 'transfer', child: Text('Transfer')),
                    DropdownMenuItem(value: 'adjust_increase', child: Text('Korreksiya (+)')),
                    DropdownMenuItem(value: 'adjust_decrease', child: Text('Korreksiya (−)')),
                    DropdownMenuItem(value: 'return', child: Text('Qaytarma')),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _movementType = val!;
                      _toWarehouseId = null;
                      _returnedByController.clear();
                      _selectedSerial = null;
                      _serialInputController.clear();
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Warehouse
                DropdownButtonFormField<int>(
                  value: _warehouseId,
                  decoration: InputDecoration(
                    labelText: _movementType == 'transfer' ? 'Mənbə Anbar *' : 'Anbar *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: _warehouses.map((w) => DropdownMenuItem<int>(value: w['id'], child: Text(w['name']))).toList(),
                  onChanged: (val) {
                    setState(() {
                      _warehouseId = val;
                      _selectedSerial = null;
                    });
                    if (val != null && _needsSerialSelect) {
                      _fetchSerialItems(val);
                    }
                  },
                  validator: (val) => val == null ? 'Zəruridir' : null,
                ),
                const SizedBox(height: 16),

                // Target warehouse for transfer
                if (_movementType == 'transfer') ...[
                  DropdownButtonFormField<int>(
                    value: _toWarehouseId,
                    decoration: InputDecoration(labelText: 'Hədəf Anbar *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    items: _warehouses.where((w) => w['id'] != _warehouseId).map((w) => DropdownMenuItem<int>(value: w['id'], child: Text(w['name']))).toList(),
                    onChanged: (val) => setState(() => _toWarehouseId = val),
                    validator: (val) => val == null ? 'Zəruridir' : null,
                  ),
                  const SizedBox(height: 16),
                ],

                // Return info
                if (_movementType == 'return') ...[
                  TextFormField(
                    controller: _returnedByController,
                    decoration: InputDecoration(labelText: 'Qaytaran haqqında', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                  const SizedBox(height: 16),
                ],

                // Serial number selection (for out/transfer/korreksiya−)
                if (_needsSerialSelect) ...[
                  _serialLoading
                      ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
                      : DropdownButtonFormField<String>(
                          value: _selectedSerial,
                          decoration: InputDecoration(labelText: 'Serial Nömrə *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                          isExpanded: true,
                          items: _serialItems.map((s) {
                            return DropdownMenuItem<String>(
                              value: s['serial_number'],
                              child: Text(s['serial_number'] ?? '', overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedSerial = val),
                          validator: (val) => val == null ? 'Serial seçin' : null,
                        ),
                  const SizedBox(height: 16),
                ],

                // Serial number input (for in/return/korreksiya+)
                if (_needsSerialInput) ...[
                  TextFormField(
                    controller: _serialInputController,
                    decoration: InputDecoration(labelText: 'Serial Nömrə *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    validator: (val) => (val == null || val.trim().isEmpty) ? 'Serial daxil edin' : null,
                  ),
                  const SizedBox(height: 16),
                ],

                // Quantity (only for non-serial products)
                if (!_isSerial) ...[
                  TextFormField(
                    controller: _quantityController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: 'Miqdar * (${widget.product.unit})', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Zəruridir';
                      if (double.tryParse(val) == null) return 'Düzgün rəqəm daxil edin';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                TextFormField(
                  controller: _referenceController,
                  decoration: InputDecoration(labelText: 'Sənəd No / Referans', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _reasonController,
                  maxLines: 2,
                  decoration: InputDecoration(labelText: 'Səbəb / Qeyd', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: _isSubmitting
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('İcra Et', style: TextStyle(fontSize: 16)),
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
