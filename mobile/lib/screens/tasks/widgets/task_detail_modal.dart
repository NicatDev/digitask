import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/core/constants.dart';
import 'package:mobile/core/services/chat_service.dart';
import 'package:mobile/screens/tasks/widgets/assignee_modal.dart';
import 'package:mobile/screens/tasks/widgets/task_display_helpers.dart';
import 'package:mobile/screens/tasks/widgets/customer_tasks_history_modal.dart';
import 'package:mobile/screens/chat/task_message_codec.dart';
import 'package:mobile/screens/tasks/widgets/files_modal.dart';
import 'package:mobile/screens/tasks/widgets/interaction_modals.dart' hide SurveyModal, FilesModal, ProductsModal;
import 'package:mobile/screens/tasks/widgets/products_modal.dart';
import 'package:mobile/screens/tasks/widgets/survey_modal.dart';

final _imageUrlRe = RegExp(r'\.(jpe?g|png|gif|webp|bmp|svg)(\?.*)?$', caseSensitive: false);

class TaskDetailModal extends StatefulWidget {
  final Map<String, dynamic> task;
  final List<dynamic> allServices;
  final List<dynamic> allUsers;
  final VoidCallback? onEdit;
  final VoidCallback? onRefresh;
  final VoidCallback? onArchivedMarked;
  final bool canEditGeneral;
  final bool canDelete;
  final bool canChangeStatus;
  final bool canManageProducts;
  final bool canManageDocuments;
  final bool canManageSurveys;
  final bool canManageAssignees;
  final bool canJoinTask;
  final bool canMarkExternalArchived;
  final bool canCommentActivity;

  const TaskDetailModal({
    super.key,
    required this.task,
    this.allServices = const [],
    this.allUsers = const [],
    this.onEdit,
    this.onRefresh,
    this.onArchivedMarked,
    this.canEditGeneral = false,
    this.canDelete = false,
    this.canChangeStatus = false,
    this.canManageProducts = false,
    this.canManageDocuments = false,
    this.canManageSurveys = false,
    this.canManageAssignees = false,
    this.canJoinTask = false,
    this.canMarkExternalArchived = false,
    this.canCommentActivity = false,
  });

  @override
  State<TaskDetailModal> createState() => _TaskDetailModalState();
}

class _TaskDetailModalState extends State<TaskDetailModal> {
  List<dynamic> _activities = [];
  bool _actLoading = true;
  final _commentCtrl = TextEditingController();
  bool _sending = false;

  int get _taskId => widget.task['id'] as int;

