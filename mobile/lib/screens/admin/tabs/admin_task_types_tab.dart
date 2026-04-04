import 'package:flutter/material.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/screens/users/list_utils.dart';

Color? _parseHexColor(String? s) {
  if (s == null || s.isEmpty) return null;
  var h = s.trim().replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) return null;
  try {
    return Color(int.parse(h, radix: 16));
  } catch (_) {
    return null;
  }
}

String? _normalizeHexInput(String raw) {
  var t = raw.trim();
  if (t.isEmpty) return null;
  if (!t.startsWith('#')) t = '#$t';
  final body = t.substring(1);
  if (!RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(body)) return null;
  return '#${body.toUpperCase()}';
}

class AdminTaskTypesTab extends StatefulWidget {
  const AdminTaskTypesTab({super.key});

  @override
  State<AdminTaskTypesTab> createState() => _AdminTaskTypesTabState();
}

class _AdminTaskTypesTabState extends State<AdminTaskTypesTab> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient().dio.get('/tasks/task-types/');
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

  Future<void> _patchActive(int id, bool v) async {
    try {
      await ApiClient().dio.patch('/tasks/task-types/$id/', data: {'is_active': v});
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
      await ApiClient().dio.delete('/tasks/task-types/$id/');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Növ silindi')),
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
      builder: (ctx) => _TaskTypeFormSheet(
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
    return Column(
      children: [
        Material(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add),
                label: const Text('Yeni növ'),
              ),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _items.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 120),
                            Center(child: Text('Məlumat yoxdur')),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: _items.length,
                          itemBuilder: (context, i) {
                            final item = _items[i];
                            final id = asApiIntId(item['id'])!;
                            final active = item['is_active'] == true;
                            final hex = item['color']?.toString() ?? '#FFFFFF';
                            final swatch = _parseHexColor(hex) ?? Colors.grey;
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
                                        Container(
                                          width: 28,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            color: swatch,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: Colors.black26),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
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
                                        child: Text(item['description'].toString()),
                                      ),
                                    Text(
                                      hex,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
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

class _TaskTypeFormSheet extends StatefulWidget {
  const _TaskTypeFormSheet({required this.existing, required this.onSuccess});

  final Map<String, dynamic>? existing;
  final VoidCallback onSuccess;

  @override
  State<_TaskTypeFormSheet> createState() => _TaskTypeFormSheetState();
}

class _TaskTypeFormSheetState extends State<_TaskTypeFormSheet> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _color;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?['name']?.toString() ?? '');
    _description = TextEditingController(text: e?['description']?.toString() ?? '');
    var c = e?['color']?.toString() ?? '#1890FF';
    if (!c.startsWith('#')) c = '#$c';
    _color = TextEditingController(text: c);
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _color.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ad mütləqdir')),
      );
      return;
    }
    final hex = _normalizeHexInput(_color.text);
    if (hex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rəng düzgün deyil (məs: #FF5733)'),
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    final data = {
      'name': _name.text.trim(),
      'description': _description.text.trim(),
      'color': hex,
    };
    try {
      if (widget.existing == null) {
        await ApiClient().dio.post('/tasks/task-types/', data: data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Növ yaradıldı')),
          );
        }
      } else {
        final id = asApiIntId(widget.existing!['id'])!;
        await ApiClient().dio.patch('/tasks/task-types/$id/', data: data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Növ yeniləndi')),
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
    final preview = _parseHexColor(_normalizeHexInput(_color.text) ?? _color.text);
    return Padding(
      padding: EdgeInsets.only(bottom: bottom, left: 16, right: 16, top: 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.existing == null ? 'Yeni növ' : 'Növü düzəlt',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Ad *'),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: preview ?? Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.black26),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _color,
                    decoration: const InputDecoration(
                      labelText: 'Rəng (hex) *',
                      hintText: '#FF5733',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
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
