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

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = '';
  }

  Future<bool> login(String username, String password) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _authService.login(username, password);

      if (response['user'] != null) {
        _user = User.fromLoginJson(response['user']);
      }

      notifyListeners();
      _setLoading(false);
      return true;

    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  Future<void> _fetchUserProfile() async {
    try {
      final responseData = await _authService.getUserProfile();

      _user = User.fromJson(responseData);
      notifyListeners();
        } catch (e) {
      await logout();
      rethrow;
    }
  }

  Future<bool> tryAutoLogin() async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null || token.isEmpty) return false;

      await _fetchUserProfile();
      return _user != null;
    } catch (e) {
      return false;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    notifyListeners();
  }
}