  @override
  void initState() {
    super.initState();
    _loadActivity();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadActivity() async {
    setState(() => _actLoading = true);
    try {
      final res = await ApiClient().dio.get('/tasks/tasks/$_taskId/activity/');
      final data = res.data;
      if (data is List) {
        setState(() => _activities = data);
      } else {
        setState(() => _activities = []);
      }
    } catch (_) {
      setState(() => _activities = []);
    } finally {
      if (mounted) setState(() => _actLoading = false);
    }
  }

  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      final res = await ApiClient().dio.post('/tasks/tasks/$_taskId/activity/', data: {'body': text});
      _commentCtrl.clear();
      if (mounted && res.data is Map<String, dynamic>) {
        setState(() {
          _activities = [res.data as Map<String, dynamic>, ..._activities];
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Şərh əlavə olundu')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Göndərilmədi')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _markExternalArchived() async {
    try {
      await ApiClient().dio.post('/tasks/tasks/$_taskId/mark-external-archived/');
      if (!mounted) return;
      setState(() {
        widget.task['is_externally_archived'] = true;
      });
      widget.onArchivedMarked?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Məlumatlar əlaqəli platformalara köçürüldü')),
      );
      _loadActivity();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Arxivləşdirmə uğursuz oldu')),
      );
    }
  }

  String _resolveMediaUrl(dynamic raw) {
    if (raw == null) return '';
    final s = raw.toString().trim();
    if (s.isEmpty) return '';
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    final origin = AppConstants.baseUrl.replaceFirst(RegExp(r'/api\$'), '');
    final path = s.startsWith('/') ? s : '/$s';
    return '$origin$path';
  }

  Future<void> _launchMediaUrl(String url) async {
    if (url.isEmpty) return;
    final u = Uri.parse(url);
    if (await canLaunchUrl(u)) {
      await launchUrl(u, mode: LaunchMode.externalApplication);
    }
  }

  List<Widget> _buildMediaSection(Map<String, dynamic> task) {
    final images = <Map<String, String>>[];
    final files = <Map<String, String>>[];

    final taskServicesRaw = task['task_services'];
    if (taskServicesRaw is List) {
      for (final ts in taskServicesRaw) {
        if (ts is! Map) continue;
        final serviceName = ts['service_name']?.toString() ?? 'Xidmət';
        final values = ts['values'];
        if (values is! List) continue;
        for (final v in values) {
          if (v is! Map) continue;
          final colName = v['column_name'] ?? v['column_key'] ?? 'Sahə';
          final colType = v['column_type']?.toString() ?? '';
          final val = v['value'];
          if (val == null || val.toString().isEmpty) continue;
          final url = _resolveMediaUrl(val);
          if (url.isEmpty) continue;
          final label = '$serviceName — $colName';
          if (colType == 'image' || _imageUrlRe.hasMatch(val.toString())) {
            images.add({'url': url, 'label': label});
          } else if (colType == 'file') {
            files.add({'url': url, 'label': label});
          }
        }
      }
    }

    final docs = task['task_documents'];
    if (docs is List) {
      for (final d in docs) {
        if (d is! Map) continue;
        final raw = d['file_url'] ?? d['file'];
        if (raw == null || raw.toString().isEmpty) continue;
        final url = _resolveMediaUrl(raw);
        final title = d['title']?.toString() ?? d['name']?.toString() ?? 'Sənəd';
        if (_imageUrlRe.hasMatch(url)) {
          images.add({'url': url, 'label': title});
        } else {
          files.add({'url': url, 'label': title});
        }
      }
    }

    if (images.isEmpty && files.isEmpty) return [];

    final out = <Widget>[_sectionTitle('Şəkillər və fayllar')];
    for (final img in images) {
      out.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(img['label']!, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              const SizedBox(height: 6),
              InkWell(
                onTap: () => _launchMediaUrl(img['url']!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    img['url']!,
                    height: 160,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
                    },
                    errorBuilder: (context, error, stackTrace) => const Padding(
                      padding: EdgeInsets.all(16),
                      child: Icon(Icons.broken_image_outlined, size: 48),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    for (final f in files) {
      out.add(
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.attach_file, size: 22),
          title: Text(f['label']!, style: const TextStyle(fontSize: 14)),
          onTap: () => _launchMediaUrl(f['url']!),
        ),
      );
    }
    return out;
  }

  void _openCustomerHistory() {
    showDialog(
      context: context,
      builder: (ctx) => CustomerTasksHistoryModal(
        taskId: _taskId,
        customerName: widget.task['customer_name']?.toString(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');
    final createdAt = task['created_at'] != null
        ? dateFormat.format(DateTime.parse(task['created_at']))
        : '-';
    final updatedAt = task['updated_at'] != null
        ? dateFormat.format(DateTime.parse(task['updated_at']))
        : '-';

    final taskServicesRaw = task['task_services'];
    List<dynamic>? taskServicesList;
    if (taskServicesRaw is List && taskServicesRaw.isNotEmpty) {
      taskServicesList = taskServicesRaw;
    }
    final hasTaskServices = taskServicesList != null;
    final svcLabels = taskServiceLabels(task, widget.allServices);

    return DraggableScrollableSheet(
      initialChildSize: 1.0,
      maxChildSize: 1.0,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: keyboardInset),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        task['title'] ?? 'Tapşırıq',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: DefaultTabController(
                  length: 4,
                  child: Column(
                    children: [
                      const TabBar(
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        tabs: [
                          Tab(text: 'Tapşırıq'),
                          Tab(text: 'Müştəri'),
                          Tab(text: 'Əməliyyatlar'),
                          Tab(text: 'Aktivlik'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final mediaWidgets = _buildMediaSection(task);
                                return ListView(
                                  controller: scrollController,
                                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                                  padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + keyboardInset),
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 14,
                                          height: 14,
                                          decoration: BoxDecoration(
                                            color: taskTypeColorFromApi(task),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.black26, width: 0.5),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            taskTypeNameFromApi(task),
                                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    _taskInfoColumn(context, task, createdAt, updatedAt),
                                    const SizedBox(height: 16),
                                    _sectionTitle('Xidmətlər'),
                                    if (hasTaskServices) ..._buildServicesList(taskServicesList!),
                                    if (!hasTaskServices)
                                      _infoRow(
                                        context,
                                        'Seçilmiş',
                                        svcLabels.isNotEmpty ? svcLabels.join(', ') : '-',
                                      ),
                                    if (task['task_products'] != null &&
                                        (task['task_products'] as List).isNotEmpty) ...[
                                      const SizedBox(height: 16),
                                      _sectionTitle('Məhsullar'),
                                      ..._buildProductsList(task['task_products'] as List),
                                    ],
                                    if (task['task_documents'] != null &&
                                        (task['task_documents'] as List).isNotEmpty) ...[
                                      const SizedBox(height: 16),
                                      _sectionTitle('Sənədlər'),
                                      ..._buildDocumentsList(task['task_documents'] as List),
                                    ],
                                    if (mediaWidgets.isNotEmpty) ...[
                                      const SizedBox(height: 16),
                                      ...mediaWidgets,
                                    ],
                                  ],
                                );
                              },
                            ),
                            ListView(
                              controller: scrollController,
                              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + keyboardInset),
                              children: [
                                _customerColumn(context, task),
                              ],
                            ),
                            ListView(
                              controller: scrollController,
                              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + keyboardInset),
                              children: [
                                _actionsColumn(context, task),
                              ],
                            ),
                            ListView(
                              controller: scrollController,
                              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + keyboardInset),
                              children: [
                                _sectionTitle('Aktivlik və şərhlər'),
                                if (_actLoading)
                                  const Padding(
                                    padding: EdgeInsets.all(24),
                                    child: Center(child: CircularProgressIndicator()),
                                  )
                                else if (_activities.isEmpty)
                                  const Text('Hələ qeyd yoxdur.', style: TextStyle(color: Colors.grey))
                                else
                                  ..._activities.map((a) {
                                    final m = a as Map<String, dynamic>;
                                    final at = m['created_at'] != null
                                        ? dateFormat.format(DateTime.parse(m['created_at']))
                                        : '';
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: Padding(
                                        padding: const EdgeInsets.all(10),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '$at · ${m['user_name'] ?? ''}',
                                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                                            ),
                                            Text(
                                              m['action_display']?.toString() ?? '',
                                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                            ),
                                            if (m['message'] != null &&
                                                m['message'].toString().isNotEmpty)
                                              Text(m['message'].toString()),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _commentCtrl,
                                  maxLines: 3,
                                  maxLength: 2000,
                                  decoration: const InputDecoration(
                                    labelText: 'Şərh',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: (_sending || !widget.canCommentActivity) ? null : _sendComment,
                                    child: _sending
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : const Text('Göndər'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            ),
          ),
        );
      },
    );
  }

  Widget _taskInfoColumn(BuildContext context, Map<String, dynamic> task, String createdAt, String updatedAt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Tapşırıq məlumatları'),
        _infoRow(context, 'Status', _statusLabel(task['status'] ?? '')),
        _infoRow(context, 'Qeyd', task['note'] ?? '-'),
        _infoRow(context, 'İcraçılar', _formatAssigneeNames(task)),
        _infoRow(context, 'Reporter', _reporterDisplay(task)),
        _infoRow(context, 'Qrup', task['group_name'] ?? '-'),
        _infoRow(context, 'Region', task['region_name'] ?? '-'),
        _infoRow(context, 'Yaradılma tarixi', createdAt),
        _infoRow(context, 'Son yenilənmə', updatedAt),
        _infoRow(context, 'Aktiv', task['is_active'] == true ? 'Bəli' : 'Xeyr'),
      ],
    );
  }

  Widget _customerColumn(BuildContext context, Map<String, dynamic> task) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Müştəri məlumatları'),
        _infoRow(context, 'Ad', task['customer_name'] ?? '-'),
        _infoRow(context, 'Ünvan', task['customer_address'] ?? '-'),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(child: _infoRow(context, 'Telefon', task['customer_phone'] ?? '-')),
              if (task['customer_phone'] != null && task['customer_phone'].toString().isNotEmpty)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _launchCaller(task['customer_phone']),
                  icon: const Icon(Icons.phone_in_talk),
                  label: const Text('Zəng et'),
                ),
            ],
          ),
        ),
        _infoRow(context, 'Qeydiyyat №', task['customer_register_number'] ?? '-'),
        _infoRow(context, 'Avadanlıq', task['customer_equipment_name'] ?? '-'),
        _infoRow(context, 'Optik qutu', task['customer_optic_box_name'] ?? '-'),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: _openCustomerHistory,
            icon: const Icon(Icons.history, size: 18),
            label: const Text('Tapşırıq tarixçəsinə bax (müştəri üzrə)'),
          ),
        ),
      ],
    );
  }

  Widget _actionsColumn(BuildContext context, Map<String, dynamic> task) {
    final List<dynamic> assigneeIds = task['assigned_to'] is List ? task['assigned_to'] : [];
    final List<dynamic> assigneeNames = task['assigned_to_names'] is List ? task['assigned_to_names'] : [];
    final currentUser = ChatService().currentUser.value;
    final isCurrentUserAssignee = currentUser != null && assigneeIds.contains(currentUser.id);
    final isDoneTask = task['status'] == 'done';
    final archived = task['is_externally_archived'] == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Əməliyyatlar'),
        _actionButton(
          icon: isCurrentUserAssignee ? Icons.person_add : Icons.group_add,
          label: isCurrentUserAssignee ? 'İcraçı əlavə et' : 'İcraya qoşul',
          onPressed: isDoneTask
              ? null
              : () {
                  if (isCurrentUserAssignee && !widget.canManageAssignees) return;
                  if (!isCurrentUserAssignee && !widget.canJoinTask) return;
                  _openAssigneeModal(context, assigneeIds, assigneeNames, isCurrentUserAssignee);
                },
        ),
        const SizedBox(height: 8),
        _actionButton(
          icon: Icons.edit,
          label: 'Düzəliş',
          onPressed: widget.canEditGeneral
              ? () {
                  Navigator.pop(context);
                  widget.onEdit?.call();
                }
              : null,
        ),
        const SizedBox(height: 8),
        _actionButton(
          icon: Icons.sync_alt,
          label: 'Status',
          onPressed: widget.canChangeStatus
              ? () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (_) => StatusModal(task: task, onSuccess: _refreshAfterAction),
                  );
                }
              : null,
        ),
        const SizedBox(height: 8),
        _actionButton(
          icon: Icons.assignment,
          label: 'Anket',
          onPressed: widget.canManageSurveys
              ? () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (_) => SurveyModal(
                      task: task,
                      allServices: widget.allServices,
                      onSuccess: _refreshAfterAction,
                    ),
                  );
                }
              : null,
        ),
        const SizedBox(height: 8),
        _actionButton(
          icon: Icons.shopping_bag,
          label: 'Məhsul (${(task['task_products'] as List?)?.length ?? 0})',
          onPressed: widget.canManageProducts
              ? () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => ProductsModal(task: task, onSuccess: _refreshAfterAction),
                  );
                }
              : null,
        ),
        const SizedBox(height: 8),
        _actionButton(
          icon: Icons.chat_bubble_outline,
          label: 'Chata göndər',
          onPressed: () => _openSendToChatDialog(context),
        ),
        const SizedBox(height: 8),
        _actionButton(
          icon: Icons.attach_file,
          label: 'Sənəd (${(task['task_documents'] as List?)?.length ?? 0})',
          onPressed: widget.canManageDocuments
              ? () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => FilesModal(task: task, onSuccess: _refreshAfterAction),
                  );
                }
              : null,
        ),
        const SizedBox(height: 8),
        if (archived)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withOpacity(0.35)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Arxivdədir',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              onPressed: widget.canMarkExternalArchived ? _markExternalArchived : null,
              icon: const Icon(Icons.inventory_2),
              label: const Text('Xidməti aktiv et'),
            ),
          ),
        if (widget.canDelete) ...[
          const SizedBox(height: 8),
          _actionButton(
            icon: Icons.delete,
            label: 'Sil',
            foregroundColor: Colors.red,
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => DeleteTaskDialog(taskId: task['id'], onSuccess: _refreshAfterAction),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    Color? foregroundColor,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Text(label),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: foregroundColor,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  void _refreshAfterAction() {
    widget.onRefresh?.call();
    _loadActivity();
  }

  void _openAssigneeModal(
    BuildContext context,
    List<dynamic> assigneeIds,
    List<dynamic> assigneeNames,
    bool isCurrentUserAssignee,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AssigneeModal(
        task: widget.task,
        allUsers: widget.allUsers,
        assigneeIds: assigneeIds,
        assigneeNames: assigneeNames,
        isCurrentUserAssignee: isCurrentUserAssignee,
        onRefresh: _refreshAfterAction,
      ),
    );
  }

  Future<void> _openSendToChatDialog(BuildContext context) async {
    final noteCtrl = TextEditingController();
    int? selectedGroupId;
    await ChatService().fetchGroups();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final groups = ChatService().groups.value;
            return AlertDialog(
              title: const Text('Tapşırığı chata göndər'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    value: selectedGroupId,
                    decoration: const InputDecoration(labelText: 'Qrup'),
                    items: groups
                        .map((g) => DropdownMenuItem<int>(
                              value: g.id,
                              child: Text(g.name),
                            ))
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedGroupId = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Qeyd',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Ləğv et')),
                FilledButton(
                  onPressed: selectedGroupId == null
                      ? null
                      : () async {
                          try {
                            final payload = buildTaskChatPayload(widget.task, noteCtrl.text);
                            await ChatService().sendMessageByApi(
                              selectedGroupId!,
                              encodeTaskChatMessage(payload),
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Tapşırıq chata göndərildi')),
                              );
                            }
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Chata göndərilmədi')),
                              );
                            }
                          }
                        },
                  child: const Text('Göndər'),
                ),
              ],
            );
          },
        );
      },
    );
    noteCtrl.dispose();
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
      ),
    );
  }

  String _reporterDisplay(Map<String, dynamic> task) {
    final r = task['reporter_name']?.toString().trim() ?? '';
    return r.isEmpty ? '-' : r;
  }

  String _formatAssigneeNames(Map<String, dynamic> task) {
    final names = task['assigned_to_names'];
    if (names is List && names.isNotEmpty) {
      return names.join(', ');
    }
    return 'Təyin olunmayıb';
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'todo':
        return 'Gözleyir';
      case 'in_progress':
        return 'İcrada';
      case 'done':
        return 'Tamamlandı';
      case 'pending':
        return 'Təxirə salınmış';
      case 'rejected':
        return 'Rədd edildi';
      default:
        return status.isNotEmpty ? status : '-';
    }
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    final narrow = MediaQuery.sizeOf(context).width < 400;
    if (narrow) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: Colors.black87)),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.black87))),
        ],
      ),
    );
  }

  List<Widget> _buildServicesList(List<dynamic> services) {
    return services.map<Widget>((s) {
      final serviceName = s['service_name'] ?? 'Xidmət';
      final note = s['note'] ?? '';
      final values = s['values'] as List<dynamic>? ?? [];
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(serviceName, style: const TextStyle(fontWeight: FontWeight.bold)),
              if (note.isNotEmpty) Text(note, style: const TextStyle(color: Colors.grey)),
              ...values.map((v) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('${v['column_name'] ?? v['column_key'] ?? '-'}: ${v['value'] ?? '-'}'),
                  )),
            ],
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildProductsList(List<dynamic> products) {
    return products.map<Widget>((p) {
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          title: Text(p['product_name'] ?? 'Məhsul'),
          subtitle: Text('Say: ${p['quantity'] ?? '-'}'),
        ),
      );
    }).toList();
  }

  List<Widget> _buildDocumentsList(List<dynamic> docs) {
    return docs.map<Widget>((d) {
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: const Icon(Icons.attach_file),
          title: Text(d['name'] ?? 'Sənəd'),
          subtitle: Text(d['file'] ?? '-'),
        ),
      );
    }).toList();
  }

  Future<void> _launchCaller(String phoneNumber) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.isEmpty) return;
    final Uri url = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
