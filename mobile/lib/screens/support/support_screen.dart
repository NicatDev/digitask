import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/core/services/chat_service.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _titleCtrl = TextEditingController();
  final _summaryCtrl = TextEditingController();
  final _currentCtrl = TextEditingController();
  final _expectedCtrl = TextEditingController();

  final _commentCtrl = TextEditingController();
  final _rejectCtrl = TextEditingController();

  List<dynamic> _items = [];
  bool _loading = true;
  bool _saving = false;
  XFile? _pickedImage;
  String _statusFilter = '';

  @override
  void initState() {
    super.initState();
    _loadSupports();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _summaryCtrl.dispose();
    _currentCtrl.dispose();
    _expectedCtrl.dispose();
    _commentCtrl.dispose();
    _rejectCtrl.dispose();
    super.dispose();
  }

  bool get _isAdmin {
    final u = ChatService().currentUser.value;
    if (u == null) return false;
    return u.isAdmin || u.isSuperAdmin;
  }

  Future<void> _loadSupports() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient().dio.get(
        '/tasks/support-requests/',
        queryParameters: _statusFilter.isEmpty ? null : {'status': _statusFilter},
      );
      final data = res.data;
      final list = (data is Map && data['results'] is List) ? data['results'] : data;
      setState(() => _items = list is List ? list : []);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Supportlar yüklənmədi')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickFile() async {
    final result = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (result == null) return;
    setState(() => _pickedImage = result);
  }

  Future<void> _createSupport() async {
    if (_titleCtrl.text.trim().isEmpty ||
        _summaryCtrl.text.trim().isEmpty ||
        _currentCtrl.text.trim().isEmpty ||
        _expectedCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bütün məcburi sahələri doldurun')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final formData = FormData.fromMap({
        'title': _titleCtrl.text.trim(),
        'summary': _summaryCtrl.text.trim(),
        'current_state': _currentCtrl.text.trim(),
        'expected_state': _expectedCtrl.text.trim(),
        if (_pickedImage != null)
          'attachment': await MultipartFile.fromFile(
            _pickedImage!.path,
            filename: _pickedImage!.name,
          ),
      });
      await ApiClient().dio.post('/tasks/support-requests/', data: formData);
      _titleCtrl.clear();
      _summaryCtrl.clear();
      _currentCtrl.clear();
      _expectedCtrl.clear();
      setState(() => _pickedImage = null);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Support müraciəti yaradıldı')),
      );
      _loadSupports();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Support yaradıla bilmədi')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setStatus(int id, String status) async {
    if (status == 'rejected' && _rejectCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reject səbəbini yazın')),
      );
      return;
    }
    try {
      await ApiClient().dio.patch('/tasks/support-requests/$id/set_status/', data: {
        'status': status,
        'reject_note': status == 'rejected' ? _rejectCtrl.text.trim() : '',
      });
      _rejectCtrl.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Status yeniləndi')),
      );
      _loadSupports();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Status yenilənmədi')),
      );
    }
  }

  Future<void> _sendComment(int id) async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    try {
      await ApiClient().dio.post('/tasks/support-requests/$id/comment/', data: {'body': text});
      _commentCtrl.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Şərh əlavə olundu')),
      );
      _loadSupports();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Şərh göndərilə bilmədi')),
      );
    }
  }

  void _openDetail(Map<String, dynamic> support) {
    final currentUserId = ChatService().currentUser.value?.id;
    final canComment = _isAdmin || support['created_by'] == currentUserId;
    showDialog(
      context: context,
      builder: (ctx) {
        final comments = (support['comments'] as List?) ?? [];
        return Dialog(
          child: SizedBox(
            width: 760,
            height: 680,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '#${support['id']} - ${support['title'] ?? ''}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ),
                      IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Status: ${support['status_display'] ?? support['status'] ?? ''}'),
                  const SizedBox(height: 10),
                  Text('Qısa xülasə: ${support['summary'] ?? ''}'),
                  const SizedBox(height: 8),
                  Text('İndiki vəziyyət: ${support['current_state'] ?? ''}'),
                  const SizedBox(height: 8),
                  Text('Olmalı olan: ${support['expected_state'] ?? ''}'),
                  if ((support['reject_note'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Reject qeydi: ${support['reject_note']}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (_isAdmin) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(onPressed: () => _setStatus(support['id'], 'accepted'), child: const Text('Accept')),
                        OutlinedButton(onPressed: () => _setStatus(support['id'], 'done'), child: const Text('Done')),
                        OutlinedButton(onPressed: () => _setStatus(support['id'], 'solved'), child: const Text('Solved')),
                        OutlinedButton(onPressed: () => _setStatus(support['id'], 'closed'), child: const Text('Closed')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _rejectCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Reject səbəbi',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => _setStatus(support['id'], 'rejected'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          child: const Text('Reject'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  const Text('Şərhlər', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: comments.isEmpty
                        ? const Center(child: Text('Hələ şərh yoxdur'))
                        : ListView.separated(
                            itemCount: comments.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (_, index) {
                              final c = comments[index] as Map<String, dynamic>;
                              return Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c['user_name']?.toString() ?? '',
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(c['body']?.toString() ?? ''),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 8),
                  if (canComment)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Şərh yazın',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => _sendComment(support['id'] as int),
                          child: const Text('Göndər'),
                        ),
                      ],
                    )
                  else
                    const Text(
                      'Bu taska yalnız açan istifadəçi və adminlər şərh yaza bilər.',
                      style: TextStyle(color: Colors.orange),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSupportCard(Map<String, dynamic> item) {
    return Card(
      child: ListTile(
        onTap: () => _openDetail(item),
        title: Text('#${item['id']} - ${item['title'] ?? ''}'),
        subtitle: Text(item['summary']?.toString() ?? ''),
        trailing: Text(item['status_display']?.toString() ?? item['status']?.toString() ?? ''),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Support')),
      body: RefreshIndicator(
        onRefresh: _loadSupports,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Supporta müraciət et', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Başlıq', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _summaryCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Qısa xülasə', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _currentCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'İndiki vəziyyət', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _expectedCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Olmalı olan', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.attach_file),
              label: Text(_pickedImage == null ? 'Şəkil əlavə et' : _pickedImage!.name),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _saving ? null : _createSupport,
              child: _saving ? const CircularProgressIndicator() : const Text('Təsdiqlə'),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(
                  child: Text('Support taskları', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                DropdownButton<String>(
                  value: _statusFilter.isEmpty ? null : _statusFilter,
                  hint: const Text('Status'),
                  items: const [
                    DropdownMenuItem(value: 'new', child: Text('Yeni')),
                    DropdownMenuItem(value: 'accepted', child: Text('Qəbul edildi')),
                    DropdownMenuItem(value: 'rejected', child: Text('Rədd edildi')),
                    DropdownMenuItem(value: 'done', child: Text('Done')),
                    DropdownMenuItem(value: 'solved', child: Text('Solved')),
                    DropdownMenuItem(value: 'closed', child: Text('Closed')),
                  ],
                  onChanged: (v) {
                    setState(() => _statusFilter = v ?? '');
                    _loadSupports();
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            else if (_items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Support taskı yoxdur'),
              )
            else
              ..._items.map((e) => _buildSupportCard(e as Map<String, dynamic>)),
          ],
        ),
      ),
    );
  }
}
