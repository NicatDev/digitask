import 'package:mobile/core/api/api_client.dart';
import 'package:flutter/material.dart';
import 'package:mobile/screens/auth/login_screen.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:mobile/screens/profile/profile_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mobile/core/services/location_service.dart';
import 'package:mobile/core/services/notification_service.dart';
import 'package:mobile/core/services/background_service.dart'; // Ensure this is imported for initializeService
import 'package:mobile/core/services/chat_service.dart';
import 'package:mobile/screens/notifications/notifications_screen.dart';
import 'package:mobile/screens/chat/chat_list_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'documents/documents_screen.dart';
import 'package:mobile/screens/tasks/tasks_screen.dart';
import 'package:mobile/screens/warehouse/warehouse_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;
  String? _userAvatar;
  final NotificationService _notificationService = NotificationService();

  final List<Widget> _screens = [
    const DashboardScreen(),
    const DocumentsScreen(),
    const TasksScreen(),
    const WarehouseScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _notificationService.initialize();
    ChatService().fetchGroups();
  }

  Future<void> _fetchUserData() async {
    try {
      final response = await ApiClient().dio.get('/users/me/');
      if (response.statusCode == 200) {
        ChatService().setCurrentUser(response.data['id']); // Update ChatService
        
        // Start Location Tracking
        if (kIsWeb) {
          // Web: Request permission via geolocator and start tracking
          await LocationService.initialize();
        } else {
          // Mobile: Request permissions and start background service
          await _requestPermissions();
          await initializeService();
        }

        setState(() {
          _userAvatar = response.data['avatar'];
        });
      }
    } catch (e) {
      print('Failed to fetch user data: $e');
    }
  }

  Future<void> _requestPermissions() async {
    await Permission.notification.request();
    await Permission.location.request();
    await Permission.locationAlways.request();
  }

  Future<void> _handleLogout() async {
    const storage = FlutterSecureStorage();
    await LocationService.stop();
    _notificationService.disconnect();
    await storage.deleteAll();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(

        title: const Text('DigiTask'), // Or dynamic title based on index
        actions: [
           ValueListenableBuilder<int>(
             valueListenable: _notificationService.unreadCount,
             builder: (context, count, child) {
               return Stack(
                 children: [
                   IconButton(
                     icon: const Icon(Icons.notifications_outlined),
                     onPressed: () {
                       Navigator.push(
                         context,
                         MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                       );
                     },
                   ),
                   if (count > 0)
                     Positioned(
                       right: 8,
                       top: 8,
                       child: Container(
                         padding: const EdgeInsets.all(2),
                         decoration: BoxDecoration(
                           color: Colors.red,
                           borderRadius: BorderRadius.circular(10),
                         ),
                         constraints: const BoxConstraints(
                           minWidth: 16,
                           minHeight: 16,
                         ),
                         child: Text(
                           '$count',
                           style: const TextStyle(
                             color: Colors.white,
                             fontSize: 10,
                           ),
                           textAlign: TextAlign.center,
                         ),
                       ),
                     ),
                 ],
               );
             },
           ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'profile') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                );
              } else if (value == 'logout') {
                _handleLogout();
              }
            },
            offset: const Offset(0, 50),
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline, size: 20, color: Colors.black54),
                    SizedBox(width: 12),
                    Text('Profile'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Logout', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0, left: 8.0),
              child: CircleAvatar(
                backgroundImage: _userAvatar != null ? NetworkImage(_userAvatar!) : null,
                child: _userAvatar == null ? const Icon(Icons.person) : null,
              ),
            ),
          ),
        ],
      ),
      body: _screens[_currentIndex],
      floatingActionButton: ValueListenableBuilder<int>(
        valueListenable: ChatService().totalUnreadCount,
        builder: (context, unreadCount, child) {
          return Transform.translate(
            offset: const Offset(0, 6),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 61,
                  height: 61,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF1565C0), // Dark Blue
                        Color(0xFF42A5F5), // Light Blue
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: FloatingActionButton(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    onPressed: () {
                       Navigator.push(
                         context,
                         MaterialPageRoute(builder: (context) => const ChatListScreen()),
                       );
                    },
                    shape: const CircleBorder(),
                    child: const Icon(Icons.chat_bubble_outline, size: 28, color: Colors.white),
                  ),
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
                      ),
                      child: Text(
                        '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomAppBar(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: const CircularNotchedRectangle(),
          notchMargin: 8.0,
          child: SizedBox(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.dashboard_outlined, Icons.dashboard, 'Home'),
                _buildNavItem(1, Icons.description_outlined, Icons.description, 'Documents'), // Was Invoices
                const SizedBox(width: 60), // Gap for FAB
                _buildNavItem(2, Icons.task_outlined, Icons.task, 'Tasks'),
                _buildNavItem(3, Icons.warehouse_outlined, Icons.warehouse, 'Warehouse'), // Was Profile
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
