// AdminDashboard.dart

// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:dreamvision/charts/enquiry_status_data.dart';
import 'package:dreamvision/services/enquiry_service.dart';
import 'package:dreamvision/utils/global_error_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:open_filex/open_filex.dart';
import '../../charts/telecaller_call_chart.dart';
import '../../widgets/filter_bottom_sheet.dart';
import 'paginated_enquiry_list.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with TickerProviderStateMixin {
  late final EnquiryService _enquiryService;
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

  String? _selectedStandard;
  String? _selectedStatus;

  final List<String> _standardOptions = ['8th', '9th', '10th', '11th', '12th'];
  final List<String> _statusOptions = [
    'interested',
    'converted',
    'closed',
    'follow-up',
  ];

  @override
  void initState() {
    super.initState();
    _enquiryService = EnquiryService();
    _tabController = TabController(length: 2, vsync: this);

    _summaryDataFuture = _fetchSummaryData(
      standard: _selectedStandard,
      status: _selectedStatus,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshCountsOnly() {
    setState(() {
      _summaryDataFuture = _fetchSummaryData(
        standard: _selectedStandard,
        status: _selectedStatus,
      );
    });
  }

  Future<Map<String, dynamic>> _fetchSummaryData({
    String? standard,
    String? status,
  }) async {
    try {
      final summaryData = await _enquiryService.getEnquiryStatusSummary(
        standard: standard,
        status: status,
      );

      return summaryData;
    } catch (e, st) {
      logger.e("Failed to fetch summary data", error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> _refreshAllData() async {
    setState(() {
      _summaryDataFuture = _fetchSummaryData(
        standard: _selectedStandard,
        status: _selectedStatus,
      );
    });

    _unassignedListKey.currentState?.refreshWithFilters(
      _selectedStandard,
      _selectedStatus,
    );
    _assignedListKey.currentState?.refreshWithFilters(
      _selectedStandard,
      _selectedStatus,
    );

    await _summaryDataFuture;
  }

  int _safeInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    final s = value?.toString() ?? '';
    final parsed = int.tryParse(s);
    if (parsed == null) {
      logger.w('safeInt: could not parse "$value" as int, defaulting to 0');
      return 0;
    }
    return parsed;
  }

  double _safePercent(int count, int total) {
    if (total <= 0) return 0.0;
    final raw = (count / total) * 100.0;
    if (raw.isNaN || raw.isInfinite) return 0.0;
    final clamped = raw.clamp(0.0, 100.0);
    return clamped;
  }

  List<ChartData> _buildChartDataFromSummary(List<dynamic> summaryData) {
    if (summaryData.isEmpty) {
      logger.i('buildChartDataFromSummary: empty summaryData');
      return [];
    }

    int total = 0;
    for (final item in summaryData) {
      if (item is! Map) {
        logger.w('buildChartDataFromSummary: skipping non-map item: $item');
        continue;
      }
      total += _safeInt(item['count']);
    }

    if (total <= 0) {
      logger.w('buildChartDataFromSummary: total <= 0, returning empty list');
      return [];
    }

    final List<ChartData> chartList = [];
    for (final item in summaryData) {
      if (item is! Map) {
        logger.w('buildChartDataFromSummary: skipping invalid item: $item');
        continue;
      }

      final statusRaw = item['status'];
      final String status =
          (statusRaw == null || statusRaw.toString().trim().isEmpty)
          ? 'Unknown'
          : statusRaw.toString().trim();

      final int count = _safeInt(item['count']);
      final double percentage = _safePercent(count, total);

      chartList.add(ChartData(status, percentage, _getStatusColor(status)));
    }

    logger.i(
      'buildChartDataFromSummary: total=$total, chartList=${chartList.map((e) => '${e.status}:${e.value.toStringAsFixed(1)}').toList()}',
    );

    return chartList;
  }

  Color _getStatusColor(String? status) {
    final key = (status ?? '').trim().toLowerCase();

    final map = {
      'interested': Colors.blue.shade600,
      'converted': Colors.green.shade600,
      'follow-up': Colors.orange.shade600,
      'closed': Colors.grey.shade600,
      'unknown': Colors.purple.shade400,
    };

    return map[key] ?? Colors.purple.shade600;
  }

  Future<void> _pickAndUploadFile() async {
    if (_isUploading) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'csv'],
    );

    if (result != null && result.files.single.path != null) {
      final filePath = result.files.single.path!;
      setState(() => _isUploading = true);

      try {
        final response = await _enquiryService.bulkUploadEnquiries(filePath);
        GlobalErrorHandler.success(response['message'] ?? 'Upload successful!');

        await _refreshAllData();
      } catch (e, st) {
        logger.e("Bulk upload failed", error: e, stackTrace: st);
        GlobalErrorHandler.error('Upload failed: $e');
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  void _applyFilters(String? standard, String? status) {
    setState(() {
      _selectedStandard = standard;
      _selectedStatus = status;

      _summaryDataFuture = _fetchSummaryData(
        standard: standard,
        status: status,
      );
    });

    _unassignedListKey.currentState?.refreshWithFilters(standard, status);
    _assignedListKey.currentState?.refreshWithFilters(standard, status);
  }

  void _clearFilters() {
    setState(() {
      _selectedStandard = null;
      _selectedStatus = null;

      _summaryDataFuture = _fetchSummaryData(standard: null, status: null);
    });

    _unassignedListKey.currentState?.refreshWithFilters(null, null);
    _assignedListKey.currentState?.refreshWithFilters(null, null);
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return EnquiryFilterBottomSheet(
          initialStandard: _selectedStandard,
          initialStatus: _selectedStatus,
          standardOptions: _standardOptions,
          statusOptions: _statusOptions,
          onApplyFilters: _applyFilters,
          onClearFilters: _clearFilters,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Admin Dashboard'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: Image.asset(
              'assets/login_bg.png',
              errorBuilder: (c, e, s) => const Icon(Icons.menu),
            ),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          FilledButton.tonalIcon(
            onPressed: _isUploading ? null : _pickAndUploadFile,
            icon: _isUploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_file),
            label: Text(_isUploading ? 'Uploading...' : 'Bulk Add'),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _openFilterSheet,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      drawer: _buildDrawer(),
      floatingActionButton: _buildFAB(),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _summaryDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _buildErrorSection(snapshot.error.toString());
          }

          if (snapshot.hasData) {

            final data = snapshot.data!;
            logger.i('Summary Data fetched: $data');
            _unassignedCount = data['unassigned_count'] ?? 0;
            _assignedCount = data['assigned_count'] ?? 0;
            _chartDataSource = _buildChartDataFromSummary(
              data['chart_data'] ?? [],
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
            },
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return SpeedDial(
      icon: Icons.add,
      activeIcon: Icons.close,
      backgroundColor: Theme.of(context).colorScheme.primary,
      foregroundColor: Theme.of(context).colorScheme.onPrimary,
      elevation: 8,
      spaceBetweenChildren: 10,
      animationCurve: Curves.easeInOutBack,
      overlayOpacity: 0.3,
      children: [
        SpeedDialChild(
          child: const Icon(Icons.upload_file_rounded, color: Colors.white),
          label: 'Bulk Upload',
          backgroundColor: Colors.teal.shade600,
          foregroundColor: Colors.white,
          elevation: 5,
          onTap: _pickAndUploadFile,
        ),
        SpeedDialChild(
          child: const Icon(Icons.download_rounded, color: Colors.white),
          label: 'Download Required Sheet',
          backgroundColor: Colors.blueGrey.shade600,
          foregroundColor: Colors.white,
          elevation: 5,
          onTap: () async {
            try {
              final filePath = await _enquiryService.downloadEnquiryTemplate();

              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Template saved in Downloads folder'),
                  action: SnackBarAction(
                    label: 'Open',
                    onPressed: () async {
                      await OpenFilex.open(filePath);
                    },
                  ),
                  duration: const Duration(seconds: 8),
                ),
              );
            } catch (e, st) {
              logger.e("Download failed", error: e, stackTrace: st);
              if (mounted) {
                GlobalErrorHandler.error('Download failed: $e');
              }
            }
          },
        ),
        SpeedDialChild(
          child: const Icon(
            Icons.person_add_alt_1_rounded,
            color: Colors.white,
          ),
          label: 'Add Enquiry',
          backgroundColor: Colors.indigo.shade600,
          foregroundColor: Colors.white,
          elevation: 5,
          onTap: () => context.push('/add-enquiry'),
        ),
      ],
    );
  }

  Widget _buildErrorSection(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Error: $error', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _summaryDataFuture = _fetchSummaryData(
                  standard: _selectedStandard,
                  status: _selectedStatus,
                );
              });
            },
            child: const Text('Retry'),
          ),
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
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  tabs: [
                    Tab(text: 'Unassigned ($_unassignedCount)'),
                    Tab(text: 'Assigned ($_assignedCount)'),
                  ],
                ),
              ),
              pinned: true,
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              PaginatedEnquiryList(
                key: _unassignedListKey,
                type: EnquiryListType.unassigned,
                initialStandard: _selectedStandard,
                initialStatus: _selectedStatus,
                onChanged: _refreshCountsOnly,
              ),
              PaginatedEnquiryList(
                key: _assignedListKey,
                type: EnquiryListType.assigned,
                initialStandard: _selectedStandard,
                initialStatus: _selectedStatus,
                onChanged: _refreshCountsOnly,
              ),
            ],
          ),
        ),
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
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return true;
  }
}
