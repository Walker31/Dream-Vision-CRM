import 'package:dreamvision/models/enquiry_model.dart';
import 'package:dreamvision/services/enquiry_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:intl/intl.dart';
import '../../charts/enquiry_status_data.dart';

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
  List<ChartData> _chartDataSource = [];

  @override
  void initState() {
    super.initState();
    _dashboardDataFuture = _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    try {
      final results = await Future.wait([
        _enquiryService.getRecentEnquiries(),
        _enquiryService.getEnquiryStatusSummary(),
      ]);

      final List<dynamic> recentEnquiryData = results[0] as List<dynamic>;
      final Map<String, dynamic> summaryData =
          results[1] as Map<String, dynamic>;
      final List<dynamic> chartSummaryData = summaryData['chart_data'] ?? [];

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

  List<ChartData> _buildChartDataFromSummary(List<dynamic> summaryData) {
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
      return ChartData(status, percentage, _getStatusColor(status));
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
                    EnquiryStatusChartCard(chartDataSource: _chartDataSource),
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