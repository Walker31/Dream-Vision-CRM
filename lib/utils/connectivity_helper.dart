// ignore_for_file: unrelated_type_equality_checks

import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityHelper {
  static final Connectivity _connectivity = Connectivity();
  static bool _isOnline = true;

  /// Initialize connectivity listener
  static void init() {
    _connectivity.onConnectivityChanged.listen((result) {
      _isOnline = result != ConnectivityResult.none;
    });
  }

  /// Check if device is online
  static Future<bool> isOnline() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _isOnline = result != ConnectivityResult.none;
      return _isOnline;
    } catch (_) {
      return _isOnline;
    }
  }

  /// Get cached online status
  static bool get isOnlineSync => _isOnline;
}
