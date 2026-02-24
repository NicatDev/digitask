import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile/core/constants.dart';

/// Shared utility for refreshing JWT access tokens.
/// Used by WebSocket services before reconnecting.
class TokenService {
  static const _storage = FlutterSecureStorage();

  /// Attempts to refresh the access token using the stored refresh token.
  /// Returns the new access token on success, or null if refresh fails.
  static Future<String?> refreshAccessToken() async {
    final refreshToken = await _storage.read(key: 'refresh_token');
    if (refreshToken == null) return null;

    try {
      final response = await Dio(BaseOptions(
        baseUrl: AppConstants.baseUrl,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      )).post('/token/refresh/', data: {'refresh': refreshToken});

      if (response.statusCode == 200) {
        final newAccessToken = response.data['access'];
        final newRefreshToken = response.data['refresh'];

        await _storage.write(key: 'access_token', value: newAccessToken);
        if (newRefreshToken != null) {
          await _storage.write(key: 'refresh_token', value: newRefreshToken);
        }

        print('[TokenService] Access token refreshed successfully');
        return newAccessToken;
      }
    } catch (e) {
      print('[TokenService] Token refresh failed: $e');
    }
    return null;
  }

  /// Gets a valid access token — tries stored one first, refreshes if needed.
  static Future<String?> getValidToken() async {
    final token = await _storage.read(key: 'access_token');
    if (token != null) return token;
    
    // No token in storage, try to refresh
    return await refreshAccessToken();
  }
}
