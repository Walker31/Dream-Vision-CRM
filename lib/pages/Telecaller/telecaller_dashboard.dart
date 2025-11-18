import 'package:dreamvision/models/enquiry_model.dart';
import 'package:dreamvision/services/enquiry_service.dart';
import 'package:dreamvision/pages/Telecaller/follow_up_sheet.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
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
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: cs.surface,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Image.asset(
            'assets/login_bg.png',
            width: 50,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest, // Dark Mode Safe
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    'DV',
                    style: TextStyle(
                      color: cs.onSurfaceVariant, // Dark Mode Safe
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
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        shape: const CircleBorder(),
        child: const Icon(Icons.add),
        onPressed: () => context.push('/add-enquiry'),
      ),
    );
  }

  Widget _buildBody() {
    final cs = Theme.of(context).colorScheme;

    if (_isFirstLoad && !_isLoadingMore) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _enquiries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_error', style: TextStyle(color: cs.error)),
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
    final cs = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 8.0,
      runSpacing: 4.0,
      children: _filters.map((filter) {
        final bool isSelected = _selectedFilter == filter;
        return FilterChip(
          label: Text(filter),
          selected: isSelected,
          showCheckmark: false,
          selectedColor: cs.primary,
          // Fix: Use onPrimary for selected text so it's visible on dark/light
          labelStyle: TextStyle(
            color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          // Fix: Use container color for unselected state
          backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          // Remove border to make it look cleaner
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          onSelected: (selected) {
            _onFilterChanged(filter);
          },
        );
      }).toList(),
    );
  }

  // Helper to determine color and text based on urgency
  Widget _buildNextFollowUpBadge(BuildContext context, String isoDateString) {
    final cs = Theme.of(context).colorScheme;

    DateTime targetDate;
    if (isoDateString.endsWith('Z')) {
      targetDate = DateTime.parse(isoDateString).toLocal();
    } else {
      targetDate = DateTime.parse(isoDateString);
      if (!targetDate.isUtc) {
        targetDate = targetDate.toLocal();
      }
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
    );

    Color bgColor;
    Color textColor;
    String labelText;
    IconData icon;

    // Adaptive Colors Logic
    if (targetDate.isBefore(now)) {
      // Overdue: Red
      bgColor = cs.errorContainer;
      textColor = cs.error;
      labelText = "Overdue";
      icon = Icons.warning_amber_rounded;
    } else if (targetDay.isAtSameMomentAs(today)) {
      // Today: Orange/Tertiary
      bgColor = cs.tertiaryContainer;
      textColor = cs.tertiary;
      labelText = "Today";
      icon = Icons.today_rounded;
    } else if (targetDay.isAtSameMomentAs(today.add(const Duration(days: 1)))) {
      // Tomorrow: Blue/Primary
      bgColor = cs.primaryContainer;
      textColor = cs.primary;
      labelText = "Tomorrow";
      icon = Icons.event_rounded;
    } else {
      // Future: Grey/Surface Variant
      bgColor = cs.surfaceContainerHighest;
      textColor = cs.onSurfaceVariant;
      labelText = DateFormat('MMM d').format(targetDate);
      icon = Icons.calendar_month_rounded;
    }

    // Append time (h:mm a)
    final timeString = DateFormat.jm().format(targetDate);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.4), // Subtle background
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 6),
          Text(
            "$labelText • $timeString",
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeadsList() {
    final cs = Theme.of(context).colorScheme;

    if (_enquiries.isEmpty && !_isFirstLoad && !_isLoadingMore) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32.0),
          child: Column(
            children: [
              Icon(Icons.search_off_rounded, size: 48, color: cs.outline),
              const SizedBox(height: 8),
              Text(
                'No leads found for "$_selectedFilter".',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 16),
              ),
            ],
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
            side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4)),
          ),
          elevation: 0,
          color: cs.surfaceContainerLow,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => context.push('/enquiry/${enquiry.id}'),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Name and Actions
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fullName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.flag_outlined,
                                  size: 14,
                                  color: cs
                                      .onSurfaceVariant, // Fix: Use Theme color
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  status,
                                  style: TextStyle(
                                    color: cs
                                        .onSurfaceVariant, // Fix: Use Theme color
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Call Button
                      IconButton.filledTonal(
                        icon: const Icon(Icons.call, size: 20),
                        onPressed: () => _makePhoneCall(enquiry.phoneNumber),
                        style: IconButton.styleFrom(
                          // Fix: Make it subtle in dark mode
                          backgroundColor: Colors.green.withValues(alpha: 0.15),
                          foregroundColor: Colors.green,
                        ),
                        tooltip: 'Call',
                      ),

                      IconButton.filledTonal(
                        icon: const Icon(Icons.history, size: 18),
                        onPressed: () {
                          context.push(
                            '/follow-ups/${enquiry.id}',
                            extra: fullName,
                          );
                        },
                        style: IconButton.styleFrom(
                          // Fix: Use Secondary container for history
                          backgroundColor: cs.secondaryContainer.withValues(
                            alpha: 0.5,
                          ),
                          foregroundColor: cs.onSecondaryContainer,
                        ),
                        tooltip: 'History',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (enquiry.nextFollowUp != null)
                        _buildNextFollowUpBadge(context, enquiry.nextFollowUp!),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: () => _showAddFollowUpForm(context, enquiry),
                        icon: const Icon(Icons.add_comment_outlined, size: 18),
                        label: const Text('Follow-up'),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
