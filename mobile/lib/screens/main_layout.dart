import 'package:mobile/core/api/api_client.dart';
import 'package:flutter/material.dart';
import 'package:mobile/screens/auth/login_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile/screens/profile/profile_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mobile/core/services/location_service.dart';
import 'package:mobile/core/services/notification_service.dart';
import 'package:mobile/core/services/background_service.dart';
import 'package:mobile/core/services/chat_service.dart';
import 'package:mobile/screens/notifications/notifications_screen.dart';
import 'package:mobile/screens/chat/chat_list_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'documents/documents_screen.dart';
import 'package:mobile/screens/tasks/tasks_screen.dart';
import 'package:mobile/screens/warehouse/warehouse_screen.dart';
import 'package:mobile/screens/users/users_screen.dart';
import 'package:mobile/screens/map/live_map_screen.dart';
import 'package:mobile/screens/admin/admin_screen.dart';
import 'package:mobile/screens/performance/performance_screen.dart';
import 'package:mobile/screens/support/support_screen.dart';
import 'package:mobile/models/user_model.dart';

/// Overlay “Daha çox” menyusunda bütün sıra eyni en (veb/mobil uyğun görünüş).
const double _kMoreMenuItemWidth = 232;

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;
  String? _userAvatar;
  final NotificationService _notificationService = NotificationService();

  // Overlay for the custom "more" menu
  OverlayEntry? _overlayEntry;
  bool _isMoreMenuOpen = false;

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

  @override
  void dispose() {
    _closeMoreMenu();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    try {
      final response = await ApiClient().dio.get('/users/me/');
      if (response.statusCode == 200) {
        final user = User.fromJson(response.data);
        ChatService().setCurrentUser(user);

        if (kIsWeb) {
          await LocationService.initialize();
        } else {
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

  // ─── Custom Overlay Menu ───────────────────────────────────────────────────

  void _toggleMoreMenu() {
    if (_isMoreMenuOpen) {
      _closeMoreMenu();
    } else {
      _openMoreMenu();
    }
  }

  void _openMoreMenu() {
    final user = ChatService().currentUser.value;
    if (user == null) return;

    final bool isAdminOrSuper = user.isAdmin || user.isSuperAdmin;
    final bool hasWarehouseAccess =
        user.isWarehouseReader || user.isWarehouseWriter || isAdminOrSuper;
    final bool hasMapAccess = user.isTaskReader ||
        user.isTaskWriter ||
        isAdminOrSuper;

    // Bottom nav bar height + system bottom padding ≈ 76px; add 8px gap above it.
    const double menuBottomOffset = 76.0 + 8.0;

    _overlayEntry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          // Transparent barrier – tap outside to close
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _closeMoreMenu,
            child: const SizedBox.expand(),
          ),
          // Menu items positioned above the bottom nav, right-aligned
          Positioned(
            bottom: menuBottomOffset,
            right: 8,
            child: Material(
              color: Colors.transparent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Shown in reverse so "Anbar" is closest to three-dot button
                  _menuCard(
                    icon: Icons.admin_panel_settings_outlined,
                    color: Colors.purple,
                    label: 'Admin',
                    hasAccess: isAdminOrSuper,
                    onTap: () => _handleMenuSelection('admin'),
                  ),
                  const SizedBox(height: 8),
                  _menuCard(
                    icon: Icons.map_outlined,
                    color: Colors.orange,
                    label: 'Xəritə',
                    hasAccess: hasMapAccess,
                    onTap: () => _handleMenuSelection('map'),
                  ),
                  const SizedBox(height: 8),
                  _menuCard(
                    icon: Icons.people_outline,
                    color: Colors.green,
                    label: 'İstifadəçilər',
                    hasAccess: isAdminOrSuper,
                    onTap: () => _handleMenuSelection('users'),
                  ),
                  const SizedBox(height: 8),
                  _menuCard(
                    icon: Icons.bar_chart_outlined,
                    color: Colors.teal,
                    label: 'Performans',
                    hasAccess: isAdminOrSuper,
                    onTap: () => _handleMenuSelection('performance'),
                  ),
                  const SizedBox(height: 8),
                  _menuCard(
                    icon: Icons.support_agent_outlined,
                    color: Colors.indigo,
                    label: 'Support',
                    hasAccess: hasMapAccess,
                    onTap: () => _handleMenuSelection('support'),
                  ),
                  const SizedBox(height: 8),
                  _menuCard(
                    icon: Icons.warehouse_outlined,
                    color: Colors.blue,
                    label: 'Anbar',
                    hasAccess: hasWarehouseAccess,
                    onTap: () => _handleMenuSelection('warehouse'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isMoreMenuOpen = true);
  }

  void _closeMoreMenu() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) setState(() => _isMoreMenuOpen = false);
  }

  void _handleMenuSelection(String value) {
    _closeMoreMenu();
    switch (value) {
      case 'warehouse':
        setState(() => _currentIndex = 3);
        break;
      case 'users':
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const UsersScreen()),
        );
        break;
      case 'map':
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const LiveMapScreen()),
        );
        break;
      case 'admin':
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const AdminScreen()),
        );
        break;
      case 'performance':
        final perfUser = ChatService().currentUser.value;
        if (perfUser != null &&
            (perfUser.isAdmin || perfUser.isSuperAdmin)) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const PerformanceScreen()),
          );
        }
        break;
      case 'support':
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const SupportScreen()),
        );
        break;
    }
  }

  /// A single floating card button — active or faded.
  Widget _menuCard({
    required IconData icon,
    required Color color,
    required String label,
    required bool hasAccess,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: hasAccess ? onTap : null,
      child: Container(
        width: _kMoreMenuItemWidth,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: hasAccess ? color : Colors.grey.withOpacity(0.35),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: hasAccess ? Colors.black87 : Colors.grey.withOpacity(0.45),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DigiTask'),
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
                        MaterialPageRoute(
                            builder: (context) => const NotificationsScreen()),
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
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          '$count',
                          style: const TextStyle(color: Colors.white, fontSize: 10),
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
                    Text('Profil'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Çıxış', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0, left: 8.0),
              child: CircleAvatar(
                backgroundImage:
                    _userAvatar != null ? NetworkImage(_userAvatar!) : null,
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
                      colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
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
                        MaterialPageRoute(
                            builder: (context) => const ChatListScreen()),
                      );
                    },
                    shape: const CircleBorder(),
                    child: const Icon(Icons.chat_bubble_outline,
                        size: 28, color: Colors.white),
                  ),
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                          color: Colors.red, shape: BoxShape.circle),
                      constraints:
                          const BoxConstraints(minWidth: 20, minHeight: 20),
                      child: Text(
                        '$unreadCount',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
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
                _buildNavItem(
                    0, Icons.dashboard_outlined, Icons.dashboard, 'Ana səhifə'),
                _buildNavItem(1, Icons.description_outlined,
                    Icons.description, 'Sənədlər'),
                const SizedBox(width: 60), // Gap for FAB
                _buildNavItem(
                    2, Icons.task_outlined, Icons.task, 'Tapşırıqlar'),
                _buildMoreNavItem(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Nav helpers ──────────────────────────────────────────────────────────

  /// Three-dot "more" button — toggles the custom overlay menu.
  Widget _buildMoreNavItem() {
    final user = ChatService().currentUser.value;
    // Performans veb ilə uyğun: bütün daxil olmuş istifadəçilər; menyu həmişə açılır.
    final bool hasAnyAccess = user != null;

    final Color dotColor =
        hasAnyAccess ? (_isMoreMenuOpen ? Colors.blue : Colors.grey[700]!) : Colors.grey.withOpacity(0.3);

    return InkWell(
      onTap: hasAnyAccess ? _toggleMoreMenu : null,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dot(dotColor),
                const SizedBox(width: 3),
                _dot(dotColor),
                const SizedBox(width: 3),
                _dot(dotColor),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Daha çox',
              style: TextStyle(fontSize: 10, color: dotColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot(Color color) => Container(
        width: 5,
        height: 5,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );

  Widget _buildNavItem(
      int index, IconData icon, IconData activeIcon, String label) {
    final user = ChatService().currentUser.value;

    if (index == 2) {
      final hasAccess =
          user != null && (user.isTaskReader || user.isTaskWriter);
      if (!hasAccess) return _buildDisabledNavItem(icon, label);
    }

    if (index == 1) {
      final hasAccess =
          user != null && (user.isDocumentReader || user.isDocumentWriter);
      if (!hasAccess) return _buildDisabledNavItem(icon, label);
    }

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
                color:
                    isSelected ? Theme.of(context).primaryColor : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisabledNavItem(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.grey.withOpacity(0.3)),
          Text(
            label,
            style:
                TextStyle(fontSize: 10, color: Colors.grey.withOpacity(0.3)),
          ),
        ],
      ),
    );
  }
}
