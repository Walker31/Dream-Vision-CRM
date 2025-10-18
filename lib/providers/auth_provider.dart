// lib/providers/auth_provider.dart
import 'dart:convert';

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
      // Step 1: Login to get and store tokens. This does not return user data.
      await _authService.login(username, password);
      
      // Step 2: After a successful login, fetch the user's profile data.
      await _fetchUserProfile();
      
      _setLoading(false);
      return true; // Success!
      
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
      return false; // Failed
    }
  }

  /// Fetches the user profile from the server using the stored token.
  Future<void> _fetchUserProfile() async {
    try {
      final response = await _apiClient.get('/users/profile/'); // Use ApiClient
      
      if (response.statusCode == 200) {
        final profileData = json.decode(response.body);
        _user = User.fromJson(profileData); // Use the corrected fromJson
        notifyListeners();
      } else {
        await logout(); // Fail safely
        throw Exception('Could not fetch user profile.');
      }
    } catch (e) {
      await logout(); // Fail safely
      rethrow;
    }
  }

  /// Logs the user out and clears all user data and tokens.
  Future<void> logout() async {
    await _authService.logout(); // This should clear tokens from secure storage
    _user = null;
    notifyListeners();
  }
}