import 'dart:async';
import 'dart:ui';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart'; 
import '../constants.dart';

// --- SHARED LOGIC ---

Future<String?> _getWebSocketUrl() async {
  const storage = FlutterSecureStorage();
  final token = await storage.read(key: 'access_token');
  if (token == null) return null;

  final uri = Uri.parse(AppConstants.baseUrl);
  String host = uri.host;
  
  // For Android emulator in debug mode, replace localhost with 10.0.2.2
  if (!kIsWeb && Platform.isAndroid && host == '127.0.0.1') {
    host = '10.0.2.2';
  }
  
  final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
  
  // Build WebSocket URL - include port only if it's explicitly set (not default 80/443)
  final portPart = (uri.port != 80 && uri.port != 443 && uri.hasPort) ? ':${uri.port}' : '';
  
  return '$wsScheme://$host$portPart/ws/tracking/?token=$token';
}

class LocationService {
  // Web State
  static StreamSubscription<Position>? _webPositionStream;
  static WebSocketChannel? _webChannel;
  static bool _webIsConnected = false;

  static Future<void> initialize() async {
    if (kIsWeb) {
      await _startWebTracking();
      return;
    }
    // For mobile, background service is initialized in background_service.dart
    // which calls LocationService.startBackgroundTracking
  }

  static Future<void> startBackgroundTracking(ServiceInstance service) async {
    // Only available for flutter 3.0.0 and later
    DartPluginRegistrant.ensureInitialized();
    WidgetsFlutterBinding.ensureInitialized(); // Required for FlutterSecureStorage

    print('[LocationService] Starting background tracking...');

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    if (Platform.isAndroid) {
      await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(
        const AndroidNotificationChannel(
          'digitask_location_channel', 
          'Location Service', 
          description: 'Tracking location in background',
          importance: Importance.low, 
        ),
      );
    }

    WebSocketChannel? channel;
    bool isConnected = false;
    
    Future<void> connectWebSocket() async {
      final wsUrl = await _getWebSocketUrl();
      print('[LocationService] WebSocket URL: $wsUrl');
      if (wsUrl == null) {
        print('[LocationService] No token found, cannot connect WebSocket');
        return;
      }
      
      try {
        channel = IOWebSocketChannel.connect(wsUrl);
        channel!.stream.listen(
          (message) {
            print('[LocationService] WS Message: $message');
          },
          onDone: () {
            print('[LocationService] WebSocket closed');
            isConnected = false;
          },
          onError: (error) {
            print('[LocationService] WebSocket error: $error');
            isConnected = false;
          },
        );
        isConnected = true;
        print('[LocationService] WebSocket connected successfully');
      } catch (e) {
        print('[LocationService] WebSocket connection failed: $e');
        isConnected = false;
      }
    }

    // Permission check inside background isolate might be tricky if not granted yet.
    // We assume permissions are granted before service starts.
    
    LocationSettings locationSettings;

    if (Platform.isAndroid) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        forceLocationManager: true,
        intervalDuration: const Duration(seconds: 10),
      );
    } else if (Platform.isIOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: 10,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );
    }

    Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) async {
      if (!kIsWeb && service is AndroidServiceInstance) {
        bool isForeground = false;
        try {
          isForeground = await service.isForegroundService(); 
        } catch (e) {
          // Ignore error in background isolate
        }

        if (isForeground) {
          flutterLocalNotificationsPlugin.show(
            888,
            'DigiTask Tracking',
            'Tracking is active',
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'digitask_location_channel',
                'Location Service',
                icon: 'ic_notification',
                ongoing: true,
              ),
            ),
          );
        }
      }

      if (!isConnected) await connectWebSocket();
      
      if (isConnected && channel != null) {
        try {
          channel!.sink.add(jsonEncode({
            'type': 'location_update',
            'latitude': position.latitude,
            'longitude': position.longitude,
          }));
        } catch (e) {
          isConnected = false;
        }
      }
      
      service.invoke(
        'update',
        {"lat": position.latitude, "lng": position.longitude},
      );
    });
    
    Timer.periodic(const Duration(seconds: 30), (timer) async {
        if (!isConnected) await connectWebSocket();
    });
  }

  static Future<void> _startWebTracking() async {
    await stop(); // Stop existing triggers
    
    print('[LocationService] Starting web tracking...');

    Future<void> connectWebSocket() async {
        final wsUrl = await _getWebSocketUrl();
        print('[LocationService] Web WebSocket URL: $wsUrl');
        if (wsUrl == null) {
          print('[LocationService] No token found for web tracking');
          return;
        }

        try {
            _webChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
            _webChannel!.stream.listen(
                (message) {
                  print('[LocationService] Web WS Message: $message');
                },
                onDone: () {
                  print('[LocationService] Web WebSocket closed');
                  _webIsConnected = false;
                },
                onError: (error) {
                  print('[LocationService] Web WebSocket error: $error');
                  _webIsConnected = false;
                },
            );
            _webIsConnected = true;
            print('[LocationService] Web WebSocket connected');
        } catch (e) {
            print('[LocationService] Web WebSocket connection failed: $e');
            _webIsConnected = false;
        }
    }

    // Check and request permission for web
    LocationPermission permission = await Geolocator.checkPermission();
    print('[LocationService] Current permission: $permission');
    
    if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        print('[LocationService] After request permission: $permission');
    }
    
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        print('[LocationService] Location permission denied, cannot track');
        return;
    }

    // Web settings
    const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
    );

    print('[LocationService] Starting web position stream...');
    _webPositionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) async {
        print('[LocationService] Web position: ${position.latitude}, ${position.longitude}');
        if (!_webIsConnected) await connectWebSocket();
        
        if (_webIsConnected && _webChannel != null) {
            try {
                _webChannel!.sink.add(jsonEncode({
                    'type': 'location_update',
                    'latitude': position.latitude,
                    'longitude': position.longitude,
                }));
                print('[LocationService] Web location sent to server');
            } catch (e) {
                print('[LocationService] Web send error: $e');
                _webIsConnected = false;
            }
        }
    });
  }
  
  @pragma('vm:entry-point') 
  static bool onServiceBackground(ServiceInstance service) {
    WidgetsFlutterBinding.ensureInitialized();
    return true;
  }

  static Future<void> stop() async {
    if (kIsWeb) {
        await _webPositionStream?.cancel();
        _webChannel?.sink.close();
        _webPositionStream = null;
        _webChannel = null;
        _webIsConnected = false;
        return;
    }

    final service = FlutterBackgroundService();
    if (await service.isRunning()) {
       service.invoke("stopService");
    }
  }
}
