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

  Future<Map<String, String>> _getAuthHeaders() async {
    String? token = await _storage.read(key: 'access_token');
    if (token == null) {
      throw const SocketException('Authentication token not found. Please log in.');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  dynamic _handleResponse(http.Response response) {
    final responseBody = jsonDecode(response.body);
    _logger.d('API Response [${response.statusCode}]: $responseBody');
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return responseBody;
    } else {
      final errorMessage = responseBody['detail'] ?? responseBody.toString();
      throw Exception('API Error: $errorMessage');
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
    final response = await http.post(url, headers: headers, body: jsonEncode(data));
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> getEnquiries({int page = 1}) async {
    final url = Uri.parse('$_baseUrl/enquiries/?page=$page');
    final headers = await _getAuthHeaders();
    final response = await http.get(url, headers: headers);
    return _handleResponse(response);
  }

  /// ✅ New function to get only the 10 most recent enquiries.
  Future<List<dynamic>> getRecentEnquiries() async {
    final url = Uri.parse('$_baseUrl/enquiries/recent/');
    final headers = await _getAuthHeaders();
    final response = await http.get(url, headers: headers);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> searchEnquiries({
    required String query,
    int page = 1,
  }) async {
    final url = Uri.parse('$_baseUrl/enquiries/search/?q=$query&page=$page');
    final headers = await _getAuthHeaders();
    final response = await http.get(url, headers: headers);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> createInteraction(Map<String, dynamic> data) async {
    final url = Uri.parse('$_baseUrl/interactions/');
    final headers = await _getAuthHeaders();
    final response = await http.post(url, headers: headers, body: jsonEncode(data));
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

  
}