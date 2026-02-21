import 'package:dreamvision/services/admin_user.dart';
import 'package:dreamvision/widgets/back_button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../utils/global_error_handler.dart';
import '../../widgets/password_display_dialog.dart';
import '../../models/user_model.dart';
import 'package:logger/logger.dart';

class AddUserPage extends StatefulWidget {
  final User? user;
  const AddUserPage({super.key, this.user});

  @override
  State<AddUserPage> createState() => _AddUserPageState();
}

class _AddUserPageState extends State<AddUserPage> {
  final _formKey = GlobalKey<FormState>();
  Logger logger = Logger();
  final _adminUserService = AdminUserService();
  bool _isSubmitting = false;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _staffIdController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  String? _selectedRole;

  bool get isEditMode => widget.user != null;

  @override
  void initState() {
    super.initState();
    if (isEditMode) _prefillFromUser(widget.user!);
  }

  void _prefillFromUser(User user) {
    _firstNameController.text = user.firstName;
    _lastNameController.text = user.lastName;
    _usernameController.text = user.username;
    _emailController.text = user.email;
    _staffIdController.text = user.staffId;
    _phoneController.text = user.phoneNumber;
    _addressController.text = user.address;
    _selectedRole = user.role;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _staffIdController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;
    setState(() => _isSubmitting = true);

    final userData = {
      "user": {
        "first_name": _firstNameController.text.trim(),
        "last_name": _lastNameController.text.trim(),
        "email": _emailController.text.trim(),
      },
      "staff_id": _staffIdController.text.trim(),
      "phone_number": _phoneController.text.trim(),
      "address": _addressController.text.trim(),
      "role": _selectedRole,
    };

    try {
      if (isEditMode) {
        logger.d(widget.user!.toJson());
        await _adminUserService.updateUser(widget.user!.userId, userData);
        if (mounted) {
          GlobalErrorHandler.success('User updated successfully');

          context.pop(true);
        }
      } else {
        final createData = {
          "username": _usernameController.text.trim(),
          "email": _emailController.text.trim(),
          "first_name": _firstNameController.text.trim(),
          "last_name": _lastNameController.text.trim(),
          "staff_id": _staffIdController.text.trim(),
          "phone_number": _phoneController.text.trim(),
          "address": _addressController.text.trim(),
          "role": _selectedRole,
        };

        final response = await _adminUserService.addUser(createData);
        final initialPassword = response['initial_password'] ?? 'Not provided';
        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => PasswordDisplayDialog(
              title: "User Created Successfully",
              username: _usernameController.text,
              password: initialPassword,
            ),
          );
          // ignore: use_build_context_synchronously
          context.pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        GlobalErrorHandler.error('Operation failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!isEditMode) return;
    final user = widget.user!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reset Password'),
          content: Text('Reset password for ${user.name}?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reset')),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() => _isSubmitting = true);
    try {
      final response = await _adminUserService.resetPassword(user.userId);
      final newPassword = response['new_password'] ?? 'Not provided';
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => PasswordDisplayDialog(
            title: "Password Reset Successful",
            username: user.username,
            password: newPassword,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        GlobalErrorHandler.error('Failed to reset password: $e');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: cs.surface,
        leading: const BackButtonIos(),
        title: Text(
          isEditMode ? 'Edit User' : 'Create User Profile',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (isEditMode)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: _isSubmitting ? null : _resetPassword,
                icon: const Icon(Icons.lock_reset_outlined),
                label: const Text('Reset Password'),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: TextButton(
              onPressed: _isSubmitting ? null : _submitForm,
              child: _isSubmitting
                  ? SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
                    )
                  : Text(isEditMode ? 'Update' : 'Save'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Card(
            elevation: 0,
            color: cs.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: cs.outlineVariant.withAlpha(80)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Theme(
                data: theme.copyWith(
                  inputDecorationTheme: InputDecorationTheme(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: cs.surfaceContainerHighest.withAlpha(40),
                    labelStyle: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionHeader(title: 'User Details'),
                    TextFormField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(labelText: 'First Name'),
                      validator: (v) => v!.isEmpty ? 'Enter first name' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(labelText: 'Last Name'),
                      validator: (v) => v!.isEmpty ? 'Enter last name' : null,
                    ),
                    const SizedBox(height: 26),
                    const _SectionHeader(title: 'Account Information'),
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(labelText: 'Username'),
                      validator: (v) => v!.isEmpty ? 'Enter username' : null,
                      enabled: !isEditMode,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Enter email';
                        final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                        return emailRegex.hasMatch(value) ? null : 'Enter a valid email';
                      },
                    ),
                    const SizedBox(height: 26),
                    const _SectionHeader(title: 'Organizational Info'),
                    TextFormField(
                      controller: _staffIdController,
                      decoration: const InputDecoration(labelText: 'Staff ID'),
                      validator: (v) => v!.isEmpty ? 'Enter Staff ID' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(labelText: 'Phone Number'),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Enter phone number';
                        return RegExp(r'^[0-9]{10}$').hasMatch(value) ? null : 'Phone must be 10 digits';
                      },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Role'),
                      items: ['Admin', 'Counsellor', 'Telecaller', 'Manager']
                          .map((role) => DropdownMenuItem(value: role, child: Text(role)))
                          .toList(),
                      initialValue: _selectedRole,
                      onChanged: (value) => setState(() => _selectedRole = value),
                      validator: (value) => value == null ? 'Select a role' : null,
                    ),
                    const SizedBox(height: 26),
                    const _SectionHeader(title: 'Contact Details'),
                    TextFormField(
                      controller: _addressController,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Address', alignLabelWithHint: true),
                      validator: (v) => v!.isEmpty ? 'Enter full address' : null,
                    ),
                    const SizedBox(height: 32),
                    FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: _isSubmitting ? null : _submitForm,
                      child: _isSubmitting
                          ? SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: cs.onPrimary, strokeWidth: 3))
                          : Text(isEditMode ? 'Update User' : 'Create User', style: const TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: Theme.of(context).colorScheme.primary)),
    );
  }
}
