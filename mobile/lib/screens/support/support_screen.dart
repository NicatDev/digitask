import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/core/constants.dart';
import 'package:mobile/core/services/chat_service.dart';

final _imageUrlRe = RegExp(r'\.(jpe?g|png|gif|webp|bmp|svg)(\?.*)?$', caseSensitive: false);

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
      final qp = <String, dynamic>{};
      if (_statusFilter.isNotEmpty) {
        qp['status'] = _statusFilter;
      } else {
        qp['scope'] = 'active';
      }
      final res = await ApiClient().dio.get('/tasks/support-requests/', queryParameters: qp);
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

  Future<void> _showPastTasksDialog() async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('Yüklənir…')),
          ],
        ),
      ),
    );
    List<dynamic> past = [];
    try {
      final res = await ApiClient().dio.get(
        '/tasks/support-requests/',
        queryParameters: {'scope': 'past'},
      );
      final data = res.data;
      final list = (data is Map && data['results'] is List) ? data['results'] : data;
      past = list is List ? list : [];
    } catch (_) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Keçmiş müraciətlər yüklənmədi')),
        );
      }
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keçmiş müraciətlər'),
        content: SizedBox(
          width: double.maxFinite,
          child: past.isEmpty
              ? const Text('Keçmiş müraciət yoxdur')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: past.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final it = past[index] as Map<String, dynamic>;
                    return ListTile(
                      title: Text('#${it['id']} — ${it['title'] ?? ''}'),
                      subtitle: Text(it['status_display']?.toString() ?? it['status']?.toString() ?? ''),
                      onTap: () {
                        Navigator.pop(ctx);
                        _openDetail(it);
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Bağla')),
        ],
      ),
    );
  }

  void _openDetail(Map<String, dynamic> support) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _SupportRequestDetailDialog(
        initial: support,
        isAdmin: _isAdmin,
        currentUserId: ChatService().currentUser.value?.id,
        onListRefresh: _loadSupports,
      ),
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
                    DropdownMenuItem(value: 'closed', child: Text('Bağlandı')),
                  ],
                  onChanged: (v) {
                    setState(() => _statusFilter = v ?? '');
                    _loadSupports();
                  },
                ),
              ],
            ),
            TextButton.icon(
              onPressed: _showPastTasksDialog,
              icon: const Icon(Icons.history),
              label: const Text('Keçmiş tapşırıqlara bax'),
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

class _SupportRequestDetailDialog extends StatefulWidget {
  const _SupportRequestDetailDialog({
    required this.initial,
    required this.isAdmin,
    required this.currentUserId,
    required this.onListRefresh,
  });

  final Map<String, dynamic> initial;
  final bool isAdmin;
  final int? currentUserId;
  final VoidCallback onListRefresh;

  @override
  State<_SupportRequestDetailDialog> createState() => _SupportRequestDetailDialogState();
}

class _SupportRequestDetailDialogState extends State<_SupportRequestDetailDialog> {
  late Map<String, dynamic> _row;
  late List<dynamic> _comments;
  final _commentCtrl = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _row = Map<String, dynamic>.from(widget.initial);
    _comments = List<dynamic>.from(_row['comments'] as List? ?? []);
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  int get _id => (_row['id'] as num).toInt();

  bool get _canComment {
    if (widget.isAdmin) return true;
    final uid = widget.currentUserId;
    if (uid == null) return false;
    final cb = _row['created_by'];
    if (cb == null) return false;
    if (cb is num) return cb.toInt() == uid;
    return cb == uid;
  }

  String _resolveAttachmentUrl(dynamic raw) {
    if (raw == null) return '';
    final s = raw.toString().trim();
    if (s.isEmpty) return '';
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    final origin = Uri.parse(AppConstants.baseUrl).origin;
    final path = s.startsWith('/') ? s : '/$s';
    return '$origin$path';
  }

  Future<void> _patchStatus(String status, {String rejectNote = ''}) async {
    try {
      final res = await ApiClient().dio.patch('/tasks/support-requests/$_id/set_status/', data: {
        'status': status,
        'reject_note': rejectNote,
      });
      if (!mounted) return;
      final data = _mapFromResponse(res.data);
      if (data != null) {
        setState(() {
          _row = Map<String, dynamic>.from(data);
          _comments = List<dynamic>.from(data['comments'] as List? ?? []);
        });
      }
      widget.onListRefresh();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Status yeniləndi')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Status yenilənmədi')));
    }
  }

  Future<void> _showRejectReasonDialog() async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rədd səbəbi'),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 4,
          maxLength: 2000,
          decoration: const InputDecoration(
            hintText: 'Rədd etmə səbəbini yazın...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Ləğv et')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Təsdiq et')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final note = reasonCtrl.text.trim();
    if (note.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rədd səbəbi yazın')),
      );
      return;
    }
    await _patchStatus('rejected', rejectNote: note);
  }

  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ApiClient().dio.post('/tasks/support-requests/$_id/comment/', data: {'body': text});
      _commentCtrl.clear();
      if (!mounted) return;
      await _reloadDetailFromServer();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Şərh əlavə olundu')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Şərh göndərilə bilmədi')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Map<String, dynamic>? _mapFromResponse(dynamic data) {
    dynamic d = data;
    if (d is String) {
      try {
        d = jsonDecode(d) as Object?;
      } catch (_) {
        return null;
      }
    }
    if (d is Map<String, dynamic>) return Map<String, dynamic>.from(d);
    if (d is Map) {
      return d.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  Future<void> _reloadDetailFromServer() async {
    try {
      final res = await ApiClient().dio.get('/tasks/support-requests/$_id/');
      final map = _mapFromResponse(res.data);
      if (!mounted || map == null) return;
      setState(() {
        _row = Map<String, dynamic>.from(map);
        _comments = List<dynamic>.from(map['comments'] as List? ?? []);
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Müraciət yenilənmədi — siyahını yeniləyin')),
        );
      }
    }
  }

  String get _status => _row['status']?.toString() ?? '';

  @override
  Widget build(BuildContext context) {
    final attachmentRaw = _row['attachment'];
    final attachmentUrl =
        attachmentRaw != null && attachmentRaw.toString().isNotEmpty
            ? _resolveAttachmentUrl(attachmentRaw)
            : '';

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '#${_row['id']} - ${_row['title'] ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 6),
              Text('Status: ${_row['status_display'] ?? _status}'),
              const SizedBox(height: 10),
              Text('Qısa xülasə: ${_row['summary'] ?? ''}'),
              const SizedBox(height: 8),
              Text('İndiki vəziyyət: ${_row['current_state'] ?? ''}'),
              const SizedBox(height: 8),
              Text('Olmalı olan: ${_row['expected_state'] ?? ''}'),
              if ((_row['reject_note'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Rədd qeydi: ${_row['reject_note']}',
                  style: const TextStyle(color: Colors.red),
                ),
              ],
              if (attachmentUrl.isNotEmpty) ...[
                const SizedBox(height: 12),
                if (_imageUrlRe.hasMatch(attachmentUrl))
                  InkWell(
                    onTap: () async {
                      final u = Uri.parse(attachmentUrl);
                      if (await canLaunchUrl(u)) {
                        await launchUrl(u, mode: LaunchMode.externalApplication);
                      }
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        attachmentUrl,
                        height: 140,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Text('Şəkli aç'),
                      ),
                    ),
                  )
                else
                  TextButton.icon(
                    onPressed: () async {
                      final u = Uri.parse(attachmentUrl);
                      if (await canLaunchUrl(u)) {
                        await launchUrl(u, mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.attach_file),
                    label: const Text('Əlavə faylı aç'),
                  ),
              ],
              if (widget.isAdmin) ...[
                const SizedBox(height: 12),
                Text('Status idarəetməsi', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (_status == 'new')
                      FilledButton(
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _patchStatus('accepted'),
                        child: const Text('Qəbul et'),
                      ),
                    if (_status == 'accepted')
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF389E0D),
                          side: const BorderSide(color: Color(0xFF389E0D)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _patchStatus('solved'),
                        child: const Text('Həll edildi'),
                      ),
                    if (_status == 'solved')
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _patchStatus('closed'),
                        child: const Text('Bağla'),
                      ),
                    if (_status != 'rejected')
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _showRejectReasonDialog,
                        child: const Text('Rədd et'),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              const Text('Şərhlər', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Expanded(
                child: _comments.isEmpty
                    ? const Center(child: Text('Hələ şərh yoxdur', style: TextStyle(color: Colors.grey)))
                    : ListView.separated(
                        itemCount: _comments.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final raw = _comments[index];
                          final c = raw is Map<String, dynamic>
                              ? raw
                              : Map<String, dynamic>.from(raw as Map);
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
              if (_canComment)
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
                    FilledButton(
                      onPressed: _sending ? null : _sendComment,
                      child: _sending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Göndər'),
                    ),
                  ],
                )
              else
                const Text(
                  'Bu taska yalnız açan istifadəçi və adminlər şərh yaza bilər.',
                  style: TextStyle(color: Colors.orange, fontSize: 13),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
