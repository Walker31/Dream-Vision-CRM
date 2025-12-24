import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

enum AppMessageType {
  success,
  error,
  warning,
  info,
  critical,
}

class GlobalErrorHandler {
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  /// PUBLIC API
  static void show(
    String message, {
    AppMessageType type = AppMessageType.info,
  }) {
    _display(message, type);
  }

  // Optional shortcuts (nice DX)
  static void success(String msg) => show(msg, type: AppMessageType.success);

  static void error(String msg) => show(msg, type: AppMessageType.error);

  static void warning(String msg) => show(msg, type: AppMessageType.warning);

  static void info(String msg) => show(msg, type: AppMessageType.info);

  static void critical(String msg) => show(msg, type: AppMessageType.critical);

  // INTERNAL
  static void _display(String message, AppMessageType type) {
    if (message.trim().isEmpty) {
      message = _defaultMessage(type);
    }

    final color = _color(type);
    final icon = _icon(type);

    // iOS → Toast
    if (Platform.isIOS) {
      Fluttertoast.showToast(
        msg: message,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: color,
        textColor: Colors.white,
        fontSize: 16,
      );
      return;
    }

    // Android → Snackbar
    if (messengerKey.currentState == null) return;

    messengerKey.currentState!.hideCurrentSnackBar();
    messengerKey.currentState!.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        elevation: 8,
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: _duration(type),
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // CONFIG HELPERS

  static Color _color(AppMessageType type) {
    switch (type) {
      case AppMessageType.success:
        return Colors.green.shade700;
      case AppMessageType.error:
        return Colors.red.shade700;
      case AppMessageType.warning:
        return Colors.orange.shade700;
      case AppMessageType.critical:
        return Colors.red.shade900;
      case AppMessageType.info:
      return Colors.blue.shade700;
    }
  }

  static IconData _icon(AppMessageType type) {
    switch (type) {
      case AppMessageType.success:
        return Icons.check_circle_outline;
      case AppMessageType.error:
        return Icons.error_outline;
      case AppMessageType.warning:
        return Icons.warning_amber_outlined;
      case AppMessageType.critical:
        return Icons.report_gmailerrorred_outlined;
      case AppMessageType.info:
      return Icons.info_outline;
    }
  }

  static Duration _duration(AppMessageType type) {
    switch (type) {
      case AppMessageType.critical:
        return const Duration(seconds: 5);
      case AppMessageType.warning:
        return const Duration(seconds: 4);
      default:
        return const Duration(seconds: 3);
    }
  }

  static String _defaultMessage(AppMessageType type) {
    switch (type) {
      case AppMessageType.success:
        return "Operation successful";
      case AppMessageType.error:
        return "Something went wrong";
      case AppMessageType.warning:
        return "Please check your input";
      case AppMessageType.critical:
        return "A critical error occurred";
      case AppMessageType.info:
      return "Information";
    }
  }
}
