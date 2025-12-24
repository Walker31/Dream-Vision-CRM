import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dreamvision/config/constants.dart';
import 'package:dreamvision/utils/global_error_handler.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

extension StringExtension on String {
  String capitalize() =>
      isEmpty ? this : "${this[0].toUpperCase()}${substring(1)}";
}

class AdminUserService {
  static const String _baseUrl = baseUrl;

  final _storage = const FlutterSecureStorage();
  final Logger logger = Logger();
  late final Dio _dio;

  AdminUserService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: 'access_token');

          if (token == null) {
            const msg = 'Authentication token not found. Please log in.';
            logger.e(msg);
            GlobalErrorHandler.error(msg);

            return handler.reject(
              DioException(
                requestOptions: options,
                message: msg,
                type: DioExceptionType.cancel,
              ),
            );
          }

          options.headers['Authorization'] = 'Bearer $token';
          return handler.next(options);
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ERROR HANDLER (UI-DRIVEN)
  // ---------------------------------------------------------------------------

  String _handleDioError(DioException e) {
    logger.e(
      'API Error: ${e.message}',
      error: e.error,
      stackTrace: e.stackTrace,
    );

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Connection timeout. Please check your internet.';
    }

    if (e.error is SocketException || e.type == DioExceptionType.unknown) {
      return 'No internet connection.';
    }

    if (e.response != null) {
      final statusCode = e.response!.statusCode ?? 0;
      final data = e.response!.data;

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

        if (data.isNotEmpty) {
          final key = data.keys.first;
          final value = data[key];
          final formattedKey = key.toString().replaceAll('_', ' ').capitalize();

          if (value is List) {
            return "$formattedKey: ${value.first}";
          }
          return "$formattedKey: $value";
        }
      }
    }

    return 'Something went wrong. Please try again.';
  }

  // ---------------------------------------------------------------------------
  // API METHODS (NO THROWS)
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> addUser(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/users/admin/add-user/', data: data);
      return response.data ?? {};
    } catch (e) {
      final msg = e is DioException ? _handleDioError(e) : e.toString();
      GlobalErrorHandler.error(msg);
      return {};
    }
  }

  Future<List<dynamic>> listUsers() async {
    try {
      final response = await _dio.get('/users/admin/list-users/');
      final body = response.data;

      if (body is Map && body.containsKey('results')) {
        return body['results'] as List<dynamic>;
      }
      if (body is List) return body;

      GlobalErrorHandler.error('Unexpected response format.');
      return [];
    } catch (e) {
      final msg = e is DioException ? _handleDioError(e) : e.toString();
      GlobalErrorHandler.error(msg);
      return [];
    }
  }

  Future<Map<String, dynamic>> deleteUser(int userId) async {
    try {
      final response = await _dio.delete('/users/admin/delete-user/$userId/');
      return response.data ?? {'message': 'User deleted successfully.'};
    } catch (e) {
      final msg = e is DioException ? _handleDioError(e) : e.toString();
      GlobalErrorHandler.error(msg);
      return {};
    }
  }

  Future<Map<String, dynamic>> resetPassword(int userId) async {
    try {
      final response = await _dio.post('/users/admin/$userId/reset-password/');
      return response.data ?? {};
    } catch (e) {
      final msg = e is DioException ? _handleDioError(e) : e.toString();
      GlobalErrorHandler.error(msg);
      return {};
    }
  }

  Future<Map<String, dynamic>> updateUser(
    int userId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.patch(
        '/users/admin/edit-user/$userId/',
        data: data,
      );
      return response.data ?? {};
    } catch (e) {
      final msg = e is DioException ? _handleDioError(e) : e.toString();
      GlobalErrorHandler.error(msg);
      return {};
    }
  }
}
