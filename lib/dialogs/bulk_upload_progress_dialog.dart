import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dreamvision/services/enquiry_service.dart';

class BulkUploadProgressDialog extends StatefulWidget {
  final String sessionId;
  final int totalRecords;

  const BulkUploadProgressDialog({
    required this.sessionId,
    required this.totalRecords,
    super.key,
  });

  @override
  State<BulkUploadProgressDialog> createState() =>
      _BulkUploadProgressDialogState();
}

class _BulkUploadProgressDialogState extends State<BulkUploadProgressDialog>
    with TickerProviderStateMixin {
  late final EnquiryService _enquiryService;
  late Timer _progressTimer;
  late AnimationController _progressController;
  late AnimationController _fadeController;

  int _currentCount = 0;
  int _percentage = 0;
  String _status = 'Starting upload...';
  bool _isCompleted = false;
  Map<String, dynamic>? _result;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _enquiryService = EnquiryService();
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _startProgressTracking();
  }

  void _startProgressTracking() {
    // Poll every 500ms for progress updates
    _progressTimer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      try {
        final progress =
            await _enquiryService.getUploadProgress(widget.sessionId);

        if (mounted) {
          setState(() {
            _currentCount = progress['current'] ?? 0;
            _percentage = progress['percentage'] ?? 0;
            _status = progress['status'] ?? 'Processing...';

            // Animate progress
            _progressController.forward(from: 0.0);

            // Check if completed
            if (_status.contains('completed')) {
              _isCompleted = true;
              _result = progress;
              _progressTimer.cancel();
              _fadeController.forward();
            } else if (_status.contains('error')) {
              _isCompleted = true;
              _errorMessage = _status;
              _progressTimer.cancel();
              _fadeController.forward();
            }
          });
        }
      } catch (e) {
        // Silent fail during polling, will retry
      }
    });
  }

  @override
  void dispose() {
    _progressTimer.cancel();
    _progressController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Color _getStatusColor() {
    if (_errorMessage != null) return const Color(0xFFEF5350);
    if (_isCompleted) return const Color(0xFF66BB6A);
    if (_percentage > 50) return const Color(0xFF29B6F6);
    return const Color(0xFFAB47BC);
  }

  IconData _getStatusIcon() {
    if (_errorMessage != null) return Icons.error_outline;
    if (_isCompleted) return Icons.check_circle;
    if (_percentage > 50) return Icons.cloud_upload;
    return Icons.upload_file;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode ? Colors.grey.shade900 : Colors.grey.shade50;
    final _ = isDarkMode ? Colors.grey.shade800 : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final secondaryTextColor = isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;

    return PopScope(
      canPop: _isCompleted,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 16,
        backgroundColor: bgColor,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDarkMode
                  ? [Colors.grey.shade900, Colors.grey.shade800]
                  : [Colors.grey.shade50, Colors.white],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with Icon
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getStatusColor().withValues(alpha:isDarkMode ? 0.25 : 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getStatusIcon(),
                        color: _getStatusColor(),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isCompleted ? 'Upload Complete' : 'Uploading',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                  color: textColor,
                                ),
                          ),
                          Text(
                            '$_currentCount of ${widget.totalRecords} records',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: secondaryTextColor,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Progress Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _getStatusColor().withValues(alpha:isDarkMode ? 0.12 : 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getStatusColor().withValues(alpha:isDarkMode ? 0.3 : 0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Progress Bar with Animation
                      ScaleTransition(
                        scale: Tween<double>(begin: 0.95, end: 1.0)
                            .animate(_progressController),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: _percentage / 100,
                            minHeight: 10,
                            backgroundColor: isDarkMode
                                ? Colors.grey.shade700
                                : Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _getStatusColor(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Percentage and Count
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Progress',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: secondaryTextColor,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$_percentage%',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: _getStatusColor(),
                                    ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Speed',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: secondaryTextColor,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${(_currentCount > 0 ? (_currentCount * 1000 / _progressTimer.tick ~/ 1000).toStringAsFixed(0) : 0)} rec/s',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: _getStatusColor(),
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Status Message
                AnimatedOpacity(
                  opacity: _errorMessage != null || _isCompleted ? 1.0 : 0.7,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _errorMessage != null
                          ? (isDarkMode
                              ? const Color(0xFF5D1F1F)
                              : const Color(0xFFFFEBEE))
                          : _isCompleted
                              ? (isDarkMode
                                  ? const Color(0xFF1B5E20)
                                  : const Color(0xFFE8F5E9))
                              : (isDarkMode
                                  ? const Color(0xFF0D47A1)
                                  : const Color(0xFFE3F2FD)),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _getStatusColor().withValues(alpha:
                            isDarkMode ? 0.5 : 0.3),
                      ),
                    ),
                    child: Text(
                      _errorMessage ??
                          (_isCompleted
                              ? '✓ All records processed successfully!'
                              : _status),
                      style: TextStyle(
                        color: _getStatusColor(),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

                // Results Summary
                if (_result != null && _isCompleted) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDarkMode
                            ? Colors.grey.shade700
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Summary',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                        ),
                        const SizedBox(height: 12),
                        _ResultRow(
                          icon: Icons.add_circle_outline,
                          label: 'Created',
                          value: '${_result!['total_created'] ?? 0}',
                          color: const Color(0xFF66BB6A),
                          isDarkMode: isDarkMode,
                        ),
                        const SizedBox(height: 8),
                        _ResultRow(
                          icon: Icons.edit_outlined,
                          label: 'Updated',
                          value: '${_result!['total_updated'] ?? 0}',
                          color: const Color(0xFF29B6F6),
                          isDarkMode: isDarkMode,
                        ),
                        if (_result!['assigned_telecaller_name'] != null) ...[
                          const SizedBox(height: 8),
                          _ResultRow(
                            icon: Icons.person_outline,
                            label: 'Assigned to',
                            value: _result!['assigned_telecaller_name'],
                            color: const Color(0xFFAB47BC),
                            isDarkMode: isDarkMode,
                          ),
                        ],
                        if (_result!['errors'] != null &&
                            (_result!['errors'] as Map).isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _ResultRow(
                            icon: Icons.warning_outlined,
                            label: 'Errors',
                            value: '${(_result!['errors'] as Map).length}',
                            color: const Color(0xFFEF5350),
                            isDarkMode: isDarkMode,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // Action Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isCompleted
                        ? () => Navigator.of(context).pop(_result)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isCompleted
                          ? _getStatusColor()
                          : (isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      disabledBackgroundColor:
                          isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                      disabledForegroundColor:
                          isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500,
                      elevation: _isCompleted ? 4 : 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      _isCompleted ? 'Done' : 'Processing...',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDarkMode;

  const _ResultRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha:isDarkMode ? 0.25 : 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 18,
            color: color,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isDarkMode ? Colors.grey.shade400 : Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
