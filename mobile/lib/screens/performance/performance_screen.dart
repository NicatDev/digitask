import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile/core/api/api_client.dart';

/// Parity with web [`frontend/src/pages/performance/index.jsx`]:
/// `GET /performance/user-stats/?period=day|week|month&date=YYYY-MM-DD`
enum PerfPeriod { day, week, month }

const _azMonths = [
  'yanvar', 'fevral', 'mart', 'aprel', 'may', 'iyun',
  'iyul', 'avqust', 'sentyabr', 'oktyabr', 'noyabr', 'dekabr',
];

String _azMonthTitle(int m) {
  final s = _azMonths[m - 1];
  return s[0].toUpperCase() + s.substring(1);
}
class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({super.key});

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  PerfPeriod _period = PerfPeriod.day;
  DateTime _anchor = DateUtils.dateOnly(DateTime.now());
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
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
        queryParameters: {
          'period': _period.name,
          'date': DateFormat('yyyy-MM-dd').format(_anchor),
        },
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
    var pickM = _anchor.month;
    var pickY = _anchor.year;
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
                      return DropdownMenuItem(value: m, child: Text(_azMonthTitle(m)));
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
      final now = DateTime.now();
      var picked = DateTime(pickY, pickM, 1);
      if (picked.isAfter(now)) picked = DateTime(now.year, now.month, 1);
      _setAnchor(picked);
    }
  }

  // ---- Dövr köməkçiləri (həftə bazar ertəsindən başlayır, backend ilə eyni) ----

  DateTime _rangeStart(DateTime d) {
    switch (_period) {
      case PerfPeriod.day:
        return d;
      case PerfPeriod.week:
        return d.subtract(Duration(days: d.weekday - DateTime.monday));
      case PerfPeriod.month:
        return DateTime(d.year, d.month, 1);
    }
  }

  bool get _isCurrent =>
      DateUtils.isSameDay(_rangeStart(_anchor), _rangeStart(DateUtils.dateOnly(DateTime.now())));

  String _fmtDay(DateTime d) => '${d.day} ${_azMonths[d.month - 1]} ${d.year}';

  String _rangeLabel() {
    final s = _rangeStart(_anchor);
    switch (_period) {
      case PerfPeriod.day:
        return _fmtDay(s);
      case PerfPeriod.month:
        return '${_azMonthTitle(s.month)} ${s.year}';
      case PerfPeriod.week:
        final e = s.add(const Duration(days: 6));
        if (s.year != e.year) return '${_fmtDay(s)} – ${_fmtDay(e)}';
        if (s.month != e.month) {
          return '${s.day} ${_azMonths[s.month - 1]} – ${e.day} ${_azMonths[e.month - 1]} ${e.year}';
        }
        return '${s.day} – ${e.day} ${_azMonths[e.month - 1]} ${e.year}';
    }
  }

  String get _todayLabel {
    switch (_period) {
      case PerfPeriod.day:
        return 'Bu gün';
      case PerfPeriod.week:
        return 'Bu həftə';
      case PerfPeriod.month:
        return 'Bu ay';
    }
  }

  void _setAnchor(DateTime d) {
    setState(() => _anchor = DateUtils.dateOnly(d));
    _load();
  }

  void _setPeriod(PerfPeriod p) {
    if (p == _period) return;
    setState(() => _period = p);
    _load();
  }

  void _shift(int dir) {
    final a = _anchor;
    switch (_period) {
      case PerfPeriod.day:
        _setAnchor(a.add(Duration(days: dir)));
        break;
      case PerfPeriod.week:
        _setAnchor(a.add(Duration(days: 7 * dir)));
        break;
      case PerfPeriod.month:
        _setAnchor(DateTime(a.year, a.month + dir, 1));
        break;
    }
  }

  Future<void> _openPicker() async {
    if (_period == PerfPeriod.month) {
      await _pickMonthYear();
      return;
    }
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _anchor.isAfter(now) ? now : _anchor,
      firstDate: DateTime(2020),
      lastDate: now,
      helpText: _period == PerfPeriod.week ? 'Həftədən istənilən günü seçin' : 'Gün seçin',
      cancelText: 'Ləğv et',
      confirmText: 'Seç',
    );
    if (picked != null && mounted) _setAnchor(picked);
  }

  Widget _buildPeriodPanel() {
    final primary = Theme.of(context).colorScheme.primary;
    return Material(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<PerfPeriod>(
              segments: const [
                ButtonSegment(value: PerfPeriod.day, label: Text('Günlük'), icon: Icon(Icons.today, size: 18)),
                ButtonSegment(value: PerfPeriod.week, label: Text('Həftəlik'), icon: Icon(Icons.view_week_outlined, size: 18)),
                ButtonSegment(value: PerfPeriod.month, label: Text('Aylıq'), icon: Icon(Icons.calendar_month_outlined, size: 18)),
              ],
              selected: {_period},
              showSelectedIcon: false,
              onSelectionChanged: _loading ? null : (s) => _setPeriod(s.first),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                IconButton.outlined(
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'Əvvəlki',
                  onPressed: _loading ? null : () => _shift(-1),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: _loading ? null : _openPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: primary.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event, size: 18, color: primary),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _rangeLabel(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.outlined(
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'Növbəti',
                  onPressed: (_loading || _isCurrent) ? null : () => _shift(1),
                ),
              ],
            ),
            if (!_isCurrent) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.center,
                child: TextButton.icon(
                  onPressed: _loading ? null : () => _setAnchor(DateTime.now()),
                  icon: const Icon(Icons.restore, size: 18),
                  label: Text(_todayLabel),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    var completed = 0;
    var active = 0;
    var activeInPeriod = 0;
    for (final r in _rows) {
      final st = r['stats'] is Map ? Map<String, dynamic>.from(r['stats'] as Map) : const <String, dynamic>{};
      completed += _asInt(st['completed']);
      active += _asInt(st['active']);
      activeInPeriod += _asInt(st['active_in_period']);
    }
    final total = completed + active;
    final eff = total > 0 ? (completed / total * 100) : 0.0;

    Widget tile(String label, String value, Color color) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(
        children: [
          Row(
            children: [
              tile('Tamamlanmış', '$completed', Colors.green),
              const SizedBox(width: 8),
              tile('Dövr üzrə aktiv', '$activeInPeriod', Colors.indigo),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              tile('Ümumi aktiv', '$active', Colors.blue),
              const SizedBox(width: 8),
              tile('Effektivlik', '${eff.toStringAsFixed(1)}%', Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('İşçi performansı'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPeriodPanel(),
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
                              padding: const EdgeInsets.only(bottom: 12),
                              itemCount: _rows.length + 1,
                              itemBuilder: (context, index) {
                                if (index == 0) return _buildSummary();
                                return Padding(
                                  padding: EdgeInsets.fromLTRB(12, index == 1 ? 12 : 0, 12, 0),
                                  child: _UserPerformanceCard(data: _rows[index - 1]),
                                );
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
    final activeInPeriod = _asInt(stats['active_in_period']);
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
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _statChip('Ümumi', '$total', Colors.blueGrey),
                    _statChip('Tamamlanmış', '$completed', Colors.green),
                    _statChip('Dövr üzrə aktiv', '$activeInPeriod', Colors.indigo),
                    _statChip('Ümumi aktiv', '$active', Colors.blue),
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
