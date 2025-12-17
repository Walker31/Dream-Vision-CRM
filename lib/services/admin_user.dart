import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dreamvision/config/constants.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

class AdminUserService {
  static const String _baseUrl = baseUrl;
  final _storage = const FlutterSecureStorage();
  Logger logger = Logger();
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
          String? token = await _storage.read(key: 'access_token');
          if (token == null) {
            logger.e('No auth token found, rejecting request.');
            final error = DioException(
              requestOptions: options,
              message: 'Authentication token not found. Please log in.',
              error: const SocketException(
                'Authentication token not found. Please log in.',
              ),
              type: DioExceptionType.cancel,
            );
            return handler.reject(error);
          }
          options.headers['Authorization'] = 'Bearer $token';
          return handler.next(options);
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UPDATED ERROR HANDLER
  // ---------------------------------------------------------------------------
  String _handleDioError(DioException e) {
    // Log for developer debugging
    logger.e(
      'API Error: ${e.message}',
      error: e.error,
      stackTrace: e.stackTrace,
    );

    // 1. Handle Network/Connection Issues
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Connection timeout. Please check your internet.';
    }
    if (e.error is SocketException || e.type == DioExceptionType.unknown) {
      return 'No internet connection.';
    }

    // 2. Handle Server Responses
    if (e.response != null) {
      final int statusCode = e.response!.statusCode ?? 0;
      final dynamic data = e.response!.data;

      // Server Error (500+): Hide raw code, show generic message
      if (statusCode >= 500) {
        return 'Server error ($statusCode). Please try again later.';
      }

      // Check for HTML (The fix for your IntegrityError screen)
      if (data is String) {
        if (data.toLowerCase().contains('<!doctype html>') ||
            data.toLowerCase().contains('<html')) {
          return 'Server returned an invalid response.';
        }
        return data;
      }

      // Client Error (400-499): Extract specific validation message
      if (data is Map) {
        // Common Django/DRF keys
        if (data['detail'] != null) return data['detail'].toString();
        if (data['message'] != null) return data['message'].toString();
        if (data['error'] != null) return data['error'].toString();

        // Field-specific errors (e.g., { "username": ["Already exists"] })
        if (data.isNotEmpty) {
          final firstKey = data.keys.first;
          final firstValue = data[firstKey];

          // Format the key (e.g., phone_number -> Phone number)
          final formattedKey = firstKey
              .toString()
              .replaceAll('_', ' ')
              .capitalize();

          if (firstValue is List) {
            return "$formattedKey: ${firstValue.first}";
          }
          return "$formattedKey: $firstValue";
        }
      }
    }

    return 'Something went wrong. Please try again.';
  }
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> addUser(Map<String, dynamic> data) async {
    logger.d('Adding User: $data');
    try {
      final response = await _dio.post('/users/admin/add-user/', data: data);
      logger.d('API Response [${response.statusCode}]: ${response.data}');
      return response.data ?? {};
    } catch (e) {
      // Using the new handler implies this will return a clean string inside the Exception
      throw Exception(e is DioException ? _handleDioError(e) : e.toString());
    }
  }

  Future<List<dynamic>> listUsers() async {
    logger.d('Fetching user list from: /users/admin/list-users/');
    try {
      final response = await _dio.get('/users/admin/list-users/');
      logger.d('API Response [${response.statusCode}]: ${response.data}');

      final responseBody = response.data;
      if (responseBody is Map && responseBody.containsKey('results')) {
        return responseBody['results'] as List<dynamic>;
      } else if (responseBody is List) {
        return responseBody;
      } else {
        logger.w('Unexpected format for user list: $responseBody');
        throw Exception('Received unexpected data format for user list.');
      }
    } catch (e) {
      throw Exception(e is DioException ? _handleDioError(e) : e.toString());
    }
  }

  Future<Map<String, dynamic>> deleteUser(int userId) async {
    final url = '/users/admin/delete-user/$userId/';
    logger.i('Attempting to delete user with ID: $userId at URL: $url');

    try {
      final response = await _dio.delete(url);

      if (response.statusCode == 204) {
        logger.d('API Response [204]: No Content (Success)');
        return {'detail': 'Operation successful.'};
      }
      logger.d('API Response [${response.statusCode}]: ${response.data}');
      return response.data ?? {};
    } catch (e) {
      throw Exception(e is DioException ? _handleDioError(e) : e.toString());
    }
  }

  Future<Map<String, dynamic>> resetPassword(int userId) async {
    final url = '/users/admin/$userId/reset-password/';
    logger.i('Attempting to reset password for user ID: $userId at URL: $url');

    try {
      final response = await _dio.post(url);

      logger.d('API Response [${response.statusCode}]: ${response.data}');
      return response.data ?? {};
    } catch (e) {
      throw Exception(e is DioException ? _handleDioError(e) : e.toString());
    }
  }

  Future<Map<String, dynamic>> updateUser(
    int userId,
    Map<String, dynamic> data,
  ) async {
    final url = '/users/admin/edit-user/$userId/';
    logger.i('Updating user $userId with data: $data');

    try {
      final response = await _dio.put(url, data: data);

      logger.d('API Response [${response.statusCode}]: ${response.data}');
      return response.data ?? {};
    } catch (e) {
      throw Exception(e is DioException ? _handleDioError(e) : e.toString());
    }
  }
}
