import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/core/constants.dart';
import 'package:mobile/screens/main_layout.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mobile/core/services/location_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:mobile/core/services/notification_diagnostics_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _requestIosPermissionsAfterLogin() async {
    if (!Platform.isIOS) return;

    try {
      // Notification permission via FirebaseMessaging is preferred on iOS.
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
    } catch (e) {
      debugPrint('iOS notification permission error: $e');
      await NotificationDiagnosticsService.instance.report(
        source: 'ios_permission_request',
        message: 'Failed to request iOS notification permission',
        code: 'IOS_NOTIF_PERMISSION_FAIL',
        error: e,
      );
    }

    try {
      // Ask location permissions in proper order for iOS.
      var locationStatus = await Permission.location.status;
      if (!locationStatus.isGranted) {
        locationStatus = await Permission.location.request();
      }
      if (locationStatus.isGranted) {
        final alwaysStatus = await Permission.locationAlways.status;
        if (!alwaysStatus.isGranted) {
          await Permission.locationAlways.request();
        }
      }
    } catch (e) {
      debugPrint('iOS location permission error: $e');
      await NotificationDiagnosticsService.instance.report(
        source: 'ios_permission_request',
        message: 'Failed to request iOS location permissions',
        code: 'IOS_LOCATION_PERMISSION_FAIL',
        error: e,
      );
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiClient().dio.post('/token/', data: {
        'username': _usernameController.text,
        'password': _passwordController.text,
      });

      if (response.statusCode == 200) {
        final access = response.data['access'];
        final refresh = response.data['refresh'];
        
        const storage = FlutterSecureStorage();
        await storage.write(key: 'access_token', value: access);
        await storage.write(key: 'refresh_token', value: refresh);

        if (mounted) {
           await _requestIosPermissionsAfterLogin();
           try {
             await LocationService.initialize();
           } catch (e) {
             debugPrint('LocationService init error: $e');
           }
           Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainLayout()),
          );
        }
      }
    } on DioException catch (e) {
      setState(() {
        _errorMessage = e.response?.data['detail'] ?? 'Giriş uğursuz oldu';
      });
    } catch (e) {
       setState(() {
        _errorMessage = 'Gözlənilməz xəta baş verdi';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openLegalPage(String path) async {
    final uri = Uri.parse('${AppConstants.webFrontendOrigin}$path');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Səhifə açıla bilmədi')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'DigiTask',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 48),
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: Colors.red.withOpacity(0.1),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'İstifadəçi adı',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (v) => v!.isEmpty ? 'Tələb olunur' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Şifrə',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                  validator: (v) => v!.isEmpty ? 'Tələb olunur' : null,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Daxil ol'),
                ),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  children: [
                    TextButton(
                      onPressed: () => _openLegalPage('/privacy-policy'),
                      child: const Text('Məxfilik siyasəti'),
                    ),
                    Text(
                      '·',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                    ),
                    TextButton(
                      onPressed: () => _openLegalPage('/terms-conditions'),
                      child: const Text('İstifadə şərtləri'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
