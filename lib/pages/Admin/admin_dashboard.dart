// AdminDashboard.dart

// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:dreamvision/charts/enquiry_status_data.dart';
import 'package:dreamvision/dialogs/bulk_upload_progress_dialog.dart';
import 'package:dreamvision/services/enquiry_service.dart';
import 'package:dreamvision/utils/global_error_handler.dart';
import 'package:dreamvision/utils/status_colors.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:open_filex/open_filex.dart';
import '../../charts/telecaller_call_chart.dart';
import '../../dialogs/telecaller_selection_dialog.dart';
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

  late Future<Map<String, dynamic>> _summaryDataFuture;
  List<ChartData> _chartDataSource = [];
  int _unassignedCount = 0;
  int _assignedCount = 0;
  Map<String, int> _statusCounts = {};
  List<String> _allStatuses = [];
  bool _isUploading = false;
  bool _isRefreshing = false; // Track refresh state for visual feedback

  String? _selectedStandard;
  String? _selectedStatus;
  int? _selectedTelecallerId;

  final List<String> _standardOptions = ['8th', '9th', '10th', '11th', '12th'];
  final ScrollController _scrollController = ScrollController();
  late final PageStorageBucket _unassignedBucket = PageStorageBucket();
  late final PageStorageBucket _assignedBucket = PageStorageBucket();
  final GlobalKey<State<PaginatedEnquiryList>> _unassignedListKey = GlobalKey();
  final GlobalKey<State<PaginatedEnquiryList>> _assignedListKey = GlobalKey();
  List<Map<String, dynamic>> _telecallerOptions = [];
  bool _isLoadingTelecallers = true;
  // Removed hardcoded _statusOptions - now fetched from API via statusNamesProvider

  @override
  void initState() {
    super.initState();
    _enquiryService = EnquiryService();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);

    _summaryDataFuture = _fetchSummaryData(
      standard: _selectedStandard,
      status: _selectedStatus,
      telecallerId: _selectedTelecallerId,
    );
    _fetchAllStatuses();
    _fetchStatusCounts();
    _fetchAssignedUnassignedCounts();
    _fetchTelecallers();
  }

  void _onTabChanged() {
    setState(() {}); // Rebuild to update IndexedStack
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _refreshCountsOnly() {
    setState(() {
      _summaryDataFuture = _fetchSummaryData(
        standard: _selectedStandard,
        status: _selectedStatus,
        telecallerId: _selectedTelecallerId,
      );
    });
    _fetchStatusCounts();
    _fetchAssignedUnassignedCounts();
  }

  Future<void> _fetchTelecallers() async {
    try {
      final result = await _enquiryService.getAssignableUsers(
        role: 'Telecaller',
      );
      if (mounted) {
        setState(() {
          _telecallerOptions = (result)
              .whereType<Map<String, dynamic>>()
              .toList();
          _isLoadingTelecallers = false;
        });
      }
    } catch (e) {
      logger.e("Failed to fetch telecallers: $e");
      if (mounted) {
        setState(() => _isLoadingTelecallers = false);
      }
    }
  }

  Future<void> _fetchAllStatuses() async {
    try {
      final response = await _enquiryService.getEnquiryStatuses();
      final statuses = (response)
          .map((s) => (s as Map<String, dynamic>)['name'] as String)
          .toList();
      if (mounted) {
        setState(() {
          _allStatuses = statuses;
        });
      }
    } catch (e) {
      logger.e("Failed to fetch all statuses: $e");
    }
  }

  Future<void> _fetchStatusCounts() async {
    try {
      final response = await _enquiryService.getStatusCounts(
        standard: _selectedStandard,
        status: _selectedStatus,
        telecallerId: _selectedTelecallerId,
      );
      final List<dynamic> counts = response['status_counts'] ?? [];
      final Map<String, int> countMap = {};

      // Initialize all statuses with 0 count
      for (var status in _allStatuses) {
        countMap[status] = 0;
      }

      // Update with actual counts
      for (var item in counts) {
        if (item is Map<String, dynamic> && item['status'] != null) {
          final count = item['count'];
          countMap[item['status']] = count is int ? count : 0;
        }
      }
      if (mounted) {
        setState(() {
          _statusCounts = countMap;
        });
      }
    } catch (e) {
      logger.e("Failed to fetch status counts: $e");
    }
  }

  /// Fetch accurate assigned/unassigned counts from dedicated API endpoint
  /// Respects current filters (standard, status, telecaller)
  Future<void> _fetchAssignedUnassignedCounts() async {
    try {
      final response = await _enquiryService.getAssignedUnassignedCounts(
        standard: _selectedStandard,
        status: _selectedStatus,
        telecallerId: _selectedTelecallerId,
      );
      if (mounted) {
        setState(() {
          _unassignedCount = response['unassigned_count'] ?? 0;
          _assignedCount = response['assigned_count'] ?? 0;
        });
      }
      logger.i(
        'Assigned/Unassigned counts: assigned=$_assignedCount, unassigned=$_unassignedCount (standard: $_selectedStandard, status: $_selectedStatus, telecaller: $_selectedTelecallerId)',
      );
    } catch (e) {
      logger.e("Failed to fetch assigned/unassigned counts: $e");
    }
  }

  Future<Map<String, dynamic>> _fetchSummaryData({
    String? standard,
    String? status,
    int? telecallerId,
  }) async {
    try {
      final summaryData = await _enquiryService.getEnquiryStatusSummary(
        standard: standard,
        status: status,
        telecallerId: telecallerId,
      );

      return summaryData;
    } catch (e, st) {
      logger.e("Failed to fetch summary data", error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> _refreshAllData() async {
    if (_isRefreshing) return; // Prevent multiple refresh attempts

    setState(() {
      _isRefreshing = true;
      _summaryDataFuture = _fetchSummaryData(
        standard: _selectedStandard,
        status: _selectedStatus,
        telecallerId: _selectedTelecallerId,
      );
    });

    try {
      await _summaryDataFuture;
      logger.i('✅ Summary data refreshed successfully');

      // Refresh assigned/unassigned counts with error handling
      try {
        await _fetchAssignedUnassignedCounts();
        logger.i(
          '✅ Assigned/Unassigned counts refreshed: unassigned=$_unassignedCount, assigned=$_assignedCount',
        );
      } catch (e) {
        logger.w('⚠️ Failed to refresh counts: $e');
        // Don't fail the entire refresh if only counts fail
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Note: Could not refresh counts, but dashboard updated',
              ),
              duration: const Duration(seconds: 3),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      // Refresh paginated lists with current filters
      if (_unassignedListKey.currentState is PaginatedEnquiryListState) {
        (_unassignedListKey.currentState as PaginatedEnquiryListState)
            .refreshWithFilters(
              _selectedStandard,
              _selectedStatus,
              _selectedTelecallerId,
            );
      }
      if (_assignedListKey.currentState is PaginatedEnquiryListState) {
        (_assignedListKey.currentState as PaginatedEnquiryListState)
            .refreshWithFilters(
              _selectedStandard,
              _selectedStatus,
              _selectedTelecallerId,
            );
      }

      logger.i('✅ All dashboard data refreshed successfully');
    } catch (e, st) {
      logger.e('❌ Dashboard refresh failed: $e', stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to refresh dashboard'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
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

    return chartList;
  }

  Color _getStatusColor(String? status) {
    return StatusColors.getShade600Color(status);
  }

  Future<void> _pickAndUploadFile() async {
    if (_isUploading) return;

    // First, show modal to select telecaller
    final selectedTelecaller = await _showTelecallerSelectionModal();
    if (selectedTelecaller == null) {
      return; // User cancelled
    }

    // Then pick file
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'csv'],
    );

    if (result != null && result.files.single.path != null) {
      final filePath = result.files.single.path!;
      setState(() => _isUploading = true);

      try {
        // Start the upload and get session ID
        final response = await _enquiryService.bulkUploadEnquiries(
          filePath,
          telecallerId: selectedTelecaller['id'],
        );

        final sessionId = response['session_id'];
        final totalRecords = response['total_records'] ?? 0;

        if (mounted && sessionId != null) {
          // Show progress dialog
          final result = await showDialog<Map<String, dynamic>>(
            context: context,
            barrierDismissible: false,
            builder: (context) => BulkUploadProgressDialog(
              sessionId: sessionId,
              totalRecords: totalRecords,
            ),
          );

          if (result != null && result['total_created'] != null) {
            final created = result['total_created'];
            final updated = result['total_updated'];
            final assignedName =
                result['assigned_telecaller_name'] ?? 'Unknown';
            GlobalErrorHandler.success(
              '✓ Successfully imported $created new enquiries\n'
              '◆ Updated $updated existing enquiries\n'
              '👤 Assigned to: $assignedName\n'
              '📊 Counts will update in 1-2 seconds',
            );

            // Small delay to ensure backend cache is cleared
            await Future.delayed(const Duration(seconds: 1));
            await _refreshAllData();
          }
        }
      } catch (e, st) {
        logger.e("Bulk upload failed", error: e, stackTrace: st);
        GlobalErrorHandler.error('Upload failed: $e');
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  Future<Map<String, dynamic>?> _showTelecallerSelectionModal() async {
    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return TelecallerSelectionDialog(
          enquiryService: _enquiryService,
          logger: logger,
        );
      },
    );
  }

  void _applyFilters(
    String? standard,
    String? status,
    int? telecallerId,
    String? teleName,
  ) {
    setState(() {
      _selectedStandard = standard;
      _selectedStatus = status;
      _selectedTelecallerId = telecallerId;

      _summaryDataFuture = _fetchSummaryData(
        standard: standard,
        status: status,
        telecallerId: telecallerId,
      );
    });

    _fetchStatusCounts();
  }

  void _clearFilters() {
    setState(() {
      _selectedStandard = null;
      _selectedStatus = null;
      _selectedTelecallerId = null;

      _summaryDataFuture = _fetchSummaryData(
        standard: null,
        status: null,
        telecallerId: null,
      );
    });

    _fetchStatusCounts();
  }

  void _openFilterSheet() {
    // Ensure status counts are fetched before opening
    _fetchStatusCounts();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        // Convert comma-separated strings back to Sets for filter sheet
        final initialStandards = _selectedStandard != null
            ? _selectedStandard!.split(',').map((s) => s.trim()).toSet()
            : <String>{};
        final initialStatuses = _selectedStatus != null
            ? _selectedStatus!.split(',').map((s) => s.trim()).toSet()
            : <String>{};

        return EnquiryFilterBottomSheet(
          initialStandards: initialStandards,
          initialStatuses: initialStatuses,
          initialTelecallerId: _selectedTelecallerId,
          standardOptions: _standardOptions,
          statusCounts: _statusCounts,
          telecallerOptions: _telecallerOptions,
          isLoadingTelecallers: _isLoadingTelecallers,
          onApplyFilters: (standards, statuses, [telecallerId, teleName]) {
            // Convert Set to comma-separated string for backend (supports multiple values)
            final standard = standards.isNotEmpty ? standards.join(',') : null;
            final status = statuses.isNotEmpty ? statuses.join(',') : null;
            _applyFilters(standard, status, telecallerId, teleName);
          },
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
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Builder(
            builder: (context) => GestureDetector(
              onTap: () {
                Scaffold.of(context).openDrawer();
              },
              child: Image.asset(
                'assets/logo.jpeg',
                width: 40,
                errorBuilder: (context, error, stackTrace) {
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
          ),
        ),
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _openFilterSheet,
          ),
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
            title: const Text('Bulk Upload Enquiries'),
            leading: _isUploading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_file),
            enabled: !_isUploading,
            onTap: _isUploading
                ? null
                : () {
                    Navigator.pop(context);
                    _pickAndUploadFile();
                  },
          ),
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
          controller: _scrollController,
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0),
                child: Column(
                  children: [
                    const TelecallerCallChart(),
                    const SizedBox(height: 16),
                    EnquiryStatusChartCard(
                      chartDataSource: _chartDataSource,
                      statusCounts: _statusCounts,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            SliverAppBar(
              pinned: true,
              toolbarHeight: 48,
              automaticallyImplyLeading: false,
              backgroundColor: Theme.of(context).colorScheme.surface,
              elevation: 0,
              flexibleSpace: Row(
                children: [
                  Expanded(
                    child: TabBar(
                      controller: _tabController,
                      tabs: [
                        Tab(text: 'Unassigned ($_unassignedCount)'),
                        Tab(text: 'Assigned ($_assignedCount)'),
                      ],
                    ),
                  ),
                  if (_isRefreshing)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh counts',
                      onPressed: _refreshAllData,
                      iconSize: 20,
                    ),
                ],
              ),
            ),
          ],
          body: IndexedStack(
            index: _tabController.index,
            children: [
              PageStorage(
                bucket: _unassignedBucket,
                child: PaginatedEnquiryList(
                  key: _unassignedListKey,
                  type: EnquiryListType.unassigned,
                  initialStandard: _selectedStandard,
                  initialStatus: _selectedStatus,
                  onChanged: _refreshCountsOnly,
                ),
              ),
              PageStorage(
                bucket: _assignedBucket,
                child: PaginatedEnquiryList(
                  key: _assignedListKey,
                  type: EnquiryListType.assigned,
                  initialStandard: _selectedStandard,
                  initialStatus: _selectedStatus,
                  onChanged: _refreshCountsOnly,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
