import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/core/services/chat_service.dart';
import 'package:mobile/models/user_model.dart';
import 'package:mobile/screens/tasks/widgets/interaction_modals.dart' hide SurveyModal, FilesModal, ProductsModal;
import 'package:mobile/screens/tasks/widgets/survey_modal.dart';
import 'package:mobile/screens/tasks/widgets/files_modal.dart';
import 'package:mobile/screens/tasks/widgets/products_modal.dart';
import 'package:mobile/screens/tasks/widgets/task_detail_modal.dart';
import 'package:mobile/screens/tasks/widgets/assignee_modal.dart';

class TaskCard extends StatelessWidget {
  final Map<String, dynamic> task;
  final List<dynamic> allServices;
  final List<dynamic> allUsers;
  final VoidCallback onEdit;
  final VoidCallback onRefresh;
  final VoidCallback? onAccept;
  final bool isWriter;

  const TaskCard({
    super.key,
    required this.task,
    required this.allServices,
    required this.allUsers,
    required this.onEdit,
    required this.onRefresh,
    this.onAccept,
    this.isWriter = false,
  });

  @override
  Widget build(BuildContext context) {
    // Format Date
    final dateStr = task['created_at'] != null 
        ? DateFormat('dd MMM yyyy').format(DateTime.parse(task['created_at']))
        : '';
    
    // Status Color & English labels
    Color statusColor = Colors.grey;
    final String statusKey = task['status'] ?? 'todo';
    const statusLabels = {
      'todo': 'TO DO',
      'in_progress': 'IN PROGRESS',
      'review': 'REVIEW',
      'done': 'DONE',
      'arrived': 'ARRIVED',
      'pending': 'PENDING',
      'rejected': 'REJECTED',
    };
    final String statusLabel = statusLabels[statusKey] ?? statusKey.toUpperCase();
    switch (statusKey) {
      case 'todo': statusColor = Colors.grey; break;
      case 'in_progress': statusColor = Colors.blue; break;
      case 'review': statusColor = Colors.orange; break;
      case 'done': statusColor = Colors.green; break;
      case 'arrived': statusColor = Colors.purple; break;
      case 'pending': statusColor = Colors.red; break;
      case 'rejected': statusColor = Colors.red[900]!; break;
    }

    // Multi-assignee: assigned_to is now a list of IDs, assigned_to_names is a list of strings
    final List<dynamic> assigneeIds = task['assigned_to'] is List ? task['assigned_to'] : [];
    final List<dynamic> assigneeNames = task['assigned_to_names'] is List ? task['assigned_to_names'] : [];
    final currentUser = ChatService().currentUser.value;
    final bool isCurrentUserAssignee = currentUser != null && assigneeIds.contains(currentUser.id);

    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
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
                    onTap: () async {
                      // Show loading dialog
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => const Center(child: CircularProgressIndicator()),
                      );
                      try {
                        final client = ApiClient().dio;
                        final response = await client.get('/tasks/tasks/${task['id']}/');
                        if (context.mounted) {
                          Navigator.pop(context); // Close loading
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => TaskDetailModal(task: response.data),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          Navigator.pop(context); // Close loading
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Məlumatlar yüklənmədi')),
                          );
                        }
                      }
                    },
                    child: Text(
                      task['title'] ?? 'Untitled',
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
            const SizedBox(height: 8),
            
            // Customer & Group
            Row(
              children: [
                const Icon(Icons.business, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    task['customer_name'] ?? 'No Customer',
                    style: const TextStyle(color: Colors.black87),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                InkWell(
                  onTap: () => _launchMaps(
                      context, 
                      task['customer_coordinates'], 
                      task['customer_address'] ?? '',
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(Icons.location_on, color: Colors.red, size: 20),
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

              if (task['customer_register_number'] != null || task['customer_phone'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
                child: Row(
                  children: [
                    if (task['customer_register_number'] != null) ...[
                      const Icon(Icons.numbers, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        task['customer_register_number'],
                        style: const TextStyle(color: Colors.black54, fontSize: 11),
                      ),
                      const SizedBox(width: 12),
                    ],
                    if (task['customer_phone'] != null) ...[
                      const Icon(Icons.phone, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        task['customer_phone'],
                        style: const TextStyle(color: Colors.black54, fontSize: 11),
                      ),
                    ],
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
            
            const Divider(),
            
            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Assignee button: "İcraya qoşul" or "İcraçı əlavə et" 
                _buildActionBtn(context, 
                  isCurrentUserAssignee ? Icons.person_add : Icons.group_add, 
                  isCurrentUserAssignee ? Colors.teal : Colors.blue, 
                  () => _openAssigneeModal(context, assigneeIds, assigneeNames, isCurrentUserAssignee),
                ),
                
                // Edit Button - Disabled if not writer
                _buildActionBtn(
                    context, 
                    Icons.edit, 
                    isWriter ? Colors.blue : Colors.grey, 
                    isWriter ? onEdit : null
                ),
                
                // Status change - only for assignees
                _buildActionBtn(context, Icons.sync_alt, 
                    isCurrentUserAssignee ? Colors.orange : Colors.grey.shade300, 
                    isCurrentUserAssignee ? () {
                  showModalBottomSheet(
                    context: context, 
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (_) => StatusModal(task: task, onSuccess: onRefresh)
                  );
                } : null),
                // Survey/Anket - only for assignees
                _buildActionBtn(context, Icons.assignment, 
                    isCurrentUserAssignee ? Colors.purple : Colors.grey.shade300, 
                    isCurrentUserAssignee ? () {
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
                // Files - only for assignees
                _buildActionBtn(context, Icons.attach_file, 
                    isCurrentUserAssignee ? Colors.grey : Colors.grey.shade300, 
                    isCurrentUserAssignee ? () {
                   showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => FilesModal(task: task, onSuccess: onRefresh));
                } : null),
                // Products - only for assignees
                 _buildActionBtn(context, Icons.shopping_bag, 
                    isCurrentUserAssignee ? Colors.green : Colors.grey.shade300, 
                    isCurrentUserAssignee ? () {
                   showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => ProductsModal(task: task, onSuccess: onRefresh));
                } : null),
                // Delete - only for privileged users (task_writer, admin, super_admin)
                if (isWriter || (currentUser?.isAdmin ?? false) || (currentUser?.isSuperAdmin ?? false))
                 _buildActionBtn(context, Icons.delete, Colors.red, () {
                   showDialog(context: context, builder: (_) => DeleteTaskDialog(taskId: task['id'], onSuccess: onRefresh));
                }),
              ],
            ),
          ],
        ),
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
}
