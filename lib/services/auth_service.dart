import 'dart:convert';
import 'package:dreamvision/config/constants.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

class AuthService {
  static const String _baseUrl = baseUrl;
  final _storage = const FlutterSecureStorage();
  Logger logger = Logger();

  Future<void> _storeTokens(Map<String, dynamic> tokens) async {
    await _storage.write(key: 'access_token', value: tokens['access']);
    await _storage.write(key: 'refresh_token', value: tokens['refresh']);
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: 'access_token');
  }

  Future<void> logout() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    final url = Uri.parse('$_baseUrl/users/login/');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'username': username, 'password': password}),
    );
    final responseBody = json.decode(response.body);

    if (response.statusCode == 200) {
      logger.d(responseBody);
      await _storeTokens(responseBody);
      return responseBody;
    } else {
      logger.e(responseBody['detail']);
      throw Exception(responseBody['detail'] ?? 'Failed to login.');
    }
  }

  Future<Map<String, dynamic>> getUserProfile() async {
    String? token = await getAccessToken();
    if (token == null) {
      throw Exception('Not authenticated. Please login.');
    }

    final url = Uri.parse('$_baseUrl/users/profile/');
    
    var response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 401) {
      logger.i('Access token expired. Refreshing token...');
      try {
        final newAccessToken = await refreshToken();

        logger.i('Retrying request with new token...');
        response = await http.get(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $newAccessToken',
          },
        );
      } catch (e) {
        rethrow;
      }
    }
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      logger.e('Failed to fetch user profile. Status: ${response.statusCode}, Body: ${response.body}');
      throw Exception('Failed to load user profile.');
    }
  }

  Future<String?> refreshToken() async {
    final refreshToken = await _storage.read(key: 'refresh_token');
    if (refreshToken == null) {
      await logout();
      throw Exception('User not authenticated.');
    }

    final url = Uri.parse('$_baseUrl/api/token/refresh/');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'refresh': refreshToken}),
    );

    if (response.statusCode == 200) {
      final newTokens = json.decode(response.body);
      await _storage.write(key: 'access_token', value: newTokens['access']);
      return newTokens['access'];
    } else {
      await logout();
      throw Exception('Session expired. Please login again.');
    }
  }

  Future<void> signUp({
    required String username,
    required String password,
    required String email,
    required String firstName,
    required String lastName,
    required String role,
  }) async {
    final url = Uri.parse('$_baseUrl/users/register/');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'username': username,
        'password': password,
        'password2': password,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'role': role,
      }),
    );
    if (response.statusCode != 201) {
      final errorData = json.decode(response.body);
      String errorMessage = _formatErrors(errorData);
      throw Exception(errorMessage);
    }
  }

  String _formatErrors(Map<String, dynamic> errors) {
    var buffer = StringBuffer();
    errors.forEach((key, value) {
      if (value is List) {
        buffer.writeln('${key.replaceAll('_', ' ').capitalize()}: ${value.join(', ')}');
      }
    });
    return buffer.toString().trim().isEmpty ? 'An unknown error occurred.' : buffer.toString();
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}