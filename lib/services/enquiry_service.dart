import 'dart:convert';
import 'dart:io';

import 'package:dreamvision/config/constants.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:logger/web.dart';

class EnquiryService {
  static const String _baseUrl = '$baseUrl/crm';

  final _storage = const FlutterSecureStorage();
  final Logger _logger = Logger();

  Future<Map<String, String>> _getAuthHeaders({bool isJson = true}) async {
    String? token = await _storage.read(key: 'access_token');
    if (token == null) {
      throw const SocketException(
        'Authentication token not found. Please log in.',
      );
    }
    return {
      if (isJson) 'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  dynamic _handleResponse(http.Response response) {
    if (response.body.isEmpty) {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        _logger.d(
          'API Response [${response.statusCode}]: Empty body (Success)',
        );
        return {};
      } else {
        _logger.w('API Response [${response.statusCode}]: Empty body (Error)');
        throw Exception('API Error: Received empty response from server.');
      }
    }

    try {
      final responseBody = jsonDecode(response.body);
      _logger.d('API Response [${response.statusCode}]: $responseBody');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return responseBody;
      } else {
        String errorMessage = 'An unknown error occurred.';
        if (responseBody is Map) {
          errorMessage =
              responseBody['detail']?.toString() ??
              responseBody['error']?.toString() ??
              responseBody.entries
                  .map(
                    (e) =>
                        '${e.key}: ${e.value is List ? e.value.join(', ') : e.value}',
                  )
                  .join('\n');

          if (responseBody.containsKey('details') &&
              responseBody['details'] is List) {
            final details = (responseBody['details'] as List).join('\n');
            errorMessage = 'Validation failed.\n$details';
          } else if (response.statusCode == 400 &&
              responseBody.entries.isNotEmpty) {
            // Handle DRF default validation error format (field: [error list])
            errorMessage = responseBody.entries
                .map((e) {
                  String keyFormatted = e.key.replaceAll('_', ' ');
                  // Apply the extension method explicitly after getting the String
                  String capitalizedKey = keyFormatted.capitalize();
                  String valueFormatted = e.value is List
                      ? e.value.join(', ')
                      : e.value.toString();
                  return '$capitalizedKey: $valueFormatted';
                })
                .join('\n');
          }
        } else if (responseBody is String) {
          errorMessage = responseBody;
        }

        throw Exception('API Error [${response.statusCode}]: $errorMessage');
      }
    } on FormatException catch (e) {
      _logger.e('Failed to decode JSON response: ${response.body}', error: e);
      throw Exception('Failed to process server response. Invalid format.');
    } catch (e) {
      _logger.e('Error handling response: ${e.toString()}');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getEnquiryById(int enquiryId) async {
    final url = Uri.parse('$_baseUrl/enquiries/$enquiryId/');
    final headers = await _getAuthHeaders();
    final response = await http.get(url, headers: headers);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> createEnquiry(Map<String, dynamic> data) async {
    final url = Uri.parse('$_baseUrl/enquiries/');
    final headers = await _getAuthHeaders();
    _logger.d('Creating Enquiry: ${jsonEncode(data)}');
    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode(data),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> getEnquiries({
    int page = 1,
    int? pageSize,
  }) async {
    var url = Uri.parse('$_baseUrl/enquiries/').replace(
      queryParameters: {
        'page': page.toString(),
        if (pageSize != null) 'page_size': pageSize.toString(),
      },
    );
    _logger.d('Fetching enquiries from URL: $url');
    final headers = await _getAuthHeaders();
    final response = await http.get(url, headers: headers);
    return _handleResponse(response);
  }

  Future<List<dynamic>> getAllEnquiries() async {
    List<dynamic> allResults = [];
    int currentPage = 1;
    bool hasNext = true;

    while (hasNext) {
      try {
        final response = await getEnquiries(page: currentPage);
        final List<dynamic> results = response['results'] ?? [];
        allResults.addAll(results);

        hasNext = response['next'] != null;
        if (hasNext) {
          currentPage++;
        }
      } catch (e) {
        _logger.e('Error fetching page $currentPage of enquiries: $e');
        hasNext = false;
      }
    }
    _logger.i("Fetched a total of ${allResults.length} enquiries.");
    return allResults;
  }

  Future<List<dynamic>> getRecentEnquiries({int limit = 10}) async {
    final url = Uri.parse(
      '$_baseUrl/enquiries/recent/',
    ).replace(queryParameters: {'limit': limit.toString()});
    _logger.d('Fetching recent enquiries from URL: $url');
    final headers = await _getAuthHeaders();
    final response = await http.get(url, headers: headers);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> searchEnquiries({
    required String query,
    int page = 1,
  }) async {
    final url = Uri.parse(
      '$_baseUrl/enquiries/search/',
    ).replace(queryParameters: {'q': query, 'page': page.toString()});
    _logger.d('Searching enquiries from URL: $url');
    final headers = await _getAuthHeaders();
    final response = await http.get(url, headers: headers);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> createInteraction(
    Map<String, dynamic> data,
  ) async {
    final url = Uri.parse('$_baseUrl/interactions/');
    final headers = await _getAuthHeaders();
    _logger.d('Creating Interaction: ${jsonEncode(data)}');
    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode(data),
    );
    return _handleResponse(response);
  }

  Future<List<dynamic>> getFollowUpsForEnquiry(int enquiryId) async {
    final url = Uri.parse(
      '$_baseUrl/follow-ups/',
    ).replace(queryParameters: {'enquiry': enquiryId.toString()});
    _logger.d('Fetching follow-ups from URL: $url');
    final headers = await _getAuthHeaders();
    final response = await http.get(url, headers: headers);
    final responseBody = _handleResponse(response);
    if (responseBody is Map && responseBody.containsKey('results')) {
      return responseBody['results'] as List<dynamic>;
    } else if (responseBody is List) {
      return responseBody;
    } else {
      _logger.w('Unexpected response format for follow-ups: $responseBody');
      return [];
    }
  }

  Future<Map<String, dynamic>> addFollowUp(Map<String, dynamic> data) async {
    final url = Uri.parse('$_baseUrl/follow-ups/');
    final headers = await _getAuthHeaders();
    _logger.d('Creating Follow-Up: ${jsonEncode(data)}');
    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode(data),
    );
    return _handleResponse(response);
  }

  Future<List<dynamic>> getSchools() async {
    final url = Uri.parse('$_baseUrl/schools/');
    final headers = await _getAuthHeaders();
    final response = await http.get(url, headers: headers);
    return _handleResponse(response);
  }

  Future<List<dynamic>> getEnquiryStatuses() async {
    final url = Uri.parse('$_baseUrl/statuses/');
    final headers = await _getAuthHeaders();
    final response = await http.get(url, headers: headers);
    return _handleResponse(response);
  }

  Future<List<dynamic>> getEnquirySources() async {
    final url = Uri.parse('$_baseUrl/sources/');
    final headers = await _getAuthHeaders();
    final response = await http.get(url, headers: headers);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> getDashboardStats() async {
    final url = Uri.parse('$_baseUrl/dashboard-stats/');
    final headers = await _getAuthHeaders();
    final response = await http.get(url, headers: headers);
    return _handleResponse(response);
  }

  Future<List<dynamic>> getEnquiryStatusSummary() async {
    final url = Uri.parse('$_baseUrl/enquiries/status_summary/');
    final headers = await _getAuthHeaders();
    final response = await http.get(url, headers: headers);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> bulkUploadEnquiries(String filePath) async {
    final url = Uri.parse('$_baseUrl/enquiries/bulk-upload/');
    final headers = await _getAuthHeaders(isJson: false);

    final request = http.MultipartRequest('POST', url);
    request.headers.addAll(headers);

    final file = File(filePath);
    if (!await file.exists()) {
      _logger.e('File not found for bulk upload: $filePath');
      throw Exception('File not found at the specified path.');
    }

    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    _logger.i('Uploading file: $filePath to $url');

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    return _handleResponse(response);
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
      queryParameters: {if (query != null && query.isNotEmpty) 'search': query},
    );
    _logger.d('Fetching assignable users from URL: $url');

    final headers = await _getAuthHeaders();
    final response = await http.get(url, headers: headers);

    final responseBody = _handleResponse(response);
    if (responseBody is Map && responseBody.containsKey('results')) {
      return responseBody['results'] as List<dynamic>;
    } else if (responseBody is List) {
      return responseBody;
    } else {
      _logger.w('Unexpected format for assignable users: $responseBody');
      return [];
    }
  }

  Future<Map<String, dynamic>> assignEnquiry({
    required int enquiryId,
    int? counsellorId,
    int? telecallerId,
  }) async {
    final url = Uri.parse('$_baseUrl/enquiries/$enquiryId/');
    final headers = await _getAuthHeaders();

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

    _logger.d('Assigning Enquiry $enquiryId: ${jsonEncode(payload)}');

    final response = await http.patch(
      url,
      headers: headers,
      body: jsonEncode(payload),
    );
    return _handleResponse(response);
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
