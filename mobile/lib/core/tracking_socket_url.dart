import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile/core/constants.dart';

/// Shared WebSocket URL for `/ws/tracking/` (live map + location service).
Future<String?> getTrackingWebSocketUrl() async {
  const storage = FlutterSecureStorage();
  final token = await storage.read(key: 'access_token');
  if (token == null) return null;

  final uri = Uri.parse(AppConstants.baseUrl);
  final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
  final portPart =
      (uri.port != 80 && uri.port != 443 && uri.hasPort) ? ':${uri.port}' : '';

  return '$wsScheme://${uri.host}$portPart/ws/tracking/?token=$token';
}
