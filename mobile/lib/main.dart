import 'package:mobile/core/api/api_client.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile/screens/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mobile/core/services/location_service.dart';
import 'screens/main_layout.dart';

import 'package:mobile/core/services/background_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // LocationService is now initialized in MainLayout after login
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

