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
      }
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _searchAddress(String q) async {
    if (q.trim().length < 3) {
      setState(() => _addressOptions = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final res = await ApiClient().dio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'format': 'json',
          'q': q.trim(),
          'limit': 5,
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
      if (!mounted) return;
      setState(() => _addressOptions = list);
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _searching = false);
    }
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
      setState(() => _coords = next);
      _mapCtrl.move(next, 16);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lokasiya tapılmadı')),
      );
    }
  }

  Future<void> _save() async {
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
                      controller: _addressCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Ünvan',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _searchCtrl,
                      onChanged: (v) {
                        Future.delayed(const Duration(milliseconds: 400), () {
                          if (!mounted) return;
                          if (_searchCtrl.text == v) _searchAddress(v);
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Ünvan axtar',
                        border: const OutlineInputBorder(),
                        suffixIcon: _searching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                              )
                            : const Icon(Icons.search),
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
                              onTap: () {
                                final next = LatLng(o['lat'] as double, o['lng'] as double);
                                setState(() {
                                  _coords = next;
                                  _addressCtrl.text = o['label'].toString();
                                  _addressOptions = [];
                                });
                                _mapCtrl.move(next, 16);
                              },
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _useMyLocation,
                        icon: const Icon(Icons.my_location),
                        label: const Text('Mənim lokasiyam'),
                      ),
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
                            onTap: (tapPosition, point) {
                              setState(() => _coords = point);
                            },
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.example.mobile',
                            ),
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
