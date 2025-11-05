import 'package:dreamvision/pages/Admin/add_user_page.dart';
import 'package:dreamvision/pages/Admin/admin_dashboard.dart';
import 'package:dreamvision/pages/CRM/crm_main.dart';
import 'package:dreamvision/pages/Counsellor/add_enquiry_page.dart';
import 'package:dreamvision/pages/Counsellor/counsellor_dashboard.dart';
import 'package:dreamvision/pages/Counsellor/enquiry_detail.dart';
import 'package:dreamvision/pages/Counsellor/all_enquiries.dart';
import 'package:dreamvision/pages/Telecaller/telecaller_dashboard.dart';
import 'package:dreamvision/pages/Admin/profile/profile_details.dart';
import 'package:dreamvision/pages/Admin/users.dart';
import 'package:dreamvision/pages/login/login.dart';
import 'package:dreamvision/pages/miscellaneous/change_password.dart';
import 'package:dreamvision/pages/miscellaneous/follow_up_page.dart';
import 'package:dreamvision/pages/settings.dart';
import 'package:dreamvision/providers/auth_provider.dart';
import 'package:dreamvision/providers/theme_provider.dart';
import 'package:dreamvision/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'models/enquiry_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthProvider()),
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
      ],
      child: const App(),
    ),
  );
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    // Access the ThemeProvider to get the current theme mode
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp.router(
      routerConfig: _router,
      title: 'DreamVision',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        colorSchemeSeed: const Color(0xFF3A5B8A),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        // Define your dark theme
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF3A5B8A),
        useMaterial3: true,
      ),
    );
  }
}

final GoRouter _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashPage()),
    GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminDashboard(),
    ),
    GoRoute(path: '/users', builder: (context, state) => const UserListPage()),
    GoRoute(path: '/crm', builder: (context, state) => const CRM()),
    GoRoute(
      path: '/telecaller',
      builder: (context, state) => const TelecallerDashboard(),
    ),
    GoRoute(
      path: '/counsellor',
      builder: (context, state) => const CounsellorDashboard(),
    ),
    GoRoute(
      path: '/add-enquiry',
      builder: (context, state) {
        // Get the enquiry object from 'extra'
        final Enquiry? enquiry = state.extra as Enquiry?;
        // Pass it to the page
        return AddEnquiryPage(enquiry: enquiry);
      },
    ),
    GoRoute(
      path: '/all-enquiries',
      builder: (context, state) => const AllEnquiriesPage(),
    ),
    GoRoute(path: '/settings', builder: (context, state) => const Settings()),
    GoRoute(
      path: '/profile-details',
      builder: (context, state) => const EmployeeDetailsPage(),
    ),
    GoRoute(
      path: '/add-user',
      builder: (context, state) => const AddUserPage(),
    ),
    GoRoute(
      path: '/enquiry/:enquiryId',
      builder: (context, state) {
        final enquiryIdString = state.pathParameters['enquiryId'];
        final enquiryId = int.tryParse(enquiryIdString ?? '') ?? 0;
        return EnquiryDetailPage(enquiryId: enquiryId);
      },
    ),
    GoRoute(
      path: '/profile/details',
      builder: (context, state) => const EmployeeDetailsPage(),
    ),
    GoRoute(
      path: '/change-password',
      builder: (context, state) => const ChangePasswordPage(),
    ),
    GoRoute(
      path: '/follow-ups/:enquiryId',
      builder: (context, state) {
        final enquiryId =
            int.tryParse(state.pathParameters['enquiryId'] ?? '') ?? 0;
        final enquiryName =
            state.extra as String? ?? 'Enquiry'; // Pass name as extra
        return FollowUpPage(enquiryId: enquiryId, enquiryName: enquiryName);
      },
    ),
  ],
);
