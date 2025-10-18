import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'dart:math';

class _SalesData {
  _SalesData(this.date, this.sales);
  final DateTime date;
  final double sales;
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  late DateTimeRange _selectedDateRange;
  late List<_SalesData> _allSalesData;
  List<_SalesData> _filteredChartData = [];

  Logger logger = Logger();

  @override
  void initState() {
    super.initState();
    // Generate dummy data for the last year
    _allSalesData = _generateDummyData();

    // Initialize the default date range to be the current month
    final now = DateTime.now();
    _selectedDateRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: now,
    );

    // Filter data for the initial view
    _filterData();
  }

  /// Generates random sales data for the past 365 days.
  List<_SalesData> _generateDummyData() {
    final random = Random();
    final today = DateTime.now();
    return List.generate(365, (index) {
      final date = today.subtract(Duration(days: index));
      final sales =
          30 + random.nextDouble() * 70; // Random sales between 30 and 100
      return _SalesData(date, sales);
    });
  }

  void _filterData() {
    setState(() {
      _filteredChartData = _allSalesData.where((data) {
        // Ensure the date is within the selected range (inclusive of start and end days)
        final startDate = _selectedDateRange.start;
        final endDate = _selectedDateRange.end;
        return (data.date.isAtSameMomentAs(startDate) ||
                data.date.isAfter(startDate)) &&
            (data.date.isAtSameMomentAs(endDate) ||
                data.date.isBefore(endDate));
      }).toList();
      // Sort the data by date for correct chart plotting
      _filteredChartData.sort((a, b) => a.date.compareTo(b.date));
    });
  }

  /// Shows the date range picker dialog.
  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _selectedDateRange) {
      _selectedDateRange = picked;
      _filterData(); // Re-filter data with the new range
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Dream Vision'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Image.asset(
              'assets/logo.jpg',
              width: 40,
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
                context.go('/login');
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      body: SingleChildScrollView(
        // Made body scrollable
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSalesChartSection(),
            const SizedBox(height: 20),
            _buildEnquiryList(
              // Removed Expanded to use SingleChildScrollView
              title: 'Unassigned Tasks/Enquiries',
              itemCount: 15,
              icon: Icons.assignment_late_outlined,
            ),
            const SizedBox(height: 20),
            _buildEnquiryList(
              // Removed Expanded
              title: 'Assigned Tasks/Enquiries',
              itemCount: 5,
              icon: Icons.assignment_turned_in_outlined,
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the top card with the Syncfusion chart and controls.
  Widget _buildSalesChartSection() {
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
                // Button to open the date range picker
                TextButton.icon(
                  icon: const Icon(Icons.calendar_today_outlined, size: 16),
                  label: Text(
                    // Display the selected date range
                    '${DateFormat.yMMMd().format(_selectedDateRange.start)} - ${DateFormat.yMMMd().format(_selectedDateRange.end)}',
                  ),
                  onPressed: () => _selectDateRange(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(height: 150, child: _buildSyncfusionChart()),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min, // Row takes minimum space
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Bulk upload feature coming soon!'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text('Bulk Add'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      context.push('/add-enquiry');
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Enquiry'),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the Syncfusion Chart widget.
  Widget _buildSyncfusionChart() {
    final theme = Theme.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final gridLineColor = isDarkMode ? Colors.white24 : Colors.black12;
    return SfCartesianChart(
      trackballBehavior: TrackballBehavior(
        enable: true,
        activationMode: ActivationMode.singleTap,
        tooltipSettings: const InteractiveTooltip(
          enable: true,
          format: 'point.x, \$point.y', // Customize tooltip text
        ),
      ),
      // Use DateTimeAxis for the x-axis
      primaryXAxis: DateTimeAxis(
        majorGridLines: const MajorGridLines(width: 0),
        axisLine: const AxisLine(width: 0),
        edgeLabelPlacement: EdgeLabelPlacement.shift,
        dateFormat: DateFormat.MMMd(),
        intervalType: DateTimeIntervalType.auto,
      ),
      primaryYAxis: NumericAxis(
        majorGridLines: MajorGridLines(width: 1, color: gridLineColor),
        axisLine: const AxisLine(width: 0),
        numberFormat: NumberFormat.compactSimpleCurrency(locale: 'en_US'),
      ),
      plotAreaBorderWidth: 0,
      series: <CartesianSeries<_SalesData, DateTime>>[
        SplineAreaSeries<_SalesData, DateTime>(
          // Use the filtered data source
          dataSource: _filteredChartData,
          xValueMapper: (_SalesData sales, _) => sales.date,
          yValueMapper: (_SalesData sales, _) => sales.sales,
          gradient: LinearGradient(
            colors: [
              theme.primaryColor,
              theme.primaryColor.withValues(alpha: 0.3),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderWidth: 2,
          borderColor: theme.primaryColor,
          markerSettings: MarkerSettings(
            isVisible: true,
            height: 5,
            width: 5,
            color: theme.primaryColor,
            borderColor: theme.cardColor,
            borderWidth: 1.5,
          ),
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
    // Wrapped in a SizedBox to constrain height when not using Expanded
    return SizedBox(
      height: 250, // Give a fixed height
      child: Column(
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
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
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
      ),
    );
  }
}
