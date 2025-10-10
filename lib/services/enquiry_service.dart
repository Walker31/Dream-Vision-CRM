import 'dart:convert';
import 'dart:io';

import 'package:dreamvision/config/constants.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:logger/web.dart';

class EnquiryService {
  static const String _baseUrl = '$baseUrl/crm'; // Assuming a base path for the CRM app

  final _storage = const FlutterSecureStorage();
  final Logger _logger = Logger();

  // --- PRIVATE HELPERS for clean, reusable code ---

  /// Returns the authorization headers with the JWT token.
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

  /// Handles the HTTP response, decoding JSON or throwing an error.
  dynamic _handleResponse(http.Response response) {
    final responseBody = jsonDecode(response.body);
    _logger.d('API Response [${response.statusCode}]: $responseBody');
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return responseBody;
    } else {
      // Try to get a meaningful error message from the response body
      final errorMessage = responseBody['detail'] ?? responseBody.toString();
      throw Exception('API Error: $errorMessage');
    }
  }

  // --- ENQUIRY ENDPOINTS ---

  /// Fetches a list of enquiries based on user role.
  Future<List<dynamic>> getEnquiries() async {
    final url = Uri.parse('$_baseUrl/enquiries/');
    final headers = await _getAuthHeaders();
    final response = await http.get(url, headers: headers);
    return _handleResponse(response);
  }

  /// Creates a new enquiry.
  /// The `data` map should match the structure expected by your EnquirySerializer.
  Future<Map<String, dynamic>> createEnquiry(Map<String, dynamic> data) async {
    final url = Uri.parse('$_baseUrl/enquiries/');
    final headers = await _getAuthHeaders();
    final response = await http.post(url, headers: headers, body: jsonEncode(data));
    return _handleResponse(response);
  }

  /// Searches for enquiries with a given query.
  Future<List<dynamic>> searchEnquiries(String query) async {
    final url = Uri.parse('$_baseUrl/enquiries/search/?q=$query');
    final headers = await _getAuthHeaders();
    final response = await http.get(url, headers: headers);
    return _handleResponse(response);
  }

  // --- INTERACTION ENDPOINTS ---

  /// Creates a new interaction for an enquiry.
  Future<Map<String, dynamic>> createInteraction(Map<String, dynamic> data) async {
    final url = Uri.parse('$_baseUrl/interactions/');
    final headers = await _getAuthHeaders();
    final response = await http.post(url, headers: headers, body: jsonEncode(data));
    return _handleResponse(response);
  }

  // --- LOOKUP DATA ENDPOINTS (for dropdowns) ---

  /// Fetches a list of all available schools.
  Future<List<dynamic>> getSchools() async {
    final url = Uri.parse('$_baseUrl/schools/');
    final headers = await _getAuthHeaders();
    final response = await http.get(url, headers: headers);
    return _handleResponse(response);
  }

  /// Fetches a list of all available enquiry statuses.
  Future<List<dynamic>> getEnquiryStatuses() async {
    final url = Uri.parse('$_baseUrl/statuses/');
    final headers = await _getAuthHeaders();
    final response = await http.get(url, headers: headers);
    return _handleResponse(response);
  }

  /// Fetches a list of all available enquiry sources.
  Future<List<dynamic>> getEnquirySources() async {
    final url = Uri.parse('$_baseUrl/sources/');
    final headers = await _getAuthHeaders();
    final response = await http.get(url, headers: headers);
    return _handleResponse(response);
  }

  // --- DASHBOARD ENDPOINT ---

  /// Fetches the analytics data for the dashboard.
  Future<Map<String, dynamic>> getDashboardStats() async {
    final url = Uri.parse('$_baseUrl/dashboard-stats/');
    final headers = await _getAuthHeaders();
    final response = await http.get(url, headers: headers);
    return _handleResponse(response);
  }
}