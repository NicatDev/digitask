class AppConstants {
  // Replace with your local IP if running on emulator (e.g., 10.0.2.2 for Android)
  // For physical device, use your machine's LAN IP (e.g., 192.168.1.X)
  static const String baseUrl = 'http://10.0.2.2:8000/api'; 
  static const String wsUrl = 'ws://10.0.2.2:8000/ws';

  // Auth
  static const String tokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  
  // Endpoints
  static const String loginEndpoint = '/token/';
  static const String refreshTokenEndpoint = '/token/refresh/';
  static const String userProfileEndpoint = '/users/me/';
  static const String liveMapEndpoint = '/live-map/';
}
