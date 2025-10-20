import 'dart:convert';
import 'dart:io';

import 'package:dreamvision/config/constants.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

class AdminUserService {
  static const String _baseUrl = baseUrl;
  final _storage = const FlutterSecureStorage();
  Logger logger = Logger();

  Future<Map<String, String>> _getAuthHeaders({bool isJson = true}) async {
    String? token = await _storage.read(key: 'access_token');
    if (token == null) {
      throw const SocketException('Authentication token not found. Please log in.');
    }
    return {
      if (isJson) 'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token',
    };
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode == 204) {
       logger.d('API Response [204]: No Content (Success)');
       return {'detail': 'Operation successful.'};
    }
    if (response.body.isEmpty) {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        logger.d('API Response [${response.statusCode}]: Empty body (Success)');
        return {};
      } else {
        logger.w('API Response [${response.statusCode}]: Empty body (Error)');
        throw Exception('API Error [${response.statusCode}]: Received empty response from server.');
      }
    }

    try {
      final responseBody = jsonDecode(response.body);
      logger.d('API Response [${response.statusCode}]: $responseBody');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return responseBody;
      } else {
        String errorMessage = 'An unknown error occurred.';
        if (responseBody is Map) {
          errorMessage = responseBody['detail']?.toString() ??
                         responseBody['error']?.toString() ??
                         responseBody.entries.map((e) => '${e.key}: ${e.value is List ? e.value.join(', ') : e.value}').join('\n') ;

           if (responseBody.containsKey('details') && responseBody['details'] is List) {
             final details = (responseBody['details'] as List).join('\n');
              errorMessage = 'Validation failed.\n$details';
           } else if (response.statusCode == 400 && responseBody.entries.isNotEmpty) {
               errorMessage = responseBody.entries
                    .map((e) {
                       String keyFormatted = e.key.replaceAll('_', ' ');
                       String capitalizedKey = keyFormatted.capitalize();
                       String valueFormatted = e.value is List ? e.value.join(', ') : e.value.toString();
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
      logger.e('Failed to decode JSON response: ${response.body}', error: e);
      throw Exception('Failed to process server response. Invalid format.');
    } catch (e) {
       logger.e('Error handling response: ${e.toString()}');
       rethrow;
    }
  }


  Future<Map<String, dynamic>> addUser(Map<String, dynamic> data) async {
    final url = Uri.parse('$_baseUrl/users/admin/add-user/');
    final headers = await _getAuthHeaders(isJson: true);
    logger.d('Adding User: ${jsonEncode(data)}');
    final response = await http.post(url, headers: headers, body: jsonEncode(data));
    return _handleResponse(response);
  }

  Future<List<dynamic>> listUsers() async {
    final url = Uri.parse('$_baseUrl/users/admin/list-users/');
    final headers = await _getAuthHeaders(isJson: false);
    logger.d('Fetching user list from: $url');
    final response = await http.get(url, headers: headers);
     final responseBody = _handleResponse(response);
     if (responseBody is Map && responseBody.containsKey('results')) {
        return responseBody['results'] as List<dynamic>;
     } else if (responseBody is List) {
        return responseBody;
     } else {
        logger.w('Unexpected format for user list: $responseBody');
        throw Exception('Received unexpected data format for user list.');
     }
  }

  Future<Map<String, dynamic>> deleteUser(int userId) async {
    final url = Uri.parse('$_baseUrl/users/admin/delete-user/$userId/');
    final headers = await _getAuthHeaders(isJson: false);
    logger.i('Attempting to delete user with ID: $userId at URL: $url');

    final response = await http.delete(url, headers: headers);

    return _handleResponse(response);
  }
}