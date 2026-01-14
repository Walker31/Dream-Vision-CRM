import 'package:dreamvision/models/enquiry_model.dart';
import 'package:dreamvision/services/enquiry_service.dart';
import 'package:dreamvision/pages/Telecaller/follow_up_sheet.dart';
import 'package:dreamvision/utils/global_error_handler.dart';
import 'package:dreamvision/utils/error_helper.dart';
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
  final TextEditingController _searchController = TextEditingController();
  Logger logger = Logger();

  List<Enquiry> _enquiries = [];
  List<bool> _animateItems = [];
  int _currentPage = 1;
  bool _hasNextPage = true;
  bool _isLoadingMore = false;
  bool _isFirstLoad = true;
  String? _error;
  String _searchQuery = '';
  Map<String, int> _statusCounts = {};
  int _cnrCount = 0;
  bool _isCnrFilterEnabled = false;

  final List<String> _statusOptions = [
    'Interested',
    'Follow-Up',
    'Closed',
    'Confirmed',
  ];
  final Set<String> _selectedStatuses = {};

  @override
  void initState() {
    super.initState();
    _fetchEnquiries(page: 1);
    _fetchStatusCounts();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _searchController.removeListener(_onSearchChanged);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() => _searchQuery = _searchController.text);
    _refresh();
    _fetchStatusCounts();
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
      final retryPolicy = RetryPolicy();

      // Build status filter: if no statuses selected or all selected, pass null
      String? statusFilter;
      if (_selectedStatuses.isNotEmpty) {
        statusFilter = _selectedStatuses.join(',');
      }

      final response = await retryPolicy.execute(
        () => _enquiryService.getTelecallerEnquiries(
          page: page,
          status: statusFilter,
          search: _searchQuery.isNotEmpty ? _searchQuery : null,
          cnr: _isCnrFilterEnabled ? 'true' : null,
        ),
      );

      final results = response['results'] as List<dynamic>;
      final newEnquiries = results.map((e) => Enquiry.fromJson(e)).toList();
      final hasNext = response['next'] != null;

      if (!mounted) return;

      if (page == 1) {
        setState(() {
          _enquiries = newEnquiries;
          _currentPage = 1;
          _hasNextPage = hasNext;
          _animateItems = List<bool>.filled(_enquiries.length, false);
        });

        for (int i = 0; i < _enquiries.length; i++) {
          Future.delayed(Duration(milliseconds: 50 * i), () {
            if (!mounted) return;
            if (i >= _animateItems.length) return;
            setState(() => _animateItems[i] = true);
          });
        }
      } else {
        final startIdx = _enquiries.length;
        setState(() {
          _enquiries.addAll(newEnquiries);
          _currentPage = page;
          _hasNextPage = hasNext;
          _animateItems.addAll(List<bool>.filled(newEnquiries.length, false));
        });

        for (int offset = 0; offset < newEnquiries.length; offset++) {
          final index = startIdx + offset;
          Future.delayed(Duration(milliseconds: 40 * offset), () {
            if (!mounted) return;
            if (index >= _animateItems.length) return;
            setState(() => _animateItems[index] = true);
          });
        }
      }
    } catch (e) {
      logger.e("Failed to fetch dashboard data: $e");
      final userMessage = ErrorHelper.getUserMessage(e);
      final isNetworkError = ErrorHelper.isNetworkError(e);

      if (!mounted) return;

      setState(() => _error = userMessage);

      // Show retry dialog for network errors
      if (isNetworkError && mounted) {
        final shouldRetry = await ErrorHelper.showRetryDialog(
          context,
          userMessage,
          title: 'Connection Error',
        );
        if (shouldRetry == true && mounted) {
          _fetchEnquiries(page: page);
        }
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

  Future<void> _fetchStatusCounts() async {
    try {
      final retryPolicy = RetryPolicy();

      // Always fetch ALL status counts regardless of filters
      // This ensures the checkbox list shows accurate counts for all statuses
      final response = await retryPolicy.execute(
        () => _enquiryService.getStatusCounts(
          search: _searchQuery.isNotEmpty ? _searchQuery : null,
          // DO NOT pass status filter here - we want counts for ALL statuses
        ),
      );
      final List<dynamic> counts = response['status_counts'] ?? [];
      final Map<String, int> countMap = {};
      for (var item in counts) {
        if (item is Map<String, dynamic> && item['status'] != null) {
          final count = item['count'];
          countMap[item['status']] = count is int ? count : 0;
        }
      }

      // Extract CNR count
      final cnrCountValue = response['cnr_count'];
      final cnrCount = cnrCountValue is int ? cnrCountValue : 0;

      if (mounted) {
        setState(() {
          _statusCounts = countMap;
          _cnrCount = cnrCount;
        });
      }
    } catch (e) {
      logger.e("Failed to fetch status counts: $e");
      if (mounted) {
        setState(() => _statusCounts = {});
      }
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (!mounted) return;
      GlobalErrorHandler.error("Could not open dialer for $phoneNumber");
    }
  }

  Future<void> _showAddFollowUpForm(
    BuildContext context,
    Enquiry enquiry,
  ) async {
    final result = await showModalBottomSheet<bool?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddFollowUpSheet(enquiry: enquiry),
    );

    // If follow-up was successfully created/updated, refresh the dashboard
    if (mounted && result == true) {
      _refresh();
      _fetchStatusCounts();
    }
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
            errorBuilder: (_, __, ___) => Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  'DV',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
        title: const Text('Telecalling Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _refresh, child: _buildBody()),
      floatingActionButton: FloatingActionButton(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        shape: const CircleBorder(),
        child: const Icon(Icons.add),
        onPressed: () async {
          final result = await context.push('/add-enquiry');
          if (result == true && mounted) {
            _refresh();
            _fetchStatusCounts();
          }
        },
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
            Icon(Icons.error_outline, size: 48, color: cs.error),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurface, fontSize: 16),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
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
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name, phone, email...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                              _refresh();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: cs.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),

              IconButton(
                icon: const Icon(Icons.filter_list_rounded),
                tooltip: 'Filter',
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (BuildContext context) {
                      return StatefulBuilder(
                        builder: (BuildContext context, StateSetter setModalState) {
                          return Container(
                            decoration: BoxDecoration(
                              color: cs.surface,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(20),
                                topRight: Radius.circular(20),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Filter by Status',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleLarge,
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close),
                                        onPressed: () => Navigator.pop(context),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  // Checkbox list
                                  Flexible(
                                    child: SingleChildScrollView(
                                      child: Column(
                                        children: [
                                          ..._statusOptions.map((status) {
                                            final isSelected = _selectedStatuses
                                                .contains(status);
                                            return CheckboxListTile(
                                              title: Text(
                                                status,
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.bodyMedium,
                                              ),
                                              subtitle: Text(
                                                'Count: ${_statusCounts[status] ?? 0}',
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.bodySmall,
                                              ),
                                              value: isSelected,
                                              onChanged: (bool? value) {
                                                setModalState(() {
                                                  if (value == true) {
                                                    _selectedStatuses.add(
                                                      status,
                                                    );
                                                  } else {
                                                    _selectedStatuses.remove(
                                                      status,
                                                    );
                                                  }
                                                });
                                              },
                                              controlAffinity:
                                                  ListTileControlAffinity
                                                      .leading,
                                            );
                                          }),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Divider
                                  const Divider(height: 24),

                                  // CNR Filter
                                  CheckboxListTile(
                                    title: Text(
                                      'CNR (Call Not Received)',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                    subtitle: Text(
                                      'Count: $_cnrCount',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                    value: _isCnrFilterEnabled,
                                    onChanged: (bool? value) {
                                      setModalState(() {
                                        _isCnrFilterEnabled = value ?? false;
                                      });
                                    },
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                  ),

                                  const SizedBox(height: 24),

                                  // Action buttons
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          icon: const Icon(Icons.clear),
                                          label: const Text('Clear All'),
                                          onPressed: () {
                                            setModalState(() {
                                              _selectedStatuses.clear();
                                              _isCnrFilterEnabled = false;
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: FilledButton.icon(
                                          icon: const Icon(Icons.check),
                                          label: const Text('Apply'),
                                          onPressed: () {
                                            Navigator.pop(context);
                                            _refresh();
                                            _fetchStatusCounts();
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
                style: IconButton.styleFrom(
                  backgroundColor: cs.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  foregroundColor: cs.onSurfaceVariant,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Assigned Leads',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildLeadsList(),
        ],
      ),
    );
  }

  Widget _buildNextFollowUpBadge(
    BuildContext context,
    String isoDateString,
    String status,
  ) {
    final cs = Theme.of(context).colorScheme;

    DateTime targetDate;
    try {
      targetDate = DateTime.parse(isoDateString).toLocal();
    } catch (_) {
      return const SizedBox.shrink();
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
    );

    late Color bgColor;
    late Color textColor;
    late String label;
    late IconData icon;

    // Skip overdue display for Converted enquiries (they're complete)
    final isConverted = status.isNotEmpty && status == 'Converted';
    if (targetDate.isBefore(now) && !isConverted) {
      bgColor = cs.errorContainer;
      textColor = cs.error;
      label = "Overdue";
      icon = Icons.warning_amber_rounded;
    } else if (targetDay == today) {
      bgColor = cs.tertiaryContainer;
      textColor = cs.tertiary;
      label = "Today";
      icon = Icons.today_rounded;
    } else if (targetDay == today.add(const Duration(days: 1))) {
      bgColor = cs.primaryContainer;
      textColor = cs.primary;
      label = "Tomorrow";
      icon = Icons.event_rounded;
    } else {
      bgColor = cs.surfaceContainerHighest;
      textColor = cs.onSurfaceVariant;
      label = DateFormat('MMM d').format(targetDate);
      icon = Icons.calendar_month_rounded;
    }

    final timeString = DateFormat.jm().format(targetDate);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      opacity: 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bgColor.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: textColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 6),
            Text(
              "$label • $timeString",
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeadsList() {
    final cs = Theme.of(context).colorScheme;

    if (_enquiries.isEmpty && !_isFirstLoad && !_isLoadingMore) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            children: [
              Icon(Icons.search_off_rounded, size: 48, color: cs.outline),
              const SizedBox(height: 8),
              Text(
                'No leads found.',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Show loading spinner when fetching enquiries
        if (_isLoadingMore && _enquiries.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Fetching enquiries...',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _enquiries.length + (_hasNextPage ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _enquiries.length) {
                return _hasNextPage
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                cs.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Loading more...',
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink();
              }

              final enquiry = _enquiries[index];
              final fullName = '${enquiry.firstName} ${enquiry.lastName ?? ''}'
                  .trim();
              final status = enquiry.currentStatusName?.isNotEmpty == true
                  ? enquiry.currentStatusName!
                  : 'No Status';

              final animated = index < _animateItems.length
                  ? _animateItems[index]
                  : true;

              return AnimatedOpacity(
                opacity: animated ? 1 : 0,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
                child: AnimatedSlide(
                  offset: animated ? Offset.zero : const Offset(0, 0.12),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: cs.outlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                    elevation: 0,
                    color: cs.surfaceContainerLow,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => context.push('/enquiry/${enquiry.id}'),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                            color: cs.onSurfaceVariant,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            status,
                                            style: TextStyle(
                                              color: cs.onSurfaceVariant,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton.filledTonal(
                                  icon: const Icon(Icons.call, size: 20),
                                  onPressed: () =>
                                      _makePhoneCall(enquiry.phoneNumber),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.green.withValues(
                                      alpha: 0.15,
                                    ),
                                    foregroundColor: Colors.green,
                                  ),
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
                                    backgroundColor: cs.secondaryContainer
                                        .withValues(alpha: 0.5),
                                    foregroundColor: cs.onSecondaryContainer,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                if (enquiry.nextFollowUp != null)
                                  _buildNextFollowUpBadge(
                                    context,
                                    enquiry.nextFollowUp!,
                                    enquiry.currentStatusName ?? '',
                                  ),
                                const Spacer(),
                                FilledButton.icon(
                                  onPressed: () =>
                                      _showAddFollowUpForm(context, enquiry),
                                  icon: const Icon(
                                    Icons.add_comment_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('Follow-up'),
                                  style: FilledButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
