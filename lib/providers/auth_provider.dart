// lib/providers/auth_provider.dart
import 'package:flutter/material.dart';
import 'package:dreamvision/services/auth_service.dart';
import 'package:dreamvision/services/api_client.dart';
import 'package:dreamvision/models/user_model.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final ApiClient _apiClient = ApiClient();

  User? _user;
  bool _isLoading = false;
  String _errorMessage = '';

  User? get user => _user;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = '';
  }

  /// Logs the user in, gets tokens, then fetches the user profile.
  Future<bool> login(String username, String password) async {
    _setLoading(true);
    _clearError();

    try {
      // Step 1: Login to get and store tokens. 
      // AuthService handles the API call and secure storage.
      await _authService.login(username, password);
      
      // Step 2: After a successful login, fetch the user's profile data.
      await _fetchUserProfile();
      
      _setLoading(false);
      return true; // Success!
      
    } catch (e) {
      // Clean up the exception message for the UI
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false; // Failed
    }
  }

  /// Fetches the user profile from the server using the stored token.
  Future<void> _fetchUserProfile() async {
    try {
      // FIXED: ApiClient.get now returns the data (Map) directly.
      // We don't check statusCode here because ApiClient throws an exception on error.
      final dynamic responseData = await _apiClient.get('/users/profile/'); 
      
      if (responseData is Map<String, dynamic>) {
        // JSON decoding is already done by Dio
        _user = User.fromJson(responseData); 
        notifyListeners();
      } else {
        throw Exception('Invalid profile data format received.');
      }
    } catch (e) {
      // If profile fetch fails, we shouldn't stay "logged in" with no user data.
      await logout(); 
      rethrow;
    }
  }

  /// Logs the user out and clears all user data and tokens.
  Future<void> logout() async {
    await _authService.logout(); // Clears tokens from secure storage
    _user = null;
    notifyListeners();
  }
}