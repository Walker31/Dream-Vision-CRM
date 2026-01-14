import 'package:flutter/material.dart';

/// User-friendly error messages mapping
class ErrorHelper {
  /// Map technical errors to user-friendly messages
  static String getUserMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    // Network errors
    if (errorStr.contains('socket') || errorStr.contains('connection refused')) {
      return 'Unable to connect. Please check your internet connection.';
    }
    if (errorStr.contains('timeout')) {
      return 'Request took too long. Please try again.';
    }
    if (errorStr.contains('failed host lookup')) {
      return 'Network error. Please check your connection.';
    }

    // Server errors
    if (errorStr.contains('403') || errorStr.contains('forbidden')) {
      return 'You don\'t have permission to perform this action.';
    }
    if (errorStr.contains('404') || errorStr.contains('not found')) {
      return 'Resource not found. Please refresh and try again.';
    }
    if (errorStr.contains('500') || errorStr.contains('internal server')) {
      return 'Server error. Please try again later.';
    }
    if (errorStr.contains('502') || errorStr.contains('bad gateway')) {
      return 'Server temporarily unavailable. Please try again.';
    }

    // Authentication
    if (errorStr.contains('401') || errorStr.contains('unauthorized')) {
      return 'Session expired. Please log in again.';
    }

    // Validation
    if (errorStr.contains('validation')) {
      return 'Please check your input and try again.';
    }

    // Default
    return 'Something went wrong. Please try again.';
  }

  /// Check if error is network-related (retryable)
  static bool isNetworkError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('socket') ||
        errorStr.contains('timeout') ||
        errorStr.contains('connection') ||
        errorStr.contains('host lookup') ||
        errorStr.contains('500') ||
        errorStr.contains('502') ||
        errorStr.contains('503');
  }

  /// Show retry dialog
  static Future<bool?> showRetryDialog(
    BuildContext context,
    String message, {
    String title = 'Error',
    String retryLabel = 'Retry',
    String cancelLabel = 'Cancel',
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(retryLabel),
          ),
        ],
      ),
    );
  }
}

/// Retry policy for failed API calls
class RetryPolicy {
  final int maxAttempts;
  final Duration delay;
  final double backoffMultiplier;

  RetryPolicy({
    this.maxAttempts = 3,
    this.delay = const Duration(milliseconds: 800),
    this.backoffMultiplier = 1.5,
  });

  /// Execute function with retry logic
  Future<T> execute<T>(Future<T> Function() fn) async {
    int attempts = 0;
    Duration currentDelay = delay;

    while (attempts < maxAttempts) {
      try {
        return await fn();
      } catch (e) {
        attempts++;
        // Only retry on network errors
        if (!ErrorHelper.isNetworkError(e) || attempts >= maxAttempts) {
          rethrow;
        }
        // Exponential backoff
        await Future.delayed(currentDelay);
        currentDelay *= backoffMultiplier;
      }
    }
    throw Exception('Max retry attempts exceeded');
  }
}
