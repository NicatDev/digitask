import 'package:flutter/material.dart';
import '../dashboard/presentation/screens/dashboard_screen.dart';
import '../tasks/presentation/screens/tasks_screen.dart';
import '../warehouse/presentation/screens/warehouse_screen.dart';
import '../users/presentation/screens/users_screen.dart';
import '../profile/presentation/screens/profile_screen.dart';
import '../chat/presentation/screens/chat_screen.dart';
import '../notifications/presentation/screens/notifications_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _centerTabController;
  late Animation<double> _centerTabScale;

  final List<Widget> _screens = const [
    DashboardScreen(),
    TasksScreen(),
    WarehouseScreen(),
    UsersScreen(),
    ProfileScreen(),
  ];

  // Tab colors
  static const List<Color> _tabColors = [
    Color(0xFF3B82F6), // Blue - Home
    Color(0xFF8B5CF6), // Violet - Tasks
    Color(0xFFF59E0B), // Amber - Warehouse
    Color(0xFF10B981), // Emerald - Users
    Color(0xFF6366F1), // Indigo - Profile
  ];

  @override
  void initState() {
    super.initState();
    _centerTabController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _centerTabScale = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _centerTabController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _centerTabController.dispose();
    super.dispose();
  }

  void _navigateToChat() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChatScreen()),
    );
  }

  void _navigateToNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  }

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
    if (index == 2) {
      _centerTabController.forward().then((_) => _centerTabController.reverse());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.task_alt, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'DigiTask',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Color(0xFF1F2937),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _navigateToChat,
            icon: const Icon(Icons.chat_bubble_outline),
            color: const Color(0xFF6B7280),
            tooltip: 'Chat',
          ),
          Stack(
            children: [
              IconButton(
                onPressed: _navigateToNotifications,
                icon: const Icon(Icons.notifications_outlined),
                color: const Color(0xFF6B7280),
                tooltip: 'Bildirişlər',
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(15),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildNavItem(0, Icons.home_outlined, Icons.home_rounded, 'Ana Səhifə'),
                _buildNavItem(1, Icons.assignment_outlined, Icons.assignment, 'Tapşırıqlar'),
                _buildCenterNavItem(),
                _buildNavItem(3, Icons.people_outline, Icons.people, 'İstifadəçilər'),
                _buildNavItem(4, Icons.person_outline, Icons.person, 'Profil'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = _currentIndex == index;
    final color = _tabColors[index];
    
    return GestureDetector(
      onTap: () => _onTabSelected(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 12 : 8,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(25) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isSelected ? color.withAlpha(30) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isSelected ? activeIcon : icon,
                color: isSelected ? color : Colors.grey.shade500,
                size: 22,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: isSelected ? color : Colors.grey.shade500,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterNavItem() {
    final isSelected = _currentIndex == 2;
    const color = Color(0xFFF59E0B); // Amber for warehouse
    
    return GestureDetector(
      onTap: () => _onTabSelected(2),
      child: AnimatedBuilder(
        animation: _centerTabScale,
        builder: (context, child) {
          return Transform.scale(
            scale: isSelected ? _centerTabScale.value : 1.0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isSelected ? null : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withAlpha(100),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSelected ? Icons.warehouse : Icons.warehouse_outlined,
                    color: isSelected ? Colors.white : Colors.grey.shade600,
                    size: 22,
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    child: isSelected
                        ? Row(
                            children: [
                              const SizedBox(width: 8),
                              Text(
                                'Anbar',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withAlpha(50),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
