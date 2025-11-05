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

      final responseBody = response.data;

      if (response.statusCode == 200) {
        logger.d(responseBody);
        await _storeTokens(responseBody);
        return responseBody;
      } else {
        logger.e(responseBody['detail']);
        throw Exception(responseBody['detail'] ?? 'Failed to login.');
      }
    } catch (e) {
      String errorMessage = (e is DioException)
          ? _handleDioError(e, 'Failed to login.')
          : 'An unknown error occurred.';
      logger.e(errorMessage);
      throw Exception(errorMessage);
    }
  }

  Future<Map<String, dynamic>> getUserProfile() async {
    String? token = await getAccessToken();
    if (token == null) {
      throw Exception('Not authenticated. Please login.');
    }

    try {
      final response = await _dio.get('/users/profile/');
      
      return response.data;
    } catch (e) {
      String errorMessage = (e is DioException)
          ? _handleDioError(e, 'Failed to load user profile.')
          : 'An unknown error occurred.';
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
      final response = await _dio.post(
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
      String errorMessage = (e is DioException)
          ? _handleDioError(e, 'Session expired. Please login again.')
          : 'Session expired. Please login again.';
      logger.e(errorMessage);
      throw Exception(errorMessage);
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
          : 'An unknown error occurred.';
      logger.e(errorMessage);
      throw Exception(errorMessage);
    }
  }

  String _formatErrors(Map<String, dynamic> errors) {
    var buffer = StringBuffer();
    errors.forEach((key, value) {
      if (value is List) {
        buffer.writeln(
            '${key.replaceAll('_', ' ').capitalize()}: ${value.join(', ')}');
      }
    });
    return buffer.toString().trim().isEmpty
        ? 'An unknown error occurred.'
        : buffer.toString();
  }

  String _handleDioError(DioException e, [String defaultError = 'An unknown error occurred.']) {
    if (e.response?.data is Map) {
      final data = e.response!.data as Map<String, dynamic>;
      
      if (data.values.isNotEmpty && data.values.first is List) {
        return _formatErrors(data);
      }
      
      return data['detail'] ?? defaultError;
    }
    if (e.type == DioExceptionType.connectionTimeout || 
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Connection timed out. Please check your network.';
    }
    if (e.type == DioExceptionType.unknown) {
      return 'Connection error. Please check your network.';
    }
    return e.message ?? defaultError;
  }

  Future<void> changePassword(
      String oldPassword, String newPassword1, String newPassword2) async {
    final token = await getAccessToken();
    if (token == null) {
      throw Exception('Not authenticated. Please log in again.');
    }

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
          : 'An unknown error occurred.';
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