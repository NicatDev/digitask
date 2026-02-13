import 'package:flutter/material.dart';
import 'package:mobile/screens/tasks/tabs/tasks_tab.dart';
import 'package:mobile/screens/tasks/tabs/customers_tab.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 0, // Hide the toolbar part to remove title space, leaving only TabBar?
          // Or just remove title. If I remove title, it still takes height.
          // User said "tasks basligi olan section lazim deyil".
          // If I set toolbarHeight to 0, I lose the actions button?
          // Wait, the actions buttons (Refresh/Filter) are inside TasksScreen? No, I moved them to TasksTab.
          // Wait, in my previous edit, TasksScreen is just a shell with just `title` and `bottom` (TabBar).
          // It does NOT have actions anymore.
          // So yes, I can set `toolbarHeight: 0`.
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
          ),
          bottom: const TabBar(
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
            tabs: [
              Tab(text: 'Tasks'),
              Tab(text: 'Customers'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            TasksTab(),
            CustomersTab(),
          ],
        ),
      ),
    );
  }
}


