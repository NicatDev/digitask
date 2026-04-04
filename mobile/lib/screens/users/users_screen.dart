import 'package:flutter/material.dart';
import 'package:mobile/screens/users/tabs/users_tab.dart';
import 'package:mobile/screens/users/tabs/roles_tab.dart';
import 'package:mobile/screens/users/tabs/regions_tab.dart';
import 'package:mobile/screens/users/tabs/groups_tab.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen>
    with SingleTickerProviderStateMixin {
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
    final primary = Theme.of(context).primaryColor;
    return Scaffold(
      appBar: AppBar(
        title: const Text('İstifadəçi İdarəetməsi'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: primary,
          tabs: const [
            Tab(text: 'İstifadəçilər'),
            Tab(text: 'Rollar'),
            Tab(text: 'Regionlar'),
            Tab(text: 'Qruplar'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          UsersTab(),
          RolesTab(),
          RegionsTab(),
          GroupsTab(),
        ],
      ),
    );
  }
}
