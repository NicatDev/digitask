import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/core/services/chat_service.dart';
import 'package:mobile/models/product.dart';
import 'package:mobile/screens/warehouse/widgets/product_card.dart';
import 'package:mobile/screens/warehouse/widgets/product_modal.dart';
import 'package:mobile/screens/warehouse/widgets/stock_movement_modal.dart';
import 'package:mobile/screens/warehouse/widgets/inventory_modal.dart';
import 'package:mobile/screens/warehouse/widgets/product_detail_modal.dart';
import 'package:mobile/screens/warehouse/widgets/serial_numbers_modal.dart';

class ProductsTab extends StatefulWidget {
  const ProductsTab({super.key});

  @override
  State<ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<ProductsTab> {
  final TextEditingController _searchController = TextEditingController();
  List<Product> _products = [];
  List<dynamic> _warehouses = [];
  List<dynamic> _categories = [];
  bool _isLoading = true;
  int _currentPage = 1;
  bool _hasNextPage = true;

  // Filters
  String _searchQuery = '';
  String _statusFilter = 'true'; // Default: active
  int? _warehouseFilter;
  int? _categoryFilter;
  Timer? _debounce;

  // Per-warehouse inventory data
  Map<int, double> _warehouseStockMap = {}; // productId -> qty in warehouse
  Map<int, int> _warehouseSerialCountMap = {}; // productId -> serial count in warehouse

  @override
  void initState() {
    super.initState();
    _fetchWarehouses();
    _fetchCategories();
    _fetchProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchWarehouses() async {
    try {
      final res = await ApiClient().dio.get('/warehouse/warehouses/', queryParameters: {'page_size': 100});
      if (mounted) {
        setState(() {
          final data = res.data;
          _warehouses = (data is Map && data.containsKey('results')) ? data['results'] : (data is List ? data : []);
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchCategories() async {
    try {
      final res = await ApiClient().dio.get('/warehouse/categories/', queryParameters: {'page_size': 100});
      if (mounted) {
        setState(() {
          final data = res.data;
          _categories = (data is Map && data.containsKey('results')) ? data['results'] : (data is List ? data : []);
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchProducts({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _currentPage = 1;
        _hasNextPage = true;
        _isLoading = true;
        _products = [];
      });
    } else {
      setState(() => _isLoading = true);
    }

    try {
      final params = <String, dynamic>{
        'search': _searchQuery,
        'page': _currentPage,
        'page_size': 10,
      };
      if (_statusFilter.isNotEmpty) params['is_active'] = _statusFilter;
      if (_categoryFilter != null) params['category'] = _categoryFilter;

      final res = await ApiClient().dio.get('/warehouse/products/', queryParameters: params);

      if (mounted) {
        setState(() {
          final data = res.data;
          if (data is Map && data.containsKey('results')) {
            _products = (data['results'] as List).map((j) => Product.fromJson(j)).toList();
            _hasNextPage = data['next'] != null;
          } else if (data is List) {
            _products = data.map((j) => Product.fromJson(j)).toList();
            _hasNextPage = false;
          }
          _isLoading = false;
        });

        // If warehouse filter is active, fetch per-warehouse stock
        if (_warehouseFilter != null) {
          _fetchWarehouseStock(_warehouseFilter!);
        } else {
          // Clear overrides
          for (final p in _products) {
            p.overrideStock = null;
            p.overrideSerialCount = null;
          }
          _warehouseStockMap = {};
          _warehouseSerialCountMap = {};
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchWarehouseStock(int warehouseId) async {
    try {
      // Fetch inventory for the selected warehouse
      final invRes = await ApiClient().dio.get('/warehouse/inventory/', queryParameters: {
        'warehouse': warehouseId,
        'page_size': 500,
      });
      final invData = invRes.data;
      final invList = (invData is Map && invData.containsKey('results')) ? invData['results'] : (invData is List ? invData : []);

      final stockMap = <int, double>{};
      for (final item in invList) {
        final productId = item['product'];
        final qty = double.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
        stockMap[productId] = qty;
      }

      // Fetch serial counts per product in this warehouse
      final serialCountMap = <int, int>{};
      for (final p in _products) {
        if (p.hasSerialNumber) {
          try {
            final snRes = await ApiClient().dio.get('/warehouse/serial-items/', queryParameters: {
              'product': p.id,
              'warehouse': warehouseId,
              'page_size': 1, // We just need the count
            });
            final snData = snRes.data;
            if (snData is Map && snData.containsKey('count')) {
              serialCountMap[p.id] = snData['count'];
            } else if (snData is Map && snData.containsKey('results')) {
              // If no count field, use list length (but page_size=1 issue)
              // Better: use larger page size or count endpoint
              final snRes2 = await ApiClient().dio.get('/warehouse/serial-items/', queryParameters: {
                'product': p.id,
                'warehouse': warehouseId,
                'page_size': 500,
              });
              final snData2 = snRes2.data;
              final snList = (snData2 is Map && snData2.containsKey('results')) ? snData2['results'] : (snData2 is List ? snData2 : []);
              serialCountMap[p.id] = snList.length;
            }
          } catch (_) {}
        }
      }

      if (mounted) {
        setState(() {
          _warehouseStockMap = stockMap;
          _warehouseSerialCountMap = serialCountMap;
          // Apply overrides to products
          for (final p in _products) {
            p.overrideStock = stockMap[p.id] ?? 0;
            if (p.hasSerialNumber) {
              p.overrideSerialCount = serialCountMap[p.id] ?? 0;
            }
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _changePage(int page) async {
    setState(() {
      _currentPage = page;
      _isLoading = true;
      _products = [];
    });
    await _fetchProducts();
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() => _searchQuery = value);
      _fetchProducts(refresh: true);
    });
  }

  Future<void> _deleteProduct(Product product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Silmək istəyirsiniz?'),
        content: Text(product.name),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Ləğv et')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sil', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await ApiClient().dio.delete('/warehouse/products/${product.id}/');
        _fetchProducts(refresh: true);
      } catch (_) {}
    }
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _ProductFilterModal(
        warehouses: _warehouses,
        categories: _categories,
        currentStatus: _statusFilter,
        currentWarehouse: _warehouseFilter,
        currentCategory: _categoryFilter,
        onApply: (status, warehouse, category) {
          setState(() {
            _statusFilter = status;
            _warehouseFilter = warehouse;
            _categoryFilter = category;
          });
          _fetchProducts(refresh: true);
        },
      ),
    );
  }

  bool get _hasActiveFilters => _warehouseFilter != null || _categoryFilter != null || _statusFilter != 'true';

  @override
  Widget build(BuildContext context) {
    final user = ChatService().currentUser.value;
    final canWrite = user?.isWarehouseWriter ?? false;

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
                      hintText: 'Məhsul axtar...',
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
                  icon: Icon(Icons.filter_list, color: _hasActiveFilters ? Colors.blue : Colors.grey),
                  onPressed: _showFilterModal,
                  style: IconButton.styleFrom(backgroundColor: Colors.white),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => _fetchProducts(refresh: true),
                  style: IconButton.styleFrom(backgroundColor: Colors.white),
                ),
              ],
            ),
          ),

          // Active warehouse filter indicator
          if (_warehouseFilter != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warehouse, size: 16, color: Colors.blue),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Anbar: ${_warehouses.firstWhere((w) => w['id'] == _warehouseFilter, orElse: () => {'name': '?'})['name']}',
                        style: TextStyle(fontSize: 13, color: Colors.blue.shade700),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        setState(() => _warehouseFilter = null);
                        _fetchProducts(refresh: true);
                      },
                      child: const Icon(Icons.close, size: 18, color: Colors.blue),
                    ),
                  ],
                ),
              ),
            ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      Expanded(
                        child: _products.isEmpty
                            ? const Center(child: Text('Məhsul tapılmadı'))
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                itemCount: _products.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (ctx, index) {
                                  final product = _products[index];
                                  return ProductCard(
                                    product: product,
                                    onEdit: canWrite ? () => _showProductModal(product) : null,
                                    onDelete: canWrite ? () => _deleteProduct(product) : null,
                                    onStockAction: canWrite ? () => _showStockModal(product) : null,
                                    onInventoryClick: () => _showInventoryModal(product),
                                    onNameClick: () => _showDetailModal(product),
                                    onSerialClick: product.hasSerialNumber ? () => _showSerialNumbersModal(product) : null,
                                  );
                                },
                              ),
                      ),

                      // Pagination + Add button row
                      if (_products.isNotEmpty || _currentPage > 1)
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: Row(
                            children: [
                              ElevatedButton(
                                onPressed: _currentPage > 1 ? () => _changePage(_currentPage - 1) : null,
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.blue),
                                child: const Icon(Icons.arrow_back, size: 18),
                              ),
                              const Spacer(),
                              Text('Səhifə $_currentPage', style: const TextStyle(fontWeight: FontWeight.bold)),
                              const Spacer(),
                              if (canWrite)
                                Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: FloatingActionButton.small(
                                    heroTag: 'add_product',
                                    onPressed: () => _showProductModal(null),
                                    backgroundColor: Colors.blue,
                                    child: const Icon(Icons.add, color: Colors.white),
                                  ),
                                ),
                              ElevatedButton(
                                onPressed: _hasNextPage ? () => _changePage(_currentPage + 1) : null,
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.blue),
                                child: const Icon(Icons.arrow_forward, size: 18),
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

  void _showProductModal(Product? product) {
    showDialog(
      context: context,
      builder: (_) => ProductModal(product: product, onSuccess: () => _fetchProducts(refresh: true)),
    );
  }

  void _showStockModal(Product product) {
    showDialog(
      context: context,
      builder: (_) => StockMovementModal(product: product, onSuccess: () => _fetchProducts(refresh: true)),
    );
  }

  void _showInventoryModal(Product product) {
    showDialog(
      context: context,
      builder: (_) => InventoryModal(product: product),
    );
  }

  void _showDetailModal(Product product) {
    showDialog(
      context: context,
      builder: (_) => ProductDetailModal(product: product),
    );
  }

  void _showSerialNumbersModal(Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SerialNumbersModal(product: product, warehouseFilter: _warehouseFilter),
    );
  }
}

// ─── Filter Modal ───────────────────────────────────────────────

class _ProductFilterModal extends StatefulWidget {
  final List<dynamic> warehouses;
  final List<dynamic> categories;
  final String currentStatus;
  final int? currentWarehouse;
  final int? currentCategory;
  final Function(String status, int? warehouse, int? category) onApply;

  const _ProductFilterModal({
    required this.warehouses,
    required this.categories,
    required this.currentStatus,
    this.currentWarehouse,
    this.currentCategory,
    required this.onApply,
  });

  @override
  State<_ProductFilterModal> createState() => _ProductFilterModalState();
}

class _ProductFilterModalState extends State<_ProductFilterModal> {
  late String _status;
  int? _warehouse;
  int? _category;

  @override
  void initState() {
    super.initState();
    _status = widget.currentStatus;
    _warehouse = widget.currentWarehouse;
    _category = widget.currentCategory;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Filtr', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),

          DropdownButtonFormField<String>(
            value: _status,
            decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: '', child: Text('Hamısı')),
              DropdownMenuItem(value: 'true', child: Text('Aktiv')),
              DropdownMenuItem(value: 'false', child: Text('Deaktiv')),
            ],
            onChanged: (val) => setState(() => _status = val ?? ''),
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<int?>(
            value: _warehouse,
            decoration: const InputDecoration(labelText: 'Anbar', border: OutlineInputBorder()),
            isExpanded: true,
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('Hamısı')),
              ...widget.warehouses.map((w) => DropdownMenuItem<int?>(value: w['id'], child: Text(w['name'] ?? ''))),
            ],
            onChanged: (val) => setState(() => _warehouse = val),
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<int?>(
            value: _category,
            decoration: const InputDecoration(labelText: 'Kateqoriya', border: OutlineInputBorder()),
            isExpanded: true,
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('Hamısı')),
              ...widget.categories.map((c) => DropdownMenuItem<int?>(value: c['id'], child: Text(c['name'] ?? ''))),
            ],
            onChanged: (val) => setState(() => _category = val),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onApply('true', null, null);
                  },
                  child: const Text('Sıfırla'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onApply(_status, _warehouse, _category);
                  },
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('Tətbiq Et'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
