import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:dreamvision/services/telecaller_service.dart';

class _StackedCallData {
  final DateTime date;
  final int followUpsToday;
  final int cnrAndDone;

  _StackedCallData(this.date, this.followUpsToday, this.cnrAndDone);

  factory _StackedCallData.fromJson(Map<String, dynamic> json) {
    return _StackedCallData(
      DateTime.parse(json['date']),
      (json['followups_today'] ?? 0) as int,
      (json['cnr_and_done'] ?? 0) as int,
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
      final response = await _service.getCallActivityData(_selectedDateRange);
      final data = response
          .map((json) => _StackedCallData.fromJson(json))
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

    if (picked != null && picked != _selectedDateRange) {
      setState(() => _selectedDateRange = picked);
      _fetchChartData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
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
            overflow: TextOverflow.ellipsis,
          ),
          onPressed: () => _selectDateRange(context),
        ),
      ],
    );
  }

  Widget _buildContent() {
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
          child: Text(
            'Failed to load chart data:\n$_errorMessage',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_chartData.isEmpty) {
      return const SizedBox(
        height: 220,
        child: Center(child: Text('No data for selected range')),
      );
    }

    return _buildChart();
  }

  Widget _buildChart() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final gridColor = isDark ? Colors.white24 : Colors.black12;
    final followColor = isDark ? Colors.blue.shade300 : theme.primaryColor;
    final cnrDoneColor = isDark ? Colors.orange.shade300 : Colors.orange;

    return SizedBox(
      height: 220,
      child: SfCartesianChart(
        plotAreaBorderWidth: 0,
        legend: const Legend(isVisible: true, position: LegendPosition.bottom),
        primaryXAxis: DateTimeAxis(
          axisLine: const AxisLine(width: 0),
          majorGridLines: const MajorGridLines(width: 0),
          dateFormat: DateFormat.MMMd(),
        ),
        primaryYAxis: NumericAxis(
          axisLine: const AxisLine(width: 0),
          majorGridLines: MajorGridLines(color: gridColor),
          minimum: 0,
        ),
        series: [
          StackedColumnSeries<_StackedCallData, DateTime>(
            name: 'Follow-ups',
            dataSource: _chartData,
            xValueMapper: (d, _) => d.date,
            yValueMapper: (d, _) => d.followUpsToday,
            color: followColor,
          ),
          StackedColumnSeries<_StackedCallData, DateTime>(
            name: 'CNR + Done',
            dataSource: _chartData,
            xValueMapper: (d, _) => d.date,
            yValueMapper: (d, _) => d.cnrAndDone,
            color: cnrDoneColor,
          ),
        ],
      ),
    );
  }
}
