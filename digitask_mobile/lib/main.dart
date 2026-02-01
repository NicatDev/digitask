import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/services/api_service.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/home/providers/home_provider.dart';
import 'features/dashboard/providers/dashboard_provider.dart';
import 'features/shell/main_shell.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize Services
    final apiService = ApiService();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(apiService)),
        ChangeNotifierProvider(create: (_) => HomeProvider(apiService)),
        ChangeNotifierProvider(create: (_) => DashboardProvider(apiService)),
      ],
      child: const MaterialAppWithAuth(),
    );
  }
}

class MaterialAppWithAuth extends StatelessWidget {
  const MaterialAppWithAuth({super.key});

  // Custom color scheme for modern look
  static const _primaryColor = Color(0xFF2563EB); // Blue-600
  static const _secondaryColor = Color(0xFF7C3AED); // Violet-600
  
  @override
  Widget build(BuildContext context) {
    final status = context.select((AuthProvider p) => p.status);

    return MaterialApp(
      title: 'DigiTask Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _primaryColor,
          secondary: _secondaryColor,
          brightness: Brightness.light,
        ),
        // Modern app bar
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 1,
        ),
        // Elevated button theme
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: status == AuthStatus.authenticated
          ? const MainShell()
          : const LoginScreen(),
    );
  }
}
