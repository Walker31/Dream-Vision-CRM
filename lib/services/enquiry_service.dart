import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dreamvision/config/constants.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

class EnquiryService {
  static final EnquiryService _instance = EnquiryService._internal();
  static bool _initialized = false;
  
  factory EnquiryService() {
    if (!_initialized) {
      _instance._init();
      _initialized = true;
    }
    return _instance;
  }

  final Logger logger = Logger();
  final _storage = const FlutterSecureStorage();
  late final Dio _dio;

  static const String _baseUrl = '$baseUrl/crm';

  EnquiryService._internal() {
    _initSync();
  }

  /// Synchronous initialization to set up Dio immediately
  void _initSync() {
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
            return handler.reject(
              DioException(
                requestOptions: options,
                message: 'Authentication token missing. Please login again.',
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

  /// Async initialization (if needed in future)
  Future<void> _init() async {
    // Placeholder for any async initialization that might be needed
  }

  // ---------------------------------------------------------------------------
  // ERROR HANDLING (SERVICE-ONLY)
  // ---------------------------------------------------------------------------

  String _handleDioError(DioException e) {
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

      if (data is Map) {
        if (data['detail'] != null) return data['detail'].toString();
        if (data['message'] != null) return data['message'].toString();
        if (data['error'] != null) return data['error'].toString();

        if (data.isNotEmpty) {
          final key = data.keys.first;
          final value = data[key];
          if (value is List) return "$key: ${value.first}";
          return "$key: $value";
        }
      }

      if (data is String) {
        if (data.toLowerCase().contains('<html')) {
          return 'Server returned an invalid response.';
        }
        return data;
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
  // PAGINATION
  // ---------------------------------------------------------------------------

  Future<dynamic> _getPaginatedList(
    String endpoint, {
    int page = 1,
    String? query,
    String? standard,
    String? status,
    String? cnr,
    int? telecallerId,
  }) async {
    try {
      final response = await _dio.get(
        endpoint,
        queryParameters: {
          'page': page.toString(),
          if (query?.isNotEmpty == true) 'search': query,
          if (standard?.isNotEmpty == true) 'standard': standard,
          if (status?.isNotEmpty == true) 'status': status,
          if (cnr?.isNotEmpty == true) 'cnr': cnr,
          if (telecallerId != null) 'telecaller_id': telecallerId,
        },
      );
      return response.data ?? {};
    } catch (e) {
      _rethrow(e);
    }
  }

  Future<dynamic> getUnassignedEnquiries({
    int page = 1,
    String? query,
    String? standard,
    String? status,
    int? telecallerId,
  }) => _getPaginatedList(
    '/enquiries/unassigned/',
    page: page,
    query: query,
    standard: standard,
    status: status,
    telecallerId: telecallerId,
  );

  Future<dynamic> getAssignedEnquiries({
    int page = 1,
    String? query,
    String? standard,
    String? status,
    int? telecallerId,
  }) => _getPaginatedList(
    '/enquiries/assigned/',
    page: page,
    query: query,
    standard: standard,
    status: status,
    telecallerId: telecallerId,
  );

  Future<dynamic> getTelecallerEnquiries({
    int page = 1,
    String? status,
    String? search,
    String? cnr,
  }) => _getPaginatedList(
    '/enquiries/my_leads/',
    page: page,
    status: status,
    query: search,
    cnr: cnr,
  );

  Future<dynamic> getAllEnquiries({
    int page = 1,
    String? status,
    String? search,
    String? standard,
    String? cnr,
  }) => _getPaginatedList(
    '/enquiries/',
    page: page,
    status: status,
    query: search,
    standard: standard,
    cnr: cnr,
  );

  Future<Map<String, dynamic>> getStatusCounts({
    String? search,
    String? standard,
    String? status,
    String? cnr,
    int? telecallerId,
  }) async {
    try {
      final response = await _dio.get(
        '/enquiries/status_counts/',
        queryParameters: {
          if (search?.isNotEmpty == true) 'search': search,
          if (standard?.isNotEmpty == true) 'standard': standard,
          if (status?.isNotEmpty == true) 'status': status,
          if (cnr?.isNotEmpty == true) 'cnr': cnr,
          if (telecallerId != null) 'telecaller_id': telecallerId,
        },
      );
      return response.data ?? {};
    } catch (e) {
      _rethrow(e);
    }
  }

  // ---------------------------------------------------------------------------
  // ENQUIRIES
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> getEnquiryById(int enquiryId) async {
    try {
      final response = await _dio.get('/enquiries/$enquiryId/');
      return response.data ?? {};
    } catch (e) {
      _rethrow(e);
    }
  }



  Future<String> downloadEnquiryTemplate() async {
    try {

      final response = await _dio.get(
        '/enquiries/template/',
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed: HTTP ${response.statusCode}');
      }

      final bytes = Uint8List.fromList(List<int>.from(response.data));

      // Save to app's documents directory (no broad storage access needed).
      // On Android 11+, this uses scoped storage automatically.
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/Sample Template.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);

      return filePath;
    } catch (e) {
      _rethrow(e);
    }
  }

  Future<Map<String, dynamic>> updateEnquiry(
    int enquiryId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.patch('/enquiries/$enquiryId/', data: data);
      return response.data ?? {};
    } catch (e) {
      _rethrow(e);
    }
  }

  Future<Map<String, dynamic>> softDeleteEnquiry(int enquiryId) async {
    try {
      final response = await _dio.patch('/enquiries/$enquiryId/soft_delete/');
      return response.data ?? {};
    } catch (e) {
      _rethrow(e);
    }
  }

  Future<Map<String, dynamic>> createEnquiry(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/enquiries/', data: data);
      logger.i('Created Enquiry: ${response.data}');
      return response.data ?? {};
    } catch (e) {
      _rethrow(e);
    }
  }

  Future<List<dynamic>> getRecentEnquiries({
    int limit = 10,
    String? search,
    String? standard,
    String? status,
    String? cnr,
  }) async {
    try {
      final response = await _dio.get(
        '/enquiries/recent/',
        queryParameters: {
          'limit': limit.toString(),
          if (search?.isNotEmpty == true) 'search': search,
          if (standard?.isNotEmpty == true) 'standard': standard,
          if (status?.isNotEmpty == true) 'status': status,
          if (cnr?.isNotEmpty == true) 'cnr': cnr,
        },
      );
      return response.data ?? [];
    } catch (e) {
      _rethrow(e);
    }
  }

  Future<Map<String, dynamic>> searchEnquiries({
    required String query,
    int page = 1,
  }) async {
    try {
      final response = await _dio.get(
        '/enquiries/search/',
        queryParameters: {'q': query, 'page': page.toString()},
      );
      return response.data ?? {};
    } catch (e) {
      _rethrow(e);
    }
  }

  // ---------------------------------------------------------------------------
  // FOLLOW UPS
  // ---------------------------------------------------------------------------

  Future<List<dynamic>> getFollowUpsForEnquiry(int enquiryId) async {
    try {
      final response = await _dio.get(
        '/follow-ups/',
        queryParameters: {'enquiry': enquiryId.toString()},
      );

      final body = response.data;
      if (body is Map && body['results'] != null) return body['results'];
      if (body is List) return body;
      return [];
    } catch (e) {
      _rethrow(e);
    }
  }

  Future<Map<String, dynamic>> addFollowUp(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/follow-ups/', data: data);
      return response.data ?? {};
    } catch (e) {
      _rethrow(e);
    }
  }

  Future<Map<String, dynamic>> updateFollowUp(
    int followUpId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.patch('/follow-ups/$followUpId/', data: data);
      return response.data ?? {};
    } catch (e) {
      _rethrow(e);
    }
  }

