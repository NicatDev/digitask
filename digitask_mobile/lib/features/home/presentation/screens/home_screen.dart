import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/home_provider.dart';
import '../widgets/task_detail_modal.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'all';
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeProvider>().fetchTasks();
      _fadeController.forward();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getFilteredTasks(List<Map<String, dynamic>> tasks) {
    List<Map<String, dynamic>> filtered = tasks;
    
    // Apply status filter
    if (_statusFilter != 'all') {
      filtered = filtered.where((t) => t['status'] == _statusFilter).toList();
    }
    
    // Apply search filter
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
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          _buildGradientHeader(),
          SliverToBoxAdapter(child: _buildSearchAndFilters()),
          _buildTasksList(),
        ],
      ),
    );
  }

  Widget _buildGradientHeader() {
    return SliverAppBar(
      expandedHeight: 140,
      pinned: true,
      stretch: true,
      backgroundColor: const Color(0xFF2563EB),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF2563EB),
                Color(0xFF7C3AED),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(30),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.task_alt, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Salam! 👋',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'Tapşırıqlarınız',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Tapşırıq axtar...',
              hintStyle: TextStyle(color: Colors.grey.shade500),
              prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
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
        // Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
    );
  }

  Widget _buildFilterChip(String value, String label, IconData icon) {
    final isSelected = _statusFilter == value;
    return FilterChip(
      selected: isSelected,
      showCheckmark: false,
      avatar: Icon(
        icon,
        size: 18,
        color: isSelected ? Colors.white : Colors.grey.shade600,
      ),
      label: Text(label),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFF2563EB),
      side: BorderSide(
        color: isSelected ? Colors.transparent : Colors.grey.shade300,
      ),
      onSelected: (_) {
        setState(() {
          _statusFilter = value;
        });
      },
    );
  }

  Widget _buildTasksList() {
    return Consumer<HomeProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (provider.error != null) {
          return SliverFillRemaining(
            child: Center(
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
            ),
          );
        }

        final filteredTasks = _getFilteredTasks(provider.tasks);

        if (filteredTasks.isEmpty) {
          return SliverFillRemaining(
            child: Center(
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
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return FadeTransition(
                  opacity: _fadeController,
                  child: _buildTaskCard(filteredTasks[index], index),
                );
              },
              childCount: filteredTasks.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task, int index) {
    final customerName = task['customer_name']?.toString() ?? task['customer_address']?.toString();
    final status = task['status']?.toString() ?? 'Unknown';
    final statusDisplay = task['status_display']?.toString() ?? status;
    
    Map<String, dynamic>? taskTypeDetails;
    if (task['task_type_details'] is Map<String, dynamic>) {
      taskTypeDetails = task['task_type_details'] as Map<String, dynamic>;
    }

    // Status color and icon
    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'done':
      case 'completed':
        statusColor = const Color(0xFF10B981); // Emerald-500
        statusIcon = Icons.check_circle;
        break;
      case 'in_progress':
        statusColor = const Color(0xFFF59E0B); // Amber-500
        statusIcon = Icons.play_circle_filled;
        break;
      case 'todo':
      case 'pending':
        statusColor = const Color(0xFF3B82F6); // Blue-500
        statusIcon = Icons.pending;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
    }

    // Task type color
    Color taskTypeColor = const Color(0xFF2563EB);
    if (taskTypeDetails != null && taskTypeDetails['color'] != null) {
      final colorStr = taskTypeDetails['color'].toString().replaceAll('#', '');
      taskTypeColor = Color(int.tryParse('0xFF$colorStr') ?? 0xFF2563EB);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 50)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showTaskDetail(task),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: taskTypeColor.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.task_alt, color: taskTypeColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task['title'] ?? 'Adsız tapşırıq',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (taskTypeDetails != null)
                            Text(
                              taskTypeDetails['name'] ?? '',
                              style: TextStyle(
                                fontSize: 13,
                                color: taskTypeColor,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withAlpha(25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 14, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            statusDisplay,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Info row
                Row(
                  children: [
                    if (customerName != null) ...[
                      Icon(Icons.person_outline, size: 16, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          customerName,
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    if (task['assigned_to_name'] != null) ...[
                      const SizedBox(width: 16),
                      Icon(Icons.assignment_ind_outlined, size: 16, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        task['assigned_to_name'],
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                  ],
                ),
                if (task['group_name'] != null || task['region_name'] != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (task['group_name'] != null) ...[
                        Icon(Icons.group_outlined, size: 16, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          task['group_name'],
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ],
                      if (task['region_name'] != null) ...[
                        const SizedBox(width: 16),
                        Icon(Icons.location_on_outlined, size: 16, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          task['region_name'],
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
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
