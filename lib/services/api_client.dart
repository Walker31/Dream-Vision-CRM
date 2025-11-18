import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dreamvision/config/constants.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
import 'auth_service.dart'; // Ensure this imports your AuthService

class ApiClient {
  static const String _baseUrl = baseUrl;
  final Dio _dio;
  final AuthService _authService = AuthService();
  final _storage = const FlutterSecureStorage();
  final Logger logger = Logger();

  // Singleton pattern (optional, but good for network clients)
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  ApiClient._internal() : _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    headers: {'Content-Type': 'application/json'},
    // Set timeouts
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  )) {
    _setupInterceptors();
  }

  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        // 1. Request Interceptor: Add Token
        onRequest: (options, handler) async {
          final token = await _storage.read(key: 'access_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },

        // 2. Error Interceptor: Handle 401 & Refresh Token
        onError: (DioException error, handler) async {
          if (error.response?.statusCode == 401) {
            logger.w("401 Detected. Attempting Token Refresh...");
            
            try {
              // Attempt to refresh
              final newToken = await _authService.refreshToken();
              
              if (newToken != null) {
                // Update header and retry original request
                final opts = error.requestOptions;
                opts.headers['Authorization'] = 'Bearer $newToken';
                
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
              }
            } catch (e) {
              logger.e("Token refresh failed: $e");
              // Optional: Trigger logout logic here if refresh fails completely
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ROBUST ERROR HANDLER (Fixes the HTML/IntegrityError Issue)
  // ---------------------------------------------------------------------------
  String _handleError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Connection timeout. Please check your network.';
    }
    if (e.error is SocketException || e.type == DioExceptionType.unknown) {
      return 'No internet connection.';
    }

    if (e.response != null) {
      final int statusCode = e.response!.statusCode ?? 0;
      final dynamic data = e.response!.data;

      // 1. Hide HTML Server Errors (The Fix)
      if (statusCode >= 500) {
        return 'Server error ($statusCode). Please try again later.';
      }
      if (data is String && (data.contains('<html') || data.contains('<!DOCTYPE'))) {
        return 'Server returned an invalid response.';
      }

      // 2. Parse Field Validation Errors
      if (data is Map) {
        if (data['detail'] != null) return data['detail'].toString();
        if (data['message'] != null) return data['message'].toString();
        
        // Extract first validation error (e.g. username: [taken])
        if (data.isNotEmpty) {
          final firstKey = data.keys.first;
          final firstValue = data[firstKey];
          
          // Capitalize key for UI
          final readableKey = firstKey.toString().replaceAll('_', ' ');
          final capKey = readableKey.isEmpty ? "" : "${readableKey[0].toUpperCase()}${readableKey.substring(1)}";

          if (firstValue is List) {
            return "$capKey: ${firstValue.first}";
          }
          return "$capKey: $firstValue";
        }
      }
    }
    return 'Something went wrong. Please try again.';
  }
  // ---------------------------------------------------------------------------

  // GET Wrapper
  Future<dynamic> get(String endpoint, {Map<String, dynamic>? queryParams}) async {
    try {
      final response = await _dio.get(endpoint, queryParameters: queryParams);
      return response.data;
    } catch (e) {
      throw Exception(e is DioException ? _handleError(e) : e.toString());
    }
  }

  // POST Wrapper
  Future<dynamic> post(String endpoint, dynamic body) async {
    try {
      final response = await _dio.post(endpoint, data: body);
      return response.data;
    } catch (e) {
      throw Exception(e is DioException ? _handleError(e) : e.toString());
    }
  }

  // PATCH Wrapper
  Future<dynamic> patch(String endpoint, dynamic body) async {
    try {
      final response = await _dio.patch(endpoint, data: body);
      return response.data;
    } catch (e) {
      throw Exception(e is DioException ? _handleError(e) : e.toString());
    }
  }

  // DELETE Wrapper
  Future<dynamic> delete(String endpoint) async {
    try {
      final response = await _dio.delete(endpoint);
      return response.data;
    } catch (e) {
      throw Exception(e is DioException ? _handleError(e) : e.toString());
    }
  }
}