import 'package:flutter/material.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/core/services/chat_service.dart';

class AssigneeModal extends StatefulWidget {
  final Map<String, dynamic> task;
  final List<dynamic> allUsers;
  final List<dynamic> assigneeIds;
  final List<dynamic> assigneeNames;
  final bool isCurrentUserAssignee;
  final VoidCallback onRefresh;

  const AssigneeModal({
    super.key,
    required this.task,
    required this.allUsers,
    required this.assigneeIds,
    required this.assigneeNames,
    required this.isCurrentUserAssignee,
    required this.onRefresh,
  });

  @override
  State<AssigneeModal> createState() => _AssigneeModalState();
}

class _AssigneeModalState extends State<AssigneeModal> {
  String _searchQuery = '';
  bool _isLoading = false;

  Future<void> _joinTask() async {
    setState(() => _isLoading = true);
    try {
      final client = ApiClient().dio;
      await client.post('/tasks/tasks/${widget.task['id']}/join_task/');
      if (mounted) {
        Navigator.pop(context);
        widget.onRefresh();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İcraya qoşuldunuz')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Xəta baş verdi')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addAssignee(int userId) async {
    setState(() => _isLoading = true);
    try {
      final client = ApiClient().dio;
      await client.post('/tasks/tasks/${widget.task['id']}/add_assignee/', data: {'user_id': userId});
      if (mounted) {
        Navigator.pop(context);
        widget.onRefresh();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İcraçı əlavə edildi')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Xəta baş verdi')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter available users (not already assigned)
    final availableUsers = widget.allUsers.where((u) {
      final id = u['id'];
      final isActive = u['is_active'] ?? true;
      final isAssigned = widget.assigneeIds.contains(id);
      if (!isActive || isAssigned) return false;
      if (_searchQuery.isNotEmpty) {
        final name = '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.toLowerCase();
        return name.contains(_searchQuery.toLowerCase());
      }
      return true;
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'İcraçılar',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(),

              // Current assignees
              if (widget.assigneeNames.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Cari icraçılar', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.assigneeNames.map((name) {
                          return Chip(
                            avatar: CircleAvatar(
                              backgroundColor: Colors.blue.shade100,
                              child: Text(
                                (name as String).isNotEmpty ? name[0].toUpperCase() : 'U',
                                style: const TextStyle(fontSize: 12, color: Colors.blue),
                              ),
                            ),
                            label: Text(name),
                            backgroundColor: Colors.blue.shade50,
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              
              if (widget.assigneeNames.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Hələ heç bir icraçı təyin edilməyib', style: TextStyle(color: Colors.grey)),
                ),

              const Divider(),

              // Join button (if not already assigned)
              if (!widget.isCurrentUserAssignee)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _joinTask,
                      icon: const Icon(Icons.group_add),
                      label: _isLoading 
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('İcraya qoşul'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),
              
              // Add assignee section (if already assigned)
              if (widget.isCurrentUserAssignee) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('İcraçı əlavə et', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'İstifadəçi axtar...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: availableUsers.length,
                    itemBuilder: (context, index) {
                      final u = availableUsers[index];
                      final name = '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
                      final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade100,
                          child: Text(initial, style: const TextStyle(color: Colors.blue)),
                        ),
                        title: Text(name.isNotEmpty ? name : (u['email'] ?? 'User')),
                        trailing: _isLoading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : IconButton(
                          icon: const Icon(Icons.person_add, color: Colors.blue),
                          onPressed: () => _addAssignee(u['id']),
                        ),
                      );
                    },
                  ),
                ),
              ],

              if (!widget.isCurrentUserAssignee)
                const Spacer(),
            ],
          ),
        );
      },
    );
  }
}
