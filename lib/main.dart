import 'dart:async';
import 'package:dreamvision/pages/Admin/add_user_page.dart';
import 'package:dreamvision/pages/Admin/admin_dashboard.dart';
import 'package:dreamvision/pages/CRM/crm_main.dart';
import 'package:dreamvision/pages/Counsellor/add_enquiry_page.dart';
import 'package:dreamvision/pages/Counsellor/counsellor_dashboard.dart';
import 'package:dreamvision/pages/Counsellor/enquiry_detail.dart';
import 'package:dreamvision/pages/Counsellor/all_enquiries.dart';
import 'package:dreamvision/pages/Manager/manager_dashboard.dart';
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
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/enquiry_model.dart';
import 'models/user_model.dart';
import 'utils/global_error_handler.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      final appDocumentDir = await getApplicationDocumentsDirectory();
      await Hive.initFlutter(appDocumentDir.path);
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);

      // Clear search preferences on app startup
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('enquiry_search_unassigned');
      await prefs.remove('enquiry_search_assigned');

      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        GlobalErrorHandler.error(details.exceptionAsString());
      };

      runApp(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (context) => AuthProvider()),
            ChangeNotifierProvider(create: (context) => ThemeProvider()),
          ],
          child: const App(),
        ),
      );
    },
    (error, stack) {
      GlobalErrorHandler.error(error.toString());
    },
  );
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp.router(
      routerConfig: _router,
      title: 'DreamVision',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: GlobalErrorHandler.messengerKey,
      themeMode: themeProvider.themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        colorSchemeSeed: const Color(0xFF3A5B8A),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
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
      path: '/manager',
      builder: (context, state) => const ManagerDashboard(),
    ),

    GoRoute(
      path: '/add-enquiry',
      builder: (context, state) {
        final Enquiry? enquiry = state.extra as Enquiry?;
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
      builder: (context, state) => EmployeeDetailsPage(),
    ),

    GoRoute(
      path: '/add-user',
      builder: (context, state) {
        final extra = state.extra;
        final user = extra is User ? extra : null;
        return AddUserPage(user: user);
      },
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
      builder: (context, state) => EmployeeDetailsPage(),
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
        final enquiryName = state.extra as String? ?? 'Enquiry';
        return FollowUpPage(enquiryId: enquiryId, enquiryName: enquiryName);
      },
    ),
  ],
);
