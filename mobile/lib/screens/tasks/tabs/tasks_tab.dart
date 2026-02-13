import 'package:flutter/material.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/screens/tasks/widgets/task_card.dart';
import 'package:mobile/screens/tasks/widgets/task_form.dart';
import 'package:mobile/screens/tasks/widgets/task_filters.dart';
import 'package:intl/intl.dart';

class TasksTab extends StatefulWidget {
  const TasksTab({super.key});

  @override
  State<TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends State<TasksTab> {
  // Data
  List<dynamic> _tasks = [];
  List<dynamic> _customers = [];
  List<dynamic> _users = [];
  List<dynamic> _groups = [];
  List<dynamic> _taskTypes = [];
  List<dynamic> _services = [];
  
  // Pagination State
  int _currentPage = 1;
  bool _hasNextPage = true;
  bool _isFirstLoadRunning = true;

  // Filters
  String _searchQuery = '';
  String? _statusFilter;
  int? _customerFilter;
  int? _assigneeFilter;
  String _activeFilter = 'all'; // all, active, inactive
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _fetchDropdowns();
    _fetchTasks();
  }

  Future<void> _fetchDropdowns() async {
    try {
      final client = ApiClient().dio;
      final custRes = await client.get('/tasks/customers/');
      final usersRes = await client.get('/users/');
      final groupsRes = await client.get('/groups/');
      final typesRes = await client.get('/tasks/task-types/');
      final servicesRes = await client.get('/tasks/services/');
      
      if (mounted) {
        setState(() {
          _customers = _extractResults(custRes.data);
          _users = _extractResults(usersRes.data);
          _groups = _extractResults(groupsRes.data);
          _taskTypes = _extractResults(typesRes.data);
          _services = _extractResults(servicesRes.data);
        });
      }
    } catch (e) {
      debugPrint('Error fetching dropdowns: $e');
    }
  }

  Future<void> _fetchTasks({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _currentPage = 1;
        _hasNextPage = true;
        _isFirstLoadRunning = true;
        _tasks = [];
      });
    }

    try {
      final client = ApiClient().dio;
      final response = await client.get(
        '/tasks/tasks/', 
        queryParameters: _buildQueryParams(),
      );
      
      if (mounted) {
        final data = response.data;
        List<dynamic> incoming = [];
        bool next = false;

        if (data is Map && data.containsKey('results')) {
          incoming = data['results'];
          next = data['next'] != null;
        } else if (data is List) {
          incoming = data;
          next = false;
        }

        setState(() {
          if (refresh) {
            _tasks = incoming;
          } else {
            _tasks.addAll(incoming);
          }
          _hasNextPage = next;
          _isFirstLoadRunning = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isFirstLoadRunning = false);
      }
    }
  }

  Future<void> _changePage(int page) async {
    setState(() {
      _currentPage = page;
      _isFirstLoadRunning = true; // Show loading for new page
      _tasks = [];
    });
    await _fetchTasks();
  }

  Future<void> _acceptTask(int taskId) async {
    try {
      final client = ApiClient().dio;
      await client.patch('/tasks/tasks/$taskId/update_status/', data: {'status': 'in_progress'});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tapşırıq qəbul edildi')));
      _fetchTasks(refresh: true);
    } catch (e) {
      debugPrint('Error accepting task: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Xəta baş verdi')));
    }
  }

  Map<String, dynamic> _buildQueryParams() {
    final params = <String, dynamic>{
      'search': _searchQuery,
      'page': _currentPage,
    };
    if (_statusFilter != null) params['status'] = _statusFilter;
    if (_customerFilter != null) params['customer'] = _customerFilter;
    if (_assigneeFilter != null) params['assigned_to'] = _assigneeFilter;
    
    if (_activeFilter == 'active') params['is_active'] = true;
    if (_activeFilter == 'inactive') params['is_active'] = false;

    return params;
  }

  List<dynamic> _extractResults(dynamic data) {
    if (data is Map && data.containsKey('results')) {
      return data['results'];
    } else if (data is List) {
      return data;
    }
    return [];
  }

  void _openFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => TaskFilterModal(
        customers: _customers,
        users: _users,
        status: _statusFilter,
        customerId: _customerFilter,
        assigneeId: _assigneeFilter,
        activeFilter: _activeFilter,
        onApply: (status, custId, assignId, active) {
          setState(() {
            _statusFilter = status;
            _customerFilter = custId;
            _assigneeFilter = assignId;
            _activeFilter = active;
          });
          _fetchTasks(refresh: true);
        },
      ),
    );
  }

  void _openTaskForm([Map<String, dynamic>? task]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => TaskFormModal(
        task: task,
        customers: _customers,
        users: _users,
        groups: _groups,
        taskTypes: _taskTypes,
        services: _services,
        onSuccess: () => _fetchTasks(refresh: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // We can expose the AppBar actions via a callback or manage state locally?
    // Since we are moving to Tabs, the AppBar is shared.
    // The user asked for "Tasks" tab and "Customers" tab.
    // The Filter/Refresh actions are specific to Tasks list.
    // We should probably put them in the Tab content (e.g. below tabs, or inside the TabView)
    // OR updating the main AppBar dynamically.
    // For simplicity, I will include the Toolbar (Search + Buttons) inside the Tab View.
    // But wait, the Search Bar is already in the body.
    // I need to add Filter/Refresh buttons somewhere since AppBar is gone from here.
    // I'll add them next to Search Bar or as a local Row.
    
    return Column(
      children: [
        // Toolbar Row (Search + Actions)
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search tasks...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onChanged: (val) {
                     _searchQuery = val;
                     Future.delayed(const Duration(milliseconds: 500), () {
                       if (mounted && _searchQuery == val) _fetchTasks(refresh: true);
                     });
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton( // Filter
                icon: const Icon(Icons.filter_list),
                onPressed: _openFilters,
                style: IconButton.styleFrom(backgroundColor: Colors.white),
              ),
              const SizedBox(width: 4),
              IconButton( // Refresh
                icon: const Icon(Icons.refresh),
                onPressed: () => _fetchTasks(refresh: true),
                style: IconButton.styleFrom(backgroundColor: Colors.white),
              ),
              const SizedBox(width: 4),
              IconButton( // Add Task
                icon: const Icon(Icons.add, color: Colors.blue),
                onPressed: () => _openTaskForm(),
                style: IconButton.styleFrom(backgroundColor: Colors.white),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: _isFirstLoadRunning
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Expanded(
                      child: _tasks.isEmpty
                          ? const Center(child: Text('No tasks found'))
                          : RefreshIndicator(
                              onRefresh: () => _fetchTasks(refresh: true),
                              child: ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                itemCount: _tasks.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (ctx, index) {
                                  return TaskCard(
                                    task: _tasks[index],
                                    allServices: _services,
                                    onEdit: () => _openTaskForm(_tasks[index]),
                                    onRefresh: () => _fetchTasks(refresh: true),
                                    onAccept: () => _acceptTask(_tasks[index]['id']),
                                  );
                                },
                              ),
                            ),
                    ),
                    
                    // Pagination Controls
                    if (!_isFirstLoadRunning && _tasks.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                            color: Colors.transparent, // Removed white background
                            // Removed boxShadow
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ElevatedButton(
                              onPressed: _currentPage > 1 ? () => _changePage(_currentPage - 1) : null,
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.blue),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.arrow_back, size: 18),
                                  SizedBox(width: 8),
                                  Text('Prev'),
                                ],
                              ),
                            ),
                            Text('Page $_currentPage', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ElevatedButton(
                              onPressed: _hasNextPage ? () => _changePage(_currentPage + 1) : null,
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.blue),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Next'),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward, size: 18),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
