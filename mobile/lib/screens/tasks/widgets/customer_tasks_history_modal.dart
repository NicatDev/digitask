import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile/core/api/api_client.dart';

/// Müştərinin bütün tapşırıqları — yalnız modal açılanda sorğu.
/// [taskId] və ya [customerId] — tək biri verilməlidir.
class CustomerTasksHistoryModal extends StatefulWidget {
  final int? taskId;
  final int? customerId;
  final String? customerName;

  const CustomerTasksHistoryModal({
    super.key,
    this.taskId,
    this.customerId,
    this.customerName,
  }) : assert(
          (taskId != null) ^ (customerId != null),
          'Either taskId or customerId must be set',
        );

  @override
  State<CustomerTasksHistoryModal> createState() => _CustomerTasksHistoryModalState();
}

class _CustomerTasksHistoryModalState extends State<CustomerTasksHistoryModal> {
  List<dynamic> _rows = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final String url;
      if (widget.customerId != null) {
        url = '/tasks/tasks/by-customer/?customer=${widget.customerId}';
      } else {
        url = '/tasks/tasks/${widget.taskId}/customer_tasks/';
      }
      final res = await ApiClient().dio.get(url);
      final data = res.data;
      if (data is List) {
        setState(() => _rows = data);
      } else {
        setState(() => _rows = []);
      }
    } catch (e) {
      setState(() => _error = 'Yüklənmədi');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.customerName != null && widget.customerName!.isNotEmpty
        ? 'Müştəri: ${widget.customerName}'
        : 'Tapşırıq tarixçəsi';

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 600),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!))
                      : _rows.isEmpty
                          ? const Center(child: Text('Tapşırıq yoxdur'))
                          : ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: _rows.length,
                              separatorBuilder: (_, __) => const Divider(),
                              itemBuilder: (ctx, i) {
                                final t = _rows[i] as Map<String, dynamic>;
                                final names = t['assigned_to_names'];
                                final assignStr = names is List && names.isNotEmpty
                                    ? names.join(', ')
                                    : '—';
                                final created = t['created_at'] != null
                                    ? DateFormat('dd.MM.yyyy HH:mm').format(DateTime.parse(t['created_at']))
                                    : '';
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            '#${t['id']}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              t['status_display']?.toString() ?? t['status']?.toString() ?? '',
                                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                                            ),
                                          ),
                                          Text(created, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        t['title']?.toString() ?? '',
                                        style: const TextStyle(fontWeight: FontWeight.w500),
                                      ),
                                      const SizedBox(height: 4),
                                      Text('İcraçılar: $assignStr', style: const TextStyle(fontSize: 13)),
                                    ],
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
