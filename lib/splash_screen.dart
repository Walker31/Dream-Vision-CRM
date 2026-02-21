// lib/features/splash/splash_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:dreamvision/providers/auth_provider.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Animation
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();

    // Begin auto-login check
    _startNavigation();
  }

  Future<void> _startNavigation() async {
    // Wait a bit so the splash animation plays
    await Future.delayed(const Duration(milliseconds: 900));

    // ignore: use_build_context_synchronously
    final auth = Provider.of<AuthProvider>(context, listen: false);

    final bool restored = await auth.tryAutoLogin();

    if (!mounted) return;

    if (!restored) {
      // Not logged in -> go to login
      context.go('/login');
      return;
    }

    // We have a valid user; route based on role
    final role = auth.user?.role ?? '';

    switch (role.toLowerCase()) {
      case 'admin':
        context.go('/admin');
        break;
      case 'telecaller':
        context.go('/telecaller');
        break;
      case 'counsellor':
      case 'counselor': // tolerate spelling
        context.go('/counsellor');
        break;
      case 'manager':
        context.go('/manager');
        break;
      case 'crm':
        context.go('/crm');
        break;
      default:
        context.go('/'); // fallback
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(48.0),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Image.asset(
                'assets/logo.jpeg',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.school_rounded, size: 64, color: cs.primary),
                      const SizedBox(height: 16),
                      Text(
                        'DreamVision',
                        style: textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
