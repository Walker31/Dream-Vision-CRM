import 'package:dreamvision/charts/enquiry_status_data.dart';
import 'package:dreamvision/models/enquiry_model.dart';
import 'package:dreamvision/services/enquiry_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';

import '../../charts/sales_data.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with TickerProviderStateMixin {
  final EnquiryService _enquiryService = EnquiryService();
  final Logger logger = Logger();
  late TabController _tabController;

  late Future<void> _dashboardDataFuture;
  List<Enquiry> _assignedEnquiries = [];
  List<Enquiry> _unassignedEnquiries = [];
  List<ChartData> _chartDataSource = [];
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _dashboardDataFuture = _fetchDashboardData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchDashboardData() async {
    try {
      final results = await Future.wait([
        _enquiryService.getAllEnquiries(),
        _enquiryService.getEnquiryStatusSummary(),
      ]);

      final List<dynamic> enquiryData = results[0];
      final List<dynamic> chartSummaryData = results[1];

      final parsedEnquiries = enquiryData.map((data) => Enquiry.fromJson(data)).toList();
      final parsedChartData = _buildChartDataFromSummary(chartSummaryData);

      final assigned = parsedEnquiries.where((e) => e.assignedToCounsellorDetails != null || e.assignedToTelecallerDetails != null).toList();
      final unassigned = parsedEnquiries.where((e) => e.assignedToCounsellorDetails == null && e.assignedToTelecallerDetails == null).toList();

      if (mounted) {
        setState(() {
          _assignedEnquiries = assigned;
          _unassignedEnquiries = unassigned;
          _chartDataSource = parsedChartData;
        });
      }
    } catch (e) {
      logger.e("Failed to fetch dashboard data: $e");
      rethrow;
    }
  }

  List<ChartData> _buildChartDataFromSummary(List<dynamic> summaryData) {
    if (summaryData.isEmpty) return [];
    final total = summaryData.fold<int>(0, (sum, item) => sum + (item['count'] as int));
    return summaryData.map((item) {
      final status = item['status'] as String;
      final count = item['count'] as int;
      final percentage = total > 0 ? (count / total) * 100 : 0.0;
      return ChartData(status, percentage, _getStatusColor(status));
    }).toList();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'interested': return Colors.blue.shade600;
      case 'converted': return Colors.green.shade600;
      case 'needs follow-up':
      case 'follow-up': return Colors.orange.shade600;
      case 'closed': return Colors.grey.shade600;
      default: return Colors.purple.shade600;
    }
  }

  Future<void> _pickAndUploadFile() async {
    if (_isUploading) return;
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx']);
    if (result != null && result.files.single.path != null) {
      String filePath = result.files.single.path!;
      setState(() => _isUploading = true);
      try {
        final response = await _enquiryService.bulkUploadEnquiries(filePath);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response['message'] ?? 'Upload successful!'), backgroundColor: Colors.green));
          setState(() => _dashboardDataFuture = _fetchDashboardData());
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e', maxLines: 5), backgroundColor: Colors.red, duration: const Duration(seconds: 7)));
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
            icon: Padding(padding: const EdgeInsets.only(left: 8.0), child: Image.asset('assets/logo.jpg', errorBuilder: (c, e, s) => const Icon(Icons.menu))),
            onPressed: () => Scaffold.of(context).openDrawer(),
            tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
          ),
        ),
        actions: [IconButton(icon: const Icon(Icons.settings), onPressed: () => context.push('/settings'))],
      ),
      drawer: _buildDrawer(),
      body: FutureBuilder<void>(
        future: _dashboardDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && _unassignedEnquiries.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('Error: ${snapshot.error}', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: () => setState(() => _dashboardDataFuture = _fetchDashboardData()), child: const Text('Retry')),
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
          ListTile(title: const Text('Manage Users'), leading: const Icon(Icons.group_outlined), onTap: () { Navigator.pop(context); context.push('/users'); }),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildDashboardContent() {
    return RefreshIndicator(
      onRefresh: _fetchDashboardData,
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0),
              child: Column(
                children: [
                  const SalesChartCard(),
                  const SizedBox(height: 16),
                  EnquiryStatusChartCard(chartDataSource: _chartDataSource),
                  const SizedBox(height: 16),
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
          SliverPersistentHeader(delegate: _SliverAppBarDelegate(TabBar(controller: _tabController, tabs: [Tab(text: 'Unassigned (${_unassignedEnquiries.length})'), Tab(text: 'Assigned (${_assignedEnquiries.length})')])), pinned: true),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildEnquiryListView(_unassignedEnquiries, 'No unassigned enquiries found.'),
            _buildEnquiryListView(_assignedEnquiries, 'No assigned enquiries found.'),
          ],
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
            icon: _isUploading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.upload_file_outlined),
            label: Text(_isUploading ? 'Uploading...' : 'Bulk Add'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => context.push('/add-enquiry'),
            icon: const Icon(Icons.add),
            label: const Text('Add Enquiry'),
            style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          ),
        ],
      ),
    );
  }

  Widget _buildEnquiryListView(List<Enquiry> enquiries, String emptyMessage) {
    if (enquiries.isEmpty) return Center(child: Text(emptyMessage, style: TextStyle(color: Colors.grey[600])));
    return ListView.separated(
      // --- FIX 1 ---
      // Apply consistent padding to all sides.
      padding: const EdgeInsets.all(16.0),
      itemCount: enquiries.length,
      itemBuilder: (context, index) {
        final enquiry = enquiries[index];
        final fullName = '${enquiry.firstName} ${enquiry.lastName ?? ''}'.trim();
        final status = enquiry.currentStatusName ?? 'Unknown';
        return Card(
          // --- FIX 2 ---
          // Remove the Card's margin, let the ListView handle spacing.
          margin: EdgeInsets.zero,
          child: ListTile(
            title: Text(fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(enquiry.phoneNumber),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Chip(label: Text(status, style: const TextStyle(color: Colors.white, fontSize: 12)), backgroundColor: _getStatusColor(status), padding: const EdgeInsets.symmetric(horizontal: 4), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, labelPadding: const EdgeInsets.symmetric(horizontal: 4.0)),
                IconButton(
                  icon: const Icon(Icons.history, color: Colors.blueGrey),
                  tooltip: 'View Follow-ups',
                  onPressed: () {
                    context.push(
                      '/follow-ups/${enquiry.id}',
                      extra: fullName,
                    );
                  },
                ),
              ],
            ),
            onTap: () => context.push('/enquiry/${enquiry.id}'),
          ),
        );
      },
      separatorBuilder: (context, index) => const SizedBox(height: 8),
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
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: Theme.of(context).scaffoldBackgroundColor, child: _tabBar);
  }
  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}

