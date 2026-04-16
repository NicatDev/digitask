import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/screens/users/list_utils.dart';

class RolesTab extends StatefulWidget {
  const RolesTab({super.key});

  @override
  State<RolesTab> createState() => _RolesTabState();
}

class _RolesTabState extends State<RolesTab> {
  List<dynamic> _items = [];
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
      if (!mounted) return;
      setState(() => _debounced = _search.text.trim().toLowerCase());
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
      final res = await ApiClient().dio.get('/roles/');
      if (mounted) {
        setState(() {
          _items = unwrapApiList(res.data);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Məlumatları yükləmək mümkün olmadı: $e')),
        );
      }
    }
  }

  List<dynamic> _filtered() {
    return _items.where((raw) {
      if (raw is! Map) return false;
      final name = (raw['name'] ?? '').toString().toLowerCase();
      final matchSearch = _debounced.isEmpty || name.contains(_debounced);
      final active = raw['is_active'] == true;
      final matchStatus = _statusFilter == 'all'
          ? true
          : _statusFilter == true
              ? active
              : !active;
      return matchSearch && matchStatus;
    }).toList();
  }

  Future<void> _delete(int id) async {
    try {
      await ApiClient().dio.delete('/roles/$id/');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rol silindi')),
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

  void _confirmDelete(int id) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Silmək'),
        content: const Text('Silmək istədiyinizə əminsiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Ləğv')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _delete(id);
            },
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _openForm({Map<String, dynamic>? existing}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _RoleFormSheet(
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
                          hintText: 'Axtar (ad)...',
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
                    value: _statusFilter,
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
                    label: const Text('Yeni rol'),
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
                            final item = list[i] as Map<String, dynamic>;
                            final id = asApiIntId(item['id'])!;
                            return Card(
                              color: Colors.white,
                              surfaceTintColor: Colors.white,
                              elevation: 1,
                              clipBehavior: Clip.antiAlias,
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
                                    if (item['description'] != null &&
                                        '${item['description']}'.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(item['description'].toString()),
                                      ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        TextButton(
                                          onPressed: () => _openForm(existing: item),
                                          child: const Text('Düzəliş'),
                                        ),
                                        TextButton(
                                          onPressed: () => _confirmDelete(id),
                                          child: const Text('Sil', style: TextStyle(color: Colors.red)),
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

class _RoleFormSheet extends StatefulWidget {
  const _RoleFormSheet({required this.existing, required this.onSuccess});

  final Map<String, dynamic>? existing;
  final VoidCallback onSuccess;

  @override
  State<_RoleFormSheet> createState() => _RoleFormSheetState();
}

class _RoleFormSheetState extends State<_RoleFormSheet> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late bool _taskWriter;
  late bool _taskReader;
  late bool _taskViewAll;
  late bool _whWriter;
  late bool _whReader;
  late bool _docWriter;
  late bool _docReader;
  late bool _admin;
  late bool _superAdmin;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?['name']?.toString() ?? '');
    _description = TextEditingController(text: e?['description']?.toString() ?? '');
    _taskWriter = e?['is_task_writer'] == true;
    _taskReader = e?['is_task_reader'] == true;
    _taskViewAll = e?['is_task_view_all'] == true;
    _whWriter = e?['is_warehouse_writer'] == true;
    _whReader = e?['is_warehouse_reader'] == true;
    _docWriter = e?['is_document_writer'] == true;
    _docReader = e?['is_document_reader'] == true;
    _admin = e?['is_admin'] == true;
    _superAdmin = e?['is_super_admin'] == true;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ad mütləqdir')),
      );
      return;
    }
    setState(() => _submitting = true);
    final data = <String, dynamic>{
      'name': _name.text,
      'description': _description.text.isEmpty ? '' : _description.text,
      'is_task_writer': _taskWriter,
      'is_task_reader': _taskReader,
      'is_task_view_all': _taskViewAll,
      'is_warehouse_writer': _whWriter,
      'is_warehouse_reader': _whReader,
      'is_document_writer': _docWriter,
      'is_document_reader': _docReader,
      'is_admin': _admin,
      'is_super_admin': _superAdmin,
    };
    try {
      if (widget.existing == null) {
        await ApiClient().dio.post('/roles/', data: data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Rol yaradıldı')),
          );
        }
      } else {
        await ApiClient().dio.put('/roles/${widget.existing!['id']}/', data: data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Rol yeniləndi')),
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
    final existing = widget.existing;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom, left: 16, right: 16, top: 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              existing == null ? 'Yeni rol' : 'Rolu düzəlt',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Ad *'),
            ),
            TextField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'Təsvir'),
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Tapşırıq (yazmaq)'),
              value: _taskWriter,
              onChanged: (v) => setState(() => _taskWriter = v),
            ),
            SwitchListTile(
              title: const Text('Tapşırıq (oxumaq)'),
              value: _taskReader,
              onChanged: (v) => setState(() => _taskReader = v),
            ),
            SwitchListTile(
              title: const Text('Tapşırıq (hamısını gör)'),
              value: _taskViewAll,
              onChanged: (v) => setState(() => _taskViewAll = v),
            ),
            SwitchListTile(
              title: const Text('Anbar (yazmaq)'),
              value: _whWriter,
              onChanged: (v) => setState(() => _whWriter = v),
            ),
            SwitchListTile(
              title: const Text('Anbar (oxumaq)'),
              value: _whReader,
              onChanged: (v) => setState(() => _whReader = v),
            ),
            SwitchListTile(
              title: const Text('Sənəd (yazmaq)'),
              value: _docWriter,
              onChanged: (v) => setState(() => _docWriter = v),
            ),
            SwitchListTile(
              title: const Text('Sənəd (oxumaq)'),
              value: _docReader,
              onChanged: (v) => setState(() => _docReader = v),
            ),
            SwitchListTile(
              title: const Text('Admin'),
              value: _admin,
              onChanged: (v) => setState(() => _admin = v),
            ),
            SwitchListTile(
              title: const Text('Super admin'),
              value: _superAdmin,
              onChanged: (v) => setState(() => _superAdmin = v),
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
