import 'package:dreamvision/models/enquiry_model.dart';
import 'package:dreamvision/services/enquiry_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';

// --- DATA MODELS ---
class _ChartData {
  _ChartData(this.status, this.value, this.color);
  final String status;
  final double value;
  final Color color;
}

class CounsellorDashboard extends StatefulWidget {
  const CounsellorDashboard({super.key});

  @override
  State<CounsellorDashboard> createState() => _CounsellorDashboardState();
}

class _CounsellorDashboardState extends State<CounsellorDashboard> {
  final Logger _logger = Logger();
  final EnquiryService _enquiryService = EnquiryService();

  late Future<void> _dashboardDataFuture;
  List<Enquiry> _recentEnquiries = [];
  List<_ChartData> _chartDataSource = [];

  @override
  void initState() {
    super.initState();
    _dashboardDataFuture = _fetchDashboardData();
  }

  /// Fetches both recent enquiries (for the list) and the full status summary (for the chart).
  Future<void> _fetchDashboardData() async {
    try {
      // Use Future.wait to run both API calls concurrently for speed
      final results = await Future.wait([
        _enquiryService.getRecentEnquiries(),
        _enquiryService.getEnquiryStatusSummary(),
      ]);

      // Process the results from Future.wait
      final List<dynamic> recentEnquiryData = results[0];
      final List<dynamic> chartSummaryData = results[1];

      final parsedEnquiries = recentEnquiryData
          .map((data) => Enquiry.fromJson(data))
          .toList();
      final parsedChartData = _buildChartDataFromSummary(chartSummaryData);

      if (mounted) {
        setState(() {
          _recentEnquiries = parsedEnquiries;
          _chartDataSource = parsedChartData;
        });
      }
    } catch (e) {
      _logger.e("Failed to fetch dashboard data: $e");
      throw Exception('Could not load dashboard data. Please try again.');
    }
  }

  /// Builds the chart data from the new aggregated summary API.
  List<_ChartData> _buildChartDataFromSummary(List<dynamic> summaryData) {
    if (summaryData.isEmpty) {
      return [];
    }

    final total = summaryData.fold<int>(
      0,
      (sum, item) => sum + (item['count'] as int),
    );

    return summaryData.map((item) {
      final status = item['status'] as String;
      final count = item['count'] as int;
      final percentage = total > 0 ? (count / total) * 100 : 0.0;
      return _ChartData(status, percentage, _getStatusColor(status));
    }).toList();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'interested':
        return Colors.blue.shade600;
      case 'converted':
        return Colors.green.shade600;
      case 'needs follow-up':
      case 'follow-up':
        return Colors.orange.shade600;
      case 'closed':
        return Colors.grey.shade600;
      default:
        return Colors.purple.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Image.asset(
            'assets/logo.jpg',
            width: 40,
            errorBuilder: (context, error, stackTrace) {
              _logger.e(error);
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
        title: const Text('Counsellor Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_outlined),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: FutureBuilder<void>(
        future: _dashboardDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _dashboardDataFuture = _fetchDashboardData();
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          } else {
            return RefreshIndicator(
              onRefresh: _fetchDashboardData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Enquiry Status Overview",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildAnalyticsCharts(),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Recent Enquiries",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.push('/all-enquiries'),
                          child: const Text('View All'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildEnquiryList(),
                  ],
                ),
              ),
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/add-enquiry'),
        label: const Text('New Enquiry'),
        icon: const Icon(Icons.add),
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildAnalyticsCharts() {
    if (_chartDataSource.isEmpty) {
      return const SizedBox(
        height: 160,
        child: Center(child: Text("No analytics data available.")),
      );
    }
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 160,
            child: SfCircularChart(
              series: <CircularSeries<_ChartData, String>>[
                DoughnutSeries<_ChartData, String>(
                  dataSource: _chartDataSource,
                  xValueMapper: (_ChartData data, _) => data.status,
                  yValueMapper: (_ChartData data, _) => data.value,
                  pointColorMapper: (_ChartData data, _) => data.color,
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
                  dataLabelMapper: (_ChartData data, _) =>
                      '${data.value.toStringAsFixed(0)}%',
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
            children: _chartDataSource
                .map(
                  (data) => _buildLegendItem(
                    data.color,
                    '${data.status} (${data.value.toStringAsFixed(1)}%)',
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(width: 16, height: 16, color: color),
          const SizedBox(width: 8),
          Flexible(child: Text(text)),
        ],
      ),
    );
  }

  Widget _buildEnquiryList() {
    if (_recentEnquiries.isEmpty) {
      return const SizedBox(
        height: 100,
        child: Center(child: Text("No recent enquiries found.")),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _recentEnquiries.length,
      itemBuilder: (context, index) {
        final enquiry = _recentEnquiries[index];
        final status = enquiry.currentStatusName ?? 'Unknown';
        final fullName = [
          enquiry.firstName,
          enquiry.middleName,
          enquiry.lastName,
        ].where((e) => e != null && e.isNotEmpty).join(' ');

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              vertical: 8,
              horizontal: 16,
            ),
            title: Text(
              fullName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  'Created: ${DateFormat.yMMMd().format(DateTime.parse(enquiry.createdAt))}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                Text(
                  'Total Interactions: ${enquiry.interactions.length}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            trailing: Chip(
              label: Text(
                status,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              backgroundColor: _getStatusColor(status),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              labelPadding: const EdgeInsets.symmetric(horizontal: 4.0),
            ),
            onTap: () {
              context.push('/enquiry/${enquiry.id}');
            },
          ),
        );
      },
    );
  }
}
