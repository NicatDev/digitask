import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/screens/admin/column_field_logic.dart';
import 'package:mobile/screens/users/list_utils.dart';

const List<MapEntry<String, String>> kFieldTypes = [
  MapEntry('string', 'Mətn (Qısa)'),
  MapEntry('text', 'Mətn (Uzun)'),
  MapEntry('integer', 'Tam ədəd'),
  MapEntry('decimal', 'Onluq ədəd'),
  MapEntry('boolean', 'Bəli/Xeyr'),
  MapEntry('date', 'Tarix'),
  MapEntry('datetime', 'Tarix və saat'),
  MapEntry('image', 'Şəkil'),
  MapEntry('file', 'Fayl'),
];

class AdminColumnsTab extends StatefulWidget {
  const AdminColumnsTab({super.key});

  @override
  State<AdminColumnsTab> createState() => _AdminColumnsTabState();
}

class _AdminColumnsTabState extends State<AdminColumnsTab> {
  List<Map<String, dynamic>> _columns = [];
  List<Map<String, dynamic>> _services = [];
  bool _loading = true;
  int? _serviceFilterId;
  final TextEditingController _search = TextEditingController();
  String _debounced = '';
  Object _statusFilter = 'all';
  bool _showFilters = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search.addListener(_onSearchChanged);
    _load();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _debounced = _search.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.removeListener(_onSearchChanged);
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final params = <String, dynamic>{};
      if (_serviceFilterId != null) {
        params['service'] = _serviceFilterId;
      }
      final results = await Future.wait([
        ApiClient().dio.get('/tasks/columns/', queryParameters: params),
        ApiClient().dio.get('/tasks/services/'),
      ]);
      if (!mounted) return;
      final colRaw = unwrapApiList(results[0].data);
      final svcRaw = unwrapApiList(results[1].data);
      setState(() {
        _columns = colRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _services = svcRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Məlumatları yükləmək mümkün olmadı: $e')),
        );
      }
    }
  }

  List<Map<String, dynamic>> _filtered() {
    return _columns.where((item) {
      final name = (item['name'] ?? '').toString().toLowerCase();
      final key = (item['key'] ?? '').toString().toLowerCase();
      final matchSearch =
          _debounced.isEmpty || name.contains(_debounced) || key.contains(_debounced);
      final active = item['is_active'] == true;
      final matchStatus = _statusFilter == 'all'
          ? true
          : _statusFilter == true
              ? active
              : !active;
      return matchSearch && matchStatus;
    }).toList();
  }

  Future<void> _patchActive(int id, bool v) async {
    try {
      await ApiClient().dio.patch('/tasks/columns/$id/', data: {'is_active': v});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status yeniləndi')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status yenilənmədi: $e')),
        );
      }
    }
  }

  Future<void> _delete(int id) async {
    try {
      await ApiClient().dio.delete('/tasks/columns/$id/');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sütun silindi')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Silinmə uğursuz oldu: $e')),
        );
      }
    }
  }

  void _openForm({Map<String, dynamic>? existing}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _ColumnFormSheet(
        existing: existing,
        allColumns: _columns,
        services: _services,
        onSuccess: () {
          Navigator.pop(ctx);
          _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final list = _filtered();

    return Column(
      children: [
        Material(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _search,
                        decoration: const InputDecoration(
                          hintText: 'Axtar...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    if (narrow)
                      IconButton(
                        icon: Icon(_showFilters ? Icons.filter_alt : Icons.filter_alt_outlined),
                        onPressed: () => setState(() => _showFilters = !_showFilters),
                      ),
                  ],
                ),
                if (!narrow || _showFilters) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int?>(
                    key: ValueKey(_serviceFilterId),
                    initialValue: _serviceFilterId,
                    decoration: const InputDecoration(labelText: 'Servis', isDense: true),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('Hamısı')),
                      ..._services.map((s) {
                        final id = asApiIntId(s['id']);
                        return DropdownMenuItem<int?>(
                          value: id,
                          child: Text(s['name']?.toString() ?? ''),
                        );
                      }),
                    ],
                    onChanged: (v) {
                      setState(() => _serviceFilterId = v);
                      _load();
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<Object>(
                    key: ValueKey(_statusFilter),
                    initialValue: _statusFilter,
                    decoration: const InputDecoration(labelText: 'Status', isDense: true),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('Hamısı')),
                      DropdownMenuItem(value: true, child: Text('Aktiv')),
                      DropdownMenuItem(value: false, child: Text('Deaktiv')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _statusFilter = v);
                    },
                  ),
                ],
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _openForm(),
                    icon: const Icon(Icons.add),
                    label: const Text('Yeni sütun'),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: list.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 120),
                            Center(child: Text('Məlumat yoxdur')),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: list.length,
                          itemBuilder: (context, i) {
                            final item = list[i];
                            final id = asApiIntId(item['id'])!;
                            final active = item['is_active'] == true;
                            return Card(
                              color: Colors.white,
                              surfaceTintColor: Colors.white,
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['name']?.toString() ?? '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      'Servis: ${item['service_name'] ?? '—'}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    Text(
                                      'Açar: ${item['key'] ?? ''}  ·  ${item['field_type_display'] ?? item['field_type']}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                    Text(
                                      'Məcburi: ${item['required'] == true ? 'Bəli' : 'Xeyr'}  ·  Sıra: ${item['order'] ?? 0}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Text('Aktiv'),
                                        Switch(
                                          value: active,
                                          onChanged: (v) => _patchActive(id, v),
                                        ),
                                        const Spacer(),
                                        TextButton(
                                          onPressed: () => _openForm(existing: item),
                                          child: const Text('Düzəliş'),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            showDialog<void>(
                                              context: context,
                                              builder: (dCtx) => AlertDialog(
                                                title: const Text('Silmək'),
                                                content: const Text(
                                                    'Silmək istədiyinizə əminsiniz?'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(dCtx),
                                                    child: const Text('Ləğv'),
                                                  ),
                                                  TextButton(
                                                    onPressed: () {
                                                      Navigator.pop(dCtx);
                                                      _delete(id);
                                                    },
                                                    child: const Text('Sil',
                                                        style: TextStyle(color: Colors.red)),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                          child: const Text('Sil',
                                              style: TextStyle(color: Colors.red)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }
}

class _ColumnFormSheet extends StatefulWidget {
  const _ColumnFormSheet({
    required this.existing,
    required this.allColumns,
    required this.services,
    required this.onSuccess,
  });

  final Map<String, dynamic>? existing;
  final List<Map<String, dynamic>> allColumns;
  final List<Map<String, dynamic>> services;
  final VoidCallback onSuccess;

  @override
  State<_ColumnFormSheet> createState() => _ColumnFormSheetState();
}

class _ColumnFormSheetState extends State<_ColumnFormSheet> {
  late final TextEditingController _name;
  late final TextEditingController _key;
  late final TextEditingController _order;
  late final TextEditingController _min;
  late final TextEditingController _max;
  int? _serviceId;
  String _fieldType = 'string';
  bool _required = false;
  bool _submitting = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?['name']?.toString() ?? '');
    _key = TextEditingController(text: e?['key']?.toString() ?? '');
    _order = TextEditingController(
      text: e?['order'] != null ? '${e!['order']}' : '0',
    );
    _min = TextEditingController(
      text: e?['min_value'] != null ? '${e!['min_value']}' : '',
    );
    _max = TextEditingController(
      text: e?['max_value'] != null ? '${e!['max_value']}' : '',
    );
    _serviceId = asApiIntId(e?['service']);
    _fieldType = e?['field_type']?.toString() ?? 'string';
    _required = e?['required'] == true;
    _name.addListener(_maybeRegenerateKey);
  }

  void _maybeRegenerateKey() {
    if (_isEdit) return;
    final sid = _serviceId;
    if (sid == null) return;
    final unique = generateUniqueColumnKey(
      name: _name.text,
      serviceId: sid,
      allColumns: widget.allColumns,
      excludeColumnId: null,
    );
    setState(() => _key.text = unique);
  }

  @override
  void dispose() {
    _name.removeListener(_maybeRegenerateKey);
    _name.dispose();
    _key.dispose();
    _order.dispose();
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final sid = _serviceId;
    if (sid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Servis seçin')),
      );
      return;
    }
    if (_name.text.trim().isEmpty || _key.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ad və açar mütləqdir')),
      );
      return;
    }
    setState(() => _submitting = true);
    final payload = <String, dynamic>{
      'service': sid,
      'name': _name.text.trim(),
      'key': _key.text.trim(),
      'field_type': _fieldType,
      'required': _required,
      'order': int.tryParse(_order.text.trim()) ?? 0,
    };
    final minT = _min.text.trim();
    final maxT = _max.text.trim();
    if (minT.isNotEmpty) {
      payload['min_value'] = num.tryParse(minT.replaceAll(',', '.'));
    } else {
      payload['min_value'] = null;
    }
    if (maxT.isNotEmpty) {
      payload['max_value'] = num.tryParse(maxT.replaceAll(',', '.'));
    } else {
      payload['max_value'] = null;
    }
    try {
      if (_isEdit) {
        final id = asApiIntId(widget.existing!['id'])!;
        await ApiClient().dio.patch('/tasks/columns/$id/', data: payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sütun yeniləndi')),
          );
        }
      } else {
        await ApiClient().dio.post('/tasks/columns/', data: payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sütun yaradıldı')),
          );
        }
      }
      if (mounted) widget.onSuccess();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Əməliyyat uğursuz oldu: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom, left: 16, right: 16, top: 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isEdit ? 'Sütunu düzəlt' : 'Yeni sütun',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Ad daxil edildikdə açar avtomatik yaradılır. Eyni servis üçün unikal olmalıdır.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              key: ValueKey(_serviceId),
              initialValue: _serviceIds.contains(_serviceId) ? _serviceId : null,
              decoration: const InputDecoration(labelText: 'Servis *'),
              items: _serviceMenuItems,
              onChanged: _isEdit
                  ? null
                  : (v) {
                      setState(() {
                        _serviceId = v;
                        _maybeRegenerateKey();
                      });
                    },
            ),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Ad *'),
              onChanged: (_) {
                if (!_isEdit) setState(() {});
              },
            ),
            TextField(
              controller: _key,
              decoration: const InputDecoration(
                labelText: 'Açar (slug) *',
              ),
              readOnly: true,
            ),
            DropdownButtonFormField<String>(
              key: ValueKey(_fieldType),
              initialValue:
                  kFieldTypes.any((e) => e.key == _fieldType) ? _fieldType : 'string',
              decoration: const InputDecoration(labelText: 'Tip *'),
              items: kFieldTypes
                  .map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _fieldType = v);
              },
            ),
            SwitchListTile(
              title: const Text('Məcburi'),
              value: _required,
              onChanged: (v) => setState(() => _required = v),
            ),
            TextField(
              controller: _order,
              decoration: const InputDecoration(labelText: 'Sıra'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _min,
              decoration: const InputDecoration(labelText: 'Minimum dəyər'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            TextField(
              controller: _max,
              decoration: const InputDecoration(labelText: 'Maksimum dəyər'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Təsdiqlə'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  List<int> get _serviceIds =>
      widget.services.map((s) => asApiIntId(s['id'])).whereType<int>().toList();

  List<DropdownMenuItem<int?>> get _serviceMenuItems {
    return widget.services
        .map((s) {
          final id = asApiIntId(s['id']);
          if (id == null) return null;
          return DropdownMenuItem<int?>(
            value: id,
            child: Text(s['name']?.toString() ?? ''),
          );
        })
        .whereType<DropdownMenuItem<int?>>()
        .toList();
  }
}
