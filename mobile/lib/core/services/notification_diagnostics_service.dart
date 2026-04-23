import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile/core/api/api_client.dart';

class NotificationDiagnosticsService {
  NotificationDiagnosticsService._();
  static final NotificationDiagnosticsService instance =
      NotificationDiagnosticsService._();

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  DateTime? _lastSentAt;
  String? _lastFingerprint;

  Future<void> report({
    required String source,
    required String message,
    String? code,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) async {
    final fingerprint = '$source|$message|$code';
    final now = DateTime.now();
    if (_lastFingerprint == fingerprint &&
        _lastSentAt != null &&
        now.difference(_lastSentAt!) < const Duration(seconds: 10)) {
      return;
    }
    _lastFingerprint = fingerprint;
    _lastSentAt = now;

    try {
      final device = await _buildDeviceContext();
      final payload = <String, dynamic>{
        'platform': defaultTargetPlatform.name,
        'source': source,
        'message': message,
        if (code != null && code.isNotEmpty) 'code': code,
        if (error != null) 'error': error.toString(),
        if (stackTrace != null) 'stack': stackTrace.toString(),
        'device': device,
        'created_at': now.toIso8601String(),
        ...?extra,
      };

      FirebaseCrashlytics.instance.log(
        '[notification][$source] $message'
            '${code != null ? ' (code=$code)' : ''}',
      );
      FirebaseCrashlytics.instance.setCustomKey(
        'notif_platform',
        defaultTargetPlatform.name,
      );
      FirebaseCrashlytics.instance.setCustomKey(
        'notif_source',
        source,
      );
      if (code != null && code.isNotEmpty) {
        FirebaseCrashlytics.instance.setCustomKey('notif_code', code);
      }
      final deviceShort =
          '${device['brand'] ?? device['name'] ?? ''} ${device['model'] ?? ''}'
              .trim();
      if (deviceShort.isNotEmpty) {
        FirebaseCrashlytics.instance.setCustomKey('notif_device', deviceShort);
      }
      await FirebaseCrashlytics.instance.recordError(
        error ?? Exception(message),
        stackTrace,
        reason: 'Notification diagnostics: $source',
        fatal: false,
        information: <String>[
          'message=$message',
          if (code != null) 'code=$code',
          'platform=${defaultTargetPlatform.name}',
          'device=${device.toString()}',
          if (extra != null) 'extra=${extra.toString()}',
        ],
      );

      await ApiClient().dio.post(
        '/audit/logs/notification-errors/',
        data: payload,
      );
    } on DioException catch (_) {
      // Best effort only: diagnostics should never break app flows.
    } catch (_) {
      // Best effort only: diagnostics should never break app flows.
    }
  }

  Future<Map<String, dynamic>> _buildDeviceContext() async {
    final base = <String, dynamic>{
      'is_physical_device': null,
    };

    if (kIsWeb) {
      return <String, dynamic>{
        ...base,
        'family': 'web',
      };
    }

    if (Platform.isAndroid) {
      final info = await _deviceInfo.androidInfo;
      return <String, dynamic>{
        ...base,
        'family': 'android',
        'brand': info.brand,
        'model': info.model,
        'manufacturer': info.manufacturer,
        'android_version': info.version.release,
        'sdk_int': info.version.sdkInt,
        'is_physical_device': info.isPhysicalDevice,
      };
    }

    if (Platform.isIOS) {
      final info = await _deviceInfo.iosInfo;
      return <String, dynamic>{
        ...base,
        'family': 'ios',
        'name': info.name,
        'model': info.model,
        'system_name': info.systemName,
        'system_version': info.systemVersion,
        'identifier_for_vendor': info.identifierForVendor,
        'is_physical_device': info.isPhysicalDevice,
      };
    }

    return <String, dynamic>{
      ...base,
      'family': defaultTargetPlatform.name,
    };
  }
}
