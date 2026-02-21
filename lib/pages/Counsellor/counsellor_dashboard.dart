import 'package:dreamvision/models/enquiry_model.dart';
import 'package:dreamvision/services/enquiry_service.dart';
import 'package:dreamvision/utils/error_helper.dart';
import 'package:dreamvision/utils/status_colors.dart';
import 'package:dreamvision/widgets/filter_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../charts/enquiry_status_data.dart';

class CounsellorDashboard extends StatefulWidget {
  const CounsellorDashboard({super.key});

  @override
  State<CounsellorDashboard> createState() => _CounsellorDashboardState();
}

class _CounsellorDashboardState extends State<CounsellorDashboard> {
  final Logger _logger = Logger();
  final EnquiryService _enquiryService = EnquiryService();
  late SharedPreferences _prefs;

  late Future<void> _dashboardDataFuture;
  List<Enquiry> _allEnquiries = [];
  List<ChartData> _chartDataSource = [];
  Map<String, int> _statusCounts = {};
  List<String> _allStatuses = [];
  int _totalCount = 0;
  int _currentPage = 1;
  bool _hasNextPage = true;
  bool _isLoadingMore = false;

  // Filter state
  Set<String> _selectedStandards = {};
  Set<String> _selectedStatuses = {};
  bool _selectedCnr = false;
  String _searchQuery = '';

  final List<String> _standardOptions = ['8th', '9th', '10th', '11th', '12th'];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  
  static const String _searchStorageKey = 'counsellor_dashboard_search';
  static const String _scrollPositionStorageKey = 'counsellor_dashboard_scroll_position';
  // Removed hardcoded _statusOptions - now fetched from API via statusNamesProvider

