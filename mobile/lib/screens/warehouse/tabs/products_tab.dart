import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/models/product.dart';
import 'package:mobile/screens/warehouse/widgets/product_card.dart';
import 'package:mobile/screens/warehouse/widgets/product_modal.dart';
import 'package:mobile/screens/warehouse/widgets/stock_movement_modal.dart';
import 'package:mobile/screens/warehouse/widgets/inventory_modal.dart';

class ProductsTab extends StatefulWidget {
  const ProductsTab({super.key});

  @override
  State<ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<ProductsTab> {
  final TextEditingController _searchController = TextEditingController();
  List<Product> _products = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _activeFilter = 'all';
  int _currentPage = 1;
  bool _hasNextPage = true;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
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
        'page_size': 5, // Matching backend/frontend
      };
      
      if (_activeFilter == 'active') {
        params['is_active'] = 'true';
      } else if (_activeFilter == 'inactive') {
        params['is_active'] = 'false';
      }

      final response = await ApiClient().dio.get(
        '/warehouse/products/',
        queryParameters: params,
      );

      if (response.statusCode == 200) {
        setState(() {
          final data = response.data;
          if (data is Map && data.containsKey('results')) {
            final List<dynamic> results = data['results'];
            _products = results.map((e) => Product.fromJson(e)).toList();
            _hasNextPage = data['next'] != null;
          } else if (data is List) {
            _products = data.map((e) => Product.fromJson(e)).toList();
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

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                  _fetchProducts(refresh: true);
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
                  _fetchProducts(refresh: true);
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
                  _fetchProducts(refresh: true);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteProduct(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: const Text('Are you sure you want to delete this product?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiClient().dio.patch('/warehouse/products/$id/', data: {'is_active': false});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product deleted')));
          _fetchProducts(refresh: true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete product')));
        }
      }
    }
  }

  void _showProductModal([Product? product]) {
    showDialog(
      context: context,
      builder: (ctx) => ProductModal(
        product: product,
        onSuccess: () => _fetchProducts(refresh: true),
      ),
    );
  }

  void _showStockModal(Product product) {
    showDialog(
      context: context,
      builder: (ctx) => StockMovementModal(
        product: product,
        onSuccess: () => _fetchProducts(refresh: true), // Refresh to update stock count
      ),
    );
  }

  void _showInventoryModal(Product product) {
    showDialog(
      context: context,
      builder: (ctx) => InventoryModal(product: product),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProductModal(),
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
                      hintText: 'Search products...',
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
                  onPressed: () => _fetchProducts(refresh: true),
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
                        child: _products.isEmpty
                            ? const Center(child: Text('No products found'))
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                itemCount: _products.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (ctx, index) {
                                  final product = _products[index];
                                  return ProductCard(
                                    product: product,
                                    onEdit: () => _showProductModal(product),
                                    onDelete: () => _deleteProduct(product.id),
                                    onStockAction: () => _showStockModal(product),
                                    onInventoryClick: () => _showInventoryModal(product),
                                  );
                                },
                              ),
                      ),
                      if (_products.isNotEmpty || _currentPage > 1)
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
