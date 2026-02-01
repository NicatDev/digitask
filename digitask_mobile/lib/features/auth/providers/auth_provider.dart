import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import 'package:dio/dio.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  AuthStatus _status = AuthStatus.unknown;
  AuthStatus get status => _status;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  Map<String, dynamic>? _user;
  Map<String, dynamic>? get user => _user;

  AuthProvider(this._apiService) {
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final token = await _storage.read(key: AppConstants.tokenKey);
    if (token != null) {
      try {
        await fetchProfile();
        _status = AuthStatus.authenticated;
      } catch (e) {
        _status = AuthStatus.unauthenticated;
        await _storage.deleteAll();
      }
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.dio.post(
        AppConstants.loginEndpoint,
        data: {
          'email': email,
          'password': password,
        },
      );

      final access = response.data['access'];
      final refresh = response.data['refresh'];

      await _storage.write(key: AppConstants.tokenKey, value: access);
      await _storage.write(key: AppConstants.refreshTokenKey, value: refresh);

      await fetchProfile();
      _status = AuthStatus.authenticated;
    } on DioException catch (e) {
      _error = e.response?.data['detail'] ?? 'Login failed. Please check your credentials.';
      _status = AuthStatus.unauthenticated;
    } catch (e) {
      _error = 'An unexpected error occurred.';
      _status = AuthStatus.unauthenticated;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchProfile() async {
    // Assuming backend has a /users/me/ or similar, or we decode token. 
    // The previous analysis didn't show the exact 'me' endpoint, but settings showed 'users' app.
    // I'll try to get user details. Check 'UserLocationModal' uses '/live-map/' to find user. 
    // Standard JWT often has user_id. 
    // For now, I will just set authenticated. Ideally we fetch user data.
    // Let's assume there is an endpoint or we just store "authenticated" for now.
    // If we need user info (name, id), we might need to decode the token or call an API.
    // The web app uses `jwt-decode` to get user ID then presumably fetches data.
    // I will skip fetching profile for this exact step to avoid guessing endpoint, 
    // but mark as authenticated.
  }

  Future<void> logout() async {
    await _storage.deleteAll();
    _status = AuthStatus.unauthenticated;
    _user = null;
    notifyListeners();
  }
}
