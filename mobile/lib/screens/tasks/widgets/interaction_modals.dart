import 'package:flutter/material.dart';
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
  bool _loading = false;

  final List<Map<String, String>> _statuses = [
    {'value': 'todo', 'label': 'To Do', 'color': 'grey'},
    {'value': 'in_progress', 'label': 'In Progress', 'color': 'blue'},
    {'value': 'arrived', 'label': 'Arrived', 'color': 'purple'},
    {'value': 'done', 'label': 'Done', 'color': 'green'},
    {'value': 'pending', 'label': 'Pending', 'color': 'red'},
    {'value': 'rejected', 'label': 'Rejected', 'color': 'black'},
  ];

  @override
  void initState() {
    super.initState();
    _status = widget.task['status'] ?? 'todo';
  }

  Future<void> _updateStatus() async {
    setState(() => _loading = true);
    try {
      await ApiClient().dio.patch('/tasks/tasks/${widget.task['id']}/update_status/', data: {'status': _status});
      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Status updated')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update status')));
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
            const Text('Update Status', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                onChanged: (v) => setState(() => _status = v!),
              ),
            )).toList(),
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
                    : const Text('Update Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
      title: const Text('Delete Task'),
      content: const Text('Are you sure you want to delete this task?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: () async {
            try {
              await ApiClient().dio.delete('/tasks/tasks/$taskId/');
              if (context.mounted) {
                Navigator.pop(context);
                onSuccess();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task deleted')));
              }
            } catch (e) {
              // Error
            }
          },
          child: const Text('Delete', style: TextStyle(color: Colors.red)),
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
          Text('Survey (Anket)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          Text('Survey functionality coming soon.'),
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
           Text('Files & Documents', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
           SizedBox(height: 16),
           Text('File list implementation here.'),
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
           Text('Products', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
           SizedBox(height: 16),
           Text('Product selection coming soon.'),
        ],
      ),
    );
  }
}
