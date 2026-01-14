import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

/// Data model for the pie chart
class ChartData {
  ChartData(this.status, this.value, this.color);
  final String status;
  final double value;
  final Color color;
}

class EnquiryStatusChartCard extends StatelessWidget {
  final List<ChartData> chartDataSource;
  final Map<String, int>? statusCounts;

  const EnquiryStatusChartCard({
    super.key,
    required this.chartDataSource,
    this.statusCounts,
  });

  double _safeValue(double v) {
    if (v.isNaN || v.isInfinite) return 0.0;
    if (v < 0) return 0.0;
    return v;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Enquiry Status Overview",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildAnalyticsCharts(context),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsCharts(BuildContext context) {
    if (chartDataSource.isEmpty) {
      return const SizedBox(
        height: 160,
        child: Center(child: Text("No status data available.")),
      );
    }

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 160,
            child: SfCircularChart(
              series: <CircularSeries<ChartData, String>>[
                DoughnutSeries<ChartData, String>(
                  dataSource: chartDataSource,
                  xValueMapper: (ChartData data, _) => data.status,
                  yValueMapper: (ChartData data, _) => _safeValue(data.value),
                  pointColorMapper: (ChartData data, _) => data.color,
                  innerRadius: '60%',
                  dataLabelSettings: const DataLabelSettings(
                    isVisible: true,
                    textStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    labelPosition: ChartDataLabelPosition.inside,
                    labelIntersectAction: LabelIntersectAction.hide,
                  ),
                  dataLabelMapper: (ChartData data, _) {
                    final v = _safeValue(data.value);
                    return '${v.toStringAsFixed(0)}%';
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: chartDataSource
                .map(
                  (data) => _buildLegendItem(
                    data.color,
                    '${data.status} (${_safeValue(data.value).toStringAsFixed(1)}%)',
                    statusCounts?[data.status] ?? 0,
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String text, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(width: 16, height: 16, color: color),
          const SizedBox(width: 8),
          Flexible(child: Text(text)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
