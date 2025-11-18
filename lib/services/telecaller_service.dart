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
        // Add timeouts
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
  // UPDATED ERROR HANDLER
  // ---------------------------------------------------------------------------
  String _handleDioError(DioException e) {
    _logger.e(
      'API Error [${e.response?.statusCode ?? 'N/A'}]: ${e.message}',
      error: e.error,
      stackTrace: e.stackTrace,
    );

    // 1. Handle Network/Connection Issues
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Connection timed out. Please check your internet.';
    }
    if (e.error is SocketException || e.type == DioExceptionType.unknown) {
      return 'No internet connection. Please check your network.';
    }

    // 2. Handle Server Responses
    if (e.response != null) {
      final int statusCode = e.response!.statusCode ?? 0;
      final dynamic data = e.response!.data;

      // A. Server Error (500+): Hide raw code, show generic message
      if (statusCode >= 500) {
        return 'Server error ($statusCode). Please try again later.';
      }

      // B. HTML Response Check (Fixes the IntegrityError HTML screen)
      if (data is String) {
        if (data.toLowerCase().contains('<!doctype html>') ||
            data.toLowerCase().contains('<html')) {
          return 'Server returned an invalid response.';
        }
        return data;
      }

      // C. Client Error (400-499): Extract specific validation message
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
      throw Exception(
        e is DioException ? _handleDioError(e) : e.toString(),
      );
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}