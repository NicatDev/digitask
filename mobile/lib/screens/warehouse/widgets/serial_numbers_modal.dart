import 'package:flutter/material.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/models/product.dart';

class SerialNumbersModal extends StatefulWidget {
  final Product product;
  final int? warehouseFilter;

  const SerialNumbersModal({super.key, required this.product, this.warehouseFilter});

  @override
  State<SerialNumbersModal> createState() => _SerialNumbersModalState();
}

class _SerialNumbersModalState extends State<SerialNumbersModal> {
  List<dynamic> _serials = [];
  List<dynamic> _filtered = [];
  bool _isLoading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchSerials();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchSerials() async {
    setState(() => _isLoading = true);
    try {
      final params = <String, dynamic>{
        'product': widget.product.id,
        'page_size': 500,
      };
      if (widget.warehouseFilter != null) {
        params['warehouse'] = widget.warehouseFilter;
      }
      final res = await ApiClient().dio.get('/warehouse/serial-items/', queryParameters: params);
      if (mounted) {
        final data = res.data;
        final list = (data is Map && data.containsKey('results')) ? data['results'] : (data is List ? data : []);
        setState(() {
          _serials = list;
          _filtered = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearch(String query) {
    final q = query.toLowerCase().trim();
    setState(() {
      if (q.isEmpty) {
        _filtered = _serials;
      } else {
        _filtered = _serials.where((s) {
          final sn = (s['serial_number'] ?? '').toString().toLowerCase();
          final wh = (s['warehouse_name'] ?? '').toString().toLowerCase();
          return sn.contains(q) || wh.contains(q);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Center(
            child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Serial Nömrələri: ${widget.product.name}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                child: Text('${_filtered.length} ədəd', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchCtrl,
            onChanged: _onSearch,
            decoration: InputDecoration(
              hintText: 'Serial nömrə axtar...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? const Center(child: Text('Serial nömrə tapılmadı'))
                    : ListView.separated(
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, index) {
                          final s = _filtered[index];
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.blue.shade50,
                              child: Text('${index + 1}', style: TextStyle(fontSize: 12, color: Colors.blue.shade700)),
                            ),
                            title: Text(s['serial_number'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                            subtitle: Text(s['warehouse_name'] ?? '', style: const TextStyle(fontSize: 12)),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
