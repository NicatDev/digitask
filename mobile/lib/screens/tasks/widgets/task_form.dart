import 'package:flutter/material.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:intl/intl.dart';

class TaskFormModal extends StatefulWidget {
  final Map<String, dynamic>? task;
  final List<dynamic> customers;
  final List<dynamic> users;
  final List<dynamic> groups; // Added
  final List<dynamic> taskTypes;
  final List<dynamic> services;
  final VoidCallback onSuccess;

  const TaskFormModal({
    super.key,
    this.task,
    required this.customers,
    required this.users,
    required this.groups, // Added
    required this.taskTypes,
    required this.services,
    required this.onSuccess,
  });

  @override
  State<TaskFormModal> createState() => _TaskFormModalState();
}

class _TaskFormModalState extends State<TaskFormModal> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _titleCtrl;
  late TextEditingController _noteCtrl; // Renamed from desc
  
  int? _customerId;
  int? _assigneeId;
  int? _groupId; // Added
  int? _taskTypeId;
  // DateTime? _deadline; // Removed
  String _status = 'todo';
  bool _isActive = true;
  List<int> _selectedServices = [];
  
  bool _isSaving = false;

  final List<Map<String, String>> _statuses = [
    {'value': 'todo', 'label': 'To Do'},
    {'value': 'in_progress', 'label': 'In Progress'},
    {'value': 'arrived', 'label': 'Arrived'}, // Order fixed
    {'value': 'done', 'label': 'Done'},
    {'value': 'pending', 'label': 'Pending'},
    {'value': 'rejected', 'label': 'Rejected'},
  ];

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _titleCtrl = TextEditingController(text: t?['title'] ?? '');
    _noteCtrl = TextEditingController(text: t?['note'] ?? ''); // Changed
    
    _customerId = t?['customer'];
    
    if (t != null && t['group'] != null) {
       _groupId = t['group'] is Map ? t['group']['id'] : t['group'];
    }

    // Handle if assigned_to is object or int
    _assigneeId = t?['assigned_to'];
    if (t != null && t['assigned_to'] is Map) {
       _assigneeId = t['assigned_to']['id'];
    }

    _taskTypeId = t?['task_type'];
    if (t != null && t['task_type'] is Map) {
       _taskTypeId = t['task_type']['id'];
    }

    _status = t?['status'] ?? 'todo';
    _isActive = t?['is_active'] ?? true;

    if (t?['services'] != null) {
       _selectedServices = List<int>.from(t!['services']);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final data = {
        'title': _titleCtrl.text,
        'note': _noteCtrl.text, // Changed
        'status': _status,
        'is_active': _isActive,
        'customer': _customerId,
        'group': _groupId, // Added
        'assigned_to': _assigneeId,
        'task_type': _taskTypeId,
        'services': _selectedServices,
      };
      
      // Removed end_date

      if (widget.task == null) {
        await ApiClient().dio.post('/tasks/tasks/', data: data);
      } else {
        await ApiClient().dio.patch('/tasks/tasks/${widget.task!['id']}/', data: data);
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.task == null ? 'Task Created' : 'Task Updated')));
      }
    } catch (e) {
      if (mounted) {
        // ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      height: MediaQuery.of(context).size.height * 0.9,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.task == null ? 'New Task' : 'Edit Task', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            Expanded(
              child: ListView(
                children: [
                  TextFormField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(labelText: 'Title'),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _noteCtrl,
                    decoration: const InputDecoration(labelText: 'Note'), // Changed
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  
                  // Status
                   DropdownButtonFormField<String>(
                    value: _status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: _statuses.map((s) => DropdownMenuItem(value: s['value'], child: Text(s['label']!))).toList(),
                    onChanged: (v) => setState(() => _status = v!),
                  ),
                  const SizedBox(height: 16),

                  // Customer
                  DropdownButtonFormField<int>(
                    value: _customerId,
                    decoration: const InputDecoration(labelText: 'Customer'),
                    items: widget.customers.map((c) => DropdownMenuItem<int>(
                      value: c['id'], 
                      child: Text(c['full_name'] ?? 'Unnamed', overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (v) => setState(() => _customerId = v),
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Group (Added)
                  DropdownButtonFormField<int>(
                    value: _groupId,
                    decoration: const InputDecoration(labelText: 'Group/Zone'),
                    items: widget.groups.map((g) => DropdownMenuItem<int>(
                      value: g['id'], 
                      child: Text(g['name'] ?? 'Unnamed'),
                    )).toList(),
                    onChanged: (v) => setState(() => _groupId = v),
                    validator: (v) => v == null ? 'Required' : null, // Group is usually mandatory
                  ),
                  const SizedBox(height: 16),

                  // Task Type
                  DropdownButtonFormField<int>(
                    value: _taskTypeId,
                    decoration: const InputDecoration(labelText: 'Task Type'),
                    items: widget.taskTypes.map((t) => DropdownMenuItem<int>(
                      value: t['id'], 
                      child: Text(t['name']),
                    )).toList(),
                    onChanged: (v) => setState(() => _taskTypeId = v),
                  ),
                   const SizedBox(height: 16),

                  // Assignee
                  DropdownButtonFormField<int>(
                    value: _assigneeId,
                    decoration: const InputDecoration(labelText: 'Assignee'),
                    items: widget.users.map((u) => DropdownMenuItem<int>(
                      value: u['id'], 
                      child: Text('${u['first_name']} ${u['last_name']}'),
                    )).toList(),
                    onChanged: (v) => setState(() => _assigneeId = v),
                  ),

                   const SizedBox(height: 16),
                   // Services
                   const Text('Services', style: TextStyle(fontWeight: FontWeight.bold)),
                   Wrap(
                     spacing: 8,
                     children: widget.services.map((s) {
                       final isSelected = _selectedServices.contains(s['id']);
                       return FilterChip(
                         label: Text(s['name']),
                         selected: isSelected,
                         onSelected: (val) {
                           setState(() {
                             if (val) {
                               _selectedServices.add(s['id']);
                             } else {
                               _selectedServices.remove(s['id']);
                             }
                           });
                         },
                       );
                     }).toList(),
                   ),

                   // Removed Deadline

                   const SizedBox(height: 16),
                   // Removed is_active

                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('Save Task'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
