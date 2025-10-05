// lib/main.dart
import 'package:dreamvision/pages/CRM/crm_main.dart';
import 'package:dreamvision/pages/Counsellor/counsellor_dashboard.dart';
import 'package:dreamvision/pages/Telecaller/telecaller_dashboard.dart';
import 'package:dreamvision/pages/home/home.dart';
import 'package:dreamvision/pages/home/profile/profile_details.dart';
import 'package:dreamvision/pages/home/users.dart';
import 'package:dreamvision/pages/login/login.dart';
import 'package:dreamvision/providers/auth_provider.dart';
import 'package:dreamvision/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

void main() async{
  // Wrap the entire app with ChangeNotifierProvider
  runApp(
    ChangeNotifierProvider(
      create: (context) => AuthProvider(),
      child: const App(),
    ),
  );
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: _router,
      title: 'DreamVision',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF3A5B8A),
        useMaterial3: true,
      ),
    );
  }
}

// GoRouter configuration with all routes
final GoRouter _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashPage()),
    GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
    GoRoute(path: '/home', builder: (context, state) => const HomePage()),
    GoRoute(path: '/users', builder: (context, state) => const UserListPage()),
    GoRoute(path: '/crm', builder: (context, state) => const CRM()),
    GoRoute(path: '/telecaller', builder: (context, state) => const TelecallerDashboard()),
    GoRoute(path: '/councellor', builder: (context, state) => const CounsellorDashboard()),
    GoRoute(
      path: '/profile/details',
      builder: (context, state) => const EmployeeDetailsPage(),
    ),
  ],
);
