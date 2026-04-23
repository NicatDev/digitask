import 'dart:async';
import 'dart:io';

import 'package:mobile/core/api/api_client.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile/screens/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import 'screens/main_layout.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:mobile/core/services/notification_diagnostics_service.dart';

// Top-level background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e, st) {
    await NotificationDiagnosticsService.instance.report(
      source: 'fcm_background_init',
      message: 'Failed to initialize Firebase in background handler',
      code: 'BG_INIT_ERROR',
      error: e,
      stackTrace: st,
      extra: {
        'message_id': message.messageId,
      },
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Route Flutter framework errors to Crashlytics.
  FlutterError.onError = (FlutterErrorDetails details) {
    unawaited(
      NotificationDiagnosticsService.instance.report(
        source: 'flutter_error',
        message: details.exceptionAsString(),
        code: 'FLUTTER_UNHANDLED',
        error: details.exception,
        stackTrace: details.stack,
      ),
    );
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    final isNetworkError =
        error is DioException ||
        error is SocketException ||
        error is TimeoutException;

    unawaited(
      NotificationDiagnosticsService.instance.report(
        source: 'platform_dispatcher',
        message: 'Unhandled platform error',
        code: 'PLATFORM_UNHANDLED',
        error: error,
        stackTrace: stack,
      ),
    );
    FirebaseCrashlytics.instance.recordError(
      error,
      stack,
      fatal: !isNetworkError,
    );
    return true;
  };
  
  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  // Request iOS notification permissions
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    provisional: false,
  );
  
  // Set foreground notification presentation options (iOS)
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );
  
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
