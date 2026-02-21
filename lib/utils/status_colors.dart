import 'package:flutter/material.dart';

/// Centralized status color configuration for the entire app
class StatusColors {
  // Base colors for each status (used in charts and simple displays)
  static const Map<String, Color> baseColors = {
    'follow-up': Color(0xFFF57C00), // orange.shade600
    'interested': Color(0xFF1976D2), // blue.shade600
    'closed': Color(0xFF757575), // grey.shade600
    'visited': Color(0xFF388E3C), // green.shade600
    'converted': Color(0xFF00897B), // teal.shade600
    'cnr': Color(0xFFD32F2F), // red.shade600
  };

  /// Get base color for a status
  static Color getBaseColor(String? status) {
    if (status == null) return Colors.purple.shade600;
    return baseColors[status.toLowerCase()] ?? Colors.purple.shade600;
  }

  /// Get dark/light mode aware colors for a status
  static ({Color bg, Color text}) getThemedColors(
    BuildContext context,
    String status,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = getBaseColor(status);

    if (isDark) {
      return (
        bg: baseColor.withValues(alpha: 0.2),
        text: baseColor.withValues(alpha: 0.9),
      );
    } else {
      return (bg: baseColor.withValues(alpha: 0.85), text: Colors.white);
    }
  }

  /// Alternative: Get shade600 variant for simple displays (charts, etc.)
  static Color getShade600Color(String? status) {
    if (status == null) return Colors.purple.shade600;
    
    final normalized = status.toLowerCase().trim();
    
    switch (normalized) {
      case 'follow-up':
        return Colors.orange.shade600;
      case 'interested':
        return Colors.blue.shade600;
      case 'closed':
        return Colors.grey.shade600;
      case 'visited':
        return Colors.green.shade600;
      case 'converted':
        return Colors.teal.shade600;
      case 'cnr':
        return Colors.red.shade600;
      // Additional statuses from DB
      case 'new':
        return Colors.purple.shade600;
      case 'not interested':
        return Colors.red.shade600;
      case 'admission confirmed':
        return Colors.teal.shade600;
      default:
        return Colors.purple.shade600;
    }
  }
}
