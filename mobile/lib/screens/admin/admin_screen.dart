import 'package:flutter/material.dart';
import 'package:mobile/screens/admin/tabs/admin_services_tab.dart';
import 'package:mobile/screens/admin/tabs/admin_columns_tab.dart';
import 'package:mobile/screens/admin/tabs/admin_task_types_tab.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: primary,
          tabs: const [
            Tab(text: 'Servislər'),
            Tab(text: 'Sütunlar'),
            Tab(text: 'Tapşırıq növləri'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          AdminServicesTab(),
          AdminColumnsTab(),
          AdminTaskTypesTab(),
        ],
      ),
    );
  }
}
