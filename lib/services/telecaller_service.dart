import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dreamvision/config/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:logger/logger.dart';

class TelecallerService {
  static const String _baseUrl = '$baseUrl/crm';

  final _storage = const FlutterSecureStorage();
  final Logger _logger = Logger();
  late final Dio _dio;

  TelecallerService() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          String? token = await _storage.read(key: 'access_token');
          if (token == null) {
            _logger.e('No auth token found, rejecting request.');
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

  /// Fetches the aggregated call activity data for the telecaller chart.
  Future<List<dynamic>> getCallActivityData(DateTimeRange dateRange) async {
    // Format dates to YYYY-MM-DD as required by the API
    final DateFormat formatter = DateFormat('yyyy-MM-dd');
    final String startDate = formatter.format(dateRange.start);
    final String endDate = formatter.format(dateRange.end);

    final queryParameters = {
      'start_date': startDate,
      'end_date': endDate,
    };


    try {
      // Calls the new endpoint: /api/crm/charts/telecaller-activity/
      final response = await _dio.get(
        '/charts/telecaller-activity/',
        queryParameters: queryParameters,
      );

      // The API returns a List<Map<String, dynamic>>
      if (response.data is List) {
        return response.data;
      } else {
        _logger.w(
            'Unexpected data format. Expected List, got ${response.data.runtimeType}');
        // Return an empty list to prevent chart errors
        return [];
      }
    } catch (e) {
      _logger.e('Error fetching call activity data', error: e);
      throw Exception(e is DioException ? _handleDioError(e) : e.toString());
    }
  }

  /// Handles parsing of Dio errors into a readable string.
  String _handleDioError(DioException e) {
    _logger.e(
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
        // Handle custom error formats like {"error": "..."}
        if (responseBody['error'] != null) {
          return responseBody['error'].toString();
        }
        
        // Standard DRF format {"detail": "..."}
        if (responseBody['detail'] != null) {
          return responseBody['detail'].toString();
        }
        
        // Standard DRF validation format {"field": ["..."]}
        if (responseBody.values.isNotEmpty && responseBody.values.first is List) {
           return responseBody.entries.map((e) {
            String keyFormatted = e.key.replaceAll('_', ' ');
            String capitalizedKey = keyFormatted.capitalize();
            String valueFormatted =
                e.value is List ? e.value.join(', ') : e.value.toString();
            return '$capitalizedKey: $valueFormatted';
          }).join('\n');
        }
      } else if (responseBody is String) {
        return responseBody;
      }
      return 'API Error [${e.response?.statusCode}]: $responseBody';
    } catch (parseError) {
      _logger.e('Error parsing error response body: $parseError');
      return 'Failed to process server response. Invalid format.';
    }
  }
}

// Helper extension for capitalizing error field names
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}