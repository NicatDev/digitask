import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile/core/api/api_client.dart';

class CustomerAddressEditModal extends StatefulWidget {
  final int customerId;
  final String customerLabel;

  const CustomerAddressEditModal({
    super.key,
    required this.customerId,
    required this.customerLabel,
  });

  @override
  State<CustomerAddressEditModal> createState() => _CustomerAddressEditModalState();
}

class _CustomerAddressEditModalState extends State<CustomerAddressEditModal> {
  final _addressCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final _mapCtrl = MapController();

  LatLng _coords = const LatLng(40.4093, 49.8671);
  bool _hasCoords = false;
  bool _loading = true;
  bool _saving = false;
  bool _searching = false;
  List<Map<String, dynamic>> _addressOptions = [];

  @override
  void initState() {
    super.initState();
    _loadCustomer();
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCustomer() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient().dio.get('/tasks/customers/${widget.customerId}/');
      final data = res.data;
      if (!mounted) return;
      _addressCtrl.text = (data['address'] ?? '').toString();
      final c = data['address_coordinates'];
      if (c is Map && c['lat'] != null && c['lng'] != null) {
        _coords = LatLng(
          double.parse(c['lat'].toString()),
          double.parse(c['lng'].toString()),
        );
        _hasCoords = true;
      }
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// OSM üçün ayrıca Dio — tətbiqin auth tokeni kənar serverə getməsin.
  static final Dio _osm = Dio(BaseOptions(
    baseUrl: 'https://nominatim.openstreetmap.org',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'User-Agent': 'DigitaskMobile/1.0', 'Accept-Language': 'az'},
  ));

  int _searchSeq = 0;

  Future<List<Map<String, dynamic>>> _searchAddress(String q) async {
    if (q.trim().length < 3) {
      setState(() => _addressOptions = []);
      return [];
    }
    final seq = ++_searchSeq;
    setState(() => _searching = true);
    try {
      final res = await _osm.get(
        '/search',
        queryParameters: {
          'format': 'json',
          'q': q.trim(),
          'limit': 6,
          'countrycodes': 'az',
        },
      );
      final list = (res.data as List)
          .map<Map<String, dynamic>>((e) => {
                'label': (e['display_name'] ?? '').toString(),
                'lat': double.parse(e['lat'].toString()),
                'lng': double.parse(e['lon'].toString()),
              })
          .toList();
      if (!mounted || seq != _searchSeq) return list;
      setState(() => _addressOptions = list);
      return list;
    } catch (_) {
      return [];
    } finally {
      if (mounted && seq == _searchSeq) setState(() => _searching = false);
    }
  }

  void _applyOption(Map<String, dynamic> o) {
    final next = LatLng(o['lat'] as double, o['lng'] as double);
    _searchSeq++;
    setState(() {
      _coords = next;
      _hasCoords = true;
      _addressCtrl.text = o['label'].toString();
      _addressOptions = [];
      _searching = false;
    });
    _mapCtrl.move(next, 17);
    FocusScope.of(context).unfocus();
  }

  /// Enter / axtarış düyməsi: ilk nəticəni xəritədə göstər.
  Future<void> _findOnMap(String q) async {
    if (q.trim().length < 3) {
      _snack('Axtarış üçün ən azı 3 hərf yazın');
      return;
    }
    final list = await _searchAddress(q);
    if (!mounted) return;
    if (list.isNotEmpty) {
      _applyOption(list.first);
    } else {
      _snack('Ünvan tapılmadı. Başqa sözlə yoxlayın və ya xəritəyə toxunun.');
    }
  }

  Future<void> _pickPoint(LatLng point) async {
    setState(() {
      _coords = point;
      _hasCoords = true;
    });
    if (_addressCtrl.text.trim().isNotEmpty) return;
    try {
      final res = await _osm.get('/reverse', queryParameters: {
        'format': 'json',
        'lat': point.latitude,
        'lon': point.longitude,
        'zoom': 18,
      });
      final label = (res.data is Map ? res.data['display_name'] : null)?.toString() ?? '';
      if (mounted && label.isNotEmpty && _addressCtrl.text.trim().isEmpty) {
        setState(() => _addressCtrl.text = label);
      }
    } catch (_) {
      // ignore
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _useMyLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lokasiya icazəsi verilməyib')),
        );
        return;
      }
      final p = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      final next = LatLng(p.latitude, p.longitude);
      _mapCtrl.move(next, 17);
      await _pickPoint(next);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lokasiya tapılmadı')),
      );
    }
  }

  Future<void> _save() async {
    if (_addressCtrl.text.trim().isEmpty) {
      _snack('Ünvanı daxil edin');
      return;
    }
    if (!_hasCoords) {
      _snack('Xəritədə müştərinin yerini seçin (axtarın və ya xəritəyə toxunun)');
      return;
    }
    setState(() => _saving = true);
    try {
      await ApiClient().dio.patch('/tasks/customers/${widget.customerId}/', data: {
        'address': _addressCtrl.text.trim(),
        'address_coordinates': {
          'lat': _coords.latitude,
          'lng': _coords.longitude,
        }
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yenilənmə uğursuz oldu')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 760,
        height: 640,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Müştəri ünvanı: ${widget.customerLabel}',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    TextField(
                      controller: _searchCtrl,
                      textInputAction: TextInputAction.search,
                      onSubmitted: _findOnMap,
                      onChanged: (v) {
                        Future.delayed(const Duration(milliseconds: 450), () {
                          if (!mounted) return;
                          if (_searchCtrl.text == v) _searchAddress(v);
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Ünvan axtar (küçə, məhəllə, bina...)',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                              )
                            : IconButton(
                                tooltip: 'Xəritədə tap',
                                icon: const Icon(Icons.travel_explore, color: Colors.blue),
                                onPressed: () => _findOnMap(_searchCtrl.text),
                              ),
                      ),
                    ),
                    if (_addressOptions.isNotEmpty)
                      Container(
                        constraints: const BoxConstraints(maxHeight: 130),
                        margin: const EdgeInsets.only(top: 6),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.builder(
                          itemCount: _addressOptions.length,
                          itemBuilder: (_, i) {
                            final o = _addressOptions[i];
                            return ListTile(
                              dense: true,
                              title: Text(
                                o['label'].toString(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => _applyOption(o),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _addressCtrl,
                      decoration: InputDecoration(
                        labelText: 'Ünvan *',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.place_outlined),
                        suffixIcon: IconButton(
                          tooltip: 'Xəritədə göstər',
                          icon: const Icon(Icons.map_outlined),
                          onPressed: () => _findOnMap(_addressCtrl.text),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _hasCoords
                                ? 'Yer seçilib. Dəqiqləşdirmək üçün xəritəyə toxunun.'
                                : 'Yer seçilməyib — axtarın və ya xəritəyə toxunun.',
                            style: TextStyle(
                              fontSize: 12,
                              color: _hasCoords ? Colors.green.shade700 : Colors.orange.shade800,
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _useMyLocation,
                          icon: const Icon(Icons.my_location, size: 18),
                          label: const Text('Mənim lokasiyam'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: FlutterMap(
                          mapController: _mapCtrl,
                          options: MapOptions(
                            initialCenter: _coords,
                            initialZoom: 14,
                            onTap: (tapPosition, point) => _pickPoint(point),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.example.mobile',
                            ),
                            if (_hasCoords)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: _coords,
                                  width: 40,
                                  height: 40,
                                  child: const Icon(Icons.location_on, color: Colors.red, size: 38),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Yadda saxla'),
                      ),
                    )
                  ],
                ),
              ),
      ),
    );
  }
}
