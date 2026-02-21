import 'package:dreamvision/models/enquiry_model.dart';
import 'package:dreamvision/services/enquiry_service.dart';
import 'package:dreamvision/utils/status_colors.dart';
import 'package:dreamvision/widgets/filter_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../charts/enquiry_status_data.dart';

class ManagerDashboard extends StatefulWidget {
  const ManagerDashboard({super.key});

  @override
  State<ManagerDashboard> createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends State<ManagerDashboard> {
  final Logger _logger = Logger();
  final EnquiryService _enquiryService = EnquiryService();
  late SharedPreferences _prefs;

  late Future<void> _dashboardDataFuture;
  List<Enquiry> _allEnquiries = [];
  List<ChartData> _chartDataSource = [];
  Map<String, int> _statusCounts = {};
  List<String> _allStatuses = [];
  int _currentPage = 1;
  bool _hasNextPage = true;
  bool _isLoadingMore = false;

  // Filter state
  Set<String> _selectedStandards = {};
  Set<String> _selectedStatuses = {};
  String _searchQuery = '';

  final List<String> _standardOptions = ['8th', '9th', '10th', '11th', '12th'];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  
  static const String _searchStorageKey = 'manager_dashboard_search';
  static const String _scrollPositionStorageKey = 'manager_dashboard_scroll_position';

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
    _searchQuery = _searchController.text;
    _saveSearchToStorage(_searchQuery);
    _currentPage = 1;
    setState(() {
      _dashboardDataFuture = _fetchDashboardData();
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (_hasNextPage && !_isLoadingMore) {
        _loadMoreEnquiries();
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
      _logger.e("Failed to fetch all statuses: $e");
    }
  }

  Future<void> _fetchDashboardData() async {
    try {
      _logger.i('Fetching manager dashboard data');
      
      final standard = _selectedStandards.join(',');
      final status = _selectedStatuses.join(',');

      // Fetch status counts
      final statusCountsResponse = await _enquiryService.getManagerStatusCounts(
        standard: standard.isNotEmpty ? standard : null,
      );

      if (mounted) {
        // Initialize all statuses with 0 count
        final counts = <String, int>{};
        for (var status in _allStatuses) {
          counts[status] = 0;
        }
        // Update with actual counts
        for (var entry in statusCountsResponse.entries) {
          counts[entry.key] = entry.value as int;
        }
        setState(() {
          _statusCounts = counts;
        });
      }

      // Fetch chart data
      final summaryResponse = await _enquiryService.getManagerStatusSummary(
        standard: standard.isNotEmpty ? standard : null,
        status: status.isNotEmpty ? status : null,
      );

      if (mounted) {
        setState(() {
          _chartDataSource = summaryResponse
              .map((item) => ChartData(
                    item['status'] ?? 'Unknown',
                    (item['count'] ?? 0).toDouble(),
                    _getStatusColor(item['status'] ?? 'Unknown'),
                  ))
              .toList();
        });
      }

      // Fetch paginated enquiries
      _currentPage = 1;
      await _loadManagerEnquiries();
    } catch (e) {
      _logger.e('Error fetching dashboard data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading dashboard: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _loadManagerEnquiries() async {
    try {
      final standard = _selectedStandards.join(',');
      final status = _selectedStatuses.join(',');

      final enquiriesData = await _enquiryService.getManagerEnquiries(
        page: _currentPage,
        standard: standard.isNotEmpty ? standard : null,
        status: status.isNotEmpty ? status : null,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );

      // Convert Map<String, dynamic> to Enquiry objects
      final enquiries = enquiriesData
          .map((data) => Enquiry.fromJson(data))
          .toList();

      if (mounted) {
        setState(() {
          if (_currentPage == 1) {
            _allEnquiries = enquiries;
          } else {
            _allEnquiries.addAll(enquiries);
          }
          _hasNextPage = enquiries.length >= 20;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      _logger.e('Error loading enquiries: $e');
      if (mounted) {
        setState(() => _isLoadingMore = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading enquiries: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _loadMoreEnquiries() async {
    if (_isLoadingMore || !_hasNextPage) return;
    setState(() => _isLoadingMore = true);
    _currentPage++;
    await _loadManagerEnquiries();
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
      _dashboardDataFuture = _fetchDashboardData();
    });
  }

  void _openFilterSheet() async {
    // Fetch status counts before opening
    try {
      final standard = _selectedStandards.join(',');
      final statusCountsResponse = await _enquiryService.getManagerStatusCounts(
        standard: standard.isNotEmpty ? standard : null,
      );

      if (mounted) {
        final statusCounts = Map<String, int>.from(
          statusCountsResponse.map((key, value) => MapEntry(key, value as int)),
        );

        // Convert comma-separated to Sets for display
        final selectedStandards = _selectedStandards;
        final selectedStatuses = _selectedStatuses;

        if (mounted) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (context) => EnquiryFilterBottomSheet(
              standardOptions: _standardOptions,
              statusCounts: statusCounts,
              onApplyFilters: _applyFilters,
              onClearFilters: _clearFilters,
              initialStandards: selectedStandards,
              initialStatuses: selectedStatuses,
            ),
          );
        }
      }
    } catch (e) {
      _logger.e('Error opening filter sheet: $e');
    }
  }

  Color _getStatusColor(String status) {
    return StatusColors.getShade600Color(status);
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
        title: const Text('Manager Dashboard'),
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
      body: FutureBuilder(
        future: _dashboardDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() => _dashboardDataFuture = _fetchDashboardData()),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Search bar
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by name or phone...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Chart
                      if (_chartDataSource.isNotEmpty) ...[
                        _buildChart(),
                        const SizedBox(height: 24),
                      ],

                      // Section header
                      Text(
                        'Enquiries',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index == _allEnquiries.length) {
                        return _isLoadingMore
                            ? const Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(),
                              )
                            : const SizedBox.shrink();
                      }

                      if (_allEnquiries.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: Text('No enquiries found.')),
                        );
                      }

                      return _buildEnquiryCard(_allEnquiries[index]);
                    },
                    childCount: _allEnquiries.length + (_isLoadingMore ? 1 : 0),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 24),
                sliver: SliverToBoxAdapter(child: Container()),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/add-enquiry'),
        tooltip: 'Add Enquiry',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildChart() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Status Overview',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        EnquiryStatusChartCard(
          chartDataSource: _chartDataSource,
          statusCounts: _statusCounts,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildEnquiryCard(Enquiry enquiry) {
    final status = enquiry.currentStatusName ?? 'Unknown';
    final fullName = [
      enquiry.firstName,
      enquiry.middleName,
      enquiry.lastName,
    ].where((e) => e != null && e.isNotEmpty).join(' ');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        title: Text(
          fullName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Created: ${DateFormat.yMMMd().format(DateTime.parse(enquiry.createdAt))}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              Text(
                'Standard: ${enquiry.enquiringForStandard ?? 'N/A'}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
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
          backgroundColor: StatusColors.getShade600Color(status),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onTap: () => context.push('/enquiry/${enquiry.id}'),
      ),
    );
  }
}
