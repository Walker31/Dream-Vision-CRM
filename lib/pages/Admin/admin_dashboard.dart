import 'dart:async';
import 'package:dreamvision/charts/enquiry_status_data.dart';
import 'package:dreamvision/services/enquiry_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';

import '../../charts/telecaller_call_chart.dart';
import 'paginated_enquiry_list.dart'; // Import the new file

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with TickerProviderStateMixin {
  final EnquiryService _enquiryService = EnquiryService();
  final Logger logger = Logger();
  late TabController _tabController;

  final GlobalKey<PaginatedEnquiryListState> _unassignedListKey =
      GlobalKey<PaginatedEnquiryListState>();
  final GlobalKey<PaginatedEnquiryListState> _assignedListKey =
      GlobalKey<PaginatedEnquiryListState>();

  late Future<Map<String, dynamic>> _summaryDataFuture;
  List<ChartData> _chartDataSource = [];
  int _unassignedCount = 0;
  int _assignedCount = 0;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _summaryDataFuture = _fetchSummaryData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _fetchSummaryData() async {
    try {
      final summaryData = await _enquiryService.getEnquiryStatusSummary();

      final List<dynamic> chartSummaryData = summaryData['chart_data'] ?? [];
      final int unassignedCount = summaryData['unassigned_count'] ?? 0;
      final int assignedCount = summaryData['assigned_count'] ?? 0;

      final parsedChartData = _buildChartDataFromSummary(chartSummaryData);

      if (mounted) {
        setState(() {
          _chartDataSource = parsedChartData;
          _unassignedCount = unassignedCount;
          _assignedCount = assignedCount;
        });
      }
      return summaryData;
    } catch (e) {
      logger.e("Failed to fetch summary data: $e");
      rethrow;
    }
  }

  Future<void> _refreshAllData() async {
    setState(() {
      _summaryDataFuture = _fetchSummaryData();
    });

    _unassignedListKey.currentState?.refresh();
    _assignedListKey.currentState?.refresh();

    await _summaryDataFuture;
  }

  List<ChartData> _buildChartDataFromSummary(List<dynamic> summaryData) {
    if (summaryData.isEmpty) return [];
    final total =
        summaryData.fold<int>(0, (sum, item) => sum + (item['count'] as int));
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

  Future<void> _pickAndUploadFile() async {
    if (_isUploading) return;
    FilePickerResult? result = await FilePicker.platform
        .pickFiles(type: FileType.custom, allowedExtensions: ['xlsx', 'csv']);
    if (result != null && result.files.single.path != null) {
      String filePath = result.files.single.path!;
      setState(() => _isUploading = true);
      try {
        final response = await _enquiryService.bulkUploadEnquiries(filePath);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(response['message'] ?? 'Upload successful!'),
              backgroundColor: Colors.green));

          _refreshAllData();
        }
      } catch (e) {
        logger.e(e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Upload failed: $e', maxLines: 5),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 7)));
        }
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Image.asset('assets/logo.jpg',
                    errorBuilder: (c, e, s) => const Icon(Icons.menu))),
            onPressed: () => Scaffold.of(context).openDrawer(),
            tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
          ),
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => context.push('/settings'))
        ],
      ),
      drawer: _buildDrawer(),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _summaryDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child:
                  Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('Error: ${snapshot.error}', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                    onPressed: () =>
                        setState(() { _summaryDataFuture = _fetchSummaryData(); }),
                    child: const Text('Retry')),
              ]),
            );
          }
          return _buildDashboardContent();
        },
      ),
    );
  }

  Drawer _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          const SizedBox(height: 72),
          ListTile(
              title: const Text('Manage Users'),
              leading: const Icon(Icons.group_outlined),
              onTap: () {
                Navigator.pop(context);
                context.push('/users');
              }),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildDashboardContent() {
    return ScrollConfiguration(
      behavior: const ScrollBehavior().copyWith(overscroll: false),
      child: RefreshIndicator(
        onRefresh: _refreshAllData,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0),
                child: Column(
                  children: [
                    const TelecallerCallChart(),
                    const SizedBox(height: 16),
                    EnquiryStatusChartCard(chartDataSource: _chartDataSource),
                    const SizedBox(height: 16),
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
                delegate: _SliverAppBarDelegate(TabBar(
                    controller: _tabController,
                    tabs: [
                      Tab(text: 'Unassigned ($_unassignedCount)'),
                      Tab(text: 'Assigned ($_assignedCount)')
                    ])),
                pinned: true),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              PaginatedEnquiryList(
                key: _unassignedListKey,
                type: EnquiryListType.unassigned,
              ),
              PaginatedEnquiryList(
                key: _assignedListKey,
                type: EnquiryListType.assigned,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Align(
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton.icon(
            onPressed: _isUploading ? null : _pickAndUploadFile,
            icon: _isUploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.upload_file_outlined),
            label: Text(_isUploading ? 'Uploading...' : 'Bulk Add'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => context.push('/add-enquiry'),
            icon: const Icon(Icons.add),
            label: const Text('Add Enquiry'),
            style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
          ),
        ],
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);
  final TabBar _tabBar;
  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;
  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
        color: Theme.of(context).scaffoldBackgroundColor, child: _tabBar);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}