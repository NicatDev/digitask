import 'package:flutter/material.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/core/services/chat_service.dart';

class CategoriesTab extends StatefulWidget {
  const CategoriesTab({super.key});

  @override
  State<CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends State<CategoriesTab> {
  List<dynamic> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiClient().dio.get('/warehouse/categories/', queryParameters: {'page_size': 100});
      if (mounted) {
        setState(() {
          final data = res.data;
          _categories = (data is Map && data.containsKey('results')) ? data['results'] : (data is List ? data : []);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool get _isWriter => ChatService().currentUser.value?.isWarehouseWriter ?? false;

  Future<void> _showCategoryDialog([Map<String, dynamic>? category]) async {
    final nameCtrl = TextEditingController(text: category?['name'] ?? '');
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(category == null ? 'Yeni Kateqoriya' : 'Kateqoriyanı Düzəlt'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Ad', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Ləğv et')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              try {
                final client = ApiClient().dio;
                if (category == null) {
                  await client.post('/warehouse/categories/', data: {'name': name});
                } else {
                  await client.patch('/warehouse/categories/${category['id']}/', data: {'name': name});
                }
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Əməliyyat uğursuz oldu')));
                }
              }
            },
            child: const Text('Təsdiqlə'),
          ),
        ],
      ),
    );
    if (result == true) _fetchCategories();
  }

  Future<void> _deleteCategory(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Silmək istəyirsiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Xeyr')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Bəli', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await ApiClient().dio.delete('/warehouse/categories/$id/');
        _fetchCategories();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Silinmədi')));
      }
    }
  }

  Future<void> _showFieldsModal(Map<String, dynamic> category) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _FieldsModal(
        category: category,
        isWriter: _isWriter,
        onChanged: () => _fetchCategories(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _isWriter
          ? FloatingActionButton(
              onPressed: () => _showCategoryDialog(),
              backgroundColor: Colors.blue,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchCategories,
              child: _categories.isEmpty
                  ? ListView(children: const [SizedBox(height: 200), Center(child: Text('Kateqoriya yoxdur'))])
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _categories.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, index) {
                        final cat = _categories[index];
                        final fields = cat['fields_list'] as List<dynamic>? ?? [];
                        return Card(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            title: Text(cat['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${fields.length} sahə', style: const TextStyle(fontSize: 12)),
                            trailing: _isWriter
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.view_list, color: Colors.blue, size: 20),
                                        onPressed: () => _showFieldsModal(cat),
                                        tooltip: 'Sahələr',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.orange, size: 20),
                                        onPressed: () => _showCategoryDialog(cat),
                                        tooltip: 'Düzəlt',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                        onPressed: () => _deleteCategory(cat['id']),
                                        tooltip: 'Sil',
                                      ),
                                    ],
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.view_list),
                                    onPressed: () => _showFieldsModal(cat),
                                  ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

class _FieldsModal extends StatefulWidget {
  final Map<String, dynamic> category;
  final bool isWriter;
  final VoidCallback onChanged;

  const _FieldsModal({required this.category, required this.isWriter, required this.onChanged});

  @override
  State<_FieldsModal> createState() => _FieldsModalState();
}

class _FieldsModalState extends State<_FieldsModal> {
  final _nameCtrl = TextEditingController();
  String _fieldType = 'string';
  List<dynamic> _fields = [];
  bool _adding = false;

  final List<Map<String, String>> _fieldTypes = [
    {'value': 'string', 'label': 'Mətn'},
    {'value': 'number', 'label': 'Rəqəm'},
    {'value': 'boolean', 'label': 'Bəli/Xeyr'},
    {'value': 'date', 'label': 'Tarix'},
  ];

  @override
  void initState() {
    super.initState();
    _fields = List.from(widget.category['fields_list'] ?? []);
  }

  Future<void> _addField() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _adding = true);
    try {
      await ApiClient().dio.post('/warehouse/categories/${widget.category['id']}/add-field/', data: {
        'name': name,
        'field_type': _fieldType,
      });
      _nameCtrl.clear();
      widget.onChanged();
      // Refresh fields
      final res = await ApiClient().dio.get('/warehouse/categories/${widget.category['id']}/');
      if (mounted) {
        setState(() {
          _fields = List.from(res.data['fields_list'] ?? []);
          _adding = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _adding = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Əlavə olunmadı')));
      }
    }
  }

  Future<void> _removeField(int fieldId) async {
    try {
      await ApiClient().dio.delete('/warehouse/categories/${widget.category['id']}/remove-field/$fieldId/');
      widget.onChanged();
      setState(() {
        _fields.removeWhere((f) => f['id'] == fieldId);
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Silinmədi')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 12),
          Text('Sahələr: ${widget.category['name']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          if (widget.isWriter) ...[
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Sahə adı',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _fieldType,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          isDense: true,
                        ),
                        items: _fieldTypes.map((t) => DropdownMenuItem(value: t['value'], child: Text(t['label']!, style: const TextStyle(fontSize: 13)))).toList(),
                        onChanged: (val) => setState(() => _fieldType = val!),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _adding ? null : _addField,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      child: _adding
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Əlavə et'),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 20),
          ],

          Expanded(
            child: _fields.isEmpty
                ? const Center(child: Text('Sahə yoxdur'))
                : ListView.separated(
                    itemCount: _fields.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, index) {
                      final field = _fields[index];
                      return ListTile(
                        dense: true,
                        title: Text(field['name'] ?? '', overflow: TextOverflow.ellipsis),
                        subtitle: Text(field['field_type'] ?? '', style: const TextStyle(fontSize: 12)),
                        trailing: widget.isWriter
                            ? IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                onPressed: () => _removeField(field['id']),
                              )
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