  @override
  void initState() {
    super.initState();
    _dashboardDataFuture = _initializeAndLoad();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _initializeAndLoad() async {
    _prefs = await SharedPreferences.getInstance();
    
    // Restore search from storage
    final savedSearch = _prefs.getString(_searchStorageKey) ?? '';
    if (mounted && savedSearch.isNotEmpty) {
      _searchController.text = savedSearch;
      _searchQuery = savedSearch;
    }
    
    // Fetch all statuses first so _statusCounts map can be initialized with all statuses
    await _fetchAllStatuses();
    await _fetchDashboardData();
    
    // Restore scroll position after data loads
    if (mounted) {
      await _restoreScrollPosition();
    }
  }

  Future<void> _saveSearchToStorage(String query) async {
    if (query.isEmpty) {
      await _prefs.remove(_searchStorageKey);
    } else {
      await _prefs.setString(_searchStorageKey, query);
    }
  }

  Future<void> _saveScrollPosition() async {
    final position = _scrollController.hasClients 
        ? _scrollController.offset 
        : 0.0;
    await _prefs.setDouble(_scrollPositionStorageKey, position);
  }

  Future<void> _restoreScrollPosition() async {
    final savedPosition = _prefs.getDouble(_scrollPositionStorageKey) ?? 0.0;
    if (_scrollController.hasClients && savedPosition > 0) {
      await Future.delayed(const Duration(milliseconds: 50));
      _scrollController.jumpTo(savedPosition);
    }
  }

  @override
  void dispose() {
    _saveScrollPosition();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _saveSearchToStorage(_searchController.text);
    setState(() => _searchQuery = _searchController.text);
    _refresh();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        _hasNextPage &&
        !_isLoadingMore) {
      _fetchAllEnquiries(page: _currentPage + 1);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _currentPage = 1;
      _hasNextPage = true;
      _allEnquiries = [];
      _totalCount = 0;
    });
    await _fetchDashboardData();
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
      _logger.e("Failed to fetch all statuses: $e");
    }
  }

  Future<void> _fetchDashboardData() async {
    try {
      final standardsParam = _selectedStandards.isNotEmpty
          ? _selectedStandards.join(',')
          : null;
      final statusParam = _selectedStatuses.isNotEmpty
          ? _selectedStatuses.join(',')
          : null;

      _logger.i(
        'Fetching counsellor dashboard - Standards: $standardsParam, Status: $statusParam, Search: $_searchQuery',
      );

      // Fetch all enquiries paginated, chart data and status counts
      await Future.wait([
        _fetchAllEnquiries(page: 1),
        _fetchChartData(standardsParam, statusParam),
        _fetchStatusCounts(standardsParam, statusParam),
      ]);
    } catch (e) {
      _logger.e("Failed to fetch dashboard data: $e");
      final userMessage = ErrorHelper.getUserMessage(e);
      throw Exception(userMessage);
    }
  }

  Future<void> _fetchAllEnquiries({int page = 1}) async {
    try {
      final retryPolicy = RetryPolicy();
      final standardsParam = _selectedStandards.isNotEmpty
          ? _selectedStandards.join(',')
          : null;
      final statusParam = _selectedStatuses.isNotEmpty
          ? _selectedStatuses.join(',')
          : null;

      if (page > 1) {
        _isLoadingMore = true;
      }

      final response = await retryPolicy.execute(
        () => _enquiryService.getAllEnquiries(
          page: page,
          search: _searchQuery.isNotEmpty ? _searchQuery : null,
          standard: standardsParam,
          status: statusParam,
          cnr: _selectedCnr ? 'true' : null,
        ),
      );

      final results = response['results'] as List<dynamic>? ?? [];
      final newEnquiries = results.map((e) => Enquiry.fromJson(e)).toList();

      // Extract total count from response
      final totalCount = response['count'] as int? ?? 0;
      final hasNext = response['next'] != null;

      if (!mounted) return;

      setState(() {
        if (page == 1) {
          _allEnquiries = newEnquiries;
          _currentPage = 1;
          _totalCount = totalCount;
        } else {
          _allEnquiries.addAll(newEnquiries);
          _currentPage = page;
          _totalCount = totalCount;
        }
        _hasNextPage = hasNext;
        _isLoadingMore = false;
      });
    } catch (e) {
      _logger.e("Failed to fetch enquiries: $e");
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<void> _fetchChartData(
    String? standardsParam,
    String? statusParam,
  ) async {
    try {
      final retryPolicy = RetryPolicy();
      final summaryData = await retryPolicy.execute(
        () => _enquiryService.getEnquiryStatusSummary(
          standard: standardsParam,
          status: statusParam,
        ),
      );

      final List<dynamic> chartSummaryData = summaryData['chart_data'] ?? [];
      final parsedChartData = _buildChartDataFromSummary(chartSummaryData);

      if (mounted) {
        setState(() => _chartDataSource = parsedChartData);
      }
    } catch (e) {
      _logger.e("Failed to fetch chart data: $e");
    }
  }

  Future<void> _fetchStatusCounts(
    String? standardsParam,
    String? statusParam,
  ) async {
    try {
      final retryPolicy = RetryPolicy();
      final statusCountData = await retryPolicy.execute(
        () => _enquiryService.getStatusCounts(
          search: _searchQuery.isNotEmpty ? _searchQuery : null,
          standard: standardsParam,
          status: statusParam,
        ),
      );

      final List<dynamic> statusCountsList =
          statusCountData['status_counts'] ?? [];

      // Build status counts map with all statuses initialized to 0
      final Map<String, int> counts = {};
      for (var status in _allStatuses) {
        counts[status] = 0;
      }
      
      // Update with actual counts
      for (var item in statusCountsList) {
        counts[item['status']] = item['count'] as int;
      }

      if (mounted) {
        setState(() => _statusCounts = counts);
      }
    } catch (e) {
      _logger.e("Failed to fetch status counts: $e");
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

    _logger.i('Chart Data Debug: Total enquiries in chart: $total');
    _logger.i('Chart Data Items: $summaryData');

    return summaryData.map((item) {
      final status = item['status'] as String;
      final count = item['count'] as int;
      final percentage = total > 0 ? (count / total) * 100 : 0.0;
      _logger.i(
        'Chart Item - Status: $status, Count: $count, Percentage: $percentage',
      );
      return ChartData(status, percentage, _getStatusColor(status));
    }).toList();
  }

  Color _getStatusColor(String status) {
    return StatusColors.getShade600Color(status);
  }

  void _applyFilters(Set<String> standards, Set<String> statuses, [int? telecallerId, String? teleName]) {
    setState(() {
      _selectedStandards = standards;
      _selectedStatuses = statuses;
      _dashboardDataFuture = _fetchDashboardData();
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedStandards = {};
      _selectedStatuses = {};
      _selectedCnr = false;
      _dashboardDataFuture = _fetchDashboardData();
    });
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return EnquiryFilterBottomSheet(
          initialStandards: _selectedStandards,
          initialStatuses: _selectedStatuses,
          standardOptions: _standardOptions,
          statusCounts: _statusCounts,
          onApplyFilters: _applyFilters,
          onClearFilters: _clearFilters,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Theme.of(context).colorScheme.surface,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Image.asset(
            'assets/logo.jpeg',
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
            icon: const Icon(Icons.filter_list),
            onPressed: _openFilterSheet,
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
            final cs = Theme.of(context).colorScheme;
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: cs.error),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.onSurface, fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () {
                      setState(() {
                        _dashboardDataFuture = _fetchDashboardData();
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                  ),
                ],
              ),
            );
          } else {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16.0),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  // Chart
                  EnquiryStatusChartCard(
                    chartDataSource: _chartDataSource,
                    statusCounts: _statusCounts,
                  ),
                  const SizedBox(height: 24),

                  // Search Bar
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by name or phone...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Total and View All
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "All Enquiries",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Total: $_totalCount',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Enquiries List
                  _buildEnquiryList(),
                ],
              ),
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: theme.colorScheme.secondaryContainer,
        foregroundColor: theme.colorScheme.onSecondaryContainer,
        shape: const CircleBorder(),
        onPressed: () async {
          final result = await context.push('/add-enquiry');
          if (result == true && mounted) {
            _dashboardDataFuture = _fetchDashboardData();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEnquiryList() {
    if (_allEnquiries.isEmpty) {
      return const SizedBox(
        height: 100,
        child: Center(child: Text("No enquiries found.")),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _allEnquiries.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _allEnquiries.length) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final enquiry = _allEnquiries[index];
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
                  'Interactions: ${enquiry.interactions.length}',
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
