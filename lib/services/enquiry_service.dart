import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dreamvision/config/constants.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/web.dart';

class EnquiryService {
  static const String _baseUrl = '$baseUrl/crm';

  final _storage = const FlutterSecureStorage();
  final Logger _logger = Logger();
  late final Dio _dio;

  EnquiryService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        headers: {'Content-Type': 'application/json'},
      ),
    );

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

    if (e.error is SocketException ||
        e.type == DioExceptionType.cancel ||
        e.type == DioExceptionType.unknown) {
      return 'Connection error. Please check your network.';
    }

    final responseBody = e.response?.data;

    if (responseBody == null || responseBody == "") {
      return 'API Error [${e.response?.statusCode}]: Received empty response from server.';
    }

    try {
      if (responseBody is Map) {
        String errorMessage = 'An unknown error occurred.';

        if (responseBody.containsKey('error') &&
            responseBody.containsKey('details') &&
            responseBody['details'] is List) {
          final details = (responseBody['details'] as List).join('\n');
          errorMessage = '${responseBody['error']}\n\n$details';
        } else if (responseBody['detail'] != null) {
          errorMessage = responseBody['detail'].toString();
        } else if (responseBody['error'] != null) {
          errorMessage = responseBody['error'].toString();
        } else if (e.response?.statusCode == 400 &&
            responseBody.entries.isNotEmpty) {
          errorMessage = responseBody.entries
              .map((e) {
                String keyFormatted = e.key.replaceAll('_', ' ');
                String capitalizedKey = keyFormatted.capitalize();
                String valueFormatted = e.value is List
                    ? e.value.join(', ')
                    : e.value.toString();
                return '$capitalizedKey: $valueFormatted';
              })
              .join('\n');
        } else {
          errorMessage = responseBody.entries
              .map(
                (e) =>
                    '${e.key}: ${e.value is List ? e.value.join(', ') : e.value}',
              )
              .join('\n');
        }
        return errorMessage;
      } else if (responseBody is String) {
        return responseBody;
      }
      return 'API Error [${e.response?.statusCode}]: $responseBody';
    } catch (parseError) {
      _logger.e('Error parsing error response body: $parseError');
      return 'Failed to process server response. Invalid format.';
    }
  }

  Future<Map<String, dynamic>> _getPaginatedList(
    String endpoint, {
    int page = 1,
    String? query,
    String? status,
  }) async {
    final queryParameters = {
      'page': page.toString(),
      if (query != null && query.isNotEmpty) 'search': query,
      if (status != null && status.isNotEmpty) 'status': status,
    };
    _logger.d('Fetching list $endpoint with params: $queryParameters');
    try {
      final response = await _dio.get(
        endpoint,
        queryParameters: queryParameters,
      );
      _logger.d('API Response [${response.statusCode}]: ${response.data}');
      return response.data ?? {};
    } catch (e) {
      _logger.e('Error fetching list $endpoint', error: e);
      throw Exception(e is DioException ? _handleDioError(e) : e.toString());
    }
  }

  Future<Map<String, dynamic>> getUnassignedEnquiries({
    int page = 1,
    String? query,
  }) {
    return _getPaginatedList(
      '/enquiries/unassigned/',
      page: page,
      query: query,
    );
  }

  Future<Map<String, dynamic>> getAssignedEnquiries({
    int page = 1,
    String? query,
  }) {
    return _getPaginatedList(
      '/enquiries/assigned/',
      page: page,
      query: query,
    );
  }

  Future<Map<String, dynamic>> getTelecallerEnquiries({
    int page = 1,
    String? status,
  }) {
    return _getPaginatedList(
      '/enquiries/my-leads/', // Assumes a new endpoint
      page: page,
      status: status,
    );
  }

  Future<Map<String, dynamic>> getEnquiryById(int enquiryId) async {
    try {
      final response = await _dio.get('/enquiries/$enquiryId/');
      _logger.d('API Response [${response.statusCode}]: ${response.data}');
      return response.data ?? {};
    } catch (e) {
      _logger.e('Error fetching enquiry $enquiryId', error: e);
      throw Exception(e is DioException ? _handleDioError(e) : e.toString());
    }
  }

  Future<Map<String, dynamic>> updateEnquiry(
    int enquiryId,
    Map<String, dynamic> data,
  ) async {
    try {
      _logger.d('Updating Enquiry $enquiryId: $data');
      final response = await _dio.patch(
        '/enquiries/$enquiryId/',
        data: data,
      );
      _logger.d('API Response [${response.statusCode}]: ${response.data}');
      return response.data ?? {};
    } catch (e) {
      _logger.e('Error updating enquiry $enquiryId', error: e);
      throw Exception(e is DioException ? _handleDioError(e) : e.toString());
    }
  }

  Future<Map<String, dynamic>> createEnquiry(Map<String, dynamic> data) async {
    try {
      _logger.d('Creating Enquiry: $data');
      final response = await _dio.post('/enquiries/', data: data);
      _logger.d('API Response [${response.statusCode}]: ${response.data}');
      return response.data ?? {};
    } catch (e) {
      _logger.e('Error creating enquiry', error: e);
      throw Exception(e is DioException ? _handleDioError(e) : e.toString());
    }
  }

  Future<List<dynamic>> getRecentEnquiries({int limit = 10}) async {
    _logger.d('Fetching recent enquiries limit: $limit');
    try {
      final response = await _dio.get(
        '/enquiries/recent/',
        queryParameters: {'limit': limit.toString()},
      );
      _logger.d('API Response [${response.statusCode}]: ${response.data}');
      return response.data ?? [];
    } catch (e) {
      _logger.e('Error fetching recent enquiries', error: e);
      throw Exception(e is DioException ? _handleDioError(e) : e.toString());
    }
  }

  Future<Map<String, dynamic>> searchEnquiries({
    required String query,
    int page = 1,
  }) async {
    final queryParameters = {'q': query, 'page': page.toString()};
    _logger.d('Searching enquiries with params: $queryParameters');
    try {
      final response = await _dio.get(
        '/enquiries/search/',
        queryParameters: queryParameters,
      );
      _logger.d('API Response [${response.statusCode}]: ${response.data}');
      return response.data ?? {};
    } catch (e) {
      _logger.e('Error searching enquiries', error: e);
      throw Exception(e is DioException ? _handleDioError(e) : e.toString());
    }
  }

  Future<Map<String, dynamic>> createInteraction(
    Map<String, dynamic> data,
  ) async {
    try {
      _logger.d('Creating Interaction: $data');
      final response = await _dio.post('/interactions/', data: data);
      _logger.d('API Response [${response.statusCode}]: ${response.data}');
      return response.data ?? {};
    } catch (e) {
      _logger.e('Error creating interaction', error: e);
      throw Exception(e is DioException ? _handleDioError(e) : e.toString());
    }
  }

  Future<Map<String, dynamic>> getEnquiries({
    int page = 1,
    String? query,
  }) {
    return _getPaginatedList(
      '/enquiries/',
      page: page,
      query: query,
    );
  }

  Future<List<dynamic>> getFollowUpsForEnquiry(int enquiryId) async {
    _logger.d('Fetching follow-ups for enquiry $enquiryId');
    try {
      final response = await _dio.get(
        '/follow-ups/',
        queryParameters: {'enquiry': enquiryId.toString()},
      );
      _logger.d('API Response [${response.statusCode}]: ${response.data}');
      final responseBody = response.data;

      if (responseBody == null) return [];
      if (responseBody is Map && responseBody.containsKey('results')) {
        return responseBody['results'] as List<dynamic>;
      } else if (responseBody is List) {
        return responseBody;
      } else {
        _logger
            .w('Unexpected response format for follow-ups: $responseBody');
        return [];
      }
    } catch (e) {
      _logger.e('Error fetching follow-ups', error: e);
      throw Exception(e is DioException ? _handleDioError(e) : e.toString());
    }
  }

  Future<Map<String, dynamic>> addFollowUp(Map<String, dynamic> data) async {
    try {
      _logger.d('Creating Follow-Up: $data');
      final response = await _dio.post('/follow-ups/', data: data);
      _logger.d('API Response [${response.statusCode}]: ${response.data}');
      return response.data ?? {};
    } catch (e) {
      _logger.e('Error creating follow-up', error: e);
      throw Exception(e is DioException ? _handleDioError(e) : e.toString());
    }
  }

  Future<List<dynamic>> getSchools() async {
    try {
      final response = await _dio.get('/schools/');
      _logger.d('API Response [${response.statusCode}]: ${response.data}');
      return response.data ?? [];
    } catch (e) {
      _logger.e('Error fetching schools', error: e);
      throw Exception(e is DioException ? _handleDioError(e) : e.toString());
    }
  }

  Future<List<dynamic>> getEnquiryStatuses() async {
    try {
      final response = await _dio.get('/statuses/');
      _logger.d('API Response [${response.statusCode}]: ${response.data}');
      return response.data ?? [];
    } catch (e) {
      _logger.e('Error fetching statuses', error: e);
      throw Exception(e is DioException ? _handleDioError(e) : e.toString());
    }
  }

  Future<List<dynamic>> getEnquirySources() async {
    try {
      final response = await _dio.get('/sources/');
      _logger.d('API Response [${response.statusCode}]: ${response.data}');
      return response.data ?? [];
    } catch (e) {
      _logger.e('Error fetching sources', error: e);
      throw Exception(e is DioException ? _handleDioError(e) : e.toString());
    }
  }

  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final response = await _dio.get('/dashboard-stats/');
      _logger.d('API Response [${response.statusCode}]: ${response.data}');
      return response.data ?? {};
    } catch (e) {
      _logger.e('Error fetching dashboard stats', error: e);
      throw Exception(e is DioException ? _handleDioError(e) : e.toString());
    }
  }

  Future<Map<String, dynamic>> getEnquiryStatusSummary() async {
    try {
      final response = await _dio.get('/enquiries/status_summary/');
      _logger.d('API Response [${response.statusCode}]: ${response.data}');

      if (response.data is Map) {
        return response.data;
      }

      if (response.data is List) {
        _logger.w(
            "Warning: status_summary endpoint is returning an old format. Please update it to return a Map with chart_data, unassigned_count, and assigned_count.");
        return {
          "chart_data": response.data,
          "unassigned_count": 0,
          "assigned_count": 0
        };
      }

      return {"chart_data": [], "unassigned_count": 0, "assigned_count": 0};
    } catch (e) {
      _logger.e('Error fetching status summary', error: e);
      throw Exception(e is DioException ? _handleDioError(e) : e.toString());
    }
  }

  Future<Map<String, dynamic>> bulkUploadEnquiries(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      _logger.e('File not found for bulk upload: $filePath');
      throw Exception('File not found at the specified path.');
    }

    String fileName = file.path.split('/').last;
    FormData formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });

    _logger.i('Uploading file: $filePath to /enquiries/bulk-upload/');

    try {
      final response = await _dio.post(
        '/enquiries/bulk-upload/',
        data: formData,
      );
      _logger.d('API Response [${response.statusCode}]: ${response.data}');
      return response.data ?? {};
    } catch (e) {
      _logger.e('Error bulk uploading file', error: e);
      throw Exception(e is DioException ? _handleDioError(e) : e.toString());
    }
  }

  Future<List<dynamic>> getAssignableUsers({
    required String role,
    String? query,
  }) async {
    String endpoint;
    if (role.toLowerCase() == 'counsellor') {
      endpoint = '$baseUrl/users/admin/list-counsellors/';
    } else if (role.toLowerCase() == 'telecaller') {
      endpoint = '$baseUrl/users/admin/list-telecallers/';
    } else {
      _logger.e('Invalid role specified for getAssignableUsers: $role');
      throw Exception('Invalid role specified.');
    }

    var url = Uri.parse(endpoint).replace(
      queryParameters: {
        if (query != null && query.isNotEmpty) 'search': query
      },
    );
    _logger.d('Fetching assignable users from URL: $url');

    try {
      final response = await _dio.getUri(url);
      _logger.d('API Response [${response.statusCode}]: ${response.data}');
      final responseBody = response.data;

      if (responseBody == null) return [];
      if (responseBody is Map && responseBody.containsKey('results')) {
        return responseBody['results'] as List<dynamic>;
      } else if (responseBody is List) {
        return responseBody;
      } else {
        _logger
            .w('Unexpected format for assignable users: $responseBody');
        return [];
      }
    } catch (e) {
      _logger.e('Error fetching assignable users', error: e);
      throw Exception(e is DioException ? _handleDioError(e) : e.toString());
    }
  }

  Future<Map<String, dynamic>> assignEnquiry({
    required int enquiryId,
    int? counsellorId,
    int? telecallerId,
  }) async {
    final Map<String, dynamic> payload = {};
    if (counsellorId != null) {
      payload['assigned_to_counsellor'] = counsellorId;
    }
    if (telecallerId != null) {
      payload['assigned_to_telecaller'] = telecallerId;
    }

    if (payload.isEmpty) {
      _logger.w('Assign Enquiry called with no IDs for enquiry $enquiryId');
      return {'message': 'No assignment specified.'};
    }

    _logger.d('Assigning Enquiry $enquiryId: $payload');

    try {
      final response = await _dio.patch(
        '/enquiries/$enquiryId/',
        data: payload,
      );
      _logger.d('API Response [${response.statusCode}]: ${response.data}');
      return response.data ?? {};
    } catch (e) {
      _logger.e('Error assigning enquiry $enquiryId', error: e);
      throw Exception(e is DioException ? _handleDioError(e) : e.toString());
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}