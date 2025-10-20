import 'package:dreamvision/services/admin_user.dart';
import 'package:dreamvision/widgets/back_button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AddUserPage extends StatefulWidget {
  const AddUserPage({super.key});

  @override
  State<AddUserPage> createState() => _AddUserPageState();
}

class _AddUserPageState extends State<AddUserPage> {
  final _formKey = GlobalKey<FormState>();
  final _adminUserService = AdminUserService();
  bool _isSubmitting = false;

  // Form controllers and state
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _staffIdController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _selectedRole;
  String? _selectedShift; // ✅ State variable for the new Shift field

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _staffIdController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    final userData = {
      'first_name': _firstNameController.text,
      'last_name': _lastNameController.text,
      'username': _usernameController.text,
      'email': _emailController.text,
      'staff_id': _staffIdController.text,
      'phone_number': _phoneController.text,
      'role': _selectedRole!,
      'shift': _selectedShift, // ✅ Add shift to the request data
      // Add other optional fields if you have UI for them
      'department': null,
      'supervisor': null,
    };

    try {
      final response = await _adminUserService.addUser(userData);
      final initialPassword = response['initial_password'] ?? 'Not provided';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'User "${_usernameController.text}" created!\nPassword: $initialPassword (Inform user!)',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 7),
          ),
        );
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButtonIos(),
        title: const Text(
          'Create New User Profile',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton(
              onPressed: _isSubmitting ? null : _submitForm,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Theme(
                data: Theme.of(context).copyWith(
                  inputDecorationTheme: InputDecorationTheme(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey.withValues(alpha:0.1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionHeader(title: 'User Identity'),
                    TextFormField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(labelText: 'First Name'),
                      validator: (value) => value!.isEmpty ? 'Enter first name' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(labelText: 'Last Name'),
                      validator: (value) => value!.isEmpty ? 'Enter last name' : null,
                    ),
                    const SizedBox(height: 24),

                    const _SectionHeader(title: 'Account Credentials'),
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(labelText: 'Username'),
                      validator: (value) => value!.isEmpty ? 'Enter username' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value!.isEmpty) return 'Enter email';
                        if (!value.contains('@')) return 'Enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    const _SectionHeader(title: 'Organizational Details'),
                    TextFormField(
                      controller: _staffIdController,
                      decoration: const InputDecoration(labelText: 'Staff ID'),
                      validator: (value) => value!.isEmpty ? 'Enter a Staff ID' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(labelText: 'Phone Number'),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value!.isEmpty) return 'Enter a phone number';
                        if (value.length < 4) return 'Phone number requires at least 4 digits';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedRole,
                      decoration: const InputDecoration(labelText: 'Role'),
                      items: ['Admin', 'Counsellor', 'Telecaller']
                          .map((role) => DropdownMenuItem(value: role, child: Text(role)))
                          .toList(),
                      onChanged: (value) => setState(() => _selectedRole = value),
                      validator: (value) => value == null ? 'Select a role' : null,
                    ),
                    const SizedBox(height: 16), // ✅ Spacing for the new field
                    
                    // ✅ NEW SHIFT DROPDOWN
                    DropdownButtonFormField<String>(
                      value: _selectedShift,
                      decoration: const InputDecoration(labelText: 'Shift (Optional)'),
                      items: ['Day', 'Night', 'Custom']
                          .map((shift) => DropdownMenuItem(value: shift, child: Text(shift)))
                          .toList(),
                      onChanged: (value) => setState(() => _selectedShift = value),
                      // No validator needed as it's optional and defaults on the backend
                    ),
                    
                    const SizedBox(height: 32),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isSubmitting ? null : _submitForm,
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                            )
                          : const Text('Create User'),
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
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

