import 'package:flutter/material.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class CustomersTab extends StatefulWidget {
  const CustomersTab({super.key});

  @override
  State<CustomersTab> createState() => _CustomersTabState();
}

class _CustomersTabState extends State<CustomersTab> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _customers = [];
  List<dynamic> _regions = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _activeFilter = 'all'; // all, active, inactive
  int _currentPage = 1;
  bool _hasNextPage = true;

  @override
  void initState() {
    super.initState();
    _fetchRegions();
    _fetchCustomers();
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

  Future<void> _fetchCustomers({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _currentPage = 1;
        _hasNextPage = true;
        _isLoading = true;
        _customers = [];
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
        '/tasks/customers/',
        queryParameters: params,
      );

      if (response.statusCode == 200) {
        setState(() {
          final data = response.data;
          if (data is Map && data.containsKey('results')) {
            _customers = data['results'];
            _hasNextPage = data['next'] != null;
          } else if (data is List) {
            _customers = data;
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
      _customers = [];
    });
    await _fetchCustomers();
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _searchQuery == value) {
        _fetchCustomers(refresh: true);
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
                  _fetchCustomers(refresh: true);
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
                  _fetchCustomers(refresh: true);
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
                  _fetchCustomers(refresh: true);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCustomerModal() {
    showDialog(
      context: context,
      builder: (ctx) => AddCustomerModal(
        regions: _regions,
        onSuccess: () => _fetchCustomers(refresh: true),
      ),
    );
  }

  void _showEditCustomerModal(Map<String, dynamic> customer) {
    showDialog(
      context: context,
      builder: (ctx) => EditCustomerModal(
        customer: customer,
        regions: _regions,
        onSuccess: () => _fetchCustomers(refresh: true),
      ),
    );
  }

  Future<void> _deleteCustomer(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Customer'),
        content: const Text('Are you sure you want to delete this customer?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiClient().dio.patch('/tasks/customers/$id/', data: {'is_active': false});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Customer deleted')));
          _fetchCustomers(refresh: true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete customer')));
        }
      }
    }
  }

  void _showLocationModal(Map<String, dynamic> customer) {
    final coords = customer['address_coordinates'];
    if (coords == null || coords['lat'] == null || coords['lng'] == null) return;

    showDialog(
      context: context,
      builder: (ctx) => LocationMapModal(
        lat: (coords['lat'] as num).toDouble(),
        lng: (coords['lng'] as num).toDouble(),
        title: customer['full_name'] ?? 'Customer',
      ),
    );
  }

  bool _hasValidCoordinates(Map<String, dynamic> customer) {
    final coords = customer['address_coordinates'];
    return coords != null && coords['lat'] != null && coords['lng'] != null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search and Filter Bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search customers...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  Icons.filter_list,
                  color: _activeFilter != 'all' ? Colors.blue : Colors.grey,
                ),
                onPressed: _showFilterModal,
                style: IconButton.styleFrom(backgroundColor: Colors.white),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.add, color: Colors.blue),
                onPressed: _showAddCustomerModal,
                style: IconButton.styleFrom(backgroundColor: Colors.white),
              ),
            ],
          ),
        ),
        
        // Content
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Expanded(
                      child: _customers.isEmpty
                          ? const Center(child: Text('No customers found'))
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: _customers.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (ctx, index) {
                                final customer = _customers[index];
                                return CustomerCard(
                                  customer: customer,
                                  onEdit: () => _showEditCustomerModal(customer),
                                  onDelete: () => _deleteCustomer(customer['id']),
                                  onLocation: _hasValidCoordinates(customer) ? () => _showLocationModal(customer) : null,
                                );
                              },
                            ),
                    ),
                    // Pagination Controls
                    if (_customers.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
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

// ==================== CUSTOMER CARD ====================
class CustomerCard extends StatelessWidget {
  final Map<String, dynamic> customer;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onLocation;

  const CustomerCard({super.key, required this.customer, required this.onEdit, required this.onDelete, this.onLocation});

  @override
  Widget build(BuildContext context) {
    final bool isActive = customer['is_active'] ?? false;
    final bool hasLocation = onLocation != null;

    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.blue.shade100,
                        child: Text(
                          (customer['full_name'] ?? 'C')[0].toUpperCase(),
                          style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          customer['full_name'] ?? 'Unknown',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      color: isActive ? Colors.green.shade700 : Colors.red.shade700,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow(Icons.phone, customer['phone_number'] ?? '-'),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.place, customer['address'] ?? '-'),
            
            const Divider(height: 24),
            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(Icons.location_on, color: hasLocation ? Colors.blue : Colors.grey.shade300),
                  onPressed: onLocation,
                  tooltip: 'View Location',
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.orange),
                  onPressed: onEdit,
                  tooltip: 'Edit',
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: onDelete,
                  tooltip: 'Delete',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
      ],
    );
  }
}

// ==================== ADD CUSTOMER MODAL ====================
class AddCustomerModal extends StatefulWidget {
  final List<dynamic> regions;
  final VoidCallback onSuccess;

  const AddCustomerModal({super.key, required this.regions, required this.onSuccess});

  @override
  State<AddCustomerModal> createState() => _AddCustomerModalState();
}

class _AddCustomerModalState extends State<AddCustomerModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _registerNumberController = TextEditingController();
  int? _selectedRegionId;
  LatLng? _selectedLocation;
  bool _isSubmitting = false;

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
        'full_name': _nameController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'register_number': _registerNumberController.text.trim(),
        'region': _selectedRegionId,
        'address': _addressController.text.trim(),
        'is_active': true,
      };

      if (_selectedLocation != null) {
        data['address_coordinates'] = {
          'lat': _selectedLocation!.latitude,
          'lng': _selectedLocation!.longitude,
        };
      }

      final response = await ApiClient().dio.post('/tasks/customers/', data: data);

      if (response.statusCode == 201) {
        if (mounted) {
          Navigator.pop(context);
          widget.onSuccess();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Customer created successfully')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to create customer')));
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
                  const Text('Add Customer', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Full Name *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                validator: (val) => val?.isEmpty == true ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(labelText: 'Phone', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _registerNumberController,
                decoration: InputDecoration(labelText: 'Register Number (VOEN)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
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
                decoration: InputDecoration(labelText: 'Address', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickLocation,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(12)),
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
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: _isSubmitting ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Create Customer', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== EDIT CUSTOMER MODAL ====================
class EditCustomerModal extends StatefulWidget {
  final Map<String, dynamic> customer;
  final List<dynamic> regions;
  final VoidCallback onSuccess;

  const EditCustomerModal({super.key, required this.customer, required this.regions, required this.onSuccess});

  @override
  State<EditCustomerModal> createState() => _EditCustomerModalState();
}

class _EditCustomerModalState extends State<EditCustomerModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _registerNumberController;
  int? _selectedRegionId;
  LatLng? _selectedLocation;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.customer['full_name'] ?? '');
    _phoneController = TextEditingController(text: widget.customer['phone_number'] ?? '');
    _addressController = TextEditingController(text: widget.customer['address'] ?? '');
    _registerNumberController = TextEditingController(text: widget.customer['register_number'] ?? '');
    _selectedRegionId = widget.customer['region'];

    final coords = widget.customer['address_coordinates'];
    if (coords != null && coords['lat'] != null && coords['lng'] != null) {
      _selectedLocation = LatLng((coords['lat'] as num).toDouble(), (coords['lng'] as num).toDouble());
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _registerNumberController.dispose();
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
        'full_name': _nameController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'register_number': _registerNumberController.text.trim(),
        'region': _selectedRegionId,
        'address': _addressController.text.trim(),
      };

      if (_selectedLocation != null) {
        data['address_coordinates'] = {
          'lat': _selectedLocation!.latitude,
          'lng': _selectedLocation!.longitude,
        };
      }

      final response = await ApiClient().dio.patch('/tasks/customers/${widget.customer['id']}/', data: data);

      if (response.statusCode == 200) {
        if (mounted) {
          Navigator.pop(context);
          widget.onSuccess();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Customer updated successfully')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update customer')));
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
                  const Text('Edit Customer', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Full Name *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                validator: (val) => val?.isEmpty == true ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(labelText: 'Phone', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _registerNumberController,
                decoration: InputDecoration(labelText: 'Register Number (VOEN)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
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
                decoration: InputDecoration(labelText: 'Address', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickLocation,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(12)),
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
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: _isSubmitting ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Update Customer', style: TextStyle(fontSize: 16)),
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
  final String title;

  const LocationMapModal({super.key, required this.lat, required this.lng, required this.title});

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
                Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
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

// ==================== LOCATION PICKER MODAL (SELECT) ====================
class LocationPickerModal extends StatefulWidget {
  final LatLng? initialLocation;

  const LocationPickerModal({super.key, this.initialLocation});

  @override
  State<LocationPickerModal> createState() => _LocationPickerModalState();
}

class _LocationPickerModalState extends State<LocationPickerModal> {
  late LatLng _currentLocation;
  final LatLng _defaultLocation = const LatLng(40.4093, 49.8671); // Baku

  @override
  void initState() {
    super.initState();
    _currentLocation = widget.initialLocation ?? _defaultLocation;
  }

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
                const Text('Pick Location', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          SizedBox(
            height: 400,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: _currentLocation,
                initialZoom: 13,
                onTap: (tapPosition, point) {
                  setState(() {
                    _currentLocation = point;
                  });
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
                      point: _currentLocation,
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
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, _currentLocation),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Confirm Location (${_currentLocation.latitude.toStringAsFixed(4)}, ${_currentLocation.longitude.toStringAsFixed(4)})',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
