import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/core/tracking_socket_url.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// OSRM public demo — same as web live-map.
const _osrmBase =
    'https://router.project-osrm.org/route/v1/driving';

const _routeColorsHex = [
  '#52c41a',
  '#1890ff',
  '#722ed1',
  '#eb2f96',
  '#fa8c16',
  '#13c2c2',
  '#f5222d',
];

Color _hexColor(String hex) {
  var h = hex.replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  return Color(int.parse(h, radix: 16));
}

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

int _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.parse(v.toString());
}

bool _isRecentlyOnline(bool isOnline, DateTime? lastSeen) {
  if (isOnline) return true;
  if (lastSeen == null) return false;
  return DateTime.now().toUtc().difference(lastSeen.toUtc()) <
      const Duration(minutes: 10);
}

class _ActiveTask {
  _ActiveTask({
    required this.id,
    required this.customerName,
    this.custLat,
    this.custLng,
    this.address,
  });

  final int id;
  final String customerName;
  final double? custLat;
  final double? custLng;
  final String? address;
}

class _MapUser {
  _MapUser({
    required this.userId,
    required this.fullName,
    required this.role,
    this.lat,
    this.lng,
    required this.isOnline,
    this.lastSeen,
    required this.tasks,
  });

  final int userId;
  final String fullName;
  final String role;
  double? lat;
  double? lng;
  bool isOnline;
  DateTime? lastSeen;
  final List<_ActiveTask> tasks;

  bool get hasLocation => lat != null && lng != null;

  String get firstName {
    final p = fullName.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    return p.isNotEmpty ? p.first : fullName;
  }

  static _MapUser fromJson(Map<String, dynamic> j) {
    final tasksRaw = j['active_tasks'] as List<dynamic>? ?? [];
    return _MapUser(
      userId: _asInt(j['user_id']),
      fullName: j['full_name']?.toString() ?? '',
      role: j['role']?.toString() ?? '',
      lat: _toDouble(j['latitude']),
      lng: _toDouble(j['longitude']),
      isOnline: j['is_online'] == true,
      lastSeen: j['last_seen'] != null
          ? DateTime.tryParse(j['last_seen'].toString())?.toUtc()
          : null,
      tasks: tasksRaw.map((t) {
        final m = t as Map<String, dynamic>;
        return _ActiveTask(
          id: _asInt(m['id']),
          customerName: m['customer_name']?.toString() ?? '',
          custLat: _toDouble(m['customer_lat']),
          custLng: _toDouble(m['customer_lng']),
          address: m['customer_address']?.toString(),
        );
      }).toList(),
    );
  }
}

class _WarehousePin {
  _WarehousePin({
    required this.id,
    required this.name,
    this.lat,
    this.lng,
  });

  final int id;
  final String name;
  final double? lat;
  final double? lng;

  bool get hasLocation => lat != null && lng != null;

  static _WarehousePin fromJson(Map<String, dynamic> j) {
    return _WarehousePin(
      id: _asInt(j['id']),
      name: j['name']?.toString() ?? '',
      lat: _toDouble(j['lat']),
      lng: _toDouble(j['lng']),
    );
  }
}

class LiveMapScreen extends StatefulWidget {
  const LiveMapScreen({super.key});

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  List<_MapUser> _users = [];
  List<_WarehousePin> _warehouses = [];
  final Set<int> _selectedUserIds = {};
  final Set<int> _selectedWarehouseIds = {};
  final Map<String, List<LatLng>> _routes = {};

  bool _loading = true;
  String? _error;

  WebSocketChannel? _wsChannel;
  StreamSubscription<dynamic>? _wsSub;

