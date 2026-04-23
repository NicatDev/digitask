import 'dart:async';
import 'dart:ui';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart'; 
import 'package:mobile/core/services/token_service.dart';
import 'package:mobile/core/tracking_socket_url.dart';

class LocationService {
  // Web State
  static StreamSubscription<Position>? _webPositionStream;
  static WebSocketChannel? _webChannel;
  static bool _webIsConnected = false;
  static StreamSubscription<Position>? _mobilePositionStream;
  static Timer? _mobileReconnectTimer;
  static bool _mobileTrackingStopped = false;
  static int _mobileReconnectAttempt = 0;

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

    _mobileTrackingStopped = false;
    _mobileReconnectTimer?.cancel();
    await _mobilePositionStream?.cancel();
    _mobilePositionStream = null;

    WebSocketChannel? channel;
    bool isConnected = false;
    
    Future<void> connectWebSocket() async {
      if (_mobileTrackingStopped) return;
      final wsUrl = await getTrackingWebSocketUrl();
      print('[LocationService] WebSocket URL: $wsUrl');
      if (wsUrl == null) {
        print('[LocationService] No token found, cannot connect WebSocket');
        return;
      }
      
      try {
        try {
          await channel?.sink.close();
        } catch (_) {}
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
        _mobileReconnectAttempt = 0;
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

    _mobilePositionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
            (Position position) async {
      if (!kIsWeb && service is AndroidServiceInstance) {
        bool isForeground = false;
        try {
          isForeground = await service.isForegroundService(); 
        } catch (e) {
          // Ignore error in background isolate
        }

        if (isForeground) {
          try {
            await flutterLocalNotificationsPlugin.show(
              id: 888,
              title: 'DigiTask Tracking',
              body: 'Tracking is active',
              notificationDetails: const NotificationDetails(
                android: AndroidNotificationDetails(
                  'digitask_location_channel',
                  'Location Service',
                  icon: 'ic_notification',
                  ongoing: true,
                ),
              ),
            );
          } catch (e) {
            print('[LocationService] Foreground notification show failed: $e');
          }
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
      
      try {
        service.invoke(
          'update',
          {"lat": position.latitude, "lng": position.longitude},
        );
      } catch (e) {
        print('[LocationService] Service invoke failed: $e');
      }
    }, onError: (error, stack) {
      print('[LocationService] Position stream error: $error');
      isConnected = false;
    }, cancelOnError: false);
    
    _mobileReconnectTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (_mobileTrackingStopped) {
        timer.cancel();
        return;
      }
      if (!isConnected) {
        final waitSeconds = _nextReconnectDelaySeconds();
        if (waitSeconds > 0) {
          await Future<void>.delayed(Duration(seconds: waitSeconds));
        }
        if (_mobileTrackingStopped) return;
        await TokenService.refreshAccessToken();
        await connectWebSocket();
      }
    });
  }

  static int _nextReconnectDelaySeconds() {
    if (_mobileReconnectAttempt == 0) {
      _mobileReconnectAttempt = 1;
      return 0;
    }
    final backoff = (1 << (_mobileReconnectAttempt - 1)).clamp(1, 8);
    _mobileReconnectAttempt = (_mobileReconnectAttempt + 1).clamp(1, 8);
    return backoff * 5; // 5s .. 40s
  }

  static Future<void> _startWebTracking() async {
    await stop(); // Stop existing triggers
    
    print('[LocationService] Starting web tracking...');

    Future<void> connectWebSocket() async {
        final wsUrl = await getTrackingWebSocketUrl();
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

    _mobileTrackingStopped = true;
    _mobileReconnectTimer?.cancel();
    _mobileReconnectTimer = null;
    await _mobilePositionStream?.cancel();
    _mobilePositionStream = null;

    final service = FlutterBackgroundService();
    if (await service.isRunning()) {
       service.invoke("stopService");
    }
  }
}
