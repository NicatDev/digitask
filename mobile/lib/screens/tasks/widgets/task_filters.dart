import 'package:flutter/material.dart';

class TaskFilterModal extends StatefulWidget {
  final List<dynamic> customers;
  final List<dynamic> users;
  final List<dynamic> groups;
  final String? status;
  final int? customerId;
  final int? groupId;
  final int? assigneeId;
  final String activeFilter;
  final Function(String? status, int? custId, int? groupId, int? assignId, String active) onApply;

  const TaskFilterModal({
    super.key,
    required this.customers,
    required this.users,
    this.groups = const [],
    this.status,
    this.customerId,
    this.groupId,
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
  int? _groupId;
  int? _assigneeId;
  String _active = 'active';

  final List<Map<String, String>> _statuses = [
    {'value': 'todo', 'label': 'Gözləyir'},
    {'value': 'in_progress', 'label': 'İcrada'},
    {'value': 'done', 'label': 'Tamamlandı'},
    {'value': 'pending', 'label': 'Təxirə salınmış'},
    {'value': 'rejected', 'label': 'Rədd edildi'},
  ];

  @override
  void initState() {
    super.initState();
    _status = widget.status;
    _customerId = widget.customerId;
    _groupId = widget.groupId;
    _assigneeId = widget.assigneeId;
    _active = widget.activeFilter;
  }

  void _reset() {
    setState(() {
      _status = null;
      _customerId = null;
      _groupId = null;
      _assigneeId = null;
      _active = 'active';
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
              const Text('Filtrlər', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              TextButton(onPressed: _reset, child: const Text('Sıfırla')),
            ],
          ),
          const SizedBox(height: 16),
          
          // Status
          DropdownButtonFormField<String>(
            value: _status,
            decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem(value: null, child: Text('Bütün Statuslar')),
              ..._statuses.map((s) => DropdownMenuItem(value: s['value'], child: Text(s['label']!))),
            ],
            onChanged: (v) => setState(() => _status = v),
          ),
          const SizedBox(height: 16),

          // Customer
          DropdownButtonFormField<int>(
            value: _customerId,
            decoration: const InputDecoration(labelText: 'Müştəri', border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem(value: null, child: Text('Bütün Müştərilər')),
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

          // Group
          DropdownButtonFormField<int>(
            value: _groupId,
            decoration: const InputDecoration(labelText: 'Qrup', border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem(value: null, child: Text('Bütün Qruplar')),
              ...widget.groups.map((g) => DropdownMenuItem<int>(
                value: g['id'], 
                child: Text(
                  _truncate(g['name'] ?? 'Unnamed', 25), 
                  overflow: TextOverflow.ellipsis
                )
              )),
            ],
            onChanged: (v) => setState(() => _groupId = v),
          ),
          const SizedBox(height: 16),

          // Assignee
          DropdownButtonFormField<int>(
            value: _assigneeId,
            decoration: const InputDecoration(labelText: 'Təhkim Olunmuş', border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem(value: null, child: Text('Bütün İstifadəçilər')),
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
            decoration: const InputDecoration(labelText: 'Aktiv Status', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('Hamısı')),
              DropdownMenuItem(value: 'active', child: Text('Yalnız Aktiv')),
              DropdownMenuItem(value: 'inactive', child: Text('Passiv')),
            ],
            onChanged: (v) => setState(() => _active = v!),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.onApply(_status, _customerId, _groupId, _assigneeId, _active);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 16),
                foregroundColor: Colors.white,
              ),
              child: const Text('Filtrləri Tətbiq Et'),
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
