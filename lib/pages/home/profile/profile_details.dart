import 'package:flutter/material.dart';

class EmployeeDetailsPage extends StatelessWidget {
  const EmployeeDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Details'),
      ),
      body: SingleChildScrollView(
        // Using a ListView for better structure and spacing
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildDetailCard(
                context,
                'Personal Information',
                [
                  _buildDetailRow('Staff ID', '107'),
                  _buildDetailRow('First Name', 'Aditya'),
                  _buildDetailRow('Last Name', 'Janga'),
                  _buildDetailRow('Email', 'aditya.janga@dreamvision.com'),
                  _buildDetailRow('Phone Number', '+91 98765 43210'),
                  _buildDetailRow('Address', '123 G-Square Complex, Nashik'),
                ],
              ),
              _buildDetailCard(
                context,
                'Work Information',
                [
                  _buildDetailRow('Department ID', 'TELECALL_DEPT_01'),
                  _buildDetailRow('Supervisor ID', 'MGR_05'),
                  _buildDetailRow('Shift', 'Day (9 AM - 6 PM)'),
                  _buildDetailRow('Username', 'aditya.j'),
                  _buildDetailRow('Password', '••••••••'),
                ],
              ),
              _buildDetailCard(
                context,
                'Employment Status',
                [
                  _buildDetailRow('Date of Joining', '15 May 2023'),
                  _buildDetailRow('Date of Resignation', 'N/A'),
                  _buildDetailRow(
                    'Status',
                    'Active',
                    valueColor: Colors.green.shade800,
                  ),
                  _buildDetailRow('Last Update', '30 Sep 2025'),
                  _buildDetailRow(
                      'Remarks', 'Top performer for Q2. Excellent communication skills.'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper to build a styled card with a title and list of details
  Widget _buildDetailCard(
      BuildContext context, String title, List<Widget> details) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Divider(height: 24),
            ...details,
          ],
        ),
      ),
    );
  }

  // Helper to build a single row of detail (e.g., "First Name: Aditya")
  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120, // Consistent width for labels
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