  final Dio _osrmDio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 20),
    validateStatus: (_) => true,
  ));

  static const _initialCenter = LatLng(40.4093, 49.8671);
  static const double _initialZoom = 12;

  @override
  void initState() {
    super.initState();
    _loadData();
    _connectWebSocket();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _wsSub?.cancel();
    _wsChannel?.sink.close();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiClient().dio.get('/live-map/');
      final data = res.data as Map<String, dynamic>?;
      if (data == null) throw Exception('Boş cavab');
      final usersList = (data['users'] as List<dynamic>? ?? [])
          .map((e) => _MapUser.fromJson(e as Map<String, dynamic>))
          .toList();
      final whList = (data['warehouses'] as List<dynamic>? ?? [])
          .map((e) => _WarehousePin.fromJson(e as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _users = usersList;
        _warehouses = whList;
        _loading = false;
      });
      _fetchAllRoutes();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _connectWebSocket() async {
    final url = await getTrackingWebSocketUrl();
    if (url == null || !mounted) return;
    try {
      if (kIsWeb) {
        _wsChannel = WebSocketChannel.connect(Uri.parse(url));
      } else {
        _wsChannel = IOWebSocketChannel.connect(url);
      }
      _wsSub = _wsChannel!.stream.listen(
        _onWsMessage,
        onError: (_) {},
        onDone: () {},
      );
    } catch (_) {}
  }

  void _onWsMessage(dynamic message) {
    if (message is! String) return;
    Map<String, dynamic>? data;
    try {
      data = jsonDecode(message) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    if (data['type'] != 'location_message') return;
    final uid = _asInt(data['user_id']);
    final lat = _toDouble(data['latitude']);
    final lng = _toDouble(data['longitude']);
    final online = data['is_online'] == true;
    if (lat == null || lng == null) return;

    if (!mounted) return;
    _MapUser? updated;
    setState(() {
      final idx = _users.indexWhere((u) => u.userId == uid);
      if (idx >= 0) {
        final u = _users[idx];
        u.lat = lat;
        u.lng = lng;
        u.isOnline = online;
        u.lastSeen = DateTime.now().toUtc();
        updated = u;
      }
    });
    if (updated != null) _fetchRoutesForUser(updated!);
  }

  Future<void> _fetchOsrmRoute(
    String routeKey,
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) async {
    if (startLat.isNaN ||
        startLng.isNaN ||
        endLat.isNaN ||
        endLng.isNaN) {
      return;
    }
    final url =
        '$_osrmBase/$startLng,$startLat;$endLng,$endLat?overview=full&geometries=geojson';
    try {
      final res = await _osrmDio.get(url);
      final data = res.data;
      if (data is! Map || data['routes'] is! List) {
        _setFallbackRoute(routeKey, startLat, startLng, endLat, endLng);
        return;
      }
      final routes = data['routes'] as List;
      if (routes.isEmpty) {
        _setFallbackRoute(routeKey, startLat, startLng, endLat, endLng);
        return;
      }
      final geom = routes[0]['geometry'];
      if (geom is! Map || geom['coordinates'] is! List) {
        _setFallbackRoute(routeKey, startLat, startLng, endLat, endLng);
        return;
      }
      final coords = geom['coordinates'] as List;
      final points = <LatLng>[];
      for (final c in coords) {
        if (c is List && c.length >= 2) {
          final lng = _toDouble(c[0]);
          final lat = _toDouble(c[1]);
          if (lat != null && lng != null) {
            points.add(LatLng(lat, lng));
          }
        }
      }
      if (points.isEmpty) {
        _setFallbackRoute(routeKey, startLat, startLng, endLat, endLng);
        return;
      }
      if (mounted) {
        setState(() => _routes[routeKey] = points);
      }
    } catch (_) {
      _setFallbackRoute(routeKey, startLat, startLng, endLat, endLng);
    }
  }

  void _setFallbackRoute(
    String routeKey,
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    if (!mounted) return;
    setState(() {
      _routes[routeKey] = [
        LatLng(startLat, startLng),
        LatLng(endLat, endLng),
      ];
    });
  }

  void _fetchAllRoutes() {
    for (final u in _users) {
      _fetchRoutesForUser(u);
    }
  }

  void _fetchRoutesForUser(_MapUser u) {
    final lat = u.lat;
    final lng = u.lng;
    if (lat == null || lng == null) return;
    for (var i = 0; i < u.tasks.length; i++) {
      final t = u.tasks[i];
      final clat = t.custLat;
      final clng = t.custLng;
      if (clat != null && clng != null) {
        unawaited(_fetchOsrmRoute(
          '${u.userId}_${t.id}',
          lat,
          lng,
          clat,
          clng,
        ));
      }
    }
  }

  void _flyTo(double lat, double lng) {
    _mapController.move(LatLng(lat, lng), 16);
  }

  void _toggleUser(int id) {
    setState(() {
      if (_selectedUserIds.contains(id)) {
        _selectedUserIds.remove(id);
      } else {
        _selectedUserIds.add(id);
      }
    });
  }

  void _toggleWarehouse(int id) {
    setState(() {
      if (_selectedWarehouseIds.contains(id)) {
        _selectedWarehouseIds.remove(id);
      } else {
        _selectedWarehouseIds.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedUserIds
        ..clear()
        ..addAll(_users.map((u) => u.userId));
      _selectedWarehouseIds
        ..clear()
        ..addAll(_warehouses.map((w) => w.id));
    });
  }

  void _clearAll() {
    setState(() {
      _selectedUserIds.clear();
      _selectedWarehouseIds.clear();
    });
  }

  List<_MapUser> get _filteredUsers {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _users;
    return _users
        .where((u) => u.fullName.toLowerCase().contains(q))
        .toList();
  }

  bool get _allUsersSelected =>
      _users.isNotEmpty && _selectedUserIds.length == _users.length;

  bool get _someUsersSelected =>
      _selectedUserIds.isNotEmpty && !_allUsersSelected;

  bool get _allWhSelected =>
      _warehouses.isNotEmpty &&
      _selectedWarehouseIds.length == _warehouses.length;

  bool get _someWhSelected =>
      _selectedWarehouseIds.isNotEmpty && !_allWhSelected;

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    for (final w in _warehouses) {
      if (!_selectedWarehouseIds.contains(w.id)) continue;
      final lat = w.lat;
      final lng = w.lng;
      if (lat == null || lng == null) continue;
      markers.add(
        Marker(
          point: LatLng(lat, lng),
          width: 44,
          height: 44,
          child: Tooltip(
            message: w.name,
            child: Icon(Icons.warehouse, color: Colors.amber.shade800, size: 40),
          ),
        ),
      );
    }

    for (final u in _users) {
      if (!_selectedUserIds.contains(u.userId)) continue;
      final lat = u.lat;
      final lng = u.lng;
      if (lat == null || lng == null) continue;
      final activeOrRecent = _isRecentlyOnline(u.isOnline, u.lastSeen);
      final color = activeOrRecent ? const Color(0xFF52c41a) : const Color(0xFF8c8c8c);

      markers.add(
        Marker(
          point: LatLng(lat, lng),
          width: 100,
          height: 64,
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {
              showModalBottomSheet<void>(
                context: context,
                builder: (ctx) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(u.fullName,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(u.role),
                      const SizedBox(height: 8),
                      Text(
                        u.isOnline
                            ? 'Online'
                            : activeOrRecent
                                ? 'Son 10 dəq aktiv'
                                : 'Offline',
                        style: TextStyle(
                          color: u.isOnline || activeOrRecent
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person, color: color, size: 36),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 3,
                        color: Colors.black26,
                      ),
                    ],
                  ),
                  child: Text(
                    u.firstName,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      for (var ti = 0; ti < u.tasks.length; ti++) {
        final t = u.tasks[ti];
        final clat = t.custLat;
        final clng = t.custLng;
        if (clat == null || clng == null) continue;
        final col = _hexColor(_routeColorsHex[ti % _routeColorsHex.length]);
        markers.add(
          Marker(
            point: LatLng(clat, clng),
            width: 40,
            height: 40,
            child: Tooltip(
              message: t.customerName,
              child: Icon(Icons.home, color: col, size: 36),
            ),
          ),
        );
      }
    }

    return markers;
  }

  List<Polyline> _buildPolylines() {
    final list = <Polyline>[];
    for (final u in _users) {
      if (!_selectedUserIds.contains(u.userId)) continue;
      for (var ti = 0; ti < u.tasks.length; ti++) {
        final t = u.tasks[ti];
        final key = '${u.userId}_${t.id}';
        final pts = _routes[key];
        if (pts == null || pts.isEmpty) continue;
        final col = _hexColor(_routeColorsHex[ti % _routeColorsHex.length]);
        list.add(
          Polyline(
            points: pts,
            color: col.withValues(alpha: 0.85),
            strokeWidth: 5,
          ),
        );
      }
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Canlı xəritə'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadData,
          ),
        ],
      ),
      endDrawer: Drawer(
        width: MediaQuery.sizeOf(context).width * 0.88 > 360
            ? 360
            : MediaQuery.sizeOf(context).width * 0.88,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Xəritə paneli',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'İstifadəçi axtar...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _selectAll,
                        child: const Text('Hamısını seç'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _clearAll,
                        child: const Text('Təmizlə'),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: [
                    ExpansionTile(
                      initiallyExpanded: true,
                      title: Row(
                        children: [
                          const Icon(Icons.person_outline, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text('İstifadəçilər (${_users.length})')),
                          Checkbox(
                            tristate: true,
                            value: _allUsersSelected
                                ? true
                                : (_someUsersSelected ? null : false),
                            onChanged: (_) {
                              if (_allUsersSelected) {
                                setState(() => _selectedUserIds.clear());
                              } else {
                                setState(() {
                                  _selectedUserIds
                                    ..clear()
                                    ..addAll(_users.map((u) => u.userId));
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      children: _filteredUsers.map((u) {
                        final hasLoc = u.hasLocation;
                        return ListTile(
                          dense: true,
                          leading: Checkbox(
                            value: _selectedUserIds.contains(u.userId),
                            onChanged: hasLoc
                                ? (_) => _toggleUser(u.userId)
                                : null,
                          ),
                          title: Row(
                            children: [
                              Icon(
                                Icons.circle,
                                size: 12,
                                color: u.isOnline
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  u.fullName,
                                  style: TextStyle(
                                    color: hasLoc ? null : Colors.grey,
                                    fontWeight:
                                        hasLoc ? FontWeight.w500 : FontWeight.normal,
                                  ),
                                ),
                              ),
                              if (!hasLoc)
                                Text(
                                  'GPS yoxdur',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                            ],
                          ),
                          onTap: hasLoc
                              ? () {
                                  setState(() {
                                    _selectedUserIds.add(u.userId);
                                  });
                                  _flyTo(u.lat!, u.lng!);
                                  Navigator.pop(context);
                                }
                              : null,
                        );
                      }).toList(),
                    ),
                    ExpansionTile(
                      initiallyExpanded: true,
                      title: Row(
                        children: [
                          const Icon(Icons.storefront_outlined, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text('Anbarlar (${_warehouses.length})')),
                          Checkbox(
                            tristate: true,
                            value: _allWhSelected
                                ? true
                                : (_someWhSelected ? null : false),
                            onChanged: (_) {
                              if (_allWhSelected) {
                                setState(() => _selectedWarehouseIds.clear());
                              } else {
                                setState(() {
                                  _selectedWarehouseIds
                                    ..clear()
                                    ..addAll(_warehouses.map((w) => w.id));
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      children: _warehouses.map((w) {
                        final hasLoc = w.hasLocation;
                        return ListTile(
                          dense: true,
                          leading: Checkbox(
                            value: _selectedWarehouseIds.contains(w.id),
                            onChanged: (_) => _toggleWarehouse(w.id),
                          ),
                          title: Text(w.name),
                          onTap: hasLoc
                              ? () {
                                  setState(() {
                                    _selectedWarehouseIds.add(w.id);
                                  });
                                  _flyTo(w.lat!, w.lng!);
                                  Navigator.pop(context);
                                }
                              : null,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: _loading
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
                          onPressed: _loadData,
                          child: const Text('Yenidən cəhd et'),
                        ),
                      ],
                    ),
                  ),
                )
              : Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _initialCenter,
                        initialZoom: _initialZoom,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.mobile',
                        ),
                        PolylineLayer(polylines: _buildPolylines()),
                        MarkerLayer(markers: _buildMarkers()),
                      ],
                    ),
                    Positioned(
                      right: 8,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Material(
                          elevation: 4,
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: IconButton(
                            tooltip: 'Filtrlər',
                            icon: const Icon(Icons.filter_list),
                            onPressed: () =>
                                _scaffoldKey.currentState?.openEndDrawer(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
