import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:dreamvision/services/auth_service.dart';
import 'package:dreamvision/models/user_model.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final Logger _logger = Logger();

  User? _user;
  bool _isLoading = false;
  String _errorMessage = '';

  User? get user => _user;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // LOGIN
  // ---------------------------------------------------------------------------

  Future<bool> login(String username, String password) async {
    _setLoading(true);
    _errorMessage = '';

    final response = await _authService.login(username, password);

    if (response['user'] == null) {
      _errorMessage = 'Login failed';
      _user = null;
      _setLoading(false);
      return false;
    }

    // Set initial user from login response
    _user = User.fromLoginJson(response['user']);
    
    // Fetch full profile to get complete employee details
    try {
      final profile = await _authService.getUserProfile();
      if (profile.isNotEmpty) {
        _user = User.fromJson(profile);
      }
    } catch (e) {
      // If profile fetch fails, continue with basic login data
      _logger.w('Could not fetch full profile after login: $e');
    }
    
    _setLoading(false);
    notifyListeners();
    return true;
  }

  // ---------------------------------------------------------------------------
  // AUTO LOGIN
  // ---------------------------------------------------------------------------

  Future<bool> tryAutoLogin() async {
    final token = await _authService.getAccessToken();

    if (token == null) return false;

    final profile = await _authService.getUserProfile();
    if (profile.isEmpty) return false;

    _user = User.fromJson(profile);
    notifyListeners();
    return true;
  }

  // ---------------------------------------------------------------------------
  // REFRESH PROFILE
  // ---------------------------------------------------------------------------

  Future<bool> refreshProfile() async {
    try {
      final profile = await _authService.getUserProfile();
      if (profile.isEmpty) return false;
      
      _user = User.fromJson(profile);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to refresh profile: $e';
      notifyListeners();
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // LOGOUT
  // ---------------------------------------------------------------------------

  Future<void> logout() async {
    _user = null;
    _errorMessage = '';
    await _authService.clearTokens();
    notifyListeners();
  }
}