import 'package:dreamvision/models/user_model.dart';
import 'package:dreamvision/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class EmployeeDetailsPage extends StatelessWidget {
  const EmployeeDetailsPage({super.key});

  // Helper to format dates, returns 'N/A' if date is null
  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final DateTime date = DateTime.parse(dateStr);
      return DateFormat('d MMMM yyyy').format(date);
    } catch (e) {
      return dateStr; // Return original string if parsing fails
    }
  }

  @override
  Widget build(BuildContext context) {
    // Access the user data from the AuthProvider
    final authProvider = Provider.of<AuthProvider>(context);
    final User? user = authProvider.user;
    // Show a loading indicator if user data is not yet available
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Employee Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      // The background color is now handled by the global theme
      appBar: AppBar(
        elevation: 0,
        // AppBar colors are inherited from the theme
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
            // Profile Header
            _buildProfileHeader(
              context: context,
              name: user.fullName,
              email: user.email,
              staffId: user.staffId,
              profilePictureUrl: user.profilePicture,
            ),
            const SizedBox(height: 20),

            // Personal Information Card
            _buildDetailCard(
              context,
              icon: Icons.person_outline,
              title: 'Personal Information',
              details: [
                _buildDetailRow(context, Icons.badge_outlined, 'Staff ID', user.staffId),
                _buildDetailRow(context, Icons.person, 'First Name', user.firstName),
                _buildDetailRow(context, Icons.person_outline, 'Last Name', user.lastName),
                _buildDetailRow(context, Icons.email_outlined, 'Email', user.email),
                _buildDetailRow(context, Icons.phone_outlined, 'Phone Number',
                    user.phoneNumber.isNotEmpty ? user.phoneNumber : 'N/A'),
                _buildDetailRow(context, Icons.location_on_outlined, 'Address',
                    user.address.isNotEmpty ? user.address : 'N/A'),
              ],
            ),

            _buildDetailCard(
              context,
              icon: Icons.work_outline,
              title: 'Work Information',
              details: [
                _buildDetailRow(context, Icons.account_tree_outlined, 'Department',
                    user.department ?? 'N/A'),
                _buildDetailRow(context, Icons.supervisor_account_outlined, 'Supervisor',
                    user.supervisor ?? 'N/A'),
                _buildDetailRow(
                    context, Icons.schedule_outlined, 'Shift', user.shift ?? 'N/A'),
                _buildDetailRow(
                    context, Icons.person_pin_outlined, 'Username', user.username),
                _buildDetailRow(context, Icons.lock_outline, 'Password', '••••••••'),
              ],
            ),

            _buildDetailCard(
              context,
              icon: Icons.verified_user_outlined,
              title: 'Employment Status',
              details: [
                _buildDetailRow(context, Icons.calendar_today_outlined,
                    'Date of Joining', _formatDate(user.dateOfJoining)),
                _buildDetailRow(context, Icons.event_busy_outlined,
                    'Date of Resignation', _formatDate(user.dateOfResignation)),
                _buildDetailRow(context, Icons.circle, 'Status', user.status,
                    valueColor: user.status.toLowerCase() == 'active'
                        ? Colors.green.shade700 // Semantic color
                        : Colors.red.shade700), // Semantic color
                _buildDetailRow(context, Icons.update_outlined, 'Last Update',
                    _formatDate(user.updatedAt)),
                _buildDetailRow(context, Icons.comment_outlined, 'Remarks',
                    user.remarks.isNotEmpty ? user.remarks : 'No remarks.'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 🧍 Profile Header Section
  Widget _buildProfileHeader({
    required BuildContext context,
    required String name,
    required String email,
    required String staffId,
    required String profilePictureUrl,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor, // Theme-aware card color
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.1), // Theme-aware shadow
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: colorScheme.primaryContainer, // Theme-aware
            backgroundImage: NetworkImage(profilePictureUrl),
            onBackgroundImageError: (_, __) {},
            child: profilePictureUrl.isEmpty
                ? Text(
                    name.isNotEmpty ? name[0] : 'U',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer, // Theme-aware
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Staff ID: $staffId',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 📄 Detail Card with Title + Icon
  Widget _buildDetailCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required List<Widget> details,
  }) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor, // Theme-aware card color
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha : 0.1), // Theme-aware shadow
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary), // Theme-aware icon color
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
          const Divider(height: 24),
          ...details,
        ],
      ),
    );
  }

  // 📌 Row with Icon + Label + Value
  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary), // Theme-aware
          const SizedBox(width: 12),
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha:0.8),
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
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  // Use provided valueColor or default to the theme's text color
                  color: valueColor ?? theme.textTheme.bodyLarge?.color,
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
