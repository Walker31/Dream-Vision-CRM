import 'package:dreamvision/pages/Telecaller/follow_up_sheet.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'dart:math'; // Import for random data generation

class _ChartData {
  _ChartData(this.date, this.calls);
  final DateTime date;
  final int calls;
}

class TelecallerDashboard extends StatefulWidget {
  const TelecallerDashboard({super.key});

  @override
  State<TelecallerDashboard> createState() => _TelecallerDashboardState();
}

class _TelecallerDashboardState extends State<TelecallerDashboard> {
  String _selectedFilter = 'Open';
  Logger logger = Logger();
  late DateTimeRange _selectedDateRange;
  late List<_ChartData> _allCallData;
  List<_ChartData> _filteredChartData = [];

  @override
  void initState() {
    super.initState();
    _allCallData = _generateDummyCallData();

    final now = DateTime.now();
    _selectedDateRange = DateTimeRange(
      start: now.subtract(const Duration(days: 6)),
      end: now,
    );
    _filterData();
  }

  List<_ChartData> _generateDummyCallData() {
    final random = Random();
    final today = DateTime.now();
    return List.generate(365, (index) {
      final date = today.subtract(Duration(days: index));
      final calls = 20 + random.nextInt(45);
      return _ChartData(date, calls);
    });
  }

  void _filterData() {
    setState(() {
      _filteredChartData = _allCallData.where((data) {
        final startDate = _selectedDateRange.start;
        final endDate = _selectedDateRange.end;
        return (data.date.isAtSameMomentAs(startDate) ||
                data.date.isAfter(startDate)) &&
            (data.date.isAtSameMomentAs(endDate) ||
                data.date.isBefore(endDate));
      }).toList();
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
      _filterData();
    }
  }

  // Method to show the Add Enquiry Follow-up Form (remains the same)
  void _showAddFollowUpForm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return const AddFollowUpSheet(); // Assuming this widget exists elsewhere
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor:Colors.white,
        leading: Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Image.asset(
              'assets/logo.jpg',
              width: 50,
              errorBuilder: (context, error, stackTrace) {
                logger.e(error);
                return Container(
                  width: 50,
                  height: 50,
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
        title: const Text('Telecalling Dashboard'),
        actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: () {
            context.push('/settings');
          }),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildChartSection(),
            const SizedBox(height: 24),

            const Text(
              'Assigned Leads',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildFilterChips(),
            const SizedBox(height: 16),
            _buildLeadsList(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push('/add-enquiry');
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Enquiry'),
      ),
    );
  }

  Widget _buildChartSection() {
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
                  'Call Activity',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.calendar_today_outlined, size: 16),
                  label: Text(
                    '${DateFormat.yMMMd().format(_selectedDateRange.start)} - ${DateFormat.yMMMd().format(_selectedDateRange.end)}',
                  ),
                  onPressed: () => _selectDateRange(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildAnalyticsChart(),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsChart() {
    final theme = Theme.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final gridLineColor = isDarkMode ? Colors.white24 : Colors.black12;

    return SizedBox(
      height: 220,
      child: SfCartesianChart(
        plotAreaBorderWidth: 0,
        trackballBehavior: TrackballBehavior(
          enable: true,
          activationMode: ActivationMode.singleTap,
          tooltipSettings: const InteractiveTooltip(
            enable: true,
            format: 'point.x: point.y calls',
          ),
        ),
        primaryXAxis: DateTimeAxis(
          // Changed from CategoryAxis
          majorGridLines: const MajorGridLines(width: 0),
          axisLine: const AxisLine(width: 0),
          edgeLabelPlacement: EdgeLabelPlacement.shift,
          dateFormat: DateFormat.MMMd(),
        ),
        primaryYAxis: NumericAxis(
          isVisible: true,
          majorGridLines: MajorGridLines(width: 1, color: gridLineColor),
          axisLine: const AxisLine(width: 0),
          numberFormat: NumberFormat.decimalPattern(),
          minimum: 0,
        ),
        series: <CartesianSeries>[
          ColumnSeries<_ChartData, DateTime>(
            dataSource: _filteredChartData, // Use filtered data
            xValueMapper: (_ChartData data, _) =>
                data.date, // Use date property
            yValueMapper: (_ChartData data, _) => data.calls,
            color: theme.primaryColor,
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            dataLabelSettings: const DataLabelSettings(
              isVisible: true,
              textStyle: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = ['Open', 'Follow-up', 'No Answer', 'Converted'];
    return Wrap(
      spacing: 8.0,
      children: filters.map((filter) {
        return FilterChip(
          label: Text(filter),
          selected: _selectedFilter == filter,
          onSelected: (selected) {
            if (selected) {
              setState(() {
                _selectedFilter = filter;
              });
            }
          },
          selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
          checkmarkColor: Theme.of(context).primaryColor,
        );
      }).toList(),
    );
  }

  Widget _buildLeadsList() {
    // ... This widget remains the same
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 8, // Placeholder
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
          child: ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            title: Text(
              'Riya Gupta #${index + 1}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Status: $_selectedFilter',
              style: TextStyle(color: Colors.grey[600]),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.call_outlined),
                  onPressed: () {},
                  color: Colors.green,
                ),
                TextButton(
                  onPressed: () => _showAddFollowUpForm(context),
                  child: const Text('Follow-up'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
