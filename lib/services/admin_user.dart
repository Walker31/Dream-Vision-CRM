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
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      headers: {
        'Content-Type': 'application/json; charset=UTF-Standard8',
      },
    ));

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
                  'Authentication token not found. Please log in.'),
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

  String _handleDioError(DioException e) {
    logger.e(
      'API Error [${e.response?.statusCode ?? 'N/A'}]: ${e.message}',
      error: e.error,
    );

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Connection timed out. Please check your network.';
    }

    if (e.error is SocketException || e.type == DioExceptionType.cancel) {
      return 'Authentication token not found. Please log in.';
    }
    
    if (e.type == DioExceptionType.unknown) {
      return 'Connection error. Please check your network.';
    }

    final responseBody = e.response?.data;

    if (responseBody == null || responseBody == "") {
      return 'API Error [${e.response?.statusCode}]: Received empty response from server.';
    }

    try {
      if (responseBody is Map) {
        String errorMessage = 'An unknown error occurred.';
        if (responseBody['detail'] != null) {
          errorMessage = responseBody['detail'].toString();
        } else if (responseBody['error'] != null) {
          errorMessage = responseBody['error'].toString();
        } else if (responseBody.containsKey('details') &&
            responseBody['details'] is List) {
          final details = (responseBody['details'] as List).join('\n');
          errorMessage = 'Validation failed.\n$details';
        } else if (e.response?.statusCode == 400 &&
            responseBody.entries.isNotEmpty) {
          errorMessage = responseBody.entries.map((e) {
            String keyFormatted = e.key.replaceAll('_', ' ');
            String capitalizedKey = keyFormatted.capitalize();
            String valueFormatted =
                e.value is List ? e.value.join(', ') : e.value.toString();
            return '$capitalizedKey: $valueFormatted';
          }).join('\n');
        } else {
          errorMessage = responseBody.entries
              .map((e) =>
                  '${e.key}: ${e.value is List ? e.value.join(', ') : e.value}')
              .join('\n');
        }
        return errorMessage;
      } else if (responseBody is String) {
        return responseBody;
      }
      return 'API Error [${e.response?.statusCode}]: $responseBody';
    } catch (parseError) {
      logger.e('Error parsing error response body: $parseError');
      return 'Failed to process server response. Invalid format.';
    }
  }

  Future<Map<String, dynamic>> addUser(Map<String, dynamic> data) async {
    logger.d('Adding User: $data');
    try {
      final response = await _dio.post('/users/admin/add-user/', data: data);
      logger.d('API Response [${response.statusCode}]: ${response.data}');
      return response.data ?? {};
    } catch (e) {
      logger.e('Error adding user', error: e);
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
      logger.e('Error listing users', error: e);
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
      logger.e('Error deleting user $userId', error: e);
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
      logger.e('Error resetting password for user $userId', error: e);
      throw Exception(e is DioException ? _handleDioError(e) : e.toString());
    }
  }
}