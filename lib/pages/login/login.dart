import 'dart:ui';
import 'package:dreamvision/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    _usernameFocus.unfocus();
    _passwordFocus.unfocus();

    final auth = context.read<AuthProvider>();
    final success = await auth.login(
      _usernameController.text.trim(),
      _passwordController.text.trim(),
    );

    if (success && mounted) {
      switch (auth.user?.role) {
        case 'Admin':
          context.go('/admin');
          break;
        case 'Counsellor':
          context.go('/counsellor');
          break;
        case 'Telecaller':
          context.go('/telecaller');
          break;
        default:
          context.go('/');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final auth = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // ------------------------------
          // ✨ BEAUTIFUL GRADIENT BACKGROUND
          // ------------------------------
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  cs.primary.withValues(alpha: .25),
                  cs.secondary.withValues(alpha: 0.20),
                  cs.surfaceContainerHighest.withValues(alpha: 0.10),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // ------------------------------
          // ✨ FLOATING GLASS LOGIN CARD
          // ------------------------------
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  padding: const EdgeInsets.all(24),
                  width: MediaQuery.of(context).size.width * 0.88,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    color: isDark
                        ? cs.surface.withValues(
                            alpha: 0.23,
                          )
                        : cs.surface,
                    border: Border.all(
                      color: cs.onSurface.withValues(alpha: 0.08),
                      width: 1.2,
                    ),
                  ),

                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo
                        Image.asset(
                          'assets/logo.jpg',
                          height: 100,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.school_rounded,
                            size: 80,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 12),

                        Text(
                          "Welcome to DV40 CRM",
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),

                        Text(
                          "Please sign in to continue",
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.7),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Username
                        _buildInput(
                          context,
                          label: "Username",
                          controller: _usernameController,
                          focusNode: _usernameFocus,
                          icon: Icons.person_outline,
                          hint: "@username",
                          onSubmit: () => FocusScope.of(
                            context,
                          ).requestFocus(_passwordFocus),
                        ),

                        const SizedBox(height: 16),

                        // Password
                        _buildInput(
                          context,
                          label: "Password",
                          controller: _passwordController,
                          focusNode: _passwordFocus,
                          icon: Icons.lock_outline,
                          hint: "Enter your password",
                          obscure: !_isPasswordVisible,
                          suffix: IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: cs.onSurfaceVariant,
                            ),
                            onPressed: () => setState(
                              () => _isPasswordVisible = !_isPasswordVisible,
                            ),
                          ),
                          onSubmit: _submitForm,
                        ),

                        const SizedBox(height: 20),

                        // Error Message
                        if (auth.errorMessage.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              auth.errorMessage,
                              style: TextStyle(color: cs.error),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      SizedBox(
                        width: double.infinity,
                        // Use FilledButton for a modern, solid M3 style
                        child: FilledButton(
                          onPressed: auth.isLoading ? null : _submitForm,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16), // A bit more padding
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20), // Match text fields
                            ),
                          ),
                          child: auth.isLoading
                              ? SizedBox( // Constrain the indicator size
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3, // Slightly thicker
                                    valueColor: AlwaysStoppedAnimation(
                                      // onPrimary is picked up automatically,
                                      // but we can be explicit
                                      Theme.of(context).colorScheme.onPrimary,
                                    ),
                                  ),
                                )
                              : const Text(
                                  "Sign In",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput(
    BuildContext context, {
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    required FocusNode focusNode,
    Widget? suffix,
    bool obscure = false,
    required VoidCallback onSubmit,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscure,
          onFieldSubmitted: (_) => onSubmit(),
          validator: (v) => v!.isEmpty ? "Please enter your $label" : null,
          decoration: InputDecoration(
            filled: true,
            fillColor: cs.surface.withValues(alpha: 0.35),
            hintText: hint,
            hintStyle: TextStyle(color: cs.onSurfaceVariant),
            prefixIcon: Icon(icon, color: cs.primary),
            suffixIcon: suffix,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: cs.outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: cs.primary, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
