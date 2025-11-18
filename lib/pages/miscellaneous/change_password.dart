import 'package:dreamvision/services/auth_service.dart';
import 'package:flutter/material.dart';

import '../../widgets/back_button.dart';

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
    FocusScope.of(context).unfocus();
    setState(() => _errorMessage = null);

    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        await _authService.changePassword(
          _oldPasswordController.text,
          _newPassword1Controller.text,
          _newPassword2Controller.text,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Password changed successfully!'),
              backgroundColor: Theme.of(context).colorScheme.tertiary,
            ),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: cs.surface,
        leading: const BackButtonIos(),
        title: const Text('Change Password'),
        centerTitle: true,
        elevation: 0,
      ),

      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),

        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Information Card
                Material(
                  elevation: 3,
                  surfaceTintColor: cs.primary,
                  shadowColor: Colors.black.withValues(alpha:0.25),
                  borderRadius: BorderRadius.circular(16),

                  child: Container(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(24),

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Secure Your Account',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: cs.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Your new password must be at least 8 characters long.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                _buildPasswordField(
                  controller: _oldPasswordController,
                  focusNode: _oldPasswordFocus,
                  label: 'Old Password',
                  obscure: _obscureOld,
                  toggle: () => setState(() => _obscureOld = !_obscureOld),
                  onSubmit: (_) =>
                      FocusScope.of(context).requestFocus(_newPassword1Focus),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Please enter your old password' : null,
                ),
                const SizedBox(height: 24),

                _buildPasswordField(
                  controller: _newPassword1Controller,
                  focusNode: _newPassword1Focus,
                  label: 'New Password',
                  helper: 'Minimum 8 characters',
                  obscure: _obscureNew1,
                  toggle: () => setState(() => _obscureNew1 = !_obscureNew1),
                  onSubmit: (_) =>
                      FocusScope.of(context).requestFocus(_newPassword2Focus),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter a new password';
                    if (v.length < 8) return 'Password must be 8+ characters';
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                _buildPasswordField(
                  controller: _newPassword2Controller,
                  focusNode: _newPassword2Focus,
                  label: 'Confirm New Password',
                  obscure: _obscureNew2,
                  toggle: () => setState(() => _obscureNew2 = !_obscureNew2),
                  onSubmit: (_) => _submitForm(),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Confirm your password';
                    if (v != _newPassword1Controller.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 32),

                if (_errorMessage != null)
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(
                      color: cs.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                const SizedBox(height: 16),

                ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
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

  // --------------------------------------------------
  // Password Field (Theme-Aware)
  // --------------------------------------------------

  Widget _buildPasswordField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    String? helper,
    required bool obscure,
    required VoidCallback toggle,
    required Function(String) onSubmit,
    required FormFieldValidator<String> validator,
  }) {
    final cs = Theme.of(context).colorScheme;

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscure,
      textInputAction: TextInputAction.next,
      validator: validator,
      onFieldSubmitted: onSubmit,

      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        helperStyle: TextStyle(color: cs.onSurfaceVariant),

        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),

        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off : Icons.visibility,
            color: cs.onSurfaceVariant,
          ),
          onPressed: toggle,
        ),

        filled: true,
        fillColor: cs.surfaceContainerHighest,

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cs.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cs.error, width: 2),
        ),
      ),
    );
  }
}
