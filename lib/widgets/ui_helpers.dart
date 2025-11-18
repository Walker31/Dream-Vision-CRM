import 'package:flutter/material.dart';

extension AsyncHandler on BuildContext {
  Future<void> safeApiCall(
    Future<dynamic> Function() action, {
    VoidCallback? onSuccess,
    bool showSuccessMessage = false,
    String successMessage = 'Operation successful',
  }) async {
    // 1. Close Keyboard
    FocusScope.of(this).unfocus();

    try {
      await action();

      if (mounted) {
        if (showSuccessMessage) {
          ScaffoldMessenger.of(this).showSnackBar(
            SnackBar(
              content: Text(successMessage),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.fixed, 
            ),
          );
        }
        onSuccess?.call();
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString().replaceAll('Exception: ', '');

        // Hide any previous snackbar to prevent stacking/lag
        ScaffoldMessenger.of(this).hideCurrentSnackBar(); 

        ScaffoldMessenger.of(this).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.fixed,
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(this).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
    }
  }
}