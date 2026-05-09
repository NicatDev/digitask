import 'package:flutter/material.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:mobile/core/services/chat_service.dart';
import 'package:mobile/screens/tasks/widgets/interaction_modals.dart' hide SurveyModal, FilesModal, ProductsModal;
import 'package:mobile/screens/tasks/widgets/survey_modal.dart';
import 'package:mobile/screens/tasks/widgets/files_modal.dart';
import 'package:mobile/screens/tasks/widgets/products_modal.dart';
import 'package:mobile/screens/tasks/widgets/task_detail_modal.dart';
import 'package:mobile/screens/tasks/widgets/assignee_modal.dart';
import 'package:mobile/screens/tasks/widgets/customer_address_edit_modal.dart';
import 'package:mobile/screens/tasks/widgets/task_display_helpers.dart';
import 'package:mobile/screens/chat/task_message_codec.dart';

String _digitsOnlyForCompare(String s) => s.replaceAll(RegExp(r'\D'), '');

bool _phoneAndRegisterAreSame(String phone, String reg) {
  if (phone.isEmpty || reg.isEmpty) return false;
  final a = _digitsOnlyForCompare(phone);
  final b = _digitsOnlyForCompare(reg);
  if (a.isEmpty || b.isEmpty) return false;
  return a == b;
}

class TaskCard extends StatelessWidget {
  final Map<String, dynamic> task;
  final List<dynamic> allServices;
  final List<dynamic> allUsers;
  final VoidCallback onEdit;
  final VoidCallback onRefresh;
  final VoidCallback? onAccept;
  final bool canEditGeneral;
  final bool canDelete;
  final bool canChangeStatus;
  final bool canManageProducts;
  final bool canManageDocuments;
  final bool canManageSurveys;
  final bool canManageAssignees;
  final bool canJoinTask;
  final bool canEditCustomerAddress;
  final bool canCommentActivity;
  final bool canMarkExternalArchived;

  const TaskCard({
    super.key,
    required this.task,
    required this.allServices,
    required this.allUsers,
    required this.onEdit,
    required this.onRefresh,
    this.onAccept,
    this.canEditGeneral = false,
    this.canDelete = false,
    this.canChangeStatus = false,
    this.canManageProducts = false,
    this.canManageDocuments = false,
    this.canManageSurveys = false,
    this.canManageAssignees = false,
    this.canJoinTask = false,
    this.canEditCustomerAddress = false,
    this.canCommentActivity = false,
    this.canMarkExternalArchived = false,
  });

