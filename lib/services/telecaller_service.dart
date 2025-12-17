import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dreamvision/config/constants.dart';
import 'package:dreamvision/utils/global_error_handler.dart';
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
  // UPDATED GLOBAL ERROR HANDLER (MATCHING AuthService & EnquiryService)
  // ---------------------------------------------------------------------------
  String _handleDioError(DioException e) {
    _logger.e(
      'API Error [${e.response?.statusCode ?? 'N/A'}]: ${e.message}',
      error: e.error,
      stackTrace: e.stackTrace,
    );

    // 🔥 1. Network issues
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Connection timed out. Please check your internet.';
    }
    if (e.error is SocketException || e.type == DioExceptionType.unknown) {
      return 'No internet connection. Please check your network.';
    }

    // 🔥 2. Server response issues
    if (e.response != null) {
      final int statusCode = e.response!.statusCode ?? 0;
      final dynamic data = e.response!.data;

      // 500 errors → generic message
      if (statusCode >= 500) {
        return 'Server error ($statusCode). Please try again later.';
      }

      // HTML response check
      if (data is String) {
        if (data.toLowerCase().contains('<!doctype html>') ||
            data.toLowerCase().contains('<html')) {
          return 'Server returned an invalid response.';
        }
        return data;
      }

      // Django/DRF JSON validation messages
      if (data is Map) {
        if (data['detail'] != null) return data['detail'].toString();
        if (data['message'] != null) return data['message'].toString();
        if (data['error'] != null) return data['error'].toString();
        if (data['non_field_errors'] != null) {
          return (data['non_field_errors'] as List).join('\n');
        }

        // Field errors
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
      /// 🔥 SHOW GLOBAL SNACKBAR
      final msg = e is DioException ? _handleDioError(e) : e.toString();
      GlobalErrorHandler.showError(msg);

      throw Exception(msg);
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
