import 'package:flutter/material.dart';
import 'package:dreamvision/services/auth_service.dart';
import 'package:dreamvision/models/user_model.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

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

  void _clearError() {
    _errorMessage = '';
  }

  // ---------------------------------------------------------------------------
  // LOGIN
  // ---------------------------------------------------------------------------
  Future<bool> login(String username, String password) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _authService.login(username, password);

      if (response['user'] == null) {
        throw Exception('Invalid login response');
      }

      _user = User.fromLoginJson(response['user']);
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _user = null;
      _setLoading(false);
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // AUTO LOGIN (CRITICAL FIX)
  // ---------------------------------------------------------------------------
  Future<bool> tryAutoLogin() async {
    try {
      final token = await _authService.getAccessToken();

      // ❌ No token → definitely not logged in
      if (token == null || token.isEmpty) {
        await logout();
        return false;
      }

      // 🔄 Try fetching profile
      final profileData = await _authService.getUserProfile();
      _user = User.fromJson(profileData);

      notifyListeners();
      return true;
    } catch (_) {
      // ❌ ANY failure → force logout
      await logout();
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // LOGOUT (SINGLE SOURCE OF TRUTH)
  // ---------------------------------------------------------------------------
  Future<void> logout() async {
    _user = null;
    _errorMessage = '';
    await _authService.logout();
    notifyListeners();
  }
}
