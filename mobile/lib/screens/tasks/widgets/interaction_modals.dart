import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile/core/api/api_client.dart';

// STATUS MODAL
class StatusModal extends StatefulWidget {
  final Map<String, dynamic> task;
  final VoidCallback onSuccess;

  const StatusModal({super.key, required this.task, required this.onSuccess});

  @override
  State<StatusModal> createState() => _StatusModalState();
}

class _StatusModalState extends State<StatusModal> {
  late String _status;
  DateTime? _rescheduledDate;
  bool _loading = false;

  final List<Map<String, String>> _statuses = [
    {'value': 'todo', 'label': 'Gözləyir', 'color': 'grey'},
    {'value': 'in_progress', 'label': 'İcrada', 'color': 'blue'},
    {'value': 'done', 'label': 'Bitib', 'color': 'green'},
    {'value': 'pending', 'label': 'Gözləmədə', 'color': 'red'},
    {'value': 'rejected', 'label': 'Rədd edilib', 'color': 'black'},
  ];

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is String) {
      return DateTime.tryParse(v.length >= 10 ? v.substring(0, 10) : v);
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final raw = widget.task['status'] ?? 'todo';
    _status = raw == 'arrived' ? 'in_progress' : raw.toString();
    _rescheduledDate = _parseDate(widget.task['rescheduled_date']);
  }

  Future<void> _pickRescheduledDate() async {
    final now = DateTime.now();
    final initial = _rescheduledDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() => _rescheduledDate = picked);
    }
  }

  Future<void> _updateStatus() async {
    if (_status == 'pending' && _rescheduledDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rescheduled date seçin')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final data = <String, dynamic>{'status': _status};
      if (_status == 'pending' && _rescheduledDate != null) {
        data['rescheduled_date'] = DateFormat('yyyy-MM-dd').format(_rescheduledDate!);
      }
      await ApiClient().dio.patch('/tasks/tasks/${widget.task['id']}/update_status/', data: data);
      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Status yeniləndi')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Status yenilənə bilmədi')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                margin: const EdgeInsets.only(bottom: 20),
              ),
            ),
            const Text('Statusu Yenilə', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ..._statuses.map((s) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                border: Border.all(color: _status == s['value'] ? Colors.blue : Colors.grey.shade200),
                borderRadius: BorderRadius.circular(12),
                color: _status == s['value'] ? Colors.blue.withOpacity(0.05) : Colors.transparent,
              ),
              child: RadioListTile<String>(
                title: Text(
                  s['label']!,
                  style: TextStyle(
                    fontWeight: _status == s['value'] ? FontWeight.bold : FontWeight.normal,
                    color: _status == s['value'] ? Colors.blue : Colors.black87,
                  ),
                ),
                value: s['value']!,
                groupValue: _status,
                activeColor: Colors.blue,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onChanged: (v) => setState(() {
                  _status = v!;
                  if (_status != 'pending') {
                    _rescheduledDate = null;
                  }
                }),
              ),
            )),
            if (_status == 'pending') ...[
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Rescheduled date', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  _rescheduledDate == null
                      ? 'Tarix seçin'
                      : DateFormat('yyyy-MM-dd').format(_rescheduledDate!),
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickRescheduledDate,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _updateStatus,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Statusu Yenilə', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}

// DELETE DIALOG
class DeleteTaskDialog extends StatelessWidget {
  final int taskId;
  final VoidCallback onSuccess;

  const DeleteTaskDialog({super.key, required this.taskId, required this.onSuccess});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tapşırığı Sil'),
      content: const Text('Bu tapşırığı silmək istədiyinizə əminsiniz?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Ləğv et')),
        TextButton(
          onPressed: () async {
            try {
              await ApiClient().dio.delete('/tasks/tasks/$taskId/');
              if (context.mounted) {
                Navigator.pop(context);
                onSuccess();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tapşırıq silindi')));
              }
            } catch (e) {
              // Error
            }
          },
          child: const Text('Sil', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }
}

// SURVEY MODAL (Placeholder)
class SurveyModal extends StatelessWidget {
  final Map<String, dynamic> task;
  const SurveyModal({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Anket', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          Text('Anket funksionallığı tezliklə əlavə olunacaq.'),
          // Implement fetching questions based on task columns
        ],
      ),
    );
  }
}

// FILES MODAL (Placeholder)
class FilesModal extends StatelessWidget {
  final Map<String, dynamic> task;
  const FilesModal({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      height: 400,
      child: const Column(
        children: [
           Text('Fayllar və Sənədlər', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
           SizedBox(height: 16),
           Text('Fayl siyahısı burada olacaq.'),
           // Access DocumentsScreen logic here? Or simple list
        ],
      ),
    );
  }
}

// PRODUCTS MODAL (Placeholder)
class ProductsModal extends StatelessWidget {
  final Map<String, dynamic> task;
  const ProductsModal({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      height: 400,
      child: const Column(
        children: [
           Text('Məhsullar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
           SizedBox(height: 16),
           Text('Məhsul seçimi tezliklə əlavə olunacaq.'),
        ],
      ),
    );
  }
}