  Future<Map<String, dynamic>> softDeleteFollowUp(int followUpId) async {
    try {
      final response = await _dio.patch('/follow-ups/$followUpId/soft_delete/');
      return response.data ?? {};
    } catch (e) {
      _rethrow(e);
    }
  }

  // ---------------------------------------------------------------------------
  // ACADEMIC
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> softDeleteAcademic(int academicId) async {
    try {
      final response = await _dio.patch(
        '/academic_performance/$academicId/soft_delete/',
      );
      return response.data ?? {};
    } catch (e) {
      _rethrow(e);
    }
  }

  // ---------------------------------------------------------------------------
  // MISC
  // ---------------------------------------------------------------------------

  Future<List<dynamic>> getSchools() async {
    try {
      final response = await _dio.get('/schools/');
      return response.data ?? [];
    } catch (e) {
      _rethrow(e);
    }
  }

  Future<List<dynamic>> getEnquiryStatuses() async {
    try {
      final response = await _dio.get('/statuses/');
      return response.data ?? [];
    } catch (e) {
      _rethrow(e);
    }
  }

  Future<List<dynamic>> getEnquirySources() async {
    try {
      final response = await _dio.get('/sources/');
      return response.data ?? [];
    } catch (e) {
      _rethrow(e);
    }
  }

