import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile/core/api/api_client.dart';

class TaskActivityFeedScreen extends StatefulWidget {
  const TaskActivityFeedScreen({super.key});

  @override
  State<TaskActivityFeedScreen> createState() => _TaskActivityFeedScreenState();
}

class _TaskActivityFeedScreenState extends State<TaskActivityFeedScreen> {
  bool _loading = true;
  int _page = 1;
  int _pageSize = 40;
  int _total = 0;
  bool _hasNext = false;
  List<dynamic> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({int? page}) async {
    setState(() => _loading = true);
    try {
      final currentPage = page ?? _page;
      final res = await ApiClient().dio.get(
        '/tasks/tasks/activity-feed/',
        queryParameters: {'page': currentPage, 'page_size': _pageSize},
      );
      final data = res.data;
      final results = (data is Map && data['results'] is List) ? (data['results'] as List) : const [];
      final count = (data is Map && data['count'] is int) ? (data['count'] as int) : results.length;
      final next = (data is Map) ? data['next'] != null : false;
      if (!mounted) return;
      setState(() {
        _page = currentPage;
        _items = results;
        _total = count;
        _hasNext = next;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _items = [];
        _total = 0;
        _hasNext = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hərəkətlər yüklənmədi')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatTaskLine(Map<String, dynamic> item) {
    final taskId = item['task_id']?.toString() ?? '—';
    final reg = item['task_register_number']?.toString().trim();
    final title = item['task_title']?.toString().trim();
    final regDisplay = (reg == null || reg.isEmpty) ? '—' : reg;
    final titleDisplay = (title == null || title.isEmpty) ? '—' : title;
    return 'Tapşırıq #$taskId · Qeyd. № $regDisplay · $titleDisplay';
  }

  String _formatProcessLine(Map<String, dynamic> item) {
    final actor = item['user_name']?.toString().trim() ?? '';
    final actionDisplay = item['action_display']?.toString().trim() ?? '';
    final message = item['message']?.toString().trim() ?? '';
    final lead = [if (actor.isNotEmpty) actor, if (actionDisplay.isNotEmpty) actionDisplay].join(' · ');
    if (message.isEmpty) return lead.isEmpty ? '-' : lead;
    if (lead.isEmpty) return message;
    return '$lead\n$message';
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tapşırıq hərəkətləri'),
        actions: [
          IconButton(
            onPressed: _loading ? null : () => _load(page: _page),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Son 7 gün üzrə (bugündən keçmişə)',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text('Cəm: $_total'),
                    ],
                  ),
                ),
                Expanded(
                  child: _items.isEmpty
                      ? const Center(child: Text('Məlumat yoxdur'))
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = (_items[index] as Map).cast<String, dynamic>();
                            final createdAt = item['created_at']?.toString();
                            final timeText = createdAt != null
                                ? dateFormat.format(DateTime.tryParse(createdAt)?.toLocal() ?? DateTime.now())
                                : '—';
                            return Card(
                              elevation: 1,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _formatTaskLine(item),
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _formatProcessLine(item),
                                      style: const TextStyle(height: 1.35),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      timeText,
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0x11000000))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _page > 1 && !_loading ? () => _load(page: _page - 1) : null,
                        icon: const Icon(Icons.chevron_left),
                        label: const Text('Əvvəlki'),
                      ),
                      Text('Səhifə $_page'),
                      OutlinedButton.icon(
                        onPressed: _hasNext && !_loading ? () => _load(page: _page + 1) : null,
                        icon: const Icon(Icons.chevron_right),
                        label: const Text('Növbəti'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
