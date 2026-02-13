import 'package:flutter/material.dart';

class TaskFilterModal extends StatefulWidget {
  final List<dynamic> customers;
  final List<dynamic> users;
  final String? status;
  final int? customerId;
  final int? assigneeId;
  final String activeFilter;
  final Function(String? status, int? custId, int? assignId, String active) onApply;

  const TaskFilterModal({
    super.key,
    required this.customers,
    required this.users,
    this.status,
    this.customerId,
    this.assigneeId,
    required this.activeFilter,
    required this.onApply,
  });

  @override
  State<TaskFilterModal> createState() => _TaskFilterModalState();
}

class _TaskFilterModalState extends State<TaskFilterModal> {
  String? _status;
  int? _customerId;
  int? _assigneeId;
  String _active = 'all';

  final List<Map<String, String>> _statuses = [
    {'value': 'todo', 'label': 'To Do'},
    {'value': 'in_progress', 'label': 'In Progress'},
    {'value': 'arrived', 'label': 'Arrived'},
    {'value': 'done', 'label': 'Done'},
    {'value': 'pending', 'label': 'Pending'},
    {'value': 'rejected', 'label': 'Rejected'},
  ];

  @override
  void initState() {
    super.initState();
    _status = widget.status;
    _customerId = widget.customerId;
    _assigneeId = widget.assigneeId;
    _active = widget.activeFilter;
  }

  void _reset() {
    setState(() {
      _status = null;
      _customerId = null;
      _assigneeId = null;
      _active = 'all';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Filters', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              TextButton(onPressed: _reset, child: const Text('Reset')),
            ],
          ),
          const SizedBox(height: 16),
          
          // Status
          DropdownButtonFormField<String>(
            value: _status,
            decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem(value: null, child: Text('All Statuses')),
              ..._statuses.map((s) => DropdownMenuItem(value: s['value'], child: Text(s['label']!))),
            ],
            onChanged: (v) => setState(() => _status = v),
          ),
          const SizedBox(height: 16),

          // Customer
          DropdownButtonFormField<int>(
            value: _customerId,
            decoration: const InputDecoration(labelText: 'Customer', border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem(value: null, child: Text('All Customers')),
              ...widget.customers.map((c) => DropdownMenuItem<int>(
                value: c['id'], 
                child: Text(
                  _truncate(c['full_name'] ?? 'Unnamed', 25), 
                  overflow: TextOverflow.ellipsis
                )
              )),
            ],
            onChanged: (v) => setState(() => _customerId = v),
          ),
          const SizedBox(height: 16),

          // Assignee
          DropdownButtonFormField<int>(
            value: _assigneeId,
            decoration: const InputDecoration(labelText: 'Assignee', border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem(value: null, child: Text('All Users')),
              ...widget.users.map((u) => DropdownMenuItem<int>(
                value: u['id'], 
                child: Text('${u['first_name']} ${u['last_name']}')
              )),
            ],
            onChanged: (v) => setState(() => _assigneeId = v),
          ),
          const SizedBox(height: 16),

          // Active
          DropdownButtonFormField<String>(
            value: _active,
            decoration: const InputDecoration(labelText: 'Active Status', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All')),
              DropdownMenuItem(value: 'active', child: Text('Active Only')),
              DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
            ],
            onChanged: (v) => setState(() => _active = v!),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.onApply(_status, _customerId, _assigneeId, _active);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 16),
                foregroundColor: Colors.white,
              ),
              child: const Text('Apply Filters'),
            ),
          ),
        ],
      ),
    );
  }

  String _truncate(String str, int len) {
    if (str.length <= len) return str;
    return '${str.substring(0, len)}...';
  }
}
