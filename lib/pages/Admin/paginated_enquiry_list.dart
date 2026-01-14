import 'dart:async';
import 'package:dreamvision/models/enquiry_model.dart';
import 'package:dreamvision/services/enquiry_service.dart';
import 'package:dreamvision/utils/global_error_handler.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';

enum EnquiryListType { unassigned, assigned }

class PaginatedEnquiryList extends StatefulWidget {
  final EnquiryListType type;
  final String? initialStandard;
  final String? initialStatus;
  final VoidCallback? onChanged;

  const PaginatedEnquiryList({
    super.key,
    required this.type,
    this.initialStandard,
    this.initialStatus,
    this.onChanged,
  });

  @override
  State<PaginatedEnquiryList> createState() => PaginatedEnquiryListState();
}

class PaginatedEnquiryListState extends State<PaginatedEnquiryList> {
  final EnquiryService _enquiryService = EnquiryService();
  final Logger _logger = Logger();
  final ScrollController _scrollController = ScrollController();

  List<Enquiry> _enquiries = [];
  int _currentPage = 1;
  bool _hasNextPage = true;
  bool _isLoading = false;
  bool _isFirstLoad = true;
  String? _searchQuery;
  Timer? _debounce;

  String? _standardFilter;
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _standardFilter = widget.initialStandard;
    _statusFilter = widget.initialStatus;
    _fetchPage(1);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels <
        _scrollController.position.maxScrollExtent * 0.9) {
      return;
    }
    if (_isLoading || !_hasNextPage) return;
    _fetchPage(_currentPage + 1);
  }

  Future<void> _fetchPage(int page) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      if (page == 1) _isFirstLoad = true;
    });

    try {
      // 1. Declare as dynamic so Dart doesn't crash when receiving a List
      final dynamic response;

      if (widget.type == EnquiryListType.unassigned) {
        response = await _enquiryService.getUnassignedEnquiries(
          page: page,
          query: _searchQuery,
          standard: _standardFilter,
          status: _statusFilter,
        );
      } else {
        response = await _enquiryService.getAssignedEnquiries(
          page: page,
          query: _searchQuery,
          standard: _standardFilter,
          status: _statusFilter,
        );
      }

      // 2. Extract results and pagination status safely
      List<dynamic> resultsList = [];
      bool hasNext = false;

      if (response is Map<String, dynamic>) {
        // Logic for standard paginated Map: {"results": [...], "next": "..."}
        resultsList = response['results'] is List ? response['results'] : [];
        hasNext = response['next'] != null;
      } else if (response is List) {
        // Logic for when the backend returns a raw List (common when empty)
        resultsList = response;
        hasNext = false;
      }

      // 3. Map to Enquiry objects with a safe cast
      final newEnquiries = resultsList
          .where((e) => e != null && e is Map<String, dynamic>)
          .map<Enquiry>((e) => Enquiry.fromJson(e as Map<String, dynamic>))
          .toList();

      if (!mounted) return;

      setState(() {
        if (page == 1) {
          _enquiries = newEnquiries;
        } else {
          _enquiries.addAll(newEnquiries);
        }
        _currentPage = page;
        _hasNextPage = hasNext;
      });
    } catch (e) {
      _logger.e("Failed to fetch enquiries: $e");
      if (mounted) {
        GlobalErrorHandler.error('Failed to load enquiries');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isFirstLoad = false;
        });
      }
    }
  }

  Future<void> refresh() async {
    _searchQuery = null;
    await _fetchPage(1);
  }

  void refreshWithFilters(String? standard, String? status) {
    _standardFilter = standard;
    _statusFilter = status;
    _searchQuery = null;
    _fetchPage(1);
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_searchQuery != query) {
        _searchQuery = query;
        _fetchPage(1);
      }
    });
  }

  ({Color bg, Color text}) _getStatusColors(
    BuildContext context,
    String status,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color base;

    switch (status.toLowerCase()) {
      case 'interested':
        base = Colors.blue;
        break;
      case 'confirmed':
        base = Colors.green;
        break;
      case 'follow-up':
      case 'needs follow-up':
        base = Colors.orange;
        break;
      case 'closed':
        base = Colors.grey;
        break;
      default:
        base = Colors.purple;
    }

    if (isDark) {
      return (
        bg: base.withValues(alpha: 0.2),
        text: base.withValues(alpha: 0.9),
      );
    } else {
      return (bg: base.withValues(alpha: 0.85), text: Colors.white);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: TextField(
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search in ${widget.type.name}...',
              prefixIcon: Icon(Icons.search, color: cs.onSurfaceVariant),
              filled: true,
              fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: cs.outline.withValues(alpha: 0.2),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: cs.primary, width: 1.5),
              ),
            ),
          ),
        ),

        // INITIAL LOADING VIEW
        if (_isFirstLoad && _isLoading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        // EMPTY VIEW
        else if (_enquiries.isEmpty && !_isLoading)
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off_outlined,
                      size: 48,
                      color: cs.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _searchQuery != null && _searchQuery!.isNotEmpty
                          ? 'No enquiries found for "$_searchQuery".'
                          : 'No ${widget.type.name} enquiries found.',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          )
        // LIST VIEW
        else
          Expanded(
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: _enquiries.length + (_hasNextPage ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == _enquiries.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final enquiry = _enquiries[index];
                final fullName =
                    "${enquiry.firstName} ${enquiry.lastName ?? ''}".trim();
                final status = enquiry.currentStatusName ?? "Unknown";
                final statusColors = _getStatusColors(context, status);

                return Card(
                  color: cs.surfaceContainerLow,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      await context.push("/enquiry/${enquiry.id}");
                      if (mounted) {
                        _fetchPage(1);
                        widget.onChanged?.call();
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // NAME + STATUS
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  fullName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: cs.onSurface,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColors.bg,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    color: statusColors.text,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          // PHONE + ACTION BUTTON
                          Row(
                            children: [
                              Icon(
                                Icons.phone_outlined,
                                size: 16,
                                color: cs.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),

                              // Phone text must be inside Expanded
                              Expanded(
                                child: Text(
                                  enquiry.phoneNumber.trim().isNotEmpty
                                      ? enquiry.phoneNumber
                                      : (enquiry.fatherPhoneNumber ??
                                            "No number"),
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),

                              // Follow-ups icon button
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                icon: Icon(
                                  Icons.history,
                                  color: cs.primary,
                                  size: 20,
                                ),
                                tooltip: "View Follow-ups",
                                onPressed: () async {
                                  await context.push(
                                    '/follow-ups/${enquiry.id}',
                                    extra: fullName,
                                  );
                                  if (mounted) {
                                    _fetchPage(1);
                                    widget.onChanged?.call();
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
