import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dreamvision/config/constants.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

class AuthService {
  static const String _baseUrl = baseUrl;
  final _storage = const FlutterSecureStorage();
  Logger logger = Logger();
  late Dio _dio;

  AuthService() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      headers: {
        'Content-Type': 'application/json',
      },
      // Add timeouts to prevent infinite hanging
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (!options.path.contains('/login') &&
              !options.path.contains('/register') &&
              !options.path.contains('/token/refresh')) {
            String? token = await getAccessToken();
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401) {
            // If the failed request was ALREADY a refresh attempt, fail immediately
            if (e.requestOptions.path.contains('/token/refresh')) {
              logger.e('Refresh token failed, logging out.');
              await logout();
              return handler.next(e);
            }

            logger.i('Access token expired. Refreshing token...');
            try {
              final newAccessToken = await refreshToken();

              if (newAccessToken != null) {
                logger.i('Retrying request with new token...');
                final opts = e.requestOptions;
                opts.headers['Authorization'] = 'Bearer $newAccessToken';

                // Retry the request
                final response = await _dio.fetch(opts);
                return handler.resolve(response);
              }
            } catch (refreshError) {
              logger.e('Token refresh failed: $refreshError');
              await logout();
              return handler.next(e);
            }
          }
          return handler.next(e);
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ROBUST ERROR HANDLER
  // ---------------------------------------------------------------------------
  String _handleDioError(DioException e, [String defaultError = 'An unknown error occurred.']) {
    // 1. Network/Connection Errors
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Connection timed out. Please check your network.';
    }
    if (e.error is SocketException || e.type == DioExceptionType.unknown) {
      return 'No internet connection. Please check your network.';
    }

    // 2. Server Response Errors
    if (e.response != null) {
      final int statusCode = e.response!.statusCode ?? 0;
      final dynamic data = e.response!.data;

      // A. Server Error (500+): Hide details, show generic message
      if (statusCode >= 500) {
        return 'Server error ($statusCode). Please try again later.';
      }

      // B. HTML Response Check (Fixes the IntegrityError HTML screen)
      if (data is String) {
        if (data.toLowerCase().contains('<!doctype html>') ||
            data.toLowerCase().contains('<html')) {
          return 'Server returned an invalid response.';
        }
        return data; // Return plain string if it's not HTML
      }

      // C. Client Error (400-499): Extract validation messages
      if (data is Map) {
        // Common Django/DRF keys
        if (data['detail'] != null) return data['detail'].toString();
        if (data['message'] != null) return data['message'].toString();
        if (data['error'] != null) return data['error'].toString();
        if (data['non_field_errors'] != null) {
           return (data['non_field_errors'] as List).join('\n');
        }

        // Field-specific errors (e.g., { "username": ["Already exists"] })
        if (data.isNotEmpty) {
          final firstKey = data.keys.first;
          final firstValue = data[firstKey];
          
          // Format the key (e.g., phone_number -> Phone number)
          final formattedKey = firstKey.toString().replaceAll('_', ' ').capitalize();

          if (firstValue is List) {
            return "$formattedKey: ${firstValue.first}";
          }
          return "$formattedKey: $firstValue";
        }
      }
    }

    return defaultError;
  }
  // ---------------------------------------------------------------------------

  Future<void> _storeTokens(Map<String, dynamic> tokens) async {
    await _storage.write(key: 'access_token', value: tokens['access']);
    await _storage.write(key: 'refresh_token', value: tokens['refresh']);
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: 'access_token');
  }

  Future<void> logout() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await _dio.post(
        '/users/login/',
        data: {
          'username': username,
          'password': password,
        },
      );

      // Safety check: Ensure data is actually a Map
      if (response.data is! Map<String, dynamic>) {
         throw Exception("Invalid server response format.");
      }

      final responseBody = response.data as Map<String, dynamic>;

      if (response.statusCode == 200) {
        logger.d(responseBody);
        await _storeTokens(responseBody);
        return responseBody;
      } else {
        throw Exception('Failed to login.');
      }
    } catch (e) {
      String errorMessage = (e is DioException)
          ? _handleDioError(e, 'Failed to login.')
          : e.toString();
      logger.e(errorMessage);
      throw Exception(errorMessage);
    }
  }
  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      // Token is added by Interceptor
      final response = await _dio.get('/users/profile/');
      return response.data;
    } catch (e) {
      String errorMessage = (e is DioException)
          ? _handleDioError(e, 'Failed to load user profile.')
          : e.toString();
      logger.e(errorMessage);
      throw Exception(errorMessage);
    }
  }

  Future<String?> refreshToken() async {
    final refreshToken = await _storage.read(key: 'refresh_token');
    if (refreshToken == null) {
      await logout();
      throw Exception('User not authenticated.');
    }

    try {
      // We create a new dio instance here to avoid infinite loops 
      // or interceptor conflicts during refresh
      final refreshDio = Dio(BaseOptions(
        baseUrl: _baseUrl,
        headers: {'Content-Type': 'application/json'},
      ));

      final response = await refreshDio.post(
        '/users/token/refresh/',
        data: {'refresh': refreshToken},
      );

      if (response.statusCode == 200) {
        final newTokens = response.data;
        await _storage.write(key: 'access_token', value: newTokens['access']);
        return newTokens['access'];
      } else {
        await logout();
        throw Exception('Session expired. Please login again.');
      }
    } catch (e) {
      await logout();
      // We generally don't show UI for refresh failure, just log out
      logger.e('Refresh failed: $e');
      return null;
    }
  }

  Future<void> signUp({
    required String username,
    required String password,
    required String email,
    required String firstName,
    required String lastName,
    required String role,
  }) async {
    try {
      await _dio.post(
        '/users/register/',
        data: {
          'username': username,
          'password': password,
          'password2': password,
          'email': email,
          'first_name': firstName,
          'last_name': lastName,
          'role': role,
        },
      );
    } catch (e) {
      String errorMessage = (e is DioException)
          ? _handleDioError(e, 'Failed to sign up.')
          : e.toString();
      logger.e(errorMessage);
      throw Exception(errorMessage);
    }
  }

  Future<void> changePassword(
      String oldPassword, String newPassword1, String newPassword2) async {
    try {
      await _dio.put(
        '/users/profile/change-password/',
        data: {
          'old_password': oldPassword,
          'new_password1': newPassword1,
          'new_password2': newPassword2,
        },
      );
    } catch (e) {
      String errorMessage = (e is DioException)
          ? _handleDioError(e, 'Failed to change password.')
          : e.toString();
      logger.e(errorMessage);
      throw Exception(errorMessage);
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}