import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/screens/warehouse/widgets/history_card.dart';
import 'package:mobile/screens/warehouse/widgets/stock_movement_files_modal.dart';

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _movements = [];
  List<dynamic> _warehouses = [];
  bool _isLoading = true;
  int _currentPage = 1;
  bool _hasNextPage = true;
  
  // Filters
  String _searchQuery = '';
  String? _typeFilter;
  int? _warehouseFilter;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchWarehouses();
    _fetchMovements();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchWarehouses() async {
    try {
      final res = await ApiClient().dio.get('/warehouse/warehouses/');
      if (mounted) {
        setState(() {
          if (res.data is Map && res.data.containsKey('results')) {
            _warehouses = res.data['results'];
          } else {
            _warehouses = res.data;
          }
        });
      }
    } catch (e) {
      //
    }
  }

  Future<void> _fetchMovements({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _currentPage = 1;
        _hasNextPage = true;
        _isLoading = true;
        _movements = [];
      });
    } else {
      setState(() => _isLoading = true);
    }

    try {
      final params = <String, dynamic>{
        'search': _searchQuery,
        'page': _currentPage,
        'page_size': 5, // Matching frontend
      };
      if (_typeFilter != null) params['movement_type'] = _typeFilter;
      if (_warehouseFilter != null) params['warehouse'] = _warehouseFilter;

      final res = await ApiClient().dio.get('/warehouse/movements/', queryParameters: params);
      
      if (mounted) {
        setState(() {
          final data = res.data;
          if (data is Map && data.containsKey('results')) {
            _movements = data['results'];
            _hasNextPage = data['next'] != null;
          } else if (data is List) {
            _movements = data;
            _hasNextPage = false;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _changePage(int page) async {
    setState(() {
      _currentPage = page;
      _isLoading = true;
      _movements = [];
    });
    await _fetchMovements();
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() => _searchQuery = value);
      _fetchMovements(refresh: true);
    });
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _HistoryFilterModal(
        warehouses: _warehouses,
        currentType: _typeFilter,
        currentWarehouse: _warehouseFilter,
        onApply: (type, warehouse) {
          setState(() {
            _typeFilter = type;
            _warehouseFilter = warehouse;
          });
          _fetchMovements(refresh: true);
        },
      ),
    );
  }

  void _showFilesModal(Map<String, dynamic> movement) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StockMovementFilesModal(
        stockMovement: movement,
        onSuccess: () {}, // No need to refresh list usually, files are separate
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Toolbar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search history...',
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
                  icon: Icon(Icons.filter_list, color: (_typeFilter != null || _warehouseFilter != null) ? Colors.blue : Colors.grey),
                  onPressed: _showFilterModal,
                  style: IconButton.styleFrom(backgroundColor: Colors.white),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => _fetchMovements(refresh: true),
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
                        child: _movements.isEmpty
                            ? const Center(child: Text('Tarixçə boşdur'))
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                itemCount: _movements.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (ctx, index) {
                                  final m = _movements[index];
                                  return HistoryCard(
                                    movement: m,
                                    onFileClick: () => _showFilesModal(m),
                                  );
                                },
                              ),
                      ),
                      
                      // Pagination
                      if (_movements.isNotEmpty || _currentPage > 1)
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

class _HistoryFilterModal extends StatefulWidget {
  final List<dynamic> warehouses;
  final String? currentType;
  final int? currentWarehouse;
  final Function(String?, int?) onApply;

  const _HistoryFilterModal({
    required this.warehouses,
    this.currentType,
    this.currentWarehouse,
    required this.onApply,
  });

  @override
  State<_HistoryFilterModal> createState() => _HistoryFilterModalState();
}

class _HistoryFilterModalState extends State<_HistoryFilterModal> {
  String? _type;
  int? _warehouse;

  final List<Map<String, String>> _types = [
    {'value': 'in', 'label': 'Giriş (Import)'},
    {'value': 'out', 'label': 'Çıxış (Export)'},
    {'value': 'transfer', 'label': 'Transfer'},
    {'value': 'adjust', 'label': 'Korreksiya'},
    {'value': 'return', 'label': 'Qaytarma'},
  ];

  @override
  void initState() {
    super.initState();
    _type = widget.currentType;
    _warehouse = widget.currentWarehouse;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Filter', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          
          DropdownButtonFormField<String>(
            value: _type,
            decoration: const InputDecoration(labelText: 'Əməliyyat Növü', border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem(value: null, child: Text('Hamısı')),
              ..._types.map((t) => DropdownMenuItem(value: t['value'], child: Text(t['label']!))),
            ],
            onChanged: (val) => setState(() => _type = val),
          ),
          const SizedBox(height: 16),
          
          DropdownButtonFormField<int>(
            value: _warehouse,
            decoration: const InputDecoration(labelText: 'Anbar', border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem(value: null, child: Text('Hamısı')),
              ...widget.warehouses.map((w) => DropdownMenuItem<int>(value: w['id'], child: Text(w['name']))),
            ],
            onChanged: (val) => setState(() => _warehouse = val),
          ),
          const SizedBox(height: 20),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onApply(_type, _warehouse);
              },
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('Tətbiq Et'),
            ),
          ),
        ],
      ),
    );
  }
}
