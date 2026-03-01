import 'package:flutter/material.dart';
import 'package:mobile/screens/warehouse/tabs/warehouses_tab.dart';
import 'package:mobile/screens/warehouse/tabs/products_tab.dart';
import 'package:mobile/screens/warehouse/tabs/history_tab.dart';
import 'package:mobile/screens/warehouse/tabs/categories_tab.dart';

class WarehouseScreen extends StatefulWidget {
  const WarehouseScreen({super.key});

  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Theme.of(context).primaryColor,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(text: 'Anbarlar'),
              Tab(text: 'Məhsullar'),
              Tab(text: 'Kateqoriyalar'),
              Tab(text: 'Tarixçə'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              WarehousesTab(),
              ProductsTab(),
              CategoriesTab(),
              HistoryTab(),
            ],
          ),
        ),
      ],
    );
  }
}
