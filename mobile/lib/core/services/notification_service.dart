import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/core/constants.dart';
import 'package:mobile/models/notification_model.dart';
import 'package:mobile/core/services/chat_service.dart';
import 'package:mobile/core/services/token_service.dart';
import 'package:mobile/core/services/notification_diagnostics_service.dart';

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
    
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
      },
    );

    // Create Android notification channel at startup.
    // Android 8+ (API 26+) requires the channel to exist BEFORE any FCM
    // notification with that channel_id arrives, otherwise the system
    // silently drops the notification.
    if (!kIsWeb && Platform.isAndroid) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'digitask_notifications',
        'DigiTask Notifications',
        description: 'Notifications from DigiTask App',
        importance: Importance.max,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    _isInitialized = true;
    
    // Initial fetch
    await fetchNotifications();
    await fetchUnreadCount();
    
    // Register FCM token
    await _registerFcmToken();
    
    // Listen for foreground FCM messages
    _setupFcmForegroundListener();
    
    // Connect WebSocket (for real-time in-app updates)
    connect();
  }

  /// Register FCM token with the backend
  Future<void> _registerFcmToken() async {
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        print('FCM Token: $fcmToken');
        await ApiClient().dio.post('/users/register-fcm-token/', data: {
          'fcm_token': fcmToken,
        });
        print('FCM token registered with backend');
      } else {
        await NotificationDiagnosticsService.instance.report(
          source: 'fcm_token_register',
          message: 'Firebase returned null FCM token',
          code: 'TOKEN_NULL',
        );
      }
      
      // Listen for token refresh
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        try {
          await ApiClient().dio.post('/users/register-fcm-token/', data: {
            'fcm_token': newToken,
          });
          print('FCM token refreshed and registered');
        } catch (e) {
          print('Error registering refreshed FCM token: $e');
          await NotificationDiagnosticsService.instance.report(
            source: 'fcm_token_refresh',
            message: 'Failed to register refreshed FCM token',
            code: 'TOKEN_REFRESH_REGISTER_FAIL',
            error: e,
          );
        }
      });
    } catch (e) {
      print('Error registering FCM token: $e');
      await NotificationDiagnosticsService.instance.report(
        source: 'fcm_token_register',
        message: 'Failed to get/register FCM token',
        code: 'TOKEN_REGISTER_FAIL',
        error: e,
      );
    }
  }

  /// Listen for FCM messages while app is in foreground
  void _setupFcmForegroundListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final notification = message.notification;
      // Show local notification in foreground for both Android and iOS.
      // iOS: setForegroundNotificationPresentationOptions handles system-level
      //   display for notification+data payloads, but local notification
      //   gives us consistent control and handles data-only messages too.
      // Android: System never auto-shows FCM in foreground, so local is required.
      if (notification != null) {
        try {
          await _showLocalNotification(
            id: notification.hashCode,
            title: notification.title ?? 'DigiTask',
            body: notification.body ?? '',
            tag: message.data['tag'],
          );
        } catch (e, st) {
          NotificationDiagnosticsService.instance.report(
            source: 'fcm_foreground_display',
            message: 'Failed to show local notification in foreground',
            code: 'FG_DISPLAY_FAIL',
            error: e,
            stackTrace: st,
            extra: {
              'message_id': message.messageId,
              'has_notification': true,
              'data': message.data,
            },
          );
        }
      }

      // Update unread count for non-chat notifications
      final type = message.data['type'];
      if (type == 'notification') {
        // Keep badge/list synced to backend as source of truth.
        fetchUnreadCount();
        fetchNotifications();
      }
    });
  }

  Timer? _reconnectTimer;
  bool _isConnecting = false;

  Future<void> connect() async {
    if (_isConnecting) return;
    _isConnecting = true;
    
    final token = await _storage.read(key: 'access_token');
    if (token == null) {
        _isConnecting = false;
        return;
    }

    // Construct WebSocket URL from AppConstants.baseUrl
    final uri = Uri.parse(AppConstants.baseUrl);
    String host = uri.host;
    
    final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
    final portPart = (uri.port != 80 && uri.port != 443 && uri.hasPort) ? ':${uri.port}' : '';
    final wsUrl = '$wsScheme://$host$portPart/ws/notifications/';
    
    try {
      print('Connecting to Notification Socket: $wsUrl');
      _channel = WebSocketChannel.connect(
        Uri.parse('$wsUrl?token=$token'),
      );

      _channel!.stream.listen(
        (message) {
          _handleMessage(message);
        },
        onError: (error) {
          print('WebSocket Error: $error');
          _scheduleReconnect();
        },
        onDone: () {
          print('WebSocket Closed');
          _scheduleReconnect();
        },
      );
      print('Notification Socket Connected');
    } catch (e) {
      print('WebSocket Connection Error: $e');
      _scheduleReconnect();
    } finally {
        _isConnecting = false;
    }
  }

  void _scheduleReconnect() {
    if (_reconnectTimer?.isActive ?? false) return;
    
    print('Scheduling reconnect in 5 seconds...');
    _reconnectTimer = Timer(const Duration(seconds: 5), () async {
      print('Attempting to reconnect WebSocket...');
      // Refresh token before reconnecting
      await TokenService.refreshAccessToken();
      connect();
    });
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
  }

  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message);
      
      // Handle Chat Notification (for in-app real-time updates)
      if (data['chat_notification'] != null) {
          ChatService().handleGlobalNotification(data['chat_notification']);
      }

      if (data['type'] == 'notification_message') {
        final notificationData = data['notification'];
        
        if (notificationData != null) {
          final notificationType =
              notificationData['notification_type']?.toString().toLowerCase();
          if (notificationType == 'chat_message') {
            return;
          }

          // Don't show local notification here — FCM handles it.
          // Just update in-app state.
          fetchUnreadCount();
          
          // Add to list (real-time update)
          try {
             final newNotification = NotificationModel.fromJson(notificationData);
             final currentList = List<NotificationModel>.from(notifications.value);
             final exists = currentList.any((n) => n.id == newNotification.id);
             if (!exists) {
               currentList.insert(0, newNotification);
             }
             notifications.value = currentList;
          } catch (e) {
             print('Error parsing notification model: $e');
          }
        }
      }
    } catch (e) {
      print('Error parsing message: $e');
      NotificationDiagnosticsService.instance.report(
        source: 'ws_notification_parse',
        message: 'Failed to parse incoming notification websocket payload',
        code: 'WS_PARSE_FAIL',
        error: e,
      );
    }
  }

  Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? tag,
  }) async {
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'digitask_notifications',
      'DigiTask Notifications',
      channelDescription: 'Notifications from DigiTask App',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@drawable/ic_notification',
      tag: tag,
    );
    
    final NotificationDetails platformChannelSpecifics =
        NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: const DarwinNotificationDetails(),
    );

    await _localNotifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
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
      NotificationDiagnosticsService.instance.report(
        source: 'notifications_fetch',
        message: 'Failed to fetch notifications list',
        code: 'FETCH_LIST_FAIL',
        error: e,
      );
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
      NotificationDiagnosticsService.instance.report(
        source: 'notifications_unread_count',
        message: 'Failed to fetch unread notification count',
        code: 'FETCH_UNREAD_FAIL',
        error: e,
      );
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await ApiClient().dio.post('/notifications/mark_read/');
      unreadCount.value = 0;
       fetchNotifications();
    } catch (e) {
      print('Error marking all as read: $e');
      NotificationDiagnosticsService.instance.report(
        source: 'notifications_mark_read',
        message: 'Failed to mark notifications as read',
        code: 'MARK_READ_FAIL',
        error: e,
      );
    }
  }


}