  Future<List<dynamic>> getExams() async {
    try {
      final response = await _dio.get('/exams/');
      return response.data ?? [];
    } catch (e) {
      _rethrow(e);
    }
  }

  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final response = await _dio.get('/dashboard-stats/');
      return response.data ?? {};
    } catch (e) {
      _rethrow(e);
    }
  }

  Future<Map<String, dynamic>> getEnquiryStatusSummary({
    String? standard,
    String? status,
    int? telecallerId,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (standard?.isNotEmpty == true) params['standard'] = standard;
      if (status?.isNotEmpty == true) params['status'] = status;
      if (telecallerId != null) params['telecaller_id'] = telecallerId;

      final response = await _dio.get(
        '/enquiries/status_summary/',
        queryParameters: params,
      );

      final data = response.data;
      logger.d('Enquiry Status Summary Data: $data');

      if (data is Map<String, dynamic>) return data;
      if (data is List) {
        return {"chart_data": data, "unassigned_count": 0, "assigned_count": 0};
      }

      return {"chart_data": [], "unassigned_count": 0, "assigned_count": 0};
    } catch (e) {
      _rethrow(e);
    }
  }

  /// Get accurate assigned/unassigned counts for Admin Dashboard
  /// Supports filtering by standard, status, and telecaller
  Future<Map<String, dynamic>> getAssignedUnassignedCounts({
    String? standard,
    String? status,
    int? telecallerId,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (standard?.isNotEmpty == true) params['standard'] = standard;
      if (status?.isNotEmpty == true) params['status'] = status;
      if (telecallerId != null) params['telecaller_id'] = telecallerId;

      final response = await _dio.get(
        '/enquiries/assigned_unassigned_counts/',
        queryParameters: params,
      );
      final data = response.data;
      logger.d('Assigned/Unassigned Counts: $data');

      if (data is Map<String, dynamic>) {
        return {
          'assigned_count': data['assigned_count'] ?? 0,
          'unassigned_count': data['unassigned_count'] ?? 0,
          'total_count': data['total_count'] ?? 0,
        };
      }

      return {
        'assigned_count': 0,
        'unassigned_count': 0,
        'total_count': 0,
      };
    } catch (e) {
      _rethrow(e);
    }
  }

  // ---------------------------------------------------------------------------
  // MANAGER DASHBOARD
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getManagerEnquiries({
    int page = 1,
    String? standard,
    String? status,
    String? search,
  }) async {
    try {
      final params = <String, dynamic>{
        'page': page,
      };
      if (standard?.isNotEmpty == true) params['standard'] = standard;
      if (status?.isNotEmpty == true) params['status'] = status;
      if (search?.isNotEmpty == true) params['search'] = search;

      final response = await _dio.get(
        '/enquiries/manager_enquiries/',
        queryParameters: params,
      );

      final data = response.data;
      logger.d('Manager enquiries response: $data');

      if (data is Map<String, dynamic> && data['results'] != null) {
        return List<Map<String, dynamic>>.from(data['results'] ?? []);
      }
      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      }

      return [];
    } catch (e) {
      _rethrow(e);
    }
  }

  Future<Map<String, dynamic>> getManagerStatusCounts({
    String? standard,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (standard?.isNotEmpty == true) params['standard'] = standard;

      final response = await _dio.get(
        '/enquiries/manager_status_summary/',
        queryParameters: params,
      );

      final data = response.data;
      logger.d('Manager status counts: $data');

      if (data is Map<String, dynamic> && data['status_counts'] != null) {
        final statusCounts = <String, int>{};
        for (final item in data['status_counts']) {
          if (item is Map<String, dynamic>) {
            statusCounts[item['status']] = item['count'] ?? 0;
          }
        }
        return statusCounts;
      }

      return {};
    } catch (e) {
      _rethrow(e);
    }
  }

  Future<List<Map<String, dynamic>>> getManagerStatusSummary({
    String? standard,
    String? status,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (standard?.isNotEmpty == true) params['standard'] = standard;
      if (status?.isNotEmpty == true) params['status'] = status;

      final response = await _dio.get(
        '/enquiries/manager_status_summary/',
        queryParameters: params,
      );

      final data = response.data;
      logger.d('Manager status summary: $data');

      if (data is Map<String, dynamic> && data['status_counts'] != null) {
        return List<Map<String, dynamic>>.from(data['status_counts'] ?? []);
      }

      return [];
    } catch (e) {
      _rethrow(e);
    }
  }

  // ---------------------------------------------------------------------------
  // BULK UPLOAD
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> bulkUploadEnquiries(
    String filePath, {
    int? telecallerId,
  }) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        throw Exception('File not found.');
      }

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          filePath,
          filename: file.path.split('/').last,
        ),
        if (telecallerId != null) 'telecaller_id': telecallerId,
      });

      final response = await _dio.post(
        '/enquiries/bulk-upload/',
        data: formData,
      );
      return response.data ?? {};
    } catch (e) {
      _rethrow(e);
    }
  }

  Future<Map<String, dynamic>> getUploadProgress(String sessionId) async {
    try {
      final response = await _dio.get(
        '/enquiries/upload-progress/$sessionId/',
      );
      return response.data ?? {
        'current': 0,
        'total': 0,
        'status': 'not_found',
        'percentage': 0,
      };
    } catch (e) {
      _rethrow(e);
    }
  }

  // ---------------------------------------------------------------------------
  // ASSIGN
  // ---------------------------------------------------------------------------

  Future<List<dynamic>> getAssignableUsers({
    required String role,
    String? query,
  }) async {
    try {
      String endpoint;

      if (role.toLowerCase() == 'counsellor') {
        endpoint = '$baseUrl/users/admin/list-counsellors/';
      } else if (role.toLowerCase() == 'telecaller') {
        endpoint = '$baseUrl/users/admin/list-telecallers/';
      } else {
        throw Exception('Invalid role specified.');
      }

      final url = Uri.parse(endpoint).replace(
        queryParameters: {if (query?.isNotEmpty == true) 'search': query},
      );

      final response = await _dio.getUri(url);
      final data = response.data;

      if (data is Map && data['results'] != null) return data['results'];
      if (data is List) return data;

      return [];
    } catch (e) {
      _rethrow(e);
    }
  }

  Future<dynamic> getEnquiries({int page = 1, String? query}) {
    return _getPaginatedList('/enquiries/', page: page, query: query);
  }

  Future<Map<String, dynamic>> assignEnquiry({
    required int enquiryId,
    int? counsellorId,
    int? telecallerId,
  }) async {
    try {
      final payload = {
        if (counsellorId != null) 'assigned_to_counsellor': counsellorId,
        if (telecallerId != null) 'assigned_to_telecaller': telecallerId,
      };

      final response = await _dio.patch(
        '/enquiries/$enquiryId/',
        data: payload,
      );
      return response.data ?? {};
    } catch (e) {
      _rethrow(e);
    }
  }

  /// Fetch all available enquiry statuses from backend
  Future<List<dynamic>> getStatusesList() async {
    try {
      final response = await _dio.get('/statuses/');
      final List<dynamic> results = response.data is List ? response.data : [];
      return results;
    } catch (e) {
      _rethrow(e);
    }
  }
}

extension StringExtension on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
