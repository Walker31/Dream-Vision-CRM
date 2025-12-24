import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dreamvision/config/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

class TelecallerService {
  static const String _baseUrl = '$baseUrl/crm';

  final _storage = const FlutterSecureStorage();
  final Logger _logger = Logger();
  late final Dio _dio;

  TelecallerService() {
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
          final token = await _storage.read(key: 'access_token');

          if (token == null) {
            return handler.reject(
              DioException(
                requestOptions: options,
                message: 'Authentication token not found. Please log in.',
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
  // ERROR HANDLING (SERVICE-ONLY)
  // ---------------------------------------------------------------------------

  String _handleDioError(DioException e) {
    _logger.e(
      'API Error [${e.response?.statusCode ?? 'N/A'}]: ${e.message}',
      error: e.error,
      stackTrace: e.stackTrace,
    );

    // Network issues
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Connection timed out. Please check your internet.';
    }

    if (e.error is SocketException || e.type == DioExceptionType.unknown) {
      return 'No internet connection. Please check your network.';
    }

    // Server response
    if (e.response != null) {
      final statusCode = e.response!.statusCode ?? 0;
      final data = e.response!.data;

      if (statusCode >= 500) {
        return 'Server error ($statusCode). Please try again later.';
      }

      if (data is String) {
        if (data.toLowerCase().contains('<!doctype html>') ||
            data.toLowerCase().contains('<html')) {
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
          final val = data[key];
          final formattedKey = key.toString().replaceAll('_', ' ').capitalize();

          if (val is List) {
            return "$formattedKey: ${val.first}";
          }
          return "$formattedKey: $val";
        }
      }
    }

    return 'Something went wrong. Please try again.';
  }

  Never _rethrow(Object e) {
    if (e is DioException) {
      throw Exception(_handleDioError(e));
    }
    throw Exception(e.toString());
  }

  // ---------------------------------------------------------------------------
  // API METHODS
  // ---------------------------------------------------------------------------

  Future<List<dynamic>> getCallActivityData(DateTimeRange dateRange) async {
    final formatter = DateFormat('yyyy-MM-dd');

    final queryParameters = {
      'start_date': formatter.format(dateRange.start),
      'end_date': formatter.format(dateRange.end),
    };

    try {
      final response = await _dio.get(
        '/charts/telecaller-activity/',
        queryParameters: queryParameters,
      );

      if (response.data is List) {
        return response.data;
      }

      _logger.w(
        'Unexpected format: Expected List, got ${response.data.runtimeType}',
      );

      return [];
    } catch (e) {
      _rethrow(e);
    }
  }
}

extension StringExtension on String {
  String capitalize() =>
      isEmpty ? this : "${this[0].toUpperCase()}${substring(1)}";
}
