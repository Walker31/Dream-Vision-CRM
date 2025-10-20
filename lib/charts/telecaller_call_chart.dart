import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'dart:math';

// Data model for the chart
class _CallChartData {
  _CallChartData(this.date, this.calls);
  final DateTime date;
  final int calls;
}

class TelecallerCallChart extends StatefulWidget {
  const TelecallerCallChart({super.key});

  @override
  State<TelecallerCallChart> createState() => _TelecallerCallChartState();
}

class _TelecallerCallChartState extends State<TelecallerCallChart> {
  late DateTimeRange _selectedDateRange;
  late List<_CallChartData> _allCallData;
  List<_CallChartData> _filteredChartData = [];

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

  List<_CallChartData> _generateDummyCallData() {
    final random = Random();
    final today = DateTime.now();
    return List.generate(365, (index) {
      final date = today.subtract(Duration(days: index));
      final calls = 20 + random.nextInt(45);
      return _CallChartData(date, calls);
    });
  }

  void _filterData() {
    setState(() {
      _filteredChartData = _allCallData.where((data) {
        final startDate = _selectedDateRange.start;
        // Set end date to end of the day
        final endDate = DateTime(_selectedDateRange.end.year,
            _selectedDateRange.end.month, _selectedDateRange.end.day, 23, 59, 59);
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
                  'Call Activity',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Flexible(
                  child: TextButton.icon(
                    icon: const Icon(Icons.calendar_today_outlined, size: 16),
                    label: Text(
                      '${DateFormat.yMMMd().format(_selectedDateRange.start)} - ${DateFormat.yMMMd().format(_selectedDateRange.end)}',
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    ),
                    onPressed: () => _selectDateRange(context),
                  ),
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
          ColumnSeries<_CallChartData, DateTime>(
            dataSource: _filteredChartData,
            xValueMapper: (_CallChartData data, _) => data.date,
            yValueMapper: (_CallChartData data, _) => data.calls,
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
}