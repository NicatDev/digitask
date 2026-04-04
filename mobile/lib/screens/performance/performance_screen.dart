import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile/core/api/api_client.dart';

/// Parity with web [`frontend/src/pages/performance/index.jsx`]:
/// `GET /performance/user-stats/?month=&year=`
class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({super.key});

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  late int _month;
  late int _year;
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _month = n.month;
    _year = n.year;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiClient().dio.get(
        '/performance/user-stats/',
        queryParameters: {'month': _month, 'year': _year},
      );
      if (!mounted) return;
      final raw = res.data;
      final list = <Map<String, dynamic>>[];
      if (raw is List) {
        for (final e in raw) {
          if (e is Map) {
            list.add(Map<String, dynamic>.from(e));
          }
        }
      }
      setState(() {
        _rows = list;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _pickMonthYear() async {
    var pickM = _month;
    var pickY = _year;
    final now = DateTime.now();
    final maxYear = now.year + 1;
    final years = List<int>.generate(maxYear - 2019, (i) => 2020 + i);

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.paddingOf(ctx).bottom + 20,
          ),
          child: StatefulBuilder(
            builder: (ctx, setModal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Ay və il seçin',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Ay',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButton<int>(
                    value: pickM,
                    isExpanded: true,
                    items: List.generate(12, (i) {
                      final m = i + 1;
                      final label =
                          DateFormat('MMMM').format(DateTime(2000, m));
                      return DropdownMenuItem(value: m, child: Text(label));
                    }),
                    onChanged: (v) {
                      if (v != null) setModal(() => pickM = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'İl',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButton<int>(
                    value: pickY,
                    isExpanded: true,
                    items: years
                        .map((y) =>
                            DropdownMenuItem(value: y, child: Text('$y')))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setModal(() => pickY = v);
                    },
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Tətbiq et'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    if (ok == true && mounted) {
      setState(() {
        _month = pickM;
        _year = pickY;
      });
      await _load();
    }
  }

  String _monthYearLabel() {
    return DateFormat('MMMM yyyy').format(DateTime(_year, _month));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('İşçi performansı'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: 'Ay seç',
            onPressed: _loading ? null : _pickMonthYear,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _monthYearLabel(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _loading ? null : _pickMonthYear,
                    icon: const Icon(Icons.edit_calendar, size: 18),
                    label: const Text('Ay'),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!, textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: _load,
                                child: const Text('Yenidən cəhd et'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _rows.isEmpty
                        ? const Center(child: Text('Məlumat yoxdur'))
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _rows.length,
                              itemBuilder: (context, index) {
                                return _UserPerformanceCard(data: _rows[index]);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _UserPerformanceCard extends StatelessWidget {
  const _UserPerformanceCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final user = data['user'] is Map
        ? Map<String, dynamic>.from(data['user'] as Map)
        : <String, dynamic>{};
    final stats = data['stats'] is Map
        ? Map<String, dynamic>.from(data['stats'] as Map)
        : <String, dynamic>{};
    final breakdown = data['breakdown'] is Map
        ? Map<String, dynamic>.from(data['breakdown'] as Map)
        : <String, dynamic>{};

    final fullName = user['full_name']?.toString() ?? '';
    final username = user['username']?.toString() ?? '';
    final title = fullName.isNotEmpty ? fullName : username;

    final total = _asInt(stats['total']);
    final completed = _asInt(stats['completed']);
    final active = _asInt(stats['active']);
    final efficiency = _asDouble(stats['efficiency']);
    final effClamped = efficiency.clamp(0.0, 100.0);

    final types = breakdown['types'] is List
        ? List<dynamic>.from(breakdown['types'] as List)
        : <dynamic>[];
    final services = breakdown['services'] is List
        ? List<dynamic>.from(breakdown['services'] as List)
        : <dynamic>[];

    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          backgroundColor: Colors.white,
          collapsedBackgroundColor: Colors.white,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding:
              const EdgeInsets.only(left: 16, right: 16, bottom: 16),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _statChip('Ümumi', '$total', Colors.blueGrey),
                    const SizedBox(width: 6),
                    _statChip('Tamamlanmış', '$completed', Colors.green),
                    const SizedBox(width: 6),
                    _statChip('Aktiv', '$active', Colors.blue),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: effClamped / 100.0,
                          minHeight: 8,
                          backgroundColor: Colors.grey.shade200,
                          color: effClamped >= 100 ? Colors.green : Colors.blue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${efficiency.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Effektivlik',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Tapşırıq növləri',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (types.isEmpty)
              Text(
                'Məlumat yoxdur',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: types.map((t) {
                  if (t is! Map) {
                    return const SizedBox.shrink();
                  }
                  final m = Map<String, dynamic>.from(t);
                  final name =
                      m['task_type__name']?.toString() ?? 'Təyin olunmayıb';
                  final c = _asInt(m['count']);
                  return Chip(
                    label: Text('$name: $c'),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: Colors.cyan.shade50,
                  );
                }).toList(),
              ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Xidmətlər',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.purple.shade800,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (services.isEmpty)
              Text(
                'Məlumat yoxdur',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: services.map((s) {
                  if (s is! Map) {
                    return const SizedBox.shrink();
                  }
                  final m = Map<String, dynamic>.from(s);
                  final name =
                      m['services__name']?.toString() ?? 'Təyin olunmayıb';
                  final c = _asInt(m['count']);
                  return Chip(
                    label: Text('$name: $c'),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: Colors.purple.shade50,
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  static Widget _statChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }
}

int _asInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

double _asDouble(dynamic v) {
  if (v == null) return 0;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}
