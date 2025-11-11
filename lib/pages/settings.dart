// ignore_for_file: use_build_context_synchronously

import 'package:dreamvision/providers/auth_provider.dart';
import 'package:dreamvision/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  bool _areNotificationsOn = true;

  Future<void> _showLogoutConfirmationDialog() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Are you sure you want to log out?'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Logout'),
              onPressed: () async {
                await authProvider.logout();
                if (mounted) {
                  context.go('/login');
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(onPressed: () {context.pop();}, icon: Icon(Icons.arrow_back_ios_new_rounded)),
        title: const Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 1.0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  const SizedBox(height: 16),
                  _buildSectionHeader('Account'),
                  _buildSettingsCard(
                    children: [
                      _buildListTile(
                        icon: CupertinoIcons.person_fill,
                        title: 'User Information',
                        onTap: () {
                          context.push('/profile-details');
                        },
                      ),
                      const Divider(height: 1),
                      _buildListTile(
                        icon: CupertinoIcons.lock,
                        title: 'Change Password',
                        onTap: () {
                          context.push('/change-password');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSectionHeader('General'),
                  _buildSettingsCard(
                    children: [
                      _buildDarkModeToggle(),
                      const Divider(height: 1),
                      _buildNotificationToggle(),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSectionHeader('More'),
                  _buildSettingsCard(
                    children: [
                      _buildListTile(
                        icon: CupertinoIcons.question_circle,
                        title: 'Help & Support',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Navigate to Help & Support')),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      _buildListTile(
                        icon: CupertinoIcons.info_circle,
                        title: 'About',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Navigate to About page')),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _buildLogoutButton(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 8.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingsCard({required List<Widget> children}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(color: Theme.of(context).dividerColor, width: 1),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      trailing:
          const Icon(CupertinoIcons.chevron_right, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildDarkModeToggle() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return SwitchListTile(
      title: const Text('Dark Mode'),
      subtitle: Text(
        'Enable dark theme across the app',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      secondary: Icon(
        themeProvider.isDarkMode ? CupertinoIcons.moon_fill : CupertinoIcons.sun_max_fill,
        color: Theme.of(context).colorScheme.primary,
      ),
      value: themeProvider.isDarkMode,
      onChanged: (value) {
        Provider.of<ThemeProvider>(context, listen: false).toggleTheme(value);
      },
    );
  }

  Widget _buildNotificationToggle() {
    return SwitchListTile(
      title: const Text('Notifications'),
      subtitle: Text(
        'Receive push notifications',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      secondary: Icon(
        _areNotificationsOn ? CupertinoIcons.bell_fill : CupertinoIcons.bell_slash_fill,
        color: Theme.of(context).colorScheme.primary,
      ),
      value: _areNotificationsOn,
      onChanged: (value) {
        setState(() {
          _areNotificationsOn = value;
        });
      },
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.logout),
        label: const Text(
          'Logout',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        onPressed: _showLogoutConfirmationDialog,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          backgroundColor: Theme.of(context).colorScheme.error,
          foregroundColor: Theme.of(context).colorScheme.onError,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
        ),
      ),
    );
  }
}