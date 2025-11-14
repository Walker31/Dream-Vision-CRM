import 'package:flutter/material.dart';

class PasswordDisplayDialog extends StatelessWidget {
  final String title;
  final String username;
  final String password;

  const PasswordDisplayDialog({
    super.key,
    required this.title,
    required this.username,
    required this.password,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('User "$username" password information:'),
          const SizedBox(height: 16),
          const Text(
            "Password:",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            password,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Please copy this password and provide it to the user. "
            "This will not be shown again.",
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ],
      ),
      actions: [
        TextButton(
          child: const Text("Done"),
          onPressed: () => Navigator.pop(context),
        )
      ],
    );
  }
}
