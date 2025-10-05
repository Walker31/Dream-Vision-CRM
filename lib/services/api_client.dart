import 'dart:convert';
import 'package:dreamvision/config/constants.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ApiClient {
  final String _baseUrl = baseUrl;
  final AuthService _authService = AuthService();

  Future<http.Response> get(String endpoint) async {
    String? token = await _authService.getAccessToken();
    
    http.Response response = await http.get(
      Uri.parse('$_baseUrl$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 401) {
      // Token expired, try to refresh it
      try {
        final newToken = await _authService.refreshToken();
        if (newToken != null) {
          // Retry the request with the new token
          response = await http.get(
            Uri.parse('$_baseUrl$endpoint'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $newToken',
            },
          );
        }
      } catch (e) {
        // Refresh failed, rethrow exception to force logout in UI
        rethrow;
      }
    }
    return response;
  }
  
  // You can create similar wrappers for POST, PUT, DELETE etc.
  Future<http.Response> post(String endpoint, Map<String, dynamic> body) async {
      String? token = await _authService.getAccessToken();
      // ... same logic as GET
      // ...
      return http.post(Uri.parse('$_baseUrl$endpoint'), 
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        }, 
        body: json.encode(body)
      );
  }
}