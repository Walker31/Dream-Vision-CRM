import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'dart:math';

// Data model for the chart
class _SalesData {
  _SalesData(this.date, this.sales);
  final DateTime date;
  final double sales;
}

class SalesChartCard extends StatefulWidget {
  const SalesChartCard({super.key});

  @override
  State<SalesChartCard> createState() => _SalesChartCardState();
}

class _SalesChartCardState extends State<SalesChartCard> {
  late DateTimeRange _selectedDateRange;
  late List<_SalesData> _allSalesData;
  List<_SalesData> _filteredChartData = [];

  @override
  void initState() {
    super.initState();
    _allSalesData = _generateDummyData();

    final now = DateTime.now();
    _selectedDateRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: now,
    );

    _filterData();
  }

  List<_SalesData> _generateDummyData() {
    final random = Random();
    final today = DateTime.now();
    return List.generate(365, (index) {
      final date = today.subtract(Duration(days: index));
      final sales = 30 + random.nextDouble() * 70;
      return _SalesData(date, sales);
    });
  }

  void _filterData() {
    setState(() {
      _filteredChartData = _allSalesData.where((data) {
        final startDate = _selectedDateRange.start;
        final endDate = DateTime(
          _selectedDateRange.end.year,
          _selectedDateRange.end.month,
          _selectedDateRange.end.day,
          23,
          59,
          59,
        );
        return !data.date.isBefore(startDate) && !data.date.isAfter(endDate);
      }).toList();
      _filteredChartData.sort((a, b) => a.date.compareTo(b.date));
    });
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
        _filterData();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  'Sales Overview',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),

                // --- FIX IS HERE ---
                Flexible(
                  // 1. Wrap the button in Flexible
                  child: TextButton.icon(
                    icon: const Icon(Icons.calendar_today_outlined, size: 16),
                    label: Text(
                      '${DateFormat.yMMMd().format(_selectedDateRange.start)} - ${DateFormat.yMMMd().format(_selectedDateRange.end)}',
                      // 2. Add overflow handling to the Text
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    ),
                    onPressed: () => _selectDateRange(context),
                  ),
                ),
                // --- END OF FIX ---
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(height: 150, child: _buildSyncfusionChart()),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncfusionChart() {
    final theme = Theme.of(context);
    final gridLineColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white24
        : Colors.black12;
    return SfCartesianChart(
      trackballBehavior: TrackballBehavior(
        enable: true,
        activationMode: ActivationMode.singleTap,
        tooltipSettings: const InteractiveTooltip(
          enable: true,
          format: 'point.x, \$point.y',
        ),
      ),
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
        numberFormat: NumberFormat.compactSimpleCurrency(locale: 'en_IN'),
      ),
      plotAreaBorderWidth: 0,
      series: <CartesianSeries<_SalesData, DateTime>>[
        SplineAreaSeries<_SalesData, DateTime>(
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
        ),
      ],
    );
  }
}
