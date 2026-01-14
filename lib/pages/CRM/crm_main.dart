import 'package:dreamvision/pages/Counsellor/counsellor_dashboard.dart';
import 'package:dreamvision/pages/Telecaller/telecaller_dashboard.dart';
import 'package:dreamvision/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
class CRM extends StatefulWidget {
  const CRM({super.key});

  @override
  State<CRM> createState() => _CRMState();
}

class _CRMState extends State<CRM> {

  Logger logger = Logger();
  @override
  Widget build(BuildContext context) {
    // Access the AuthProvider to get user information
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    
    // A simple loading state while the user data is being fetched
    if (user == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Conditionally return the correct dashboard based on the user's role
    return Scaffold(
      body: Builder(
        builder: (context) {
          
          switch (user.role) {
            case 'Telecaller':
              return const TelecallerDashboard();
            case 'Counsellor':
            case 'Admin': // Admin sees the Counsellor dashboard
              return const CounsellorDashboard();
            default:
              // Fallback for any unknown roles
              return const Scaffold(
                body: Center(
                  child: Text('You do not have a role assigned.'),
                ),
              );
          }
        },
      ),
    );
  }
}
