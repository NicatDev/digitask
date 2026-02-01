import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class AppConstants {
  // Get the appropriate base URL based on platform
  static String get baseUrl {
    if (kIsWeb) {
      // Web browser - use localhost directly
      return 'http://127.0.0.1:8000/api';
    }
    try {
      if (Platform.isAndroid) {
        // Android emulator uses 10.0.2.2 to reach host machine
        return 'http://10.0.2.2:8000/api';
      } else if (Platform.isIOS) {
        // iOS simulator uses localhost
        return 'http://127.0.0.1:8000/api';
      }
    } catch (_) {
      // Platform not available (web)
    }
    // Default fallback
    return 'http://127.0.0.1:8000/api';
  }
  
  static String get wsUrl {
    if (kIsWeb) {
      return 'ws://127.0.0.1:8000/ws';
    }
    try {
      if (Platform.isAndroid) {
        return 'ws://10.0.2.2:8000/ws';
      }
    } catch (_) {
      // Platform not available
    }
    return 'ws://127.0.0.1:8000/ws';
  }

  // Auth
  static const String tokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  
  // Endpoints
  static const String loginEndpoint = '/token/';
  static const String refreshTokenEndpoint = '/token/refresh/';
  static const String userProfileEndpoint = '/users/me/';
  static const String liveMapEndpoint = '/live-map/';
  static const String tasksEndpoint = '/tasks/tasks/';
}
