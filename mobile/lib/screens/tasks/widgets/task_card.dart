import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/screens/tasks/widgets/interaction_modals.dart' hide SurveyModal, FilesModal, ProductsModal;
import 'package:mobile/screens/tasks/widgets/survey_modal.dart';
import 'package:mobile/screens/tasks/widgets/files_modal.dart';
import 'package:mobile/screens/tasks/widgets/products_modal.dart';
import 'package:mobile/screens/tasks/widgets/task_detail_modal.dart';

class TaskCard extends StatelessWidget {
  final Map<String, dynamic> task;
  final List<dynamic> allServices;
  final VoidCallback onEdit;
  final VoidCallback onRefresh;
  final VoidCallback? onAccept;

  const TaskCard({
    super.key,
    required this.task,
    required this.allServices,
    required this.onEdit,
    required this.onRefresh,
    this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    // Format Date (Created At)
    final dateStr = task['created_at'] != null 
        ? DateFormat('dd MMM yyyy').format(DateTime.parse(task['created_at']))
        : '';
    
    // Status Color (unchanged logic)
    Color statusColor = Colors.grey;
    String statusLabel = task['status'] ?? 'todo';
    switch (statusLabel) {
      case 'todo': statusColor = Colors.grey; break;
      case 'in_progress': statusColor = Colors.blue; break;
      case 'review': statusColor = Colors.orange; break;
      case 'done': statusColor = Colors.green; break;
      case 'arrived': statusColor = Colors.purple; break;
      case 'pending': statusColor = Colors.red; break;
      case 'rejected': statusColor = Colors.red[900]!; break;
    }

    // Avatar logic (unchanged)
    String? avatarUrl;
    String initials = 'U';
    
    if (task['assigned_to_detail'] != null && task['assigned_to_detail'] is Map) {
         final user = task['assigned_to_detail'];
         // ... (existing logic if detail provided, but serializer usually provides flat fields or nested)
         // Serializer says: `assigned_to` is FK (ID), `assigned_to_name` is string.
         // Wait, serializer DOES NOT send user object with avatar. Only `assigned_to` (id) and `assigned_to_name`.
         // I cannot show avatar unless I fetch user list and match ID, or if I rely on checking `_users` list in parent?
         // TaskCard doesn't have list of users.
         // I will SKIP avatar image for now or use initials from `assigned_to_name` if possible.
         // `assigned_to_name` is available.
    }

    // Clean up Avatar logic to use name initials if avatar not available
    final String assigneeName = task['assigned_to_name'] ?? 'Unassigned';
    if (assigneeName != 'Unassigned') {
        initials = assigneeName.isNotEmpty ? assigneeName[0].toUpperCase() : 'U';
    }

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
                    onTap: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => TaskDetailModal(task: task),
                    ),
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
                    (task['status_display'] ?? statusLabel).toUpperCase(), // Use display name from backend if avail
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
                if (assigneeName != 'Unassigned')
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.blue.shade100,
                    child: Text(initials, style: const TextStyle(fontSize: 10, color: Colors.blue)),
                  ),
              ],
            ),
            
            const Divider(),
            
            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                if (task['assigned_to'] == null || task['assigned_to_name'] == null)
                  _buildActionBtn(context, Icons.person_add, Colors.teal, onAccept ?? () {}),
                
                _buildActionBtn(context, Icons.edit, Colors.blue, onEdit),
                _buildActionBtn(context, Icons.sync_alt, Colors.orange, () {
                  showModalBottomSheet(
                    context: context, 
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (_) => StatusModal(task: task, onSuccess: onRefresh)
                  );
                }),
                _buildActionBtn(context, Icons.assignment, Colors.purple, () {
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
                }),
                _buildActionBtn(context, Icons.attach_file, Colors.grey, () {
                   showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => FilesModal(task: task, onSuccess: onRefresh));
                }),
                 _buildActionBtn(context, Icons.shopping_bag, Colors.green, () {
                   showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => ProductsModal(task: task, onSuccess: onRefresh));
                }),
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

  Widget _buildActionBtn(BuildContext context, IconData icon, Color color, VoidCallback onTap) {
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