  @override
  Widget build(BuildContext context) {
    // Format Date
    final createdAt = task['created_at'] != null
        ? DateTime.tryParse(task['created_at'].toString())
        : null;
    final dateStr = createdAt != null ? DateFormat('dd MMM yyyy').format(createdAt) : '';
    final timeStr = createdAt != null ? DateFormat('HH:mm').format(createdAt) : '';
    
    // Status Color & English labels
    Color statusColor = Colors.grey;
    final String statusKey = task['status'] ?? 'todo';
    const statusLabels = {
      'todo': 'GÖZLEYİR',
      'in_progress': 'ICRADA',
      'review': 'YOXLAMA',
      'done': 'BİTİB',
      'pending': 'TƏXİRƏ SALINMIŞ',
      'rejected': 'REDD EDİLİB',
    };
    final String statusLabel = statusLabels[statusKey] ?? statusKey.toUpperCase();
    switch (statusKey) {
      case 'todo': statusColor = Colors.grey; break;
      case 'in_progress': statusColor = Colors.blue; break;
      case 'review': statusColor = Colors.orange; break;
      case 'done': statusColor = Colors.green; break;
      case 'pending': statusColor = Colors.red; break;
      case 'rejected': statusColor = Colors.red[900]!; break;
    }

    // Multi-assignee: assigned_to is now a list of IDs, assigned_to_names is a list of strings
    final List<dynamic> assigneeIds = task['assigned_to'] is List ? task['assigned_to'] : [];
    final List<dynamic> assigneeNames = task['assigned_to_names'] is List ? task['assigned_to_names'] : [];
    final currentUser = ChatService().currentUser.value;
    final bool isCurrentUserAssignee = currentUser != null && assigneeIds.contains(currentUser.id);
    final bool isDoneTask = statusKey == 'done';
    final svcLabels = taskServiceLabels(task, allServices);
    final bool highlightReschedule = isCurrentUserAssignee &&
        statusKey == 'pending' &&
        task['rescheduled_date'] != null;
    final bool isExternallyArchived = task['is_externally_archived'] == true;

    String? rescheduleFootnote;
    String? pendingNoteFootnote;
    if (statusKey == 'pending' && task['rescheduled_date'] != null) {
      final rd = task['rescheduled_date'];
      final s = rd.toString().trim();
      if (s.isNotEmpty) {
        DateTime? dt;
        if (s.length >= 10) {
          dt = DateTime.tryParse(s.substring(0, 10));
        }
        dt ??= DateTime.tryParse(s);
        final formatted = dt != null
            ? DateFormat('dd MMM yyyy').format(dt)
            : s;
        rescheduleFootnote = '$formatted tarixinə qədər təxirə salınmışdı';
      }
      final pendingNote = (task['pending_note'] ?? '').toString().trim();
      if (pendingNote.isNotEmpty) {
        pendingNoteFootnote = 'Qeyd: $pendingNote';
      }
    }

    final Widget cardInner = Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Title + Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => TaskDetailModal(
                        task: task,
                        allServices: allServices,
                        allUsers: allUsers,
                        onEdit: onEdit,
                        onRefresh: onRefresh,
                        onArchivedMarked: onRefresh,
                        canEditGeneral: canEditGeneral,
                        canDelete: canDelete,
                        canChangeStatus: canChangeStatus,
                        canManageProducts: canManageProducts,
                        canManageDocuments: canManageDocuments,
                        canManageSurveys: canManageSurveys,
                        canManageAssignees: canManageAssignees,
                        canJoinTask: canJoinTask,
                        canMarkExternalArchived: canMarkExternalArchived,
                        canCommentActivity: canCommentActivity,
                      ),
                    ),
                    child: Text(
                       '#${task['id']} - ${task['title'] ?? 'Başlıqsız'}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: taskTypeColorFromApi(task),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black26, width: 0.5),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    taskTypeNameFromApi(task),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            if (svcLabels.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.work_outline, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      svcLabels.join(', '),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),

            // Customer & Group
            Row(
              children: [
                const Icon(Icons.business, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    task['customer_name'] ?? 'Müştəri yoxdur',
                    style: const TextStyle(color: Colors.black87),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                InkWell(
                  onTap: () => _openCustomerAddressEditor(
                    context: context,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(Icons.edit_location_alt, color: Colors.orange, size: 20),
                  ),
                ),
                InkWell(
                  onTap: () => _openSendToChatDialog(context),
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(Icons.share, color: Colors.blueGrey, size: 20),
                  ),
                ),
              ],
            ),
            if (task['group_name'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Row(
                  children: [
                    const Icon(Icons.group_work, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      task['group_name'],
                      style: const TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 4),
            // Date + Assignees row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      dateStr,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    if (timeStr.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Text(
                        timeStr,
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ],
                ),
                // Assignees avatars - tap to open assignee modal
                if (assigneeNames.isNotEmpty)
                  GestureDetector(
                    onTap: () => _openAssigneeModal(context, assigneeIds, assigneeNames, isCurrentUserAssignee),
                    child: Row(
                      children: [
                        ...assigneeNames.take(3).map((name) {
                          final initial = (name as String).isNotEmpty ? name[0].toUpperCase() : 'U';
                          return Padding(
                            padding: const EdgeInsets.only(left: 2),
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.blue.shade100,
                              child: Text(initial, style: const TextStyle(fontSize: 10, color: Colors.blue)),
                            ),
                          );
                        }),
                        if (assigneeNames.length > 3)
                          Padding(
                            padding: const EdgeInsets.only(left: 2),
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.grey.shade200,
                              child: Text('+${assigneeNames.length - 3}', style: const TextStyle(fontSize: 9, color: Colors.grey)),
                            ),
                          ),
                        const SizedBox(width: 4),
                        Icon(Icons.people, size: 16, color: Colors.blue.shade300),
                      ],
                    ),
                  ),
              ],
            ),
            if (rescheduleFootnote != null) ...[
              const SizedBox(height: 6),
              Text(
                rescheduleFootnote,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.red.shade800,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (pendingNoteFootnote != null) ...[
                const SizedBox(height: 4),
                Text(
                  pendingNoteFootnote,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.red.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],

            const Divider(),
            
            // Actions
            Wrap(
              alignment: WrapAlignment.spaceAround,
              runSpacing: 4,
              children: [
                // Assignee button: "İcraya qoşul" or "İcraçı əlavə et" 
                _buildActionBtn(context, 
                  isCurrentUserAssignee ? Icons.person_add : Icons.group_add, 
                  isDoneTask
                      ? Colors.grey.shade300
                      : (isCurrentUserAssignee ? (canManageAssignees ? Colors.teal : Colors.grey.shade300) : (canJoinTask ? Colors.blue : Colors.grey.shade300)),
                  isDoneTask
                      ? null
                      : () {
                          if (isCurrentUserAssignee && !canManageAssignees) return;
                          if (!isCurrentUserAssignee && !canJoinTask) return;
                          _openAssigneeModal(context, assigneeIds, assigneeNames, isCurrentUserAssignee);
                        },
                ),
                
                // Edit Button - Disabled if not writer
                _buildActionBtn(
                    context, 
                    Icons.edit, 
                    canEditGeneral ? Colors.blue : Colors.grey, 
                    canEditGeneral ? onEdit : null
                ),
                
                // Status change - only for assignees
                _buildActionBtn(context, Icons.sync_alt, 
                    canChangeStatus ? Colors.orange : Colors.grey.shade300, 
                    canChangeStatus ? () {
                  showModalBottomSheet(
                    context: context, 
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (_) => StatusModal(task: task, onSuccess: onRefresh)
                  );
                } : null),
                // Survey/Anket
                _buildActionBtn(context, Icons.assignment, 
                    canManageSurveys ? Colors.purple : Colors.grey.shade300, 
                    canManageSurveys ? () {
                  showModalBottomSheet(
                    context: context, 
                    isScrollControlled: true, 
                    useSafeArea: true,
                    builder: (_) => SurveyModal(
                      task: task, 
                      allServices: allServices,
                      onSuccess: onRefresh,
                    )
                  );
                } : null),
                // Files
                _buildActionBtn(context, Icons.attach_file, 
                    canManageDocuments ? Colors.grey : Colors.grey.shade300, 
                    canManageDocuments ? () {
                   showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => FilesModal(task: task, onSuccess: onRefresh));
                } : null),
                // Products
                _buildActionBtn(context, Icons.shopping_bag, 
                    canManageProducts ? Colors.green : Colors.grey.shade300, 
                    canManageProducts ? () {
                   showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => ProductsModal(task: task, onSuccess: onRefresh));
                } : null),
                _buildActionBtn(
                  context,
                  isExternallyArchived ? Icons.check_circle : Icons.inventory_2,
                  isExternallyArchived
                      ? Colors.green
                      : (canMarkExternalArchived ? Colors.blue : Colors.grey.shade300),
                  (!isExternallyArchived && canMarkExternalArchived)
                      ? () => _markExternalArchived(context)
                      : null,
                ),
                if (canDelete)
                 _buildActionBtn(context, Icons.delete, Colors.red, () {
                   showDialog(context: context, builder: (_) => DeleteTaskDialog(taskId: task['id'], onSuccess: onRefresh));
                }),
              ],
            ),
            ..._buildCustomerContactActions(context),
          ],
        ),
    );

    if (highlightReschedule) {
      return Card(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.amber.shade700, width: 2),
        ),
        child: cardInner,
      );
    }

    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isCurrentUserAssignee
            ? const BorderSide(color: Colors.blue, width: 2)
            : BorderSide.none,
      ),
      child: cardInner,
    );
  }

  List<Widget> _buildCustomerContactActions(BuildContext context) {
    final phone = (task['customer_phone'] ?? '').toString().trim();
    final reg = (task['customer_register_number'] ?? '').toString().trim();
    final address = (task['customer_address'] ?? '').toString();
    final rawCoords = task['customer_coordinates'];
    Map<String, dynamic>? coords;
    if (rawCoords is Map) {
      coords = Map<String, dynamic>.from(rawCoords);
    }
    final canMaps = (coords != null && coords['lat'] != null && coords['lng'] != null) ||
        address.isNotEmpty;

    if (phone.isEmpty && reg.isEmpty && !canMaps) {
      return const [];
    }

    final callColumnChildren = <Widget>[];
    final sameDial = _phoneAndRegisterAreSame(phone, reg);

    if (sameDial) {
      callColumnChildren.add(
        _customerDialButton(
          context: context,
          backgroundColor: Colors.green.shade600,
          icon: Icons.phone,
          label: phone,
          suffixLabel: ' (Əlaqə nömrəsi)',
          dialValue: phone,
        ),
      );
    } else {
      if (phone.isNotEmpty) {
        callColumnChildren.add(
          _customerDialButton(
            context: context,
            backgroundColor: Colors.green.shade600,
            icon: Icons.phone,
            label: phone,
            suffixLabel: ' (Əlaqə nömrəsi)',
            dialValue: phone,
          ),
        );
      }
      if (reg.isNotEmpty) {
        if (callColumnChildren.isNotEmpty) {
          callColumnChildren.add(const SizedBox(height: 8));
        }
        callColumnChildren.add(
          _customerDialButton(
            context: context,
            backgroundColor: Colors.blue.shade700,
            icon: Icons.phone,
            label: reg,
            suffixLabel: ' (Qeydiyyat nömrəsi)',
            dialValue: reg,
          ),
        );
      }
    }

    final topRowChildren = <Widget>[];
    if (callColumnChildren.isNotEmpty) {
      topRowChildren.add(
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: callColumnChildren,
          ),
        ),
      );
    } else if (canMaps) {
      topRowChildren.add(const Spacer());
    }

    if (canMaps) {
      if (topRowChildren.isNotEmpty) {
        topRowChildren.add(const SizedBox(width: 8));
      }
      topRowChildren.add(
        IconButton(
          style: IconButton.styleFrom(
            backgroundColor: Colors.red.shade50,
            foregroundColor: Colors.red,
            padding: const EdgeInsets.all(12),
          ),
          icon: const Icon(Icons.location_on),
          onPressed: () => _launchMaps(context, coords, address),
        ),
      );
    }

    return [
      const SizedBox(height: 8),
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: topRowChildren,
      ),
    ];
  }

  Widget _customerDialButton({
    required BuildContext context,
    required Color backgroundColor,
    required IconData icon,
    required String label,
    String? suffixLabel,
    required String dialValue,
  }) {
    return FilledButton.icon(
      onPressed: () => _launchCaller(dialValue, context),
      icon: Icon(icon, color: Colors.white, size: 20),
      label: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: label),
            if (suffixLabel != null)
              TextSpan(
                text: suffixLabel,
                style: TextStyle(
                  color: Colors.grey.shade300,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: Colors.white,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _openAssigneeModal(BuildContext context, List<dynamic> assigneeIds, List<dynamic> assigneeNames, bool isCurrentUserAssignee) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AssigneeModal(
        task: task,
        allUsers: allUsers,
        assigneeIds: assigneeIds,
        assigneeNames: assigneeNames,
        isCurrentUserAssignee: isCurrentUserAssignee,
        onRefresh: onRefresh,
      ),
    );
  }

  Widget _buildActionBtn(BuildContext context, IconData icon, Color color, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Icon(icon, color: color, size: 20),
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
                            final payload = buildTaskChatPayload(task, noteCtrl.text);
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

  Future<void> _openCustomerAddressEditor({
    required BuildContext context,
  }) async {
    if (!canEditCustomerAddress) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Müştəri ünvanı redaktəsi üçün icazəniz yoxdur')),
        );
      }
      return;
    }

    final rawCustomerId = task['customer'];
    final customerId = rawCustomerId is int ? rawCustomerId : int.tryParse(rawCustomerId?.toString() ?? '');
    if (customerId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Müştəri məlumatı tapılmadı')),
        );
      }
      return;
    }

    final customerName = task['customer_name']?.toString().trim() ?? '';
    final registerNumber = task['customer_register_number']?.toString().trim() ?? '';
    final customerLabel = registerNumber.isNotEmpty ? '$customerName - $registerNumber' : customerName;

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => CustomerAddressEditModal(
        customerId: customerId,
        customerLabel: customerLabel.isEmpty ? 'Müştəri' : customerLabel,
      ),
    );

    if (saved == true && context.mounted) {
      onRefresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Müştəri ünvanı yeniləndi')),
      );
    }
  }

  Future<void> _markExternalArchived(BuildContext context) async {
    try {
      await ApiClient().dio.post('/tasks/tasks/${task['id']}/mark-external-archived/');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Məlumatlar əlaqəli platformalara köçürüldü')),
        );
      }
      onRefresh();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Arxivləşdirmə uğursuz oldu')),
        );
      }
    }
  }

  Future<void> _launchMaps(BuildContext context, Map<String, dynamic>? coords, String address) async {
    Uri? url;
    if (coords != null && coords['lat'] != null && coords['lng'] != null) {
      url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${coords['lat']},${coords['lng']}');
    } else if (address.isNotEmpty) {
      url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}');
    }

    if (url != null) {
      try {
        if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
           if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Xəritə açıla bilmədi')));
        }
      } catch (e) {
         if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Xəritə xətası')));
      }
    } else {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ünvan mövcud deyil')));
    }
  }

  Future<void> _launchCaller(String phoneNumber, [BuildContext? context]) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.isEmpty) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zəng üçün etibarlı nömrə yoxdur')),
        );
      }
      return;
    }

    final Uri url = Uri.parse('tel:$cleanPhone');
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        // Fallback or error log
      }
    } catch (e) {
      // Error log
    }
  }
}
