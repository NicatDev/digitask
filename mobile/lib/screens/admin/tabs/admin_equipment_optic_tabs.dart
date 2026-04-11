import 'package:flutter/material.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/screens/users/list_utils.dart';

/// Web Admin ilə eyni: avadanlıq / optik qutu CRUD (ad, təsvir, aktiv).
class AdminEquipmentTab extends StatelessWidget {
  const AdminEquipmentTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SimpleEntityAdminTab(
      apiPath: '/tasks/equipment',
      emptyMessage: 'Avadanlıq yoxdur',
      newButtonLabel: 'Yeni avadanlıq',
      formTitleNew: 'Yeni avadanlıq',
      formTitleEdit: 'Avadanlığı düzəlt',
      deleteSuccess: 'Avadanlıq silindi',
      createdSuccess: 'Avadanlıq əlavə olundu',
      updatedSuccess: 'Avadanlıq yeniləndi',
    );
  }
}

class AdminOpticBoxTab extends StatelessWidget {
  const AdminOpticBoxTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SimpleEntityAdminTab(
      apiPath: '/tasks/optic-boxes',
      emptyMessage: 'Optik qutu yoxdur',
      newButtonLabel: 'Yeni optik qutu',
      formTitleNew: 'Yeni optik qutu',
      formTitleEdit: 'Optik qutunu düzəlt',
      deleteSuccess: 'Optik qutu silindi',
      createdSuccess: 'Optik qutu əlavə olundu',
      updatedSuccess: 'Optik qutu yeniləndi',
    );
  }
}

class _SimpleEntityAdminTab extends StatefulWidget {
  const _SimpleEntityAdminTab({
    required this.apiPath,
    required this.emptyMessage,
    required this.newButtonLabel,
    required this.formTitleNew,
    required this.formTitleEdit,
    required this.deleteSuccess,
    required this.createdSuccess,
    required this.updatedSuccess,
  });

  final String apiPath;
  final String emptyMessage;
  final String newButtonLabel;
  final String formTitleNew;
  final String formTitleEdit;
  final String deleteSuccess;
  final String createdSuccess;
  final String updatedSuccess;

  @override
  State<_SimpleEntityAdminTab> createState() => _SimpleEntityAdminTabState();
}

class _SimpleEntityAdminTabState extends State<_SimpleEntityAdminTab> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  String get _base => widget.apiPath.endsWith('/') ? widget.apiPath : '${widget.apiPath}/';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient().dio.get(_base, queryParameters: {'page_size': 100});
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
      await ApiClient().dio.patch('$_base$id/', data: {'is_active': v});
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
      await ApiClient().dio.delete('$_base$id/');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.deleteSuccess)),
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
      builder: (ctx) => _EntityFormSheet(
        apiBase: _base,
        existing: existing,
        formTitleNew: widget.formTitleNew,
        formTitleEdit: widget.formTitleEdit,
        createdSuccess: widget.createdSuccess,
        updatedSuccess: widget.updatedSuccess,
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
                label: Text(widget.newButtonLabel),
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
                          children: [
                            const SizedBox(height: 120),
                            Center(child: Text(widget.emptyMessage)),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: _items.length,
                          itemBuilder: (context, i) {
                            final item = _items[i];
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
                                    Row(
                                      children: [
                                        Text(
                                          '#$id',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
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
                                        '${item['description']}'.trim().isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(
                                          item['description'].toString(),
                                          style: TextStyle(
                                            color: Colors.grey.shade800,
                                            fontSize: 14,
                                          ),
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
                                                  'Silmək istədiyinizə əminsiniz?',
                                                ),
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
                                                    child: const Text(
                                                      'Sil',
                                                      style: TextStyle(color: Colors.red),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                          child: const Text(
                                            'Sil',
                                            style: TextStyle(color: Colors.red),
                                          ),
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

class _EntityFormSheet extends StatefulWidget {
  const _EntityFormSheet({
    required this.apiBase,
    required this.existing,
    required this.formTitleNew,
    required this.formTitleEdit,
    required this.createdSuccess,
    required this.updatedSuccess,
    required this.onSuccess,
  });

  final String apiBase;
  final Map<String, dynamic>? existing;
  final String formTitleNew;
  final String formTitleEdit;
  final String createdSuccess;
  final String updatedSuccess;
  final VoidCallback onSuccess;

  @override
  State<_EntityFormSheet> createState() => _EntityFormSheetState();
}

class _EntityFormSheetState extends State<_EntityFormSheet> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?['name']?.toString() ?? '');
    _description = TextEditingController(text: e?['description']?.toString() ?? '');
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
      'description': _description.text.trim(),
    };
    try {
      if (widget.existing == null) {
        await ApiClient().dio.post(widget.apiBase, data: data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(widget.createdSuccess)),
          );
        }
      } else {
        final id = asApiIntId(widget.existing!['id'])!;
        await ApiClient().dio.patch('${widget.apiBase}$id/', data: data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(widget.updatedSuccess)),
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
              widget.existing == null ? widget.formTitleNew : widget.formTitleEdit,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Ad *'),
            ),
            const SizedBox(height: 8),
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
