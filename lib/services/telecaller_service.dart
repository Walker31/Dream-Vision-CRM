import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dreamvision/config/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

class TelecallerService {
  static const String _baseUrl = '$baseUrl/crm'; // (unchanged)

  final _storage = const FlutterSecureStorage();
  final Logger _logger = Logger();
  late final Dio _dio;

  TelecallerService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: 'access_token');

          if (token == null) {
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

  Future<List<dynamic>> getCallActivityData(DateTimeRange dateRange) async {
    final formatter = DateFormat('yyyy-MM-dd');

    final queryParameters = {
      'start_date': formatter.format(dateRange.start),
      'end_date': formatter.format(dateRange.end),
    };

    try {
      final response = await _dio.get(
        '/charts/telecaller-activity/', // (unchanged)
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
      _logger.e('Error fetching telecaller chart data', error: e);
      throw Exception(
        e is DioException ? _handleDioError(e) : e.toString(),
      );
    }
  }

  String _handleDioError(DioException e) {
    _logger.e(
      'API Error [${e.response?.statusCode ?? 'N/A'}]: ${e.message}',
      error: e.error,
    );

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Connection timed out. Please check your internet.';
    }

    if (e.type == DioExceptionType.cancel ||
        e.error is SocketException) {
      return 'Authentication token not found. Please log in.';
    }

    if (e.type == DioExceptionType.unknown) {
      return 'Network error. Check your connection.';
    }

    final body = e.response?.data;

    if (body == null || body == "") {
      return 'API Error [${e.response?.statusCode}]: Empty response.';
    }

    try {
      if (body is Map) {
        if (body['error'] != null) return body['error'];
        if (body['detail'] != null) return body['detail'];

        if (body.values.isNotEmpty && body.values.first is List) {
          return body.entries.map((entry) {
            final key = entry.key.replaceAll('_', ' ').capitalize();
            final value = entry.value.join(', ');
            return "$key: $value";
          }).join('\n');
        }
      }

      if (body is String) return body;

      return 'API Error: $body';
    } catch (_) {
      return 'Failed to parse server error.';
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
