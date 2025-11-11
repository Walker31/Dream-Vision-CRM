import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:dreamvision/services/telecaller_service.dart';

class _StackedCallData {
  _StackedCallData(this.date, this.followUpsToday, this.cnrAndDone);

  final DateTime date;
  final int followUpsToday;
  final int cnrAndDone;

  factory _StackedCallData.fromJson(Map<String, dynamic> json) {
    return _StackedCallData(
      DateTime.parse(json['date']),
      json['followups_today'] as int,
      json['cnr_and_done'] as int,
    );
  }
}

class TelecallerCallChart extends StatefulWidget {
  const TelecallerCallChart({super.key});

  @override
  State<TelecallerCallChart> createState() => _TelecallerCallChartState();
}

class _TelecallerCallChartState extends State<TelecallerCallChart> {
  late DateTimeRange _selectedDateRange;
  List<_StackedCallData> _chartData = [];

  late final TelecallerService _service;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _service = TelecallerService();

    final now = DateTime.now();
    _selectedDateRange = DateTimeRange(
      start: now.subtract(const Duration(days: 6)),
      end: now,
    );

    _fetchChartData();
  }

  Future<void> _fetchChartData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final responseData = await _service.getCallActivityData(
        _selectedDateRange,
      );

      if (!mounted) return;

      final data = responseData
          .map(
            (json) => _StackedCallData.fromJson(json as Map<String, dynamic>),
          )
          .toList();

      if (!mounted) return;

      setState(() {
        _chartData = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (!mounted) return;

    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
      });

      _fetchChartData();
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
            _buildChartContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildChartContent() {
    if (_isLoading) {
      return const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return SizedBox(
        height: 220,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Failed to load chart data:\n$_errorMessage',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ),
      );
    }

    if (_chartData.isEmpty) {
      return const SizedBox(
        height: 220,
        child: Center(child: Text('No data for the selected range.')),
      );
    }

    return _buildAnalyticsChart();
  }

  Widget _buildAnalyticsChart() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final gridLineColor = isDarkMode ? Colors.white24 : Colors.black12;

    final followUpsColor = theme.primaryColor.withValues(alpha: 0.8);
    final cnrDoneColor = Colors.orange.shade400;

    return SizedBox(
      height: 220,
      child: SfCartesianChart(
        plotAreaBorderWidth: 0,
        legend: const Legend(
          isVisible: true,
          position: LegendPosition.bottom,
          overflowMode: LegendItemOverflowMode.wrap,
          textStyle: TextStyle(fontSize: 12),
        ),
        trackballBehavior: TrackballBehavior(
          enable: true,
          activationMode: ActivationMode.singleTap,
          tooltipSettings: InteractiveTooltip(
            enable: true,
            format: 'series.name: point.y',
            color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
            textStyle: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
        ),
        primaryXAxis: DateTimeAxis(
          majorGridLines: const MajorGridLines(width: 0),
          axisLine: const AxisLine(width: 0),
          edgeLabelPlacement: EdgeLabelPlacement.shift,
          dateFormat: DateFormat.MMMd(),
          labelStyle: const TextStyle(fontSize: 10),
        ),
        primaryYAxis: NumericAxis(
          isVisible: true,
          majorGridLines: MajorGridLines(width: 1, color: gridLineColor),
          axisLine: const AxisLine(width: 0),
          numberFormat: NumberFormat.decimalPattern(),
          minimum: 0,
          labelStyle: const TextStyle(fontSize: 10),
        ),
        series: <CartesianSeries>[
          StackedColumnSeries<_StackedCallData, DateTime>(
            dataSource: _chartData,
            xValueMapper: (data, _) => data.date,
            yValueMapper: (data, _) => data.followUpsToday,
            name: 'Follow-ups',
            color: followUpsColor,
            borderRadius: const BorderRadius.all(Radius.circular(4)),
          ),
          StackedColumnSeries<_StackedCallData, DateTime>(
            dataSource: _chartData,
            xValueMapper: (data, _) => data.date,
            yValueMapper: (data, _) => data.cnrAndDone,
            name: 'CNR / Done',
            color: cnrDoneColor,
            borderRadius: const BorderRadius.all(Radius.circular(4)),
          ),
        ],
      ),
    );
  }
}
