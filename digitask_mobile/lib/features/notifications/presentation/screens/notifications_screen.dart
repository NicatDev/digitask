import 'package:flutter/material.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1F2937)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Bildirişlər',
          style: TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text('Hamısını oxu'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildNotificationItem(
            'Yeni tapşırıq',
            'Sizə yeni tapşırıq təyin edildi: Router quraşdırması',
            '5 dəq əvvəl',
            Icons.assignment,
            const Color(0xFF3B82F6),
            true,
          ),
          _buildNotificationItem(
            'Status dəyişikliyi',
            'Tapşırıq #42 tamamlandı olaraq işarələndi',
            '1 saat əvvəl',
            Icons.check_circle,
            const Color(0xFF10B981),
            true,
          ),
          _buildNotificationItem(
            'Anbar bildirişi',
            'Router stoku azdır (5 ədəd qalıb)',
            '3 saat əvvəl',
            Icons.warning,
            const Color(0xFFF59E0B),
            false,
          ),
          _buildNotificationItem(
            'Yeni mesaj',
            'Qrup 1-dən yeni mesaj gəldi',
            'Dünən',
            Icons.message,
            const Color(0xFF8B5CF6),
            false,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(
    String title,
    String description,
    String time,
    IconData icon,
    Color color,
    bool isUnread,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isUnread ? Colors.white : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isUnread ? 10 : 5),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: isUnread ? Border.all(color: color.withAlpha(50)) : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: isUnread ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
            if (isUnread)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
