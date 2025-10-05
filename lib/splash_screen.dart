import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    // Navigate to the login page after a 3-second delay.
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        // Use go() to replace the splash screen in the navigation stack,
        // so the user can't press "back" to see it again.
        context.go('/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(48.0), // Adds some space around the logo
          child: Image.asset(
            'assets/Logo Vertical.jpg',
            // This is a fallback widget that will be shown if the image
            // fails to load for any reason.
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Text(
                  'DreamVision',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
