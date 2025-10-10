import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

// A simple data model class for the Syncfusion chart data
class _SalesData {
  _SalesData(this.day, this.sales);
  final double day;
  final double sales;
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  String _selectedTimeframe = 'This Month';
  Logger logger = Logger();
  final List<String> _timeframeOptions = [
    'This Month',
    'Last Quarter',
    'Last 6 Months',
    'This Week',
  ];

  // Dummy data for the Syncfusion chart
  final List<_SalesData> _chartData = [
    _SalesData(1, 35),
    _SalesData(5, 42),
    _SalesData(10, 28),
    _SalesData(15, 55),
    _SalesData(20, 48),
    _SalesData(25, 62),
    _SalesData(30, 58),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // The title is now just the Text widget
        title: const Text('Dream Vision'),
        elevation: 1,
        // The logo is now placed in the `actions` list
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Image.asset(
              'assets/logo.jpg',
              width: 40, // Slightly increased size for better visibility
              errorBuilder: (context, error, stackTrace) {
                logger.e(error);
                return Container(
                  width: 40,
                  height: 40,
                  color: Colors.grey[700],
                  child: const Center(
                    child: Text(
                      'DV',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            // const SizedBox(height: 50),
            // ListTile(title: const Text('CRM'), onTap: () {
            //   context.push('/crm');
            // }),
            const SizedBox(height: 72),
            ListTile(
              title: const Text('Manage Users'),
              leading: const Icon(Icons.group_outlined),
              onTap: () {
                context.push('/users');
              },
            ),
            const Spacer(),
            ListTile(
              title: const Text('Logout'),
              leading: const Icon(Icons.logout),
              onTap: () {
                // Proper logout logic should be handled by a provider
                context.go('/login');
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSalesChartSection(),
            const SizedBox(height: 20),
            Expanded(
              child: _buildEnquiryList(
                title: 'Unassigned Tasks/Enquiries',
                itemCount: 15,
                icon: Icons.assignment_late_outlined,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _buildEnquiryList(
                title: 'Assigned Tasks/Enquiries',
                itemCount: 5,
                icon: Icons.assignment_turned_in_outlined,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the top card with the Syncfusion chart and controls.
  Widget _buildSalesChartSection() {
    // ... This function remains the same ...
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Sales',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                DropdownButton<String>(
                  value: _selectedTimeframe,
                  underline: Container(),
                  items: _timeframeOptions.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedTimeframe = newValue!;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(height: 150, child: _buildSyncfusionChart()),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add),
                label: const Text('Add Enquiry'),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the Syncfusion Chart widget.
  Widget _buildSyncfusionChart() {
    // ... This function remains the same ...
    final theme = Theme.of(context);
    return SfCartesianChart(
      primaryXAxis: const NumericAxis(isVisible: false),
      primaryYAxis: const NumericAxis(isVisible: false),
      plotAreaBorderWidth: 0,
      series: <CartesianSeries<_SalesData, double>>[
        SplineAreaSeries<_SalesData, double>(
          dataSource: _chartData,
          xValueMapper: (_SalesData sales, _) => sales.day,
          yValueMapper: (_SalesData sales, _) => sales.sales,
          gradient: LinearGradient(
            colors: [theme.primaryColor, theme.primaryColor.withOpacity(0.3)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderWidth: 2,
          borderColor: theme.primaryColor,
        ),
      ],
    );
  }

  /// Builds a reusable list for enquiries.
  Widget _buildEnquiryList({
    required String title,
    required int itemCount,
    required IconData icon,
  }) {
    // ... This function remains the same ...
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListView.builder(
              itemCount: itemCount,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: Icon(icon, color: Theme.of(context).primaryColor),
                  title: Text('Enquiry #${index + 1}'),
                  subtitle: const Text('Tap to see details...'),
                  onTap: () {},
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
