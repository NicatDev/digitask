import 'package:flutter/material.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile/screens/warehouse/widgets/location_picker_modal.dart';
import 'package:mobile/screens/warehouse/widgets/warehouse_card.dart';

class WarehousesTab extends StatefulWidget {
  const WarehousesTab({super.key});

  @override
  State<WarehousesTab> createState() => _WarehousesTabState();
}

class _WarehousesTabState extends State<WarehousesTab> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _warehouses = [];
  List<dynamic> _regions = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _activeFilter = 'all';
  int _currentPage = 1;
  bool _hasNextPage = true;

  @override
  void initState() {
    super.initState();
    _fetchRegions();
    _fetchWarehouses();
  }

  Future<void> _fetchRegions() async {
    try {
      final response = await ApiClient().dio.get('/regions/');
      if (response.statusCode == 200) {
        setState(() {
          final data = response.data;
          if (data is Map && data.containsKey('results')) {
            _regions = data['results'];
          } else if (data is List) {
            _regions = data;
          }
        });
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> _fetchWarehouses({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _currentPage = 1;
        _hasNextPage = true;
        _isLoading = true;
        _warehouses = [];
      });
    } else {
      setState(() => _isLoading = true);
    }

    try {
      final params = <String, dynamic>{
        'search': _searchQuery,
        'page': _currentPage,
      };
      
      if (_activeFilter == 'active') {
        params['is_active'] = 'true';
      } else if (_activeFilter == 'inactive') {
        params['is_active'] = 'false';
      }

      final response = await ApiClient().dio.get(
        '/warehouse/warehouses/',
        queryParameters: params,
      );

      if (response.statusCode == 200) {
        setState(() {
          final data = response.data;
          if (data is Map && data.containsKey('results')) {
            _warehouses = data['results'];
            _hasNextPage = data['next'] != null;
          } else if (data is List) {
            _warehouses = data;
            _hasNextPage = false;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _changePage(int page) async {
    setState(() {
      _currentPage = page;
      _isLoading = true;
      _warehouses = [];
    });
    await _fetchWarehouses();
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _searchQuery == value) {
        _fetchWarehouses(refresh: true);
      }
    });
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filter by Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('All'),
              leading: Radio<String>(
                value: 'all',
                groupValue: _activeFilter,
                onChanged: (val) {
                  setState(() => _activeFilter = val!);
                  Navigator.pop(ctx);
                  _fetchWarehouses(refresh: true);
                },
              ),
            ),
            ListTile(
              title: const Text('Active'),
              leading: Radio<String>(
                value: 'active',
                groupValue: _activeFilter,
                onChanged: (val) {
                  setState(() => _activeFilter = val!);
                  Navigator.pop(ctx);
                  _fetchWarehouses(refresh: true);
                },
              ),
            ),
            ListTile(
              title: const Text('Inactive'),
              leading: Radio<String>(
                value: 'inactive',
                groupValue: _activeFilter,
                onChanged: (val) {
                  setState(() => _activeFilter = val!);
                  Navigator.pop(ctx);
                  _fetchWarehouses(refresh: true);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddWarehouseModal() {
    showDialog(
      context: context,
      builder: (ctx) => AddWarehouseModal(
        regions: _regions,
        onSuccess: () => _fetchWarehouses(refresh: true),
      ),
    );
  }

  void _showEditWarehouseModal(Map<String, dynamic> warehouse) {
    showDialog(
      context: context,
      builder: (ctx) => EditWarehouseModal(
        warehouse: warehouse,
        regions: _regions,
        onSuccess: () => _fetchWarehouses(refresh: true),
      ),
    );
  }

  Future<void> _deleteWarehouse(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Warehouse'),
        content: const Text('Are you sure you want to delete this warehouse?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiClient().dio.patch('/warehouse/warehouses/$id/', data: {'is_active': false});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Warehouse deleted')));
          _fetchWarehouses(refresh: true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete warehouse')));
        }
      }
    }
  }

  void _showLocationModal(Map<String, dynamic> warehouse) {
    final coords = warehouse['coordinates'];
    if (coords == null || coords['lat'] == null || coords['lng'] == null) return;

    showDialog(
      context: context,
      builder: (ctx) => LocationMapModal(
        lat: (coords['lat'] as num).toDouble(),
        lng: (coords['lng'] as num).toDouble(),
        warehouseName: warehouse['name'] ?? 'Warehouse',
      ),
    );
  }

  bool _hasValidCoordinates(Map<String, dynamic> warehouse) {
    final coords = warehouse['coordinates'];
    return coords != null && coords['lat'] != null && coords['lng'] != null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddWarehouseModal,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search warehouses...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.filter_list, color: _activeFilter != 'all' ? Colors.blue : Colors.grey),
                  onPressed: _showFilterModal,
                  style: IconButton.styleFrom(backgroundColor: Colors.white),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => _fetchWarehouses(refresh: true),
                  style: IconButton.styleFrom(backgroundColor: Colors.white),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      Expanded(
                        child: _warehouses.isEmpty
                            ? const Center(child: Text('No warehouses found'))
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                itemCount: _warehouses.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (ctx, index) {
                                  final warehouse = _warehouses[index] as Map<String, dynamic>;
                                  return WarehouseCard(
                                    warehouse: warehouse,
                                    onEdit: () => _showEditWarehouseModal(warehouse),
                                    onDelete: () => _deleteWarehouse(warehouse['id']),
                                    onLocation: _hasValidCoordinates(warehouse) ? () => _showLocationModal(warehouse) : null,
                                  );
                                },
                              ),
                      ),
                      if (_warehouses.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              ElevatedButton(
                                onPressed: _currentPage > 1 ? () => _changePage(_currentPage - 1) : null,
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.blue),
                                child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.arrow_back, size: 18), SizedBox(width: 8), Text('Prev')]),
                              ),
                              Text('Page $_currentPage', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ElevatedButton(
                                onPressed: _hasNextPage ? () => _changePage(_currentPage + 1) : null,
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.blue),
                                child: const Row(mainAxisSize: MainAxisSize.min, children: [Text('Next'), SizedBox(width: 8), Icon(Icons.arrow_forward, size: 18)]),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ==================== ADD WAREHOUSE MODAL ====================
class AddWarehouseModal extends StatefulWidget {
  final List<dynamic> regions;
  final VoidCallback onSuccess;

  const AddWarehouseModal({super.key, required this.regions, required this.onSuccess});

  @override
  State<AddWarehouseModal> createState() => _AddWarehouseModalState();
}

class _AddWarehouseModalState extends State<AddWarehouseModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _noteController = TextEditingController();
  int? _selectedRegionId;
  LatLng? _selectedLocation;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickLocation() async {
    final result = await showDialog<LatLng>(
      context: context,
      builder: (ctx) => LocationPickerModal(initialLocation: _selectedLocation),
    );
    if (result != null) {
      setState(() => _selectedLocation = result);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRegionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a region')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final data = {
        'name': _nameController.text.trim(),
        'region': _selectedRegionId,
        'address': _addressController.text.trim(),
        'note': _noteController.text.trim(),
        'is_active': true,
      };

      if (_selectedLocation != null) {
        data['coordinates'] = {
          'lat': _selectedLocation!.latitude,
          'lng': _selectedLocation!.longitude,
        };
      }

      final response = await ApiClient().dio.post('/warehouse/warehouses/', data: data);

      if (response.statusCode == 201) {
        if (mounted) {
          Navigator.pop(context);
          widget.onSuccess();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Warehouse created successfully')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to create warehouse')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Add Warehouse', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Name *', hintText: 'Enter warehouse name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                validator: (val) => val?.isEmpty == true ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _selectedRegionId,
                decoration: InputDecoration(labelText: 'Region *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                items: widget.regions.map((r) => DropdownMenuItem<int>(value: r['id'], child: Text(r['name'] ?? 'Region ${r['id']}'))).toList(),
                onChanged: (val) => setState(() => _selectedRegionId = val),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(labelText: 'Address', hintText: 'Enter address', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickLocation,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedLocation != null
                              ? 'Lat: ${_selectedLocation!.latitude.toStringAsFixed(4)}, Lng: ${_selectedLocation!.longitude.toStringAsFixed(4)}'
                              : 'Select Location on Map',
                          style: TextStyle(color: _selectedLocation != null ? Colors.black : Colors.grey[600]),
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _noteController,
                maxLines: 3,
                decoration: InputDecoration(labelText: 'Note', hintText: 'Enter note', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: _isSubmitting ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Create Warehouse', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== EDIT WAREHOUSE MODAL ====================
class EditWarehouseModal extends StatefulWidget {
  final Map<String, dynamic> warehouse;
  final List<dynamic> regions;
  final VoidCallback onSuccess;

  const EditWarehouseModal({super.key, required this.warehouse, required this.regions, required this.onSuccess});

  @override
  State<EditWarehouseModal> createState() => _EditWarehouseModalState();
}

class _EditWarehouseModalState extends State<EditWarehouseModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _noteController;
  int? _selectedRegionId;
  LatLng? _selectedLocation;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.warehouse['name'] ?? '');
    _addressController = TextEditingController(text: widget.warehouse['address'] ?? '');
    _noteController = TextEditingController(text: widget.warehouse['note'] ?? '');
    _selectedRegionId = widget.warehouse['region'];
    
    // Parse coordinates
    final coords = widget.warehouse['coordinates'];
    if (coords != null && coords['lat'] != null && coords['lng'] != null) {
      _selectedLocation = LatLng((coords['lat'] as num).toDouble(), (coords['lng'] as num).toDouble());
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickLocation() async {
    final result = await showDialog<LatLng>(
      context: context,
      builder: (ctx) => LocationPickerModal(initialLocation: _selectedLocation),
    );
    if (result != null) {
      setState(() => _selectedLocation = result);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRegionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a region')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final data = {
        'name': _nameController.text.trim(),
        'region': _selectedRegionId,
        'address': _addressController.text.trim(),
        'note': _noteController.text.trim(),
      };

      if (_selectedLocation != null) {
        data['coordinates'] = {
          'lat': _selectedLocation!.latitude,
          'lng': _selectedLocation!.longitude,
        };
      }

      final response = await ApiClient().dio.patch('/warehouse/warehouses/${widget.warehouse['id']}/', data: data);

      if (response.statusCode == 200) {
        if (mounted) {
          Navigator.pop(context);
          widget.onSuccess();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Warehouse updated successfully')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update warehouse')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Edit Warehouse', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Name *', hintText: 'Enter warehouse name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                validator: (val) => val?.isEmpty == true ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _selectedRegionId,
                decoration: InputDecoration(labelText: 'Region *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                items: widget.regions.map((r) => DropdownMenuItem<int>(value: r['id'], child: Text(r['name'] ?? 'Region ${r['id']}'))).toList(),
                onChanged: (val) => setState(() => _selectedRegionId = val),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(labelText: 'Address', hintText: 'Enter address', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickLocation,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedLocation != null
                              ? 'Lat: ${_selectedLocation!.latitude.toStringAsFixed(4)}, Lng: ${_selectedLocation!.longitude.toStringAsFixed(4)}'
                              : 'Select Location on Map',
                          style: TextStyle(color: _selectedLocation != null ? Colors.black : Colors.grey[600]),
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _noteController,
                maxLines: 3,
                decoration: InputDecoration(labelText: 'Note', hintText: 'Enter note', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: _isSubmitting ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Update Warehouse', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== LOCATION MAP MODAL (VIEW) ====================
class LocationMapModal extends StatelessWidget {
  final double lat;
  final double lng;
  final String warehouseName;

  const LocationMapModal({super.key, required this.lat, required this.lng, required this.warehouseName});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(warehouseName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          SizedBox(
            height: 300,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(lat, lng),
                initialZoom: 15,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.mobile',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(lat, lng),
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Lat: ${lat.toStringAsFixed(6)}, Lng: ${lng.toStringAsFixed(6)}', style: const TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}
