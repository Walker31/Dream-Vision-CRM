// ignore_for_file: use_build_context_synchronously

import 'dart:typed_data';
import 'package:dreamvision/widgets/back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:file_saver/file_saver.dart';
import '../../services/admin_user.dart';
import '../../widgets/password_display_dialog.dart';

class User {
  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String? staffId;
  final String role;

  String get name => '$firstName $lastName'.trim();

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.staffId,
    required this.role,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final userData = json['user'] as Map<String, dynamic>? ?? {};
    return User(
      id: userData['id'] ?? 0,
      username: userData['username'] ?? 'N/A',
      email: userData['email'] ?? 'N/A',
      firstName: userData['first_name'] ?? '',
      lastName: userData['last_name'] ?? '',
      staffId: json['staff_id'] as String?,
      role: json['role'] ?? 'Unknown',
    );
  }
}

class UserListPage extends StatefulWidget {
  const UserListPage({super.key});
  @override
  State<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> {
  final AdminUserService _adminUserService = AdminUserService();
  final _searchController = TextEditingController();
  List<User> _allUsers = [];
  List<User> _filteredUsers = [];
  bool _isLoading = true;
  bool _isExporting = false;
  String? _error;
  Logger logger = Logger();

  @override
  void initState() {
    super.initState();
    _refreshUsers();
    _searchController.addListener(_filterUsers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshUsers() async {
    if (!_isLoading) setState(() => _isLoading = true);
    setState(() => _error = null);
    try {
      final responseData = await _adminUserService.listUsers();
      final users = responseData
          .map((u) => User.fromJson(u as Map<String, dynamic>))
          .toList();
      setState(() {
        _allUsers = users;
        _filterUsers();
      });
    } catch (e) {
      setState(() => _error = 'Failed to load users: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredUsers = query.isEmpty
          ? _allUsers
          : _allUsers.where((user) {
              return user.name.toLowerCase().contains(query) ||
                  user.email.toLowerCase().contains(query) ||
                  user.username.toLowerCase().contains(query);
            }).toList();
    });
  }

  Future<void> _navigateToAddUser() async {
    final result = await context.push('/add-user');
    if (result == true && mounted) _refreshUsers();
  }

  void _deleteUser(User user) {
    _adminUserService.deleteUser(user.id);
    setState(() {
      _allUsers.removeWhere((u) => u.id == user.id);
      _filterUsers();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${user.name} has been deleted.'),
        backgroundColor: Colors.orange[700],
      ),
    );
  }

  void _showDeleteConfirmationDialog(User user) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text('Delete ${user.name}? This cannot be undone.'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Delete'),
              onPressed: () {
                _deleteUser(user);
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  void _showPasswordResetConfirmationDialog(User user) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reset Password'),
          content: Text(
            'Are you sure you want to reset password for ${user.name}?',
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () async {
                Navigator.pop(context);
                await _resetPassword(user);
              },
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _resetPassword(User user) async {
    try {
      final response = await _adminUserService.resetPassword(user.id);
      final newPassword = response['new_password'];
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) {
          return PasswordDisplayDialog(
            title: "Password Reset Successful",
            username: user.username,
            password: newPassword,
          );
        },
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _exportUsers() async {
    if (_filteredUsers.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No users to export.')));
      return;
    }

    setState(() => _isExporting = true);

    try {
      final workbook = xlsio.Workbook();
      final sheet = workbook.worksheets[0];

      sheet.getRangeByName('A1').setText('User Directory');
      final titleStyle = workbook.styles.add('title');
      titleStyle.bold = true;
      titleStyle.fontSize = 16;
      sheet.getRangeByName('A1').cellStyle = titleStyle;

      final headers = ['ID', 'Username', 'Name', 'Email', 'Role', 'Staff ID'];
      for (int i = 0; i < headers.length; i++) {
        sheet.getRangeByIndex(3, i + 1).setText(headers[i]);
      }

      final headerStyle = workbook.styles.add('h');
      headerStyle.bold = true;
      headerStyle.backColor = '#E8EEF6';
      headerStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      sheet.getRangeByName('A3:F3').cellStyle = headerStyle;

      int row = 4;
      for (final u in _filteredUsers) {
        sheet.getRangeByIndex(row, 1).setNumber(u.id.toDouble());
        sheet.getRangeByIndex(row, 2).setText(u.username);
        sheet.getRangeByIndex(row, 3).setText(u.name);
        sheet.getRangeByIndex(row, 4).setText(u.email);
        sheet.getRangeByIndex(row, 5).setText(u.role);
        sheet.getRangeByIndex(row, 6).setText(u.staffId ?? '');
        row++;
      }

      sheet.getRangeByName('A3:F${row - 1}').cellStyle.borders.all.lineStyle =
          xlsio.LineStyle.thin;

      for (int c = 1; c <= 6; c++) {
        sheet.autoFitColumn(c);
      }

      final bytes = Uint8List.fromList(workbook.saveAsStream());
      workbook.dispose();

      await FileSaver.instance.saveFile(
        name: 'users_${DateTime.now().toIso8601String().split("T").first}',
        bytes: bytes,
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Exported successfully.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }

    if (mounted) setState(() => _isExporting = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButtonIos(),
        title: const Text('Manage Users'),
      ),

      floatingActionButton: SpeedDial(
        icon: Icons.add,
        activeIcon: Icons.close,
        foregroundColor: cs.onPrimaryContainer,
        backgroundColor: cs.primaryContainer,
        overlayColor: Colors.black,
        overlayOpacity: 0.25,
        spacing: 10,
        spaceBetweenChildren: 12,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        children: [
          SpeedDialChild(
            child: const Icon(Icons.person_add_alt_1),
            backgroundColor: cs.secondaryContainer,
            foregroundColor: cs.onSecondaryContainer,
            label: 'Add New User',
            onTap: _navigateToAddUser,
          ),
          SpeedDialChild(
            child: _isExporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download),
            backgroundColor: cs.tertiaryContainer,
            foregroundColor: cs.onTertiaryContainer,
            label: _isExporting ? 'Exporting...' : 'Export XLSX',
            onTap: _isExporting ? null : _exportUsers,
          ),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _SearchBar(controller: _searchController),
            const SizedBox(height: 16),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshUsers,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_filteredUsers.isEmpty) return _buildEmptyState();
    return RefreshIndicator(onRefresh: _refreshUsers, child: _buildUserList());
  }

  Widget _buildUserList() {
    return ListView.builder(
      itemCount: _filteredUsers.length,
      itemBuilder: (context, index) {
        final user = _filteredUsers[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6.0),
          child: ListTile(
            leading: CircleAvatar(
              child: Text(user.name.isNotEmpty ? user.name[0] : '?'),
            ),
            title: Text(
              user.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.email),
                Text(
                  'Role: ${user.role}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: Theme.of(context).colorScheme.error,
                  onPressed: () => _showDeleteConfirmationDialog(user),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  color: Theme.of(context).colorScheme.error,
                  onPressed: () => _showPasswordResetConfirmationDialog(user),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isEmpty
                ? 'No Users Found'
                : 'No users match your search',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: 'Search Users',
        hintText: 'Search by name, email, username...',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 12,
        ),
      ),
    );
  }
}
