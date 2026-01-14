import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dreamvision/config/constants.dart';
import 'package:dreamvision/utils/global_error_handler.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

class AuthService {
  static const String _baseUrl = baseUrl;
  final _storage = const FlutterSecureStorage();
  final Logger logger = Logger();
  late Dio _dio;

  AuthService() {
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

          // 🚫 Do NOT attach token to auth endpoints
          if (!options.path.contains('/users/login') &&
              !options.path.contains('/users/register') &&
              !options.path.contains('/users/token/refresh')) {
            final token = await getAccessToken();
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }

          handler.next(options);
        },

        onError: (DioException e, handler) async {
          final path = e.requestOptions.path;
          logger.e('❌ ${e.response?.statusCode} → $path');

          // 🚫 NEVER refresh during login/register
          if (path.contains('/users/login') ||
              path.contains('/users/register')) {
            return handler.next(e);
          }

          if (e.response?.statusCode == 401) {
            // 🚫 Refresh endpoint itself failed → hard logout
            if (path.contains('/users/token/refresh')) {
              await clearTokens();
              return handler.next(e);
            }

            final newToken = await refreshToken();
            if (newToken != null) {
              final opts = e.requestOptions;
              opts.headers['Authorization'] = 'Bearer $newToken';
              return handler.resolve(await _dio.fetch(opts));
            }

            // Refresh failed → logout
            await clearTokens();
          }

          handler.next(e);
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TOKEN STORAGE
  // ---------------------------------------------------------------------------

  Future<void> _storeTokens(Map<String, dynamic> tokens) async {
    await _storage.write(key: 'access_token', value: tokens['access']);
    await _storage.write(key: 'refresh_token', value: tokens['refresh']);
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: 'access_token');
  }

  Future<void> clearTokens() async {
    logger.w('🔒 Clearing tokens');
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
  }

  // ---------------------------------------------------------------------------
  // LOGIN
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await _dio.post(
        '/users/login/',
        data: {'username': username, 'password': password},
      );

      await _storeTokens(response.data);
      return response.data;
    } catch (e) {
      final msg = e is DioException
          ? _handleDioError(e, 'Login failed.')
          : e.toString();
      GlobalErrorHandler.error(msg);
      return {};
    }
  }

  // ---------------------------------------------------------------------------
  // PROFILE
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final response = await _dio.get('/users/profile/');
      return response.data;
    } catch (e) {
      final msg = e is DioException
          ? _handleDioError(e, 'Failed to load profile.')
          : e.toString();
      GlobalErrorHandler.error(msg);
      return {};
    }
  }

  // ---------------------------------------------------------------------------
  // REFRESH TOKEN (SAFE)
  // ---------------------------------------------------------------------------

  Future<String?> refreshToken() async {
    final refreshToken = await _storage.read(key: 'refresh_token');

    if (refreshToken == null) {
      return null;
    }

    try {
      final dio = Dio(BaseOptions(baseUrl: _baseUrl));
      final response = await dio.post(
        '/users/token/refresh/',
        data: {'refresh': refreshToken},
      );

      final newAccess = response.data['access'];
      await _storage.write(key: 'access_token', value: newAccess);
      return newAccess;
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // ERROR HANDLER
  // ---------------------------------------------------------------------------

  String _handleDioError(
    DioException e,
    String fallback,
  ) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Network timeout.';
    }

    if (e.error is SocketException) {
      return 'No internet connection.';
    }

    if (e.response?.data is Map &&
        e.response!.data['detail'] != null) {
      return e.response!.data['detail'];
    }

    return fallback;
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
