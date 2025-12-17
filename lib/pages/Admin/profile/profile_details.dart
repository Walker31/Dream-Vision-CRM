import 'package:dreamvision/models/user_model.dart';
import 'package:dreamvision/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

class EmployeeDetailsPage extends StatefulWidget {
   const EmployeeDetailsPage({super.key});

  @override
  State<EmployeeDetailsPage> createState() => _EmployeeDetailsPageState();
}

class _EmployeeDetailsPageState extends State<EmployeeDetailsPage> {
  Logger logger = Logger();

  // Helper to format date
  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final DateTime date = DateTime.parse(dateStr);
      return DateFormat('d MMMM yyyy').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final User? user = authProvider.user;
    logger.d(user?.toJson());
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text('Employee Details'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Theme.of(context).colorScheme.surface,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_rounded),
        ),
        title: const Text(
          'Employee Details',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildProfileHeader(
              context: context,
              name: user.fullName,
              email: user.email,
              staffId: user.staffId,
              profilePictureUrl: user.profilePicture,
            ),
            const SizedBox(height: 20),

            _buildDetailCard(
              context,
              icon: Icons.person_outline,
              title: 'Personal Information',
              details: [
                _buildDetailRow(
                  context,
                  Icons.badge_outlined,
                  'Staff ID',
                  user.staffId,
                ),
                _buildDetailRow(
                  context,
                  Icons.person,
                  'First Name',
                  user.firstName,
                ),
                _buildDetailRow(
                  context,
                  Icons.person_outline,
                  'Last Name',
                  user.lastName,
                ),
                _buildDetailRow(
                  context,
                  Icons.email_outlined,
                  'Email',
                  user.email,
                ),
                _buildDetailRow(
                  context,
                  Icons.phone_outlined,
                  'Phone Number',
                  user.phoneNumber.isNotEmpty ? user.phoneNumber : 'N/A',
                ),
                _buildDetailRow(
                  context,
                  Icons.location_on_outlined,
                  'Address',
                  user.address.isNotEmpty ? user.address : 'N/A',
                ),
              ],
            ),

            _buildDetailCard(
              context,
              icon: Icons.work_outline,
              title: 'Work Information',
              details: [
                _buildDetailRow(
                  context,
                  Icons.person_pin_outlined,
                  'Username',
                  user.username,
                ),
                _buildDetailRow(
                  context,
                  Icons.lock_outline,
                  'Password',
                  '••••••••',
                ),
              ],
            ),

            _buildDetailCard(
              context,
              icon: Icons.verified_user_outlined,
              title: 'Employment Status',
              details: [
                _buildDetailRow(
                  context,
                  Icons.calendar_today_outlined,
                  'Date of Joining',
                  _formatDate(user.dateOfJoining),
                ),
                _buildDetailRow(
                  context,
                  Icons.circle,
                  'Status',
                  user.status,
                  valueColor: user.status.toLowerCase() == 'active'
                      ? Theme.of(context).colorScheme.tertiary
                      : Theme.of(context).colorScheme.error,
                ),
                _buildDetailRow(
                  context,
                  Icons.update_outlined,
                  'Last Update',
                  _formatDate(user.updatedAt),
                ),
                _buildDetailRow(
                  context,
                  Icons.comment_outlined,
                  'Remarks',
                  user.remarks.isNotEmpty ? user.remarks : 'No remarks.',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- PROFILE HEADER ------------------
  Widget _buildProfileHeader({
    required BuildContext context,
    required String name,
    required String email,
    required String staffId,
    required String profilePictureUrl,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: cs.primaryContainer,
            child: Icon(Icons.person, size: 40, color: cs.onPrimaryContainer),
          ),
          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Staff ID: $staffId',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------- DETAIL CARD -------------------
  Widget _buildDetailCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required List<Widget> details,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Divider(height: 1, color: cs.outlineVariant),
          const SizedBox(height: 12),

          ...details,
        ],
      ),
    );
  }

  // ------------------- DETAIL ROW -------------------
  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: cs.primary),
          const SizedBox(width: 12),

          SizedBox(
            width: 130,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),

          Expanded(
            child: Tooltip(
              message: value,
              child: Text(
                value,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: valueColor ?? cs.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
