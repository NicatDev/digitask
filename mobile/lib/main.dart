import 'package:mobile/core/api/api_client.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile/screens/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mobile/core/services/location_service.dart';
import 'screens/main_layout.dart';

import 'package:mobile/core/services/background_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Top-level background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  
  // Show local notification for background FCM message
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@drawable/ic_notification');
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  
  final notification = message.notification;
  if (notification != null) {
    final androidDetails = AndroidNotificationDetails(
      'digitask_notifications',
      'DigiTask Notifications',
      channelDescription: 'Notifications from DigiTask App',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@drawable/ic_notification',
      tag: message.data['tag'],
    );
    
    await flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(android: androidDetails),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  @override
  void initState() {
    super.initState();
    // Permissions are now handled in MainLayout to ensure correct timing with Service Init
  }

  Future<bool> _checkAuth() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');
    
    if (token == null) return false;

    try {
      final response = await ApiClient().dio.get('/users/me/');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DigiTask',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF0F2F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          titleTextStyle: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
          iconTheme: IconThemeData(color: Colors.black),
        ),
      ),
      home: FutureBuilder<bool>(
        future: _checkAuth(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.data == true) {
            return const MainLayout();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
