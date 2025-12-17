import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class GlobalErrorHandler {
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  /// UNIVERSAL ERROR DISPLAY
  static void showError(String message) {
    if (message.trim().isEmpty) message = "Something went wrong";

    // -------------------------------------------------------------
    // iOS Fallback → Toast (Snackbars often fail inside BottomSheets)
    // -------------------------------------------------------------
    if (Platform.isIOS) {
      Fluttertoast.showToast(
        msg: message,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red.shade700,
        textColor: Colors.white,
        fontSize: 16,
      );
      return;
    }

    // -------------------------------------------------------------
    // ANDROID → Custom Snackbar Theme
    // -------------------------------------------------------------
    if (messengerKey.currentState == null) return;

    messengerKey.currentState!.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        elevation: 8,
        backgroundColor: Colors.red.shade700,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
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
}
