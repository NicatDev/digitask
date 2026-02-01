import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

class ApiService {
  final Dio _dio = Dio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  ApiService() {
    _dio.options.baseUrl = AppConstants.baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 5);
    _dio.options.receiveTimeout = const Duration(seconds: 3);
    _dio.options.headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: AppConstants.tokenKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        if (e.response?.statusCode == 401) {
           // Check if we are already trying to refresh or if this WAS a refresh attempt
           if (e.requestOptions.path.contains(AppConstants.refreshTokenEndpoint)) {
             // Refresh failed, logout
             await _storage.deleteAll();
             return handler.next(e); 
           }

           final refreshToken = await _storage.read(key: AppConstants.refreshTokenKey);
           if (refreshToken != null) {
             try {
               final refreshResponse = await _dio.post(
                 AppConstants.refreshTokenEndpoint, 
                 data: {'refresh': refreshToken}
               );
               
               final newAccess = refreshResponse.data['access'];
               // If backend rotates refresh tokens, capture that too
               final newRefresh = refreshResponse.data['refresh']; 

               await _storage.write(key: AppConstants.tokenKey, value: newAccess);
               if (newRefresh != null) {
                 await _storage.write(key: AppConstants.refreshTokenKey, value: newRefresh);
               }

               // Retry original request
               final opts = e.requestOptions;
               opts.headers['Authorization'] = 'Bearer $newAccess';
               
               final clonedRequest = await _dio.request(
                 opts.path,
                 options: Options(
                   method: opts.method,
                   headers: opts.headers,
                 ),
                 data: opts.data,
                 queryParameters: opts.queryParameters,
               );
               
               return handler.resolve(clonedRequest);
             } catch (refreshErr) {
               // Refresh failure
               await _storage.deleteAll();
               return handler.next(e);
             }
           }
        }
        return handler.next(e);
      },
    ));
  }

  Dio get dio => _dio;
}
