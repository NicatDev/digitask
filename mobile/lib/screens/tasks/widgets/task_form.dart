import 'package:flutter/material.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class TaskFormModal extends StatefulWidget {
  final Map<String, dynamic>? task;
  final List<dynamic> users;
  final List<dynamic> groups;
  final List<dynamic> taskTypes;
  final List<dynamic> services;
  final VoidCallback onSuccess;

  const TaskFormModal({
    super.key,
    this.task,
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
  String _customerLabel = '';
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
    _customerLabel = _formatCustomerLabel(
      t?['customer_name']?.toString(),
      t?['customer_register_number']?.toString(),
    );
    
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

    // If editing an older task payload without customer_name fields, fetch label lazily.
    if (_customerId != null && _customerLabel.isEmpty) {
      _ensureCustomerLabelLoaded();
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

  static String _formatCustomerLabel(String? name, String? regNum) {
    final n = (name ?? '').trim();
    final r = (regNum ?? '').trim();
    if (n.isEmpty) return '';
    if (r.isEmpty) return n;
    return '$n - $r';
  }

  Future<void> _ensureCustomerLabelLoaded() async {
    final id = _customerId;
    if (id == null || _customerLabel.isNotEmpty) return;
    try {
      final res = await ApiClient().dio.get('/tasks/customers/$id/');
      final data = res.data;
      if (!mounted) return;
      if (data is Map) {
        setState(() {
          _customerLabel = _formatCustomerLabel(
            data['full_name']?.toString(),
            data['register_number']?.toString(),
          );
        });
      }
    } catch (_) {}
  }

  Future<void> _pickCustomer() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _CustomerPickerSheet(),
    );
    if (result == null) return;
    setState(() {
      _customerId = result['id'] as int?;
      _customerLabel = (result['label'] ?? '').toString();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_customerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Müştəri seçin')),
      );
      return;
    }
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

  Future<void> _openCustomerAddressEditor() async {
    if (_customerId == null) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _TaskCustomerAddressModal(
        customerId: _customerId!,
        customerLabel: _customerLabel,
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Müştəri ünvanı yeniləndi')),
      );
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

                  if (widget.task != null && _status != 'todo' && _customerId != null) ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _openCustomerAddressEditor,
                        icon: const Icon(Icons.location_on),
                        label: const Text('Müştəri ünvanını redaktə et'),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Customer (searchable by name and register number)
                  InkWell(
                    onTap: _pickCustomer,
                    borderRadius: BorderRadius.circular(8),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Müştəri *',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.search),
                      ),
                      child: Text(
                        _customerLabel.isNotEmpty ? _customerLabel : 'Seçin',
                        style: TextStyle(
                          color: _customerLabel.isNotEmpty ? Colors.black : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  if (_customerId == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('Tələb olunur', style: TextStyle(color: Colors.red, fontSize: 12)),
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

class _CustomerPickerSheet extends StatefulWidget {
  const _CustomerPickerSheet();

  @override
  State<_CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _TaskCustomerAddressModal extends StatefulWidget {
  final int customerId;
  final String customerLabel;

  const _TaskCustomerAddressModal({
    required this.customerId,
    required this.customerLabel,
  });

  @override
  State<_TaskCustomerAddressModal> createState() => _TaskCustomerAddressModalState();
}

class _TaskCustomerAddressModalState extends State<_TaskCustomerAddressModal> {
  final _addressCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final _mapCtrl = MapController();

  LatLng _coords = const LatLng(40.4093, 49.8671);
  bool _loading = true;
  bool _saving = false;
  bool _searching = false;
  List<Map<String, dynamic>> _addressOptions = [];

  @override
  void initState() {
    super.initState();
    _loadCustomer();
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCustomer() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient().dio.get('/tasks/customers/${widget.customerId}/');
      final data = res.data;
      if (!mounted) return;
      _addressCtrl.text = (data['address'] ?? '').toString();
      final c = data['address_coordinates'];
      if (c is Map && c['lat'] != null && c['lng'] != null) {
        _coords = LatLng(
          double.parse(c['lat'].toString()),
          double.parse(c['lng'].toString()),
        );
      }
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _searchAddress(String q) async {
    if (q.trim().length < 3) {
      setState(() => _addressOptions = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final res = await ApiClient().dio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'format': 'json',
          'q': q.trim(),
          'limit': 5,
          'countrycodes': 'az',
        },
      );
      final list = (res.data as List)
          .map<Map<String, dynamic>>((e) => {
                'label': (e['display_name'] ?? '').toString(),
                'lat': double.parse(e['lat'].toString()),
                'lng': double.parse(e['lon'].toString()),
              })
          .toList();
      if (!mounted) return;
      setState(() => _addressOptions = list);
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _useMyLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lokasiya icazəsi verilməyib')),
        );
        return;
      }
      final p = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      final next = LatLng(p.latitude, p.longitude);
      setState(() => _coords = next);
      _mapCtrl.move(next, 16);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lokasiya tapılmadı')),
      );
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ApiClient().dio.patch('/tasks/customers/${widget.customerId}/', data: {
        'address': _addressCtrl.text.trim(),
        'address_coordinates': {
          'lat': _coords.latitude,
          'lng': _coords.longitude,
        }
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yenilənmə uğursuz oldu')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 760,
        height: 640,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Müştəri ünvanı: ${widget.customerLabel}',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    TextField(
                      controller: _addressCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Ünvan',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _searchCtrl,
                      onChanged: (v) {
                        Future.delayed(const Duration(milliseconds: 400), () {
                          if (!mounted) return;
                          if (_searchCtrl.text == v) _searchAddress(v);
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Ünvan axtar',
                        border: const OutlineInputBorder(),
                        suffixIcon: _searching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                              )
                            : const Icon(Icons.search),
                      ),
                    ),
                    if (_addressOptions.isNotEmpty)
                      Container(
                        constraints: const BoxConstraints(maxHeight: 130),
                        margin: const EdgeInsets.only(top: 6),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.builder(
                          itemCount: _addressOptions.length,
                          itemBuilder: (_, i) {
                            final o = _addressOptions[i];
                            return ListTile(
                              dense: true,
                              title: Text(
                                o['label'].toString(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () {
                                final next = LatLng(o['lat'] as double, o['lng'] as double);
                                setState(() {
                                  _coords = next;
                                  _addressCtrl.text = o['label'].toString();
                                  _addressOptions = [];
                                });
                                _mapCtrl.move(next, 16);
                              },
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _useMyLocation,
                        icon: const Icon(Icons.my_location),
                        label: const Text('Mənim lokasiyam'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: FlutterMap(
                          mapController: _mapCtrl,
                          options: MapOptions(
                            initialCenter: _coords,
                            initialZoom: 14,
                            onTap: (tapPosition, point) {
                              setState(() => _coords = point);
                            },
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.example.mobile',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: _coords,
                                  width: 40,
                                  height: 40,
                                  child: const Icon(Icons.location_on, color: Colors.red, size: 38),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Yadda saxla'),
                      ),
                    )
                  ],
                ),
              ),
      ),
    );
  }
}

class _CustomerPickerSheetState extends State<_CustomerPickerSheet> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<dynamic> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasNext = true;
  int _page = 1;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _fetch(page: 1, append: false);
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasNext || _loadingMore || _loading) return;
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 100) {
      _fetch(page: _page + 1, append: true);
    }
  }

  Future<void> _fetch({required int page, required bool append}) async {
    if (!append) {
      setState(() {
        _loading = true;
        _items = [];
        _page = 1;
        _hasNext = true;
      });
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final res = await ApiClient().dio.get(
        '/tasks/customers/options/',
        queryParameters: {
          'page': page,
          'page_size': 10,
          'search': _search.isEmpty ? null : _search,
          'is_active': 'true',
        },
      );
      final data = res.data;
      if (!mounted) return;
      if (data is Map && data.containsKey('results')) {
        final results = data['results'] as List;
        setState(() {
          _items = append ? [..._items, ...results] : results;
          _hasNext = data['next'] != null;
          _page = page;
        });
      }
    } catch (_) {
      if (!mounted) return;
      // keep previous items
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _onSearchChanged(String v) {
    _search = v.trim();
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      if (_searchCtrl.text.trim() == _search) {
        _fetch(page: 1, append: false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.85;
    return SizedBox(
      height: height,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Müştəri seçin',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                hintText: 'Ad soyad və ya qeydiyyat nömrəsi...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    controller: _scrollCtrl,
                    itemCount: _items.length + (_loadingMore ? 1 : 0),
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      if (_loadingMore && index == _items.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final c = _items[index];
                      final id = c['id'];
                      final label = c['label'] ?? c['full_name'] ?? '';
                      return ListTile(
                        title: Text(label.toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () => Navigator.pop(context, {
                          'id': id is int ? id : int.tryParse(id.toString()),
                          'label': label.toString(),
                        }),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
