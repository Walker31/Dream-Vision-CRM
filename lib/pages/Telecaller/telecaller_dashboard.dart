import 'package:dreamvision/models/enquiry_model.dart';
import 'package:dreamvision/services/enquiry_service.dart';
import 'package:dreamvision/pages/Telecaller/follow_up_sheet.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../charts/telecaller_call_chart.dart';

class TelecallerDashboard extends StatefulWidget {
  const TelecallerDashboard({super.key});

  @override
  State<TelecallerDashboard> createState() => _TelecallerDashboardState();
}

class _TelecallerDashboardState extends State<TelecallerDashboard> {
  final EnquiryService _enquiryService = EnquiryService();
  final ScrollController _scrollController = ScrollController();
  Logger logger = Logger();

  List<Enquiry> _enquiries = [];
  int _currentPage = 1;
  bool _hasNextPage = true;
  bool _isLoadingMore = false;
  bool _isFirstLoad = true;
  String? _error;

  final List<String> _filters = ['All', 'Interested', 'Follow-up', 'Closed'];
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _fetchEnquiries(page: 1);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        _hasNextPage &&
        !_isLoadingMore) {
      _fetchEnquiries(page: _currentPage + 1);
    }
  }

  Future<void> _fetchEnquiries({int page = 1}) async {
    if (_isLoadingMore) return;
    setState(() {
      _isLoadingMore = true;
      if (page == 1) {
        _isFirstLoad = true;
        _error = null;
      }
    });

    try {
      final response = await _enquiryService.getTelecallerEnquiries(
        page: page,
        status: _selectedFilter == 'All' ? null : _selectedFilter,
      );

      final List<dynamic> results = response['results'];
      final newEnquiries = results
          .map((data) => Enquiry.fromJson(data))
          .toList();

      if (mounted) {
        setState(() {
          if (page == 1) {
            _enquiries = newEnquiries;
          } else {
            _enquiries.addAll(newEnquiries);
          }
          _currentPage = page;
          _hasNextPage = response['next'] != null;
        });
      }
    } catch (e) {
      logger.e("Failed to fetch dashboard data: $e");
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          _isFirstLoad = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    await _fetchEnquiries(page: 1);
  }

  void _onFilterChanged(String filter) {
    if (_selectedFilter == filter) return;

    setState(() {
      _selectedFilter = filter;
    });
    _refresh();
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      logger.e('Could not launch $launchUri');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Could not open dialer for $phoneNumber"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddFollowUpForm(BuildContext context, Enquiry enquiry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return AddFollowUpSheet(enquiry: enquiry);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Image.asset(
            'assets/logo.jpg',
            width: 50,
            errorBuilder: (context, error, stackTrace) {
              logger.e(error);
              return Container(
                width: 50,
                height: 50,
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
        title: const Text('Telecalling Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              context.push('/settings');
            },
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _refresh, child: _buildBody()),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add),
        onPressed: () => context.push('/add-enquiry'),
      ),
    );
  }

  Widget _buildBody() {
    if (_isFirstLoad && !_isLoadingMore) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _enquiries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _refresh, child: const Text('Retry')),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TelecallerCallChart(),
          const SizedBox(height: 24),
          const Text(
            'Assigned Leads',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildFilterChips(),
          const SizedBox(height: 16),
          _buildLeadsList(),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Wrap(
      spacing: 8.0,
      runSpacing: 4.0,
      children: _filters.map((filter) {
        final bool isSelected = _selectedFilter == filter;
        return FilterChip(
          label: Text(filter),
          selected: isSelected,
          showCheckmark: false,
          selectedColor: Theme.of(context).primaryColor,
          labelStyle: TextStyle(
            color: isSelected
                ? Colors.white
                : Theme.of(context).textTheme.bodyLarge?.color,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          backgroundColor: Colors.grey.withAlpha(25),
          onSelected: (selected) {
            _onFilterChanged(filter);
          },
        );
      }).toList(),
    );
  }

  Widget _buildLeadsList() {
    if (_enquiries.isEmpty && !_isFirstLoad && !_isLoadingMore) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32.0),
          child: Text(
            'No leads found for "$_selectedFilter".',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _enquiries.length + (_hasNextPage ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _enquiries.length) {
          return _hasNextPage
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                )
              : const SizedBox.shrink();
        }

        final enquiry = _enquiries[index];
        final fullName = '${enquiry.firstName} ${enquiry.lastName ?? ''}'
            .trim();
        final status = enquiry.currentStatusName ?? 'Unknown';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
          child: ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            title: Text(
              fullName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Status: $status',
              style: TextStyle(color: Colors.grey[600]),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.call_outlined),
                  onPressed: () => _makePhoneCall(enquiry.phoneNumber),
                  color: Colors.green,
                  tooltip: 'Call ${enquiry.phoneNumber}',
                ),
                IconButton(
                  icon: const Icon(Icons.history, color: Colors.blueGrey),
                  tooltip: 'View Follow-ups',
                  onPressed: () {
                    context.push('/follow-ups/${enquiry.id}', extra: fullName);
                  },
                ),
                TextButton(
                  onPressed: () => _showAddFollowUpForm(context, enquiry),
                  child: const Text('Follow-up'),
                ),
              ],
            ),
            onTap: () => context.push('/enquiry/${enquiry.id}'),
          ),
        );
      },
    );
  }
}
