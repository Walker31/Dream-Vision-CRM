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

    _user = User.fromLoginJson(response['user']);
    _setLoading(false);
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
  // LOGOUT
  // ---------------------------------------------------------------------------

  Future<void> logout() async {
    _user = null;
    _errorMessage = '';
    await _authService.clearTokens();
    notifyListeners();
  }
}