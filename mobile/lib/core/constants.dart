import 'package:flutter/foundation.dart';

class AppConstants {
  /// React web app host (e.g. legal pages). API lives on a different host — see [baseUrl].
  static const String webFrontendOrigin = 'https://digitask.digigroup.az';

  // Production URL for release builds, local URLs for debug
  static String get baseUrl {
    if (kReleaseMode) {
      // Production - Release APK
      return 'https://app.digitask.digigroup.az/api';
    } else {
      // Development - Local debug
      return 'https://app.digitask.digigroup.az/api';
    }
  }
  
  // WebSocket URL derived from baseUrl
  static String get wsUrl {
    final uri = Uri.parse(baseUrl);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    // Remove /api suffix for WebSocket base
    final wsBase = baseUrl.replaceFirst('/api', '');
    return wsBase.replaceFirst(uri.scheme, scheme);
  }
}

