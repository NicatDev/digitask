import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/core/services/chat_service.dart';
import 'package:mobile/models/user_model.dart';
import 'package:mobile/screens/users/list_utils.dart';

class UsersTab extends StatefulWidget {
  const UsersTab({super.key});

  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab> {
  List<dynamic> _users = [];
  List<dynamic> _roles = [];
  List<dynamic> _groups = [];
  bool _loading = true;

  final TextEditingController _searchController = TextEditingController();
  String _debouncedSearch = '';
  Timer? _debounce;

  String? _roleFilterName;
  String? _groupFilterName;
  Object _statusFilter = 'all';
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _load();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() => _debouncedSearch = _searchController.text.trim());
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final client = ApiClient().dio;
      final usersRes = await client.get('/users/');
      final rolesRes = await client.get('/roles/');
      final groupsRes = await client.get('/groups/');
      if (!mounted) return;
      setState(() {
        _users = unwrapApiList(usersRes.data);
        _roles = unwrapApiList(rolesRes.data);
        _groups = unwrapApiList(groupsRes.data);
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('İstifadəçiləri yükləmək mümkün olmadı: $e')),
        );
      }
    }
  }

  Future<void> _maybeRefreshCurrentUser(int userId) async {
    final me = ChatService().currentUser.value;
    if (me == null || me.id != userId) return;
    try {
      final res = await ApiClient().dio.get('/users/me/');
      if (res.statusCode == 200 && mounted) {
        ChatService().setCurrentUser(User.fromJson(res.data));
      }
    } catch (_) {}
  }

  List<dynamic> _filtered() {
    final q = _debouncedSearch.toLowerCase();
    return _users.where((item) {
      if (item is! Map) return false;
      final username = (item['username'] ?? '').toString().toLowerCase();
      final email = (item['email'] ?? '').toString().toLowerCase();
      final fn = (item['first_name'] ?? '').toString().toLowerCase();
      final ln = (item['last_name'] ?? '').toString().toLowerCase();
      final matchSearch = q.isEmpty ||
          username.contains(q) ||
          email.contains(q) ||
          fn.contains(q) ||
          ln.contains(q);
      final roleName = item['role_name']?.toString();
      final groupName = item['group_name']?.toString();
      final matchRole =
          _roleFilterName == null || roleName == _roleFilterName;
      final matchGroup =
          _groupFilterName == null || groupName == _groupFilterName;
      final active = item['is_active'] == true;
      final matchStatus = _statusFilter == 'all'
          ? true
          : _statusFilter == true
              ? active
              : !active;
      return matchSearch && matchRole && matchGroup && matchStatus;
    }).toList();
  }

  Future<void> _deleteUser(int id) async {
    try {
      await ApiClient().dio.delete('/users/$id/');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İstifadəçi silindi')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Silinmə uğursuz oldu: $e')),
        );
      }
    }
  }

  Future<void> _uploadAvatar(int userId, XFile image) async {
    try {
      var fileName = image.name;
      if (fileName.isEmpty || !fileName.contains('.')) {
        fileName = image.path.split(RegExp(r'[/\\]')).last;
        if (!fileName.contains('.')) fileName = '$fileName.jpg';
      }
      final bytes = await image.readAsBytes();
      final formData = FormData.fromMap({
        'avatar': MultipartFile.fromBytes(bytes, filename: fileName),
      });
      await ApiClient().dio.patch('/users/$userId/', data: formData);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avatar yeniləndi')),
        );
        await _maybeRefreshCurrentUser(userId);
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Avatar yenilənmədi: $e')),
        );
      }
    }
  }

  Future<void> _pickAvatar(int userId) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) await _uploadAvatar(userId, image);
  }

  void _confirmDelete(int id) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Silmək'),
        content: const Text('Silmək istədiyinizə əminsiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Ləğv')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteUser(id);
            },
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _openUserForm({Map<String, dynamic>? existing}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _UserFormSheet(
        roles: _roles,
        groups: _groups,
        existing: existing,
        onSuccess: () {
          Navigator.pop(ctx);
          _load();
        },
      ),
    );
  }

  void _openPasswordSheet(int userId) {
    final pass = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(ctx).bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Şifrəni dəyiş', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: pass,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Yeni şifrə *'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                if (pass.text.isEmpty) return;
                try {
                  await ApiClient().dio.post(
                    '/users/$userId/change_password/',
                    data: {'password': pass.text},
                  );
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Şifrə dəyişdirildi')),
                    );
                    Navigator.pop(ctx);
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Şifrə dəyişimi uğursuz oldu: $e')),
                    );
                  }
                }
              },
              child: const Text('Yenilə'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final list = _filtered();

    return Column(
      children: [
        Material(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Axtar (ad, email)...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    if (narrow)
                      IconButton(
                        icon: Icon(_showFilters ? Icons.filter_alt : Icons.filter_alt_outlined),
                        onPressed: () => setState(() => _showFilters = !_showFilters),
                      ),
                  ],
                ),
                if (!narrow || _showFilters) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    value: _roleFilterName,
                    decoration: const InputDecoration(labelText: 'Rol', isDense: true),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('Hamısı')),
                      ..._roles.map((r) {
                        final name = (r as Map)['name']?.toString() ?? '';
                        return DropdownMenuItem<String?>(value: name, child: Text(name));
                      }),
                    ],
                    onChanged: (v) => setState(() => _roleFilterName = v),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    value: _groupFilterName,
                    decoration: const InputDecoration(labelText: 'Qrup', isDense: true),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('Hamısı')),
                      ..._groups.map((g) {
                        final name = (g as Map)['name']?.toString() ?? '';
                        return DropdownMenuItem<String?>(value: name, child: Text(name));
                      }),
                    ],
                    onChanged: (v) => setState(() => _groupFilterName = v),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<Object>(
                    value: _statusFilter,
                    decoration: const InputDecoration(labelText: 'Status', isDense: true),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('Hamısı')),
                      DropdownMenuItem(value: true, child: Text('Aktiv')),
                      DropdownMenuItem(value: false, child: Text('Deaktiv')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _statusFilter = v);
                    },
                  ),
                ],
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _openUserForm(),
                    icon: const Icon(Icons.person_add_outlined),
                    label: const Text('Yeni istifadəçi'),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: list.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 120),
                            Center(child: Text('Məlumat yoxdur')),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: list.length,
                          itemBuilder: (context, i) {
                            final item = list[i] as Map<String, dynamic>;
                            final id = item['id'] as int;
                            final avatarUrl = item['avatar']?.toString();
                            return Card(
                              color: Colors.white,
                              surfaceTintColor: Colors.white,
                              elevation: 1,
                              clipBehavior: Clip.antiAlias,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        GestureDetector(
                                          onTap: () => _pickAvatar(id),
                                          child: Stack(
                                            clipBehavior: Clip.none,
                                            children: [
                                              CircleAvatar(
                                                radius: 28,
                                                backgroundImage: avatarUrl != null &&
                                                        avatarUrl.isNotEmpty
                                                    ? NetworkImage(avatarUrl)
                                                    : null,
                                                child: avatarUrl == null || avatarUrl.isEmpty
                                                    ? const Icon(Icons.person)
                                                    : null,
                                              ),
                                              Positioned(
                                                right: -2,
                                                bottom: -2,
                                                child: Material(
                                                  color: Colors.white,
                                                  shape: const CircleBorder(),
                                                  child: Icon(
                                                    Icons.edit,
                                                    size: 16,
                                                    color: Theme.of(context).colorScheme.primary,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item['username']?.toString() ?? '',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              Text(item['email']?.toString() ?? ''),
                                              if (item['phone_number'] != null &&
                                                  '${item['phone_number']}'.isNotEmpty)
                                                Text(item['phone_number'].toString()),
                                              Text(
                                                'Rol: ${item['role_name'] ?? '—'}  |  Qrup: ${item['group_name'] ?? '—'}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        TextButton(
                                          onPressed: () => _openUserForm(existing: item),
                                          child: const Text('Düzəliş'),
                                        ),
                                        TextButton(
                                          onPressed: () => _openPasswordSheet(id),
                                          child: const Text('Şifrə'),
                                        ),
                                        TextButton(
                                          onPressed: () => _confirmDelete(id),
                                          child: const Text('Sil', style: TextStyle(color: Colors.red)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }
}

class _UserFormSheet extends StatefulWidget {
  const _UserFormSheet({
    required this.roles,
    required this.groups,
    required this.existing,
    required this.onSuccess,
  });

  final List<dynamic> roles;
  final List<dynamic> groups;
  final Map<String, dynamic>? existing;
  final VoidCallback onSuccess;

  @override
  State<_UserFormSheet> createState() => _UserFormSheetState();
}

class _UserFormSheetState extends State<_UserFormSheet> {
  late final TextEditingController _username;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _password;
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  int? _roleId;
  int? _groupId;
  late bool _createActive;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _username = TextEditingController(text: e?['username']?.toString() ?? '');
    _email = TextEditingController(text: e?['email']?.toString() ?? '');
    _phone = TextEditingController(text: e?['phone_number']?.toString() ?? '');
    _password = TextEditingController();
    _firstName = TextEditingController(text: e?['first_name']?.toString() ?? '');
    _lastName = TextEditingController(text: e?['last_name']?.toString() ?? '');
    _roleId = asApiIntId(e?['role']);
    _groupId = asApiIntId(e?['group']);
    _createActive = e?['is_active'] == true || e == null;
  }

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _firstName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_username.text.isEmpty || _email.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İstifadəçi adı və email mütləqdir')),
      );
      return;
    }
    if (widget.existing == null && _password.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Şifrə mütləqdir')),
      );
      return;
    }
    setState(() => _submitting = true);
    final data = <String, dynamic>{
      'username': _username.text,
      'email': _email.text,
      'phone_number': _phone.text.isEmpty ? null : _phone.text,
      'first_name': _firstName.text.isEmpty ? null : _firstName.text,
      'last_name': _lastName.text.isEmpty ? null : _lastName.text,
      'role': _roleId,
      'group': _groupId,
    };
    if (widget.existing == null) {
      data['password'] = _password.text;
      data['is_active'] = _createActive;
    }
    try {
      if (widget.existing == null) {
        await ApiClient().dio.post('/users/', data: data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('İstifadəçi yaradıldı')),
          );
        }
      } else {
        await ApiClient().dio.put('/users/${widget.existing!['id']}/', data: data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('İstifadəçi yeniləndi')),
          );
        }
      }
      if (mounted) widget.onSuccess();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Əməliyyat uğursuz oldu: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final existing = widget.existing;
    return Padding(
      padding: EdgeInsets.only(
        bottom: bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              existing == null ? 'Yeni İstifadəçi' : 'İstifadəçiyə düzəliş',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _username,
              decoration: const InputDecoration(labelText: 'İstifadəçi adı *'),
            ),
            TextField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email *'),
              keyboardType: TextInputType.emailAddress,
            ),
            TextField(
              controller: _phone,
              decoration: const InputDecoration(labelText: 'Telefon nömrəsi'),
            ),
            if (existing == null)
              TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Şifrə *'),
              ),
            TextField(
              controller: _firstName,
              decoration: const InputDecoration(labelText: 'Ad'),
            ),
            TextField(
              controller: _lastName,
              decoration: const InputDecoration(labelText: 'Soyad'),
            ),
            DropdownButtonFormField<int?>(
              value: _roleId,
              decoration: const InputDecoration(labelText: 'Rol'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('—')),
                ...widget.roles.map((r) {
                  final m = r as Map;
                  return DropdownMenuItem<int?>(
                    value: asApiIntId(m['id']),
                    child: Text('${m['name']}'),
                  );
                }),
              ],
              onChanged: (v) => setState(() => _roleId = v),
            ),
            DropdownButtonFormField<int?>(
              value: _groupId,
              decoration: const InputDecoration(labelText: 'Qrup'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('—')),
                ...widget.groups.map((g) {
                  final m = g as Map;
                  return DropdownMenuItem<int?>(
                    value: asApiIntId(m['id']),
                    child: Text('${m['name']}'),
                  );
                }),
              ],
              onChanged: (v) => setState(() => _groupId = v),
            ),
            if (existing == null) ...[
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('Aktiv'),
                value: _createActive,
                onChanged: (v) => setState(() => _createActive = v),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Təsdiqlə'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
