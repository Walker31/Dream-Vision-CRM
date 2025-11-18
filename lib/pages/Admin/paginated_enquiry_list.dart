import 'dart:async';
import 'package:dreamvision/models/enquiry_model.dart';
import 'package:dreamvision/services/enquiry_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';

enum EnquiryListType { unassigned, assigned }

class PaginatedEnquiryList extends StatefulWidget {
  final EnquiryListType type;

  const PaginatedEnquiryList({super.key, required this.type});

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

  @override
  void initState() {
    super.initState();
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
      final Map<String, dynamic> response;
      if (widget.type == EnquiryListType.unassigned) {
        response = await _enquiryService.getUnassignedEnquiries(
          page: page,
          query: _searchQuery,
        );
      } else {
        response = await _enquiryService.getAssignedEnquiries(
          page: page,
          query: _searchQuery,
        );
      }

      final List<dynamic> resultsData = response['results'] ?? [];
      final newEnquiries = resultsData
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
      _logger.e("Failed to fetch ${widget.type} enquiries: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
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

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_searchQuery != query) {
        _searchQuery = query;
        _fetchPage(1);
      }
    });
  }

  // Updated to return a Record (Background Color, Text Color)
  ({Color bg, Color text}) _getStatusColors(BuildContext context, String status) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Helper for base colors
    Color baseColor;
    switch (status.toLowerCase()) {
      case 'interested':
        baseColor = Colors.blue;
        break;
      case 'converted':
        baseColor = Colors.green;
        break;
      case 'needs follow-up':
      case 'follow-up':
        baseColor = Colors.orange;
        break;
      case 'closed':
        baseColor = Colors.grey;
        break;
      default:
        baseColor = Colors.purple;
    }

    if (isDark) {
      // Dark Mode: Dark background, light text
      return (
        bg: baseColor.withValues(alpha: 0.2), 
        text: baseColor.withValues(alpha: 0.9) // Slightly lighter shade logic handled by Flutter usually, but using alpha is safer
      );
    } else {
      // Light Mode: Light background, dark text (Standard Chip style)
      // Or Solid background, White text (Your previous style)
      // Let's stick to Solid for Light mode as it pops more
      return (bg: baseColor.withValues(alpha: 0.8), text: Colors.white);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 12.0),
          child: TextField(
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search in ${widget.type.name}...',
              hintStyle: TextStyle(color: cs.onSurfaceVariant),
              prefixIcon: Icon(Icons.search, color: cs.onSurfaceVariant),
              filled: true,
              fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide.none, // Cleaner look
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide(color: cs.primary, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
            ),
          ),
        ),
        if (_isFirstLoad && _isLoading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_enquiries.isEmpty && !_isLoading)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off_outlined, size: 48, color: cs.outline),
                  const SizedBox(height: 16),
                  Text(
                    _searchQuery != null && _searchQuery!.isNotEmpty
                        ? 'No enquiries found for "$_searchQuery".'
                        : 'No ${widget.type.name} enquiries found.',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 16),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
              itemCount: _enquiries.length + (_hasNextPage ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _enquiries.length) {
                  return _hasNextPage
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : const SizedBox.shrink();
                }

                final enquiry = _enquiries[index];
                final fullName =
                    '${enquiry.firstName} ${enquiry.lastName ?? ''}'.trim();
                final status = enquiry.currentStatusName ?? 'Unknown';
                final statusColors = _getStatusColors(context, status);

                return Card(
                  margin: EdgeInsets.zero,
                  elevation: 0,
                  color: cs.surfaceContainerLow, // Slightly distinct from background
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4)),
                  ),
                  child: InkWell(
                    onTap: () => context.push('/enquiry/${enquiry.id}'),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                              // Status Chip
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4
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
                          Row(
                            children: [
                              Icon(Icons.phone_outlined, 
                                size: 16, color: cs.onSurfaceVariant),
                              const SizedBox(width: 6),
                              Text(
                                enquiry.phoneNumber,
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 13
                                ),
                              ),
                              const Spacer(),
                              // History Button
                              SizedBox(
                                width: 32,
                                height: 32,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: Icon(
                                    Icons.history,
                                    color: cs.primary,
                                    size: 20,
                                  ),
                                  tooltip: 'View Follow-ups',
                                  onPressed: () {
                                    context.push(
                                      '/follow-ups/${enquiry.id}',
                                      extra: fullName,
                                    );
                                  },
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
              separatorBuilder: (context, index) => const SizedBox(height: 12),
            ),
          ),
      ],
    );
  }
}