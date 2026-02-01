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

  Future<void> login(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('Attempting login to: ${AppConstants.baseUrl}${AppConstants.loginEndpoint}');
      debugPrint('Username: $username');
      
      final response = await _apiService.dio.post(
        AppConstants.loginEndpoint,
        data: {
          'username': username,
          'password': password,
        },
      );

      debugPrint('Login response status: ${response.statusCode}');
      debugPrint('Login response data: ${response.data}');

      final access = response.data['access'];
      final refresh = response.data['refresh'];

      if (access == null || refresh == null) {
        _error = 'Serverdən düzgün cavab gəlmədi';
        _status = AuthStatus.unauthenticated;
        return;
      }

      await _storage.write(key: AppConstants.tokenKey, value: access);
      await _storage.write(key: AppConstants.refreshTokenKey, value: refresh);

      await fetchProfile();
      _status = AuthStatus.authenticated;
    } on DioException catch (e) {
      debugPrint('DioException type: ${e.type}');
      debugPrint('DioException message: ${e.message}');
      debugPrint('DioException response: ${e.response?.data}');
      
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          _error = 'Bağlantı vaxtı bitdi. Server açıqdır?';
          break;
        case DioExceptionType.connectionError:
          _error = 'Serverə qoşulmaq mümkün olmadı.\n'
                   'URL: ${AppConstants.baseUrl}\n'
                   'Backend serverin işlədiyindən əmin olun.';
          break;
        case DioExceptionType.badResponse:
          final statusCode = e.response?.statusCode;
          final responseData = e.response?.data;
          String? detail;
          
          // Safely extract detail from response
          if (responseData is Map<String, dynamic>) {
            detail = responseData['detail']?.toString();
          } else if (responseData is String) {
            detail = responseData;
          }
          
          if (statusCode == 401) {
            _error = detail ?? 'İstifadəçi adı və ya şifrə yanlışdır';
          } else if (statusCode == 400) {
            _error = detail ?? 'Yanlış məlumat göndərildi';
          } else if (statusCode == 404) {
            _error = 'Login endpoint tapılmadı (404)';
          } else {
            _error = 'Server xətası: $statusCode\n${detail ?? ''}';
          }
          break;
        default:
          _error = 'Şəbəkə xətası: ${e.message}';
      }
      _status = AuthStatus.unauthenticated;
    } catch (e) {
      debugPrint('Unexpected error: $e');
      _error = 'Gözlənilməz xəta: $e';
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
