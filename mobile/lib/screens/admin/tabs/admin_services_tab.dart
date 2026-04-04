import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/screens/admin/admin_service_icons.dart';
import 'package:mobile/screens/users/list_utils.dart';

class AdminServicesTab extends StatefulWidget {
  const AdminServicesTab({super.key});

  @override
  State<AdminServicesTab> createState() => _AdminServicesTabState();
}

class _AdminServicesTabState extends State<AdminServicesTab> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
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
      final res = await ApiClient().dio.get('/tasks/services/');
      if (!mounted) return;
      final raw = unwrapApiList(res.data);
      setState(() {
        _items = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
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
    return _items.where((item) {
      final name = (item['name'] ?? '').toString().toLowerCase();
      final desc = (item['description'] ?? '').toString().toLowerCase();
      final matchSearch =
          _debounced.isEmpty || name.contains(_debounced) || desc.contains(_debounced);
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
      await ApiClient().dio.patch('/tasks/services/$id/', data: {'is_active': v});
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
      await ApiClient().dio.delete('/tasks/services/$id/');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Servis silindi')),
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
      builder: (ctx) => _ServiceFormSheet(
        existing: existing,
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
                    label: const Text('Yeni servis'),
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
                            final iconName = item['icon']?.toString() ?? 'AppstoreOutlined';
                            final active = item['is_active'] == true;
                            final count = item['columns_count'];
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
                                    Row(
                                      children: [
                                        Icon(
                                          adminServiceIconPreview(iconName),
                                          size: 28,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            item['name']?.toString() ?? '',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (item['description'] != null &&
                                        '${item['description']}'.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          item['description'].toString(),
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                    Text(
                                      'ID: $id  ·  Sütun sayı: ${count ?? '—'}',
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

class _ServiceFormSheet extends StatefulWidget {
  const _ServiceFormSheet({required this.existing, required this.onSuccess});

  final Map<String, dynamic>? existing;
  final VoidCallback onSuccess;

  @override
  State<_ServiceFormSheet> createState() => _ServiceFormSheetState();
}

class _ServiceFormSheetState extends State<_ServiceFormSheet> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late String _iconName;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?['name']?.toString() ?? '');
    _description = TextEditingController(text: e?['description']?.toString() ?? '');
    _iconName = e?['icon']?.toString() ?? 'AppstoreOutlined';
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ad mütləqdir')),
      );
      return;
    }
    setState(() => _submitting = true);
    final data = {
      'name': _name.text.trim(),
      'icon': _iconName,
      'description': _description.text.trim(),
    };
    try {
      if (widget.existing == null) {
        await ApiClient().dio.post('/tasks/services/', data: data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Servis yaradıldı')),
          );
        }
      } else {
        final id = asApiIntId(widget.existing!['id'])!;
        await ApiClient().dio.patch('/tasks/services/$id/', data: data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Servis yeniləndi')),
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
              widget.existing == null ? 'Yeni servis' : 'Servisi düzəlt',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Ad *'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: ValueKey(_iconName),
              initialValue: kAdminServiceIconOptions.any((o) => o.name == _iconName)
                  ? _iconName
                  : 'AppstoreOutlined',
              decoration: const InputDecoration(labelText: 'İkon *'),
              isExpanded: true,
              items: kAdminServiceIconOptions
                  .map(
                    (o) => DropdownMenuItem(
                      value: o.name,
                      child: Row(
                        children: [
                          Icon(adminServiceIconPreview(o.name), size: 22),
                          const SizedBox(width: 8),
                          Expanded(child: Text(o.label)),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _iconName = v);
              },
            ),
            TextField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'Təsvir'),
              maxLines: 3,
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
}
