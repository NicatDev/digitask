import 'package:flutter/material.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:intl/intl.dart';

class TaskFormModal extends StatefulWidget {
  final Map<String, dynamic>? task;
  final List<dynamic> customers;
  final List<dynamic> users;
  final List<dynamic> groups;
  final List<dynamic> taskTypes;
  final List<dynamic> services;
  final VoidCallback onSuccess;

  const TaskFormModal({
    super.key,
    this.task,
    required this.customers,
    required this.users,
    required this.groups,
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
  late TextEditingController _noteCtrl;
  
  int? _customerId;
  List<int> _assigneeIds = [];
  int? _groupId;
  int? _taskTypeId;
  String _status = 'todo';
  DateTime? _rescheduledDate;
  bool _isActive = true;
  List<int> _selectedServices = [];
  
  bool _isSaving = false;

  final List<Map<String, String>> _statuses = [
    {'value': 'todo', 'label': 'Gözləyir'},
    {'value': 'in_progress', 'label': 'İcrada'},
    {'value': 'done', 'label': 'Bitib'},
    {'value': 'pending', 'label': 'Gözləmədə'},
    {'value': 'rejected', 'label': 'Rədd edilib'},
  ];

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _titleCtrl = TextEditingController(text: t?['title'] ?? '');
    _noteCtrl = TextEditingController(text: t?['note'] ?? '');
    
    _customerId = t?['customer'];
    
    if (t != null && t['group'] != null) {
       _groupId = t['group'] is Map ? t['group']['id'] : t['group'];
    }

    // Handle assigned_to as list of IDs (M2M)
    if (t != null && t['assigned_to'] is List) {
      _assigneeIds = List<int>.from(t['assigned_to']);
    }

    _taskTypeId = t?['task_type'];
    if (t != null && t['task_type'] is Map) {
       _taskTypeId = t['task_type']['id'];
    }

    _status = t?['status'] ?? 'todo';
    if (_status == 'arrived') {
      _status = 'in_progress';
    }
    _isActive = t?['is_active'] ?? true;

    if (t?['services'] != null) {
       _selectedServices = List<int>.from(t!['services']);
    }

    final rd = t?['rescheduled_date'];
    if (rd is String && rd.length >= 10) {
      _rescheduledDate = DateTime.tryParse(rd.substring(0, 10));
    }
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

  String _getCustomerLabel(int customerId) {
    final c = widget.customers.firstWhere(
      (c) => c['id'] == customerId,
      orElse: () => <String, dynamic>{},
    );
    if (c.isEmpty) return '';
    final name = c['full_name'] ?? 'Adsız';
    final regNum = c['register_number'];
    return regNum != null ? '$name - $regNum' : name;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_status == 'pending' && _rescheduledDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rescheduled date seçin')),
      );
      return;
    }
    setState(() => _isSaving = true);

    try {
      final data = <String, dynamic>{
        'title': _titleCtrl.text,
        'note': _noteCtrl.text,
        'status': _status,
        'is_active': _isActive,
        'customer': _customerId,
        'group': _groupId,
        'assigned_to': _assigneeIds,
        'task_type': _taskTypeId,
        'services': _selectedServices,
      };
      if (_status == 'pending' && _rescheduledDate != null) {
        data['rescheduled_date'] = DateFormat('yyyy-MM-dd').format(_rescheduledDate!);
      } else {
        data['rescheduled_date'] = null;
      }

      if (widget.task == null) {
        await ApiClient().dio.post('/tasks/tasks/', data: data);
      } else {
        await ApiClient().dio.patch('/tasks/tasks/${widget.task!['id']}/', data: data);
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.task == null ? 'Tapşırıq yaradıldı' : 'Tapşırıq yeniləndi')));
      }
    } catch (e) {
      if (mounted) {
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
                Text(widget.task == null ? 'Yeni Tapşırıq' : 'Tapşırığı Redaktə Et', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            Expanded(
              child: ListView(
                children: [
                  TextFormField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(labelText: 'Başlıq'),
                    validator: (v) => v!.isEmpty ? 'Tələb olunur' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _noteCtrl,
                    decoration: const InputDecoration(labelText: 'Qeyd'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  
                  // Status
                   DropdownButtonFormField<String>(
                    value: _status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: _statuses.map((s) => DropdownMenuItem(value: s['value'], child: Text(s['label']!))).toList(),
                    onChanged: (v) => setState(() {
                      _status = v!;
                      if (_status != 'pending') {
                        _rescheduledDate = null;
                      }
                    }),
                  ),
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
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Customer (searchable by name and register number)
                  Autocomplete<Map<String, dynamic>>(
                    initialValue: _customerId != null
                        ? TextEditingValue(text: _getCustomerLabel(_customerId!))
                        : null,
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      final query = textEditingValue.text.toLowerCase();
                      return widget.customers.cast<Map<String, dynamic>>().where((c) {
                        final name = (c['full_name'] ?? '').toString().toLowerCase();
                        final regNum = (c['register_number'] ?? '').toString().toLowerCase();
                        return name.contains(query) || regNum.contains(query);
                      });
                    },
                    displayStringForOption: (c) {
                      final name = c['full_name'] ?? 'Adsız';
                      final regNum = c['register_number'];
                      return regNum != null ? '$name - $regNum' : name;
                    },
                    onSelected: (c) => setState(() => _customerId = c['id']),
                    fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: 'Müştəri',
                          suffixIcon: Icon(Icons.search),
                        ),
                        validator: (v) => _customerId == null ? 'Tələb olunur' : null,
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(8),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 200),
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (context, index) {
                                final c = options.elementAt(index);
                                 final name = c['full_name'] ?? 'Adsız';
                                final regNum = c['register_number'];
                                return ListTile(
                                  title: Text(regNum != null ? '$name - $regNum' : name),
                                  onTap: () => onSelected(c),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Group
                  DropdownButtonFormField<int>(
                    value: _groupId,
                    decoration: const InputDecoration(labelText: 'Qrup/Zona'),
                    items: widget.groups.map((g) => DropdownMenuItem<int>(
                      value: g['id'], 
                      child: Text(g['name'] ?? 'Adsız'),
                    )).toList(),
                    onChanged: (v) => setState(() => _groupId = v),
                  ),
                  const SizedBox(height: 16),

                  // Task Type
                  DropdownButtonFormField<int>(
                    value: _taskTypeId,
                    decoration: const InputDecoration(labelText: 'Tapşırıq Tipi'),
                    items: widget.taskTypes.map((t) => DropdownMenuItem<int>(
                      value: t['id'], 
                      child: Text(t['name']),
                    )).toList(),
                    onChanged: (v) => setState(() => _taskTypeId = v),
                  ),
                   const SizedBox(height: 16),

                  // Assignees (Multi-select with chips)
                  const Text('İcraçılar', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: widget.users.where((u) => u['is_active'] == true).map((u) {
                      final isSelected = _assigneeIds.contains(u['id']);
                      final name = '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
                      return FilterChip(
                        label: Text(name.isNotEmpty ? name : (u['email'] ?? 'İstifadəçi')),
                        selected: isSelected,
                        onSelected: (val) {
                          setState(() {
                            if (val) {
                              _assigneeIds.add(u['id']);
                            } else {
                              _assigneeIds.remove(u['id']);
                            }
                          });
                        },
                        selectedColor: Colors.blue.shade100,
                        checkmarkColor: Colors.blue,
                      );
                    }).toList(),
                  ),

                   const SizedBox(height: 16),
                   // Services
                   const Text('Xidmətlər', style: TextStyle(fontWeight: FontWeight.bold)),
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

                   const SizedBox(height: 16),
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
                child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('Yadda Saxla'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
