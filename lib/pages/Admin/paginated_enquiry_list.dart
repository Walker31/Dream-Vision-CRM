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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'interested':
        return Colors.blue.shade600;
      case 'converted':
        return Colors.green.shade600;
      case 'needs follow-up':
      case 'follow-up':
        return Colors.orange.shade600;
      case 'closed':
        return Colors.grey.shade600;
      default:
        return Colors.purple.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
          child: TextField(
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search in ${widget.type.name}...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12.0),
            ),
          ),
        ),
        if (_isFirstLoad && _isLoading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_enquiries.isEmpty && !_isLoading)
          Expanded(
            child: Center(
              child: Text(
                _searchQuery != null && _searchQuery!.isNotEmpty
                    ? 'No enquiries found for "$_searchQuery".'
                    : 'No ${widget.type.name} enquiries found.',
                style: TextStyle(color: Colors.grey[600]),
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
                return Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    title: Text(
                      fullName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(enquiry.phoneNumber),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Chip(
                          label: Text(
                            status,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          backgroundColor: _getStatusColor(status),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          labelPadding: const EdgeInsets.symmetric(
                            horizontal: 4.0,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.history,
                            color: Colors.blueGrey,
                          ),
                          tooltip: 'View Follow-ups',
                          onPressed: () {
                            context.push(
                              '/follow-ups/${enquiry.id}',
                              extra: fullName,
                            );
                          },
                        ),
                      ],
                    ),
                    onTap: () => context.push('/enquiry/${enquiry.id}'),
                  ),
                );
              },
              separatorBuilder: (context, index) => const SizedBox(height: 8),
            ),
          ),
      ],
    );
  }
}
