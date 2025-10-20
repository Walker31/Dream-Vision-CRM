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
  Logger logger = Logger();

  late Future<void> _dashboardDataFuture;
  List<Enquiry> _allEnquiries = [];
  List<Enquiry> _filteredEnquiries = [];

  // Use statuses from your backend
  final List<String> _filters = ['All', 'Interested', 'Follow-up', 'Closed'];
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _dashboardDataFuture = _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    try {
      // In a real app, this would be a dedicated endpoint like
      // _enquiryService.getEnquiriesForTelecaller()
      final enquiryData = await _enquiryService.getAllEnquiries();
      final parsedEnquiries = enquiryData
          .map((data) => Enquiry.fromJson(data))
          .toList();

      if (mounted) {
        setState(() {
          // For this demo, we filter all enquiries that have a telecaller assigned
          _allEnquiries = parsedEnquiries
              .where((e) => e.assignedToTelecallerDetails != null)
              .toList();
          _filterLeadsList(); // Apply the default filter
        });
      }
    } catch (e) {
      logger.e("Failed to fetch dashboard data: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to load data: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
      rethrow;
    }
  }

  /// Filters the master list of enquiries based on the selected chip
  void _filterLeadsList() {
    setState(() {
      if (_selectedFilter == 'All') {
        _filteredEnquiries = List.from(_allEnquiries);
      } else {
        _filteredEnquiries = _allEnquiries.where((enquiry) {
          final status = enquiry.currentStatusName ?? 'Unknown';
          return status.toLowerCase() == _selectedFilter.toLowerCase();
        }).toList();
      }
    });
  }

  /// Launches the phone dialer
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

  /// Shows the Add Enquiry Follow-up Form
  void _showAddFollowUpForm(BuildContext context, Enquiry enquiry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        // Pass the specific enquiry to the sheet
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
      body: RefreshIndicator(
        onRefresh: _fetchDashboardData,
        child: FutureBuilder<void>(
          future: _dashboardDataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                _allEnquiries.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            return _buildDashboardContent();
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push('/add-enquiry');
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Enquiry'),
      ),
    );
  }

  Widget _buildDashboardContent() {
    return SingleChildScrollView(
      // This ensures the RefreshIndicator works even when list is short
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Use the imported chart widget
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

  // --- WIDGET UPDATED ---
  Widget _buildFilterChips() {
    return Wrap(
      spacing: 8.0,
      runSpacing: 4.0, // Added runSpacing
      children: _filters.map((filter) {
        final bool isSelected = _selectedFilter == filter;
        return FilterChip(
          label: Text(filter),
          selected: isSelected,
          showCheckmark: false, // Hide the checkmark
          selectedColor: Theme.of(
            context,
          ).primaryColor, // Background for selected
          labelStyle: TextStyle(
            color: isSelected
                ? Colors.white
                : Theme.of(context).textTheme.bodyLarge?.color,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          backgroundColor: Colors.grey.withAlpha(
            25,
          ), // Background for unselected
          onSelected: (selected) {
            setState(() {
              _selectedFilter = filter;
              _filterLeadsList(); // Re-filter the list
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildLeadsList() {
    if (_filteredEnquiries.isEmpty) {
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
      itemCount: _filteredEnquiries.length,
      itemBuilder: (context, index) {
        final enquiry = _filteredEnquiries[index];
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
