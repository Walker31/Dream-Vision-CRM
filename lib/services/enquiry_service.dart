import 'dart:io';
import 'dart:typed_data';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:dreamvision/config/constants.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class EnquiryService {
  static final EnquiryService _instance = EnquiryService._internal();
  factory EnquiryService() => _instance;
  Logger logger = Logger();

  EnquiryService._internal() {
    _init();
  }

  static const String _baseUrl = '$baseUrl/crm';

  final _storage = const FlutterSecureStorage();
  late Dio _dio;

  Future<void> _init() async {
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
                message: "Authentication token missing. Please login again.",
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

  String _handleDioError(DioException e) {
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

      // Server Error (500+): Generic message
      if (statusCode >= 500) {
        return 'Server error ($statusCode). Please try again later.';
      }

      // Client Error (400-499): Extract message
      if (data is Map) {
        if (data['detail'] != null) return data['detail'].toString();
        if (data['message'] != null) return data['message'].toString();
        if (data['error'] != null) return data['error'].toString();

        if (data.isNotEmpty) {
          final firstKey = data.keys.first;
          final firstValue = data[firstKey];
          if (firstValue is List) return "$firstKey: ${firstValue.first}";
          return "$firstKey: $firstValue";
        }
      }

      // --- NEW FIX HERE ---
      // Check if the response is a String and looks like HTML
      if (data is String) {
        if (data.toLowerCase().contains('<!doctype html>') ||
            data.toLowerCase().contains('<html')) {
          return 'Server Error: The server returned an invalid response.';
        }
        // Otherwise return the plain text string
        return data;
      }
    }

    return 'Something went wrong. Please try again.';
  }

  Future<Map<String, dynamic>> _getPaginatedList(
    String endpoint, {
    int page = 1,
    String? query,
    String? status,
  }) async {
    try {
      final response = await _dio.get(
        endpoint,
        queryParameters: {
          'page': page.toString(),
          if (query?.isNotEmpty == true) 'search': query,
          if (status?.isNotEmpty == true) 'status': status,
        },
      );
      return response.data ?? {};
    } catch (e) {
      throw Exception(e is DioException ? _handleDioError(e) : e.toString());
    }
  }

  Future<Map<String, dynamic>> getUnassignedEnquiries({
    int page = 1,
    String? query,
  }) => _getPaginatedList('/enquiries/unassigned/', page: page, query: query);

  Future<Map<String, dynamic>> getAssignedEnquiries({
    int page = 1,
    String? query,
  }) => _getPaginatedList('/enquiries/assigned/', page: page, query: query);

  Future<Map<String, dynamic>> getTelecallerEnquiries({
    int page = 1,
    String? status,
  }) => _getPaginatedList('/enquiries/my_leads/', page: page, status: status);

  Future<Map<String, dynamic>> getEnquiryById(int enquiryId) async {
    try {
      final response = await _dio.get('/enquiries/$enquiryId/');
      return response.data ?? {};
    } catch (e) {
      throw Exception(e is DioException ? _handleDioError(e) : e.toString());
    }
  }

  Future<void> _ensureStoragePermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      if (sdkInt >= 30) {
        // Android 11 (API 30) and above
        if (!await Permission.manageExternalStorage.isGranted) {
          final result = await Permission.manageExternalStorage.request();
          if (!result.isGranted) {
            throw Exception('Storage permission denied');
          }
        }
      } else {
        // Android 10 and below
        if (!await Permission.storage.isGranted) {
          final result = await Permission.storage.request();
          if (!result.isGranted) {
            throw Exception('Storage permission denied');
          }
        }
      }
    }
  }

  Future<String> downloadEnquiryTemplate() async {
    try {
      await _ensureStoragePermission();

      final response = await _dio.get(
        '/enquiries/template/',
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed: HTTP ${response.statusCode}');
      }

      final bytes = Uint8List.fromList(List<int>.from(response.data));

      Directory directory;

      if (Platform.isAndroid) {
        final downloads = Directory('/storage/emulated/0/Download');
        if (await downloads.exists()) {
          directory = downloads;
        } else {
          directory = await getApplicationDocumentsDirectory();
        }
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else {
        directory =
            await getDownloadsDirectory() ?? await getTemporaryDirectory();
      }

      final filePath = '${directory.path}/Sample Template.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);

      return filePath;
    } catch (e) {
      throw Exception('Failed to download template: $e');
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
      throw Exception(e is DioException ? _handleDioError(e) : e.toString());
    }
  }

  Future<Map<String, dynamic>> getEnquiries({int page = 1, String? query}) {
    return _getPaginatedList('/enquiries/', page: page, query: query);
  }

  Future<Map<String, dynamic>> deleteEnquiry(int enquiryId) async {
    try {
      final response = await _dio.patch(
        '/enquiries/$enquiryId/',
        data: {'is_deleted': true},
      );

      return response.data ?? {};
    } catch (e) {
      throw Exception(e is DioException ? _handleDioError(e) : e.toString());
    }
  }

  Future<Map<String, dynamic>> createEnquiry(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/enquiries/', data: data);
      return response.data ?? {};
    } catch (e) {
      throw Exception(e is DioException ? _handleDioError(e) : e.toString());
    }
  }

  Future<List<dynamic>> getRecentEnquiries({int limit = 10}) async {
    try {
      final response = await _dio.get(
        '/enquiries/recent/',
        queryParameters: {'limit': limit.toString()},
      );
      return response.data ?? [];
    } catch (e) {
      throw Exception(e is DioException ? _handleDioError(e) : e.toString());
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
      throw Exception(e is DioException ? _handleDioError(e) : e.toString());
    }
  }

  Future<Map<String, dynamic>> createInteraction(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.post('/interactions/', data: data);
      return response.data ?? {};
    } catch (e) {
      throw Exception(e is DioException ? _handleDioError(e) : e.toString());
    }
  }

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
      throw Exception(e is DioException ? _handleDioError(e) : e.toString());
    }
  }

  Future<Map<String, dynamic>> addFollowUp(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/follow-ups/', data: data);
      return response.data ?? {};
    } catch (e) {
      throw Exception(e is DioException ? _handleDioError(e) : e.toString());
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
      throw Exception(e is DioException ? _handleDioError(e) : e.toString());
    }
  }

  Future<List<dynamic>> getSchools() async {
    try {
      final response = await _dio.get('/schools/');
      return response.data ?? [];
    } catch (e) {
      throw Exception(e is DioException ? _handleDioError(e) : e.toString());
    }
  }

  Future<List<dynamic>> getEnquiryStatuses() async {
    try {
      final response = await _dio.get('/statuses/');
      return response.data ?? [];
    } catch (e) {
      throw Exception(e is DioException ? _handleDioError(e) : e.toString());
    }
  }

  Future<List<dynamic>> getEnquirySources() async {
    try {
      final response = await _dio.get('/sources/');
      return response.data ?? [];
    } catch (e) {
      throw Exception(e is DioException ? _handleDioError(e) : e.toString());
    }
  }

  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final response = await _dio.get('/dashboard-stats/');
      return response.data ?? {};
    } catch (e) {
      throw Exception(e is DioException ? _handleDioError(e) : e.toString());
    }
  }

  Future<Map<String, dynamic>> getEnquiryStatusSummary() async {
    try {
      final response = await _dio.get('/enquiries/status_summary/');
      final data = response.data;

      if (data is Map<String, dynamic>) return data;

      if (data is List) {
        return {"chart_data": data, "unassigned_count": 0, "assigned_count": 0};
      }

      return {"chart_data": [], "unassigned_count": 0, "assigned_count": 0};
    } catch (e) {
      throw Exception(e is DioException ? _handleDioError(e) : e.toString());
    }
  }

  Future<Map<String, dynamic>> bulkUploadEnquiries(String filePath) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) throw Exception('File not found.');

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          filePath,
          filename: file.path.split('/').last,
        ),
      });

      final response = await _dio.post(
        '/enquiries/bulk-upload/',
        data: formData,
      );
      return response.data ?? {};
    } catch (e) {
      throw Exception(e is DioException ? _handleDioError(e) : e.toString());
    }
  }

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
      throw Exception(e is DioException ? _handleDioError(e) : e.toString());
    }
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
      throw Exception(e is DioException ? _handleDioError(e) : e.toString());
    }
  }
}

extension StringExtension on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
