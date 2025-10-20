import 'package:dreamvision/services/auth_service.dart';
import 'package:flutter/material.dart';

import '../../widgets/back_button.dart'; // Ensure this import path is correct

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  final _oldPasswordController = TextEditingController();
  final _newPassword1Controller = TextEditingController();
  final _newPassword2Controller = TextEditingController();

  bool _obscureOld = true;
  bool _obscureNew1 = true;
  bool _obscureNew2 = true;

  bool _isLoading = false;
  String? _errorMessage;

  // Added focus nodes for better keyboard navigation and input management
  final FocusNode _oldPasswordFocus = FocusNode();
  final FocusNode _newPassword1Focus = FocusNode();
  final FocusNode _newPassword2Focus = FocusNode();

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPassword1Controller.dispose();
    _newPassword2Controller.dispose();
    _oldPasswordFocus.dispose();
    _newPassword1Focus.dispose();
    _newPassword2Focus.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    // Dismiss the keyboard
    FocusScope.of(context).unfocus();

    setState(() {
      _errorMessage = null; // Clear previous errors
    });

    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        await _authService.changePassword(
          _oldPasswordController.text,
          _newPassword1Controller.text,
          _newPassword2Controller.text,
        );

        // If successful
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password changed successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        // If an error occurs (e.g., wrong old password)
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get primary color from theme for consistent styling
    final primaryColor = Theme.of(context).primaryColor;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButtonIos(),
        title: const Text('Change Password'),
        centerTitle: true, // Center the title for a cleaner look
        elevation: 0, // Remove shadow for a flatter design
        backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Match scaffold background
      ),
      body: GestureDetector(
        onTap: () {
          // Dismiss keyboard when tapping outside text fields
          FocusScope.of(context).unfocus();
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0), // Increased padding
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch children horizontally
              children: [
                // Informative Header Card
                Card(
                  elevation: 4, // Slightly more elevation for prominence
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16), // More rounded corners
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0), // Increased padding inside card
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Secure Your Account',
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: primaryColor, // Use primary color for main title
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'For your security, please update your password. Your new password must be strong and at least 8 characters long.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32), // Increased spacing

                // Password Input Fields
                _buildPasswordFormField(
                  controller: _oldPasswordController,
                  focusNode: _oldPasswordFocus,
                  labelText: 'Old Password',
                  obscureText: _obscureOld,
                  toggleObscure: () {
                    setState(() {
                      _obscureOld = !_obscureOld;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your old password';
                    }
                    return null;
                  },
                  textInputAction: TextInputAction.next, // Go to next field on submit
                  onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_newPassword1Focus),
                ),
                const SizedBox(height: 24),
                _buildPasswordFormField(
                  controller: _newPassword1Controller,
                  focusNode: _newPassword1Focus,
                  labelText: 'New Password',
                  helperText: 'Minimum 8 characters',
                  obscureText: _obscureNew1,
                  toggleObscure: () {
                    setState(() {
                      _obscureNew1 = !_obscureNew1;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a new password';
                    }
                    if (value.length < 8) {
                      return 'Password must be at least 8 characters long';
                    }
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_newPassword2Focus),
                ),
                const SizedBox(height: 24),
                _buildPasswordFormField(
                  controller: _newPassword2Controller,
                  focusNode: _newPassword2Focus,
                  labelText: 'Confirm New Password',
                  obscureText: _obscureNew2,
                  toggleObscure: () {
                    setState(() {
                      _obscureNew2 = !_obscureNew2;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your new password';
                    }
                    if (value != _newPassword1Controller.text) {
                      return 'The passwords do not match';
                    }
                    return null;
                  },
                  textInputAction: TextInputAction.done, // Done on submit for last field
                  onFieldSubmitted: (_) => _submitForm(), // Submit form when done on last field
                ),

                const SizedBox(height: 32),

                // Error Message Display
                if (_errorMessage != null)
                  AnimatedOpacity(
                    opacity: _errorMessage != null ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        _errorMessage!,
                        style: textTheme.bodyLarge?.copyWith(
                          color: Colors.red[700],
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                // Submit Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16), // Larger button
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12), // Consistent rounded corners
                    ),
                    backgroundColor: primaryColor, // Use theme primary color
                    foregroundColor: Colors.white,
                    textStyle: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24, // Consistent height for circular progress
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text('Save Changes'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Refactored password form field into a reusable widget
  Widget _buildPasswordFormField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String labelText,
    String? helperText,
    required bool obscureText,
    required VoidCallback toggleObscure,
    required String? Function(String?) validator,
    required TextInputAction textInputAction,
    required ValueChanged<String> onFieldSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: labelText,
        helperText: helperText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8), // Slightly rounded borders
          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[400]!, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey[600],
          ),
          onPressed: toggleObscure,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), // Adjusted padding
      ),
      validator: validator,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
    );
  }
}