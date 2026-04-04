import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/screens/users/list_utils.dart';

class GroupsTab extends StatefulWidget {
  const GroupsTab({super.key});

  @override
  State<GroupsTab> createState() => _GroupsTabState();
}

class _GroupsTabState extends State<GroupsTab> {
  List<dynamic> _items = [];
  List<dynamic> _regions = [];
  bool _loading = true;
  final TextEditingController _search = TextEditingController();
  String _debounced = '';
  Object _statusFilter = 'all';
  String? _regionFilterName;
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
      final client = ApiClient().dio;
      final gRes = await client.get('/groups/');
      final rRes = await client.get('/regions/');
      if (mounted) {
        setState(() {
          _items = unwrapApiList(gRes.data);
          _regions = unwrapApiList(rRes.data);
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
      final regionName = raw['region_name']?.toString();
      final matchRegion =
          _regionFilterName == null || regionName == _regionFilterName;
      final active = raw['is_active'] == true;
      final matchStatus = _statusFilter == 'all'
          ? true
          : _statusFilter == true
              ? active
              : !active;
      return matchSearch && matchRegion && matchStatus;
    }).toList();
  }

  Future<void> _delete(int id) async {
    try {
      await ApiClient().dio.delete('/groups/$id/');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Qrup silindi')),
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
      builder: (ctx) => _GroupFormSheet(
        regions: _regions,
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
                  DropdownButtonFormField<String?>(
                    value: _regionFilterName,
                    decoration: const InputDecoration(labelText: 'Region', isDense: true),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('Hamısı')),
                      ..._regions.map((r) {
                        final name = (r as Map)['name']?.toString() ?? '';
                        return DropdownMenuItem<String?>(value: name, child: Text(name));
                      }),
                    ],
                    onChanged: (v) => setState(() => _regionFilterName = v),
                  ),
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
                    label: const Text('Yeni qrup'),
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
                                    Text(
                                      'Region: ${item['region_name'] ?? '—'}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade700,
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

class _GroupFormSheet extends StatefulWidget {
  const _GroupFormSheet({
    required this.regions,
    required this.existing,
    required this.onSuccess,
  });

  final List<dynamic> regions;
  final Map<String, dynamic>? existing;
  final VoidCallback onSuccess;

  @override
  State<_GroupFormSheet> createState() => _GroupFormSheetState();
}

class _GroupFormSheetState extends State<_GroupFormSheet> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  int? _regionId;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?['name']?.toString() ?? '');
    _description = TextEditingController(text: e?['description']?.toString() ?? '');
    _regionId = asApiIntId(e?['region']);
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.isEmpty || _regionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ad və region mütləqdir')),
      );
      return;
    }
    setState(() => _submitting = true);
    final data = <String, dynamic>{
      'name': _name.text,
      'region': _regionId,
      'description': _description.text.isEmpty ? '' : _description.text,
    };
    try {
      if (widget.existing == null) {
        await ApiClient().dio.post('/groups/', data: data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Qrup yaradıldı')),
          );
        }
      } else {
        await ApiClient().dio.put('/groups/${widget.existing!['id']}/', data: data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Qrup yeniləndi')),
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
              existing == null ? 'Yeni qrup' : 'Qrupu düzəlt',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Ad *'),
            ),
            DropdownButtonFormField<int?>(
              value: () {
                final ids = widget.regions
                    .map((r) => asApiIntId((r as Map)['id']))
                    .whereType<int>()
                    .toSet();
                return _regionId != null && ids.contains(_regionId) ? _regionId : null;
              }(),
              decoration: const InputDecoration(labelText: 'Region *'),
              items: widget.regions.map((r) {
                final m = r as Map;
                return DropdownMenuItem<int?>(
                  value: asApiIntId(m['id']),
                  child: Text('${m['name']}'),
                );
              }).toList(),
              onChanged: (v) => setState(() => _regionId = v),
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
