import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  late Dio dio;
  final storage = const FlutterSecureStorage();

  factory ApiClient() {
    return _instance;
  }

  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.data is FormData) {
            options.headers.remove(Headers.contentTypeHeader);
          }
          final token = await storage.read(key: 'access_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          
          print('API Request: ${options.method} ${options.baseUrl}${options.path}');
          print('API Timeout: ${options.connectTimeout}');
          print('API Headers: ${options.headers}');
          
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401) {
            final refreshToken = await storage.read(key: 'refresh_token');
            if (refreshToken != null) {
              try {
                // Create a new Dio instance to avoid interceptor loops
                // or just use valid options if we can.
                // Safest is a new minimal Dio or just using a different path
                // that doesn't trigger the interceptor logic (but we are in onError).
                // Actually, since we are in QueuedInterceptorsWrapper, other requests are paused.
                
                final response = await Dio(BaseOptions(
                  baseUrl: AppConstants.baseUrl,
                  headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json',
                  },
                )).post('/token/refresh/', data: {'refresh': refreshToken});

                if (response.statusCode == 200) {
                  final newAccessToken = response.data['access'];
                  final newRefreshToken = response.data['refresh']; // if backend rotates it
                  
                  await storage.write(key: 'access_token', value: newAccessToken);
                  // If backend returns a new refresh token, save it too
                  if (newRefreshToken != null) {
                    await storage.write(key: 'refresh_token', value: newRefreshToken);
                  }

                  // Retry the original request
                  final opts = e.requestOptions;
                  opts.headers['Authorization'] = 'Bearer $newAccessToken';
                  
                  // We need to retry the request with the new token
                  final clonedRequest = await dio.fetch(opts);
                  return handler.resolve(clonedRequest);
                }
              } catch (refreshError) {
                // Refresh failed
                await storage.delete(key: 'access_token');
                await storage.delete(key: 'refresh_token');
                return handler.next(e);
              }
            } else {
              // No refresh token
              await storage.delete(key: 'access_token');
              await storage.delete(key: 'refresh_token');
            }
          }
          return handler.next(e);
        },
      ),
    );
  }
}
