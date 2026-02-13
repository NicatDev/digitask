import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/core/constants.dart';
import 'package:mobile/models/notification_model.dart';
import 'package:mobile/core/services/chat_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  
  WebSocketChannel? _channel;
  final _storage = const FlutterSecureStorage();
  
  // State
  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);
  final ValueNotifier<List<NotificationModel>> notifications =
      ValueNotifier<List<NotificationModel>>([]);

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize Local Notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@drawable/ic_notification');
    
    // Note: iOS permissions are requested in main.dart, but we need config here
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        // We'll implement navigation later if needed
      },
    );

    _isInitialized = true;
    
    // Initial fetch
    await fetchNotifications();
    await fetchUnreadCount();
    
    // Connect WebSocket
    connect();
  }

  Future<void> connect() async {
    final token = await _storage.read(key: 'access_token');
    if (token == null) return;

    // Construct WebSocket URL from AppConstants.baseUrl
    final uri = Uri.parse(AppConstants.baseUrl);
    String host = uri.host;
    
    // For Android emulator in debug mode, replace localhost with 10.0.2.2
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android && host == '127.0.0.1') {
      host = '10.0.2.2';
    }
    
    final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
    final portPart = (uri.port != 80 && uri.port != 443 && uri.hasPort) ? ':${uri.port}' : '';
    final wsUrl = '$wsScheme://$host$portPart/ws/notifications/';
    
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('$wsUrl?token=$token'),
      );

      _channel!.stream.listen(
        (message) {
          _handleMessage(message);
        },
        onError: (error) {
          print('WebSocket Error: $error');
          // Simple reconnect logic could go here
        },
        onDone: () {
          print('WebSocket Closed');
        },
      );
    } catch (e) {
      print('WebSocket Connection Error: $e');
    }
  }

  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message);
      
      // Handle Chat Notification
      if (data['chat_notification'] != null) {
          ChatService().handleGlobalNotification(data['chat_notification']);
      }

      if (data['type'] == 'notification_message') {
        final notificationData = data['notification'];
        
        if (notificationData != null) {
          // Show Local Notification
          _showLocalNotification(
            id: notificationData['id'] ?? 0, // Fallback id
            title: notificationData['title'] ?? 'DigiTask',
            body: notificationData['message'] ?? '',
          );

          // Update Unread Count
          unreadCount.value++;
          
          // Add to list (if we want to update list in real-time)
          try {
             final newNotification = NotificationModel.fromJson(notificationData);
             final currentList = List<NotificationModel>.from(notifications.value);
             currentList.insert(0, newNotification);
             notifications.value = currentList;
          } catch (e) {
             print('Error parsing notification model: $e');
          }
        }
      }
    } catch (e) {
      print('Error parsing message: $e');
    }
  }

  Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'digitask_notifications',
      'DigiTask Notifications',
      channelDescription: 'Notifications from DigiTask App',
      importance: Importance.max,
      priority: Priority.high,
    );
    
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _localNotifications.show(
      id,
      title,
      body,
      platformChannelSpecifics,
    );
  }

  Future<void> fetchNotifications() async {
    try {
      final response = await ApiClient().dio.get('/notifications/');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        notifications.value = data.map((json) => NotificationModel.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error fetching notifications: $e');
    }
  }

  Future<void> fetchUnreadCount() async {
    try {
      final response = await ApiClient().dio.get('/notifications/unread_count/');
      if (response.statusCode == 200) {
        unreadCount.value = response.data['unread_count'];
      }
    } catch (e) {
      print('Error fetching unread count: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await ApiClient().dio.post('/notifications/mark_read/');
      unreadCount.value = 0;
      // Mark all local objects as read
      final currentList = notifications.value.map((n) {
         // Since NotificationModel is immutable, we'd strictly need to create new objects
         // But for simple display, maybe just refetch or assume read
         return n; 
      }).toList();
       // actually, backend update is done, let's just refetch to be sure or just clear unread
       // The requirement says "Mark all as read" button.
       // We can just set unreadCount to 0.
       // If we track isRead per item, we might need to update that too.
       fetchNotifications(); // optimal to refetch
    } catch (e) {
      print('Error marking all as read: $e');
    }
  }

  void disconnect() {
    _channel?.sink.close();
  }
}
