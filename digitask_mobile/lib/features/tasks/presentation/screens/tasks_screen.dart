import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../home/providers/home_provider.dart';
import '../../../home/presentation/widgets/task_detail_modal.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeProvider>().fetchTasks();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getFilteredTasks(List<Map<String, dynamic>> tasks) {
    List<Map<String, dynamic>> filtered = tasks;
    
    if (_statusFilter != 'all') {
      filtered = filtered.where((t) => t['status'] == _statusFilter).toList();
    }
    
    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((t) {
        final title = (t['title'] ?? '').toString().toLowerCase();
        final customerName = (t['customer_name'] ?? '').toString().toLowerCase();
        return title.contains(query) || customerName.contains(query);
      }).toList();
    }
    
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search and Filters
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Search Bar
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Tapşırıq axtar...',
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('all', 'Hamısı', Icons.list),
                    const SizedBox(width: 8),
                    _buildFilterChip('todo', 'Gözləyir', Icons.hourglass_empty),
                    const SizedBox(width: 8),
                    _buildFilterChip('in_progress', 'İcrada', Icons.play_arrow),
                    const SizedBox(width: 8),
                    _buildFilterChip('done', 'Tamamlandı', Icons.check_circle_outline),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Task List
        Expanded(
          child: Consumer<HomeProvider>(
            builder: (context, provider, _) {
              if (provider.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (provider.error != null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                      const SizedBox(height: 16),
                      Text(provider.error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => provider.fetchTasks(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Yenidən cəhd et'),
                      ),
                    ],
                  ),
                );
              }

              final filteredTasks = _getFilteredTasks(provider.tasks);

              if (filteredTasks.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        _statusFilter == 'all' 
                            ? 'Tapşırıq tapılmadı'
                            : 'Bu statusda tapşırıq yoxdur',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () => provider.fetchTasks(),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredTasks.length,
                  itemBuilder: (context, index) {
                    return _buildTaskCard(filteredTasks[index]);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String value, String label, IconData icon) {
    final isSelected = _statusFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _statusFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final customerName = task['customer_name']?.toString() ?? task['customer_address']?.toString();
    final status = task['status']?.toString() ?? 'Unknown';
    final statusDisplay = task['status_display']?.toString() ?? status;
    
    Map<String, dynamic>? taskTypeDetails;
    if (task['task_type_details'] is Map<String, dynamic>) {
      taskTypeDetails = task['task_type_details'] as Map<String, dynamic>;
    }

    Color statusColor;
    switch (status) {
      case 'done':
      case 'completed':
        statusColor = const Color(0xFF10B981);
        break;
      case 'in_progress':
        statusColor = const Color(0xFFF59E0B);
        break;
      case 'todo':
      case 'pending':
        statusColor = const Color(0xFF3B82F6);
        break;
      default:
        statusColor = Colors.grey;
    }

    Color taskTypeColor = const Color(0xFF2563EB);
    if (taskTypeDetails != null && taskTypeDetails['color'] != null) {
      final colorStr = taskTypeDetails['color'].toString().replaceAll('#', '');
      taskTypeColor = Color(int.tryParse('0xFF$colorStr') ?? 0xFF2563EB);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showTaskDetail(task),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: taskTypeColor.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.task_alt, color: taskTypeColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task['title'] ?? 'Adsız tapşırıq',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1F2937),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (taskTypeDetails != null)
                            Text(
                              taskTypeDetails['name'] ?? '',
                              style: TextStyle(
                                fontSize: 12,
                                color: taskTypeColor,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusColor.withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        statusDisplay,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                if (customerName != null || task['assigned_to_name'] != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (customerName != null) ...[
                        Icon(Icons.person_outline, size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            customerName,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      if (task['group_name'] != null) ...[
                        const SizedBox(width: 12),
                        Icon(Icons.group_outlined, size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          task['group_name'],
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTaskDetail(Map<String, dynamic> task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TaskDetailModal(task: task),
    );
  }
}
