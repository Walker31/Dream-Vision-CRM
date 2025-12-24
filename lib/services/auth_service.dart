import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dreamvision/config/constants.dart';
import 'package:dreamvision/utils/global_error_handler.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

class AuthService {
  static const String _baseUrl = baseUrl;
  final _storage = const FlutterSecureStorage();
  Logger logger = Logger();
  late Dio _dio;

  AuthService() {
    logger.i('Initializing AuthService');
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        headers: {'Content-Type': 'application/json'},
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          logger.i('Outgoing Request → ${options.method} ${options.uri}');
          if (!options.path.contains('/login') &&
              !options.path.contains('/register') &&
              !options.path.contains('/token/refresh')) {
            String? token = await getAccessToken();
            if (token != null) {
              logger.i('Adding Authorization header');
              options.headers['Authorization'] = 'Bearer $token';
            } else {
              logger.w('No access token found');
            }
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          logger.e('Request Error → ${e.requestOptions.path}');
          if (e.response?.statusCode == 401) {
            if (e.requestOptions.path.contains('/token/refresh')) {
              logger.e('Refresh token invalid. Logging out.');
              await logout();
              return handler.next(e);
            }

            logger.w('Access token expired. Requesting refresh...');
            try {
              final newAccessToken = await refreshToken();
              if (newAccessToken != null) {
                logger.i('Retrying failed request with refreshed token');
                final opts = e.requestOptions;
                opts.headers['Authorization'] = 'Bearer $newAccessToken';
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

  String _handleDioError(
    DioException e, [
    String defaultError = 'An unknown error occurred.',
  ]) {
    logger.e('Handling Dio Error → ${e.message}');
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Connection timed out. Please check your network.';
    }
    if (e.error is SocketException || e.type == DioExceptionType.unknown) {
      return 'No internet connection. Please check your network.';
    }

    if (e.response != null) {
      final int statusCode = e.response!.statusCode ?? 0;
      final data = e.response!.data;
      logger.e('Server Response Error ($statusCode) → $data');

      if (statusCode >= 500) {
        return 'Server error ($statusCode). Please try again later.';
      }

      if (data is String) {
        if (data.toLowerCase().contains('<html')) {
          return 'Server returned an invalid response.';
        }
        return data;
      }

      if (data is Map) {
        if (data['detail'] != null) return data['detail'].toString();
        if (data['message'] != null) return data['message'].toString();
        if (data['error'] != null) return data['error'].toString();
        if (data['non_field_errors'] != null) {
          return (data['non_field_errors'] as List).join('\n');
        }

        if (data.isNotEmpty) {
          final key = data.keys.first;
          final value = data[key];
          final formattedKey = key.toString().replaceAll('_', ' ').capitalize();
          if (value is List) return "$formattedKey: ${value.first}";
          return "$formattedKey: $value";
        }
      }
    }

    return defaultError;
  }

  

  Future<void> _storeTokens(Map<String, dynamic> tokens) async {
    logger.i('Storing tokens');
    await _storage.write(key: 'access_token', value: tokens['access']);
    await _storage.write(key: 'refresh_token', value: tokens['refresh']);
  }

  Future<String?> getAccessToken() async {
    logger.i('Fetching access token from storage');
    return await _storage.read(key: 'access_token');
  }

  Future<void> logout() async {
    logger.w('Logging out user. Clearing tokens.');
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    logger.i('Attempting login for user: $username');
    try {
      final response = await _dio.post(
        '/users/login/',
        data: {'username': username, 'password': password},
      );

      if (response.data is! Map<String, dynamic>) {
        final msg = "Invalid server response format.";
        logger.e(msg);
        GlobalErrorHandler.error(msg);
      }

      final responseBody = response.data;
      logger.i('Login successful: $responseBody');

      await _storeTokens(responseBody);
      return responseBody;
    } catch (e) {
      final errorMessage = (e is DioException)
          ? _handleDioError(e, 'Failed to login.')
          : e.toString();
      logger.e('Login error → $errorMessage');
      GlobalErrorHandler.error(errorMessage);
      return {};
    }
  }

  Future<Map<String, dynamic>> getUserProfile() async {
    logger.i('Fetching user profile');
    try {
      final response = await _dio.get('/users/profile/');
      logger.i('Profile loaded → ${response.data}');
      return response.data;
    } catch (e) {
      final msg = (e is DioException)
          ? _handleDioError(e, 'Failed to load user profile.')
          : e.toString();
      logger.e('Profile fetch error → $msg');
      GlobalErrorHandler.error(msg);
      return {};
    }
  }

  Future<String?> refreshToken() async {
    final refreshToken = await _storage.read(key: 'refresh_token');
    logger.i('Attempting token refresh');

    if (refreshToken == null) {
      logger.w('No refresh token found');
      await logout();
      GlobalErrorHandler.info('Session expired. Please login again.');
    }

    try {
      final refreshDio = Dio(
        BaseOptions(
          baseUrl: _baseUrl,
          headers: {'Content-Type': 'application/json'},
        ),
      );

      final response = await refreshDio.post(
        '/users/token/refresh/',
        data: {'refresh': refreshToken},
      );

      if (response.statusCode == 200) {
        logger.i('Token refreshed successfully');
        final newTokens = response.data;
        await _storage.write(key: 'access_token', value: newTokens['access']);
        return newTokens['access'];
      } else {
        logger.e('Refresh token invalid');
        await logout();
        GlobalErrorHandler.info('Session expired. Please login again.');
      }
    } catch (e) {
      logger.e('Refresh token error → $e');
      await logout();
      GlobalErrorHandler.error('Session expired. Please login again.');
      return null;
    }
    return null;
  }

  Future<void> signUp({
    required String username,
    required String password,
    required String email,
    required String firstName,
    required String lastName,
    required String role,
  }) async {
    logger.i('Signing up user: $username');
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
      logger.i('Signup successful');
    } catch (e) {
      final msg = (e is DioException)
          ? _handleDioError(e, 'Failed to sign up.')
          : e.toString();
      logger.e('Signup error → $msg');
      GlobalErrorHandler.error(msg);
    }
  }

  Future<void> changePassword(
    String oldPassword,
    String newPassword1,
    String newPassword2,
  ) async {
    logger.i('Changing password');
    try {
      await _dio.put(
        '/users/profile/change-password/',
        data: {
          'old_password': oldPassword,
          'new_password1': newPassword1,
          'new_password2': newPassword2,
        },
      );
      logger.i('Password changed successfully');
    } catch (e) {
      final msg = (e is DioException)
          ? _handleDioError(e, 'Failed to change password.')
          : e.toString();
      logger.e('Password change error → $msg');
      GlobalErrorHandler.error(msg);
      
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
