import 'dart:async';
import 'package:dreamvision/services/enquiry_service.dart';
import 'package:dreamvision/widgets/back_button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/enquiry_model.dart';

class AllEnquiriesPage extends StatefulWidget {
  const AllEnquiriesPage({super.key});

  @override
  State<AllEnquiriesPage> createState() => _AllEnquiriesPageState();
}

class _AllEnquiriesPageState extends State<AllEnquiriesPage> {
  final EnquiryService _enquiryService = EnquiryService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  final List<Enquiry> _enquiries = [];
  int _currentPage = 1;
  bool _hasNextPage = true;
  bool _isLoadingMore = false;
  bool _isFirstLoad = true;
  String? _error;
  String _searchQuery = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchEnquiries(page: 1); // Pass page 1
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _searchController.removeListener(_onSearchChanged);
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        _hasNextPage &&
        !_isLoadingMore) {
      _fetchEnquiries(page: _currentPage + 1); // Pass next page
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_searchQuery != _searchController.text) {
        setState(() {
          _searchQuery = _searchController.text;
        });
        _refresh();
      }
    });
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
      // --- THIS IS THE FIX ---
      // Use searchEnquiries if searching,
      // otherwise use the main getEnquiries
      final response = _searchQuery.isEmpty
          ? await _enquiryService.getEnquiries(page: page)
          : await _enquiryService.searchEnquiries(
              query: _searchQuery,
              page: page,
            );
      // --- END FIX ---

      final List<dynamic> results = response['results'];
      final newEnquiries = results
          .map((data) => Enquiry.fromJson(data))
          .toList();

      setState(() {
        if (page == 1) {
          _enquiries.clear();
        }
        _enquiries.addAll(newEnquiries);
        _currentPage = page;
        _hasNextPage = response['next'] != null;
      });
    } catch (e) {
      setState(() => _error = 'Failed to load enquiries: $e');
    } finally {
      setState(() {
        _isLoadingMore = false;
        _isFirstLoad = false;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _currentPage = 1;
      _hasNextPage = true;
    });
    await _fetchEnquiries(page: 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButtonIos(),
        title: const Text('All Enquiries'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, phone, email...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).scaffoldBackgroundColor,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isFirstLoad) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _enquiries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _refresh, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_enquiries.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
            Center(
              child: Text(
                _searchQuery.isEmpty
                    ? 'No enquiries found.'
                    : 'No results for "$_searchQuery"',
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(8.0),
        itemCount: _enquiries.length + (_hasNextPage ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _enquiries.length) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _EnquiryListItem(enquiry: _enquiries[index]);
        },
      ),
    );
  }
}

class _EnquiryListItem extends StatelessWidget {
  final Enquiry enquiry;

  const _EnquiryListItem({required this.enquiry});

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

  IconData _getTempIcon(String? temp) {
    switch (temp?.toLowerCase()) {
      case 'hot':
        return Icons.local_fire_department;
      case 'warm':
        return Icons.wb_sunny;
      case 'cold':
        return Icons.ac_unit;
      default:
        return Icons.device_thermostat;
    }
  }

  Color _getTempColor(String? temp) {
    switch (temp?.toLowerCase()) {
      case 'hot':
        return Colors.red;
      case 'warm':
        return Colors.orange;
      case 'cold':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fullName = '${enquiry.firstName} ${enquiry.lastName ?? ''}'.trim();
    final status = enquiry.currentStatusName ?? 'Unknown';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        title: Text(
          fullName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(enquiry.phoneNumber),
              const SizedBox(height: 4),
              if (enquiry.leadTemperature != null)
                Row(
                  children: [
                    Icon(
                      _getTempIcon(enquiry.leadTemperature),
                      size: 16,
                      color: _getTempColor(enquiry.leadTemperature),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      enquiry.leadTemperature!,
                      style: TextStyle(
                        color: _getTempColor(enquiry.leadTemperature),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Chip(
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
            ),
            IconButton(
              icon: const Icon(Icons.history, color: Colors.blueGrey),
              tooltip: 'View Follow-up History',
              onPressed: () {
                context.push('/follow-ups/${enquiry.id}', extra: fullName);
              },
            ),
          ],
        ),
        onTap: () => context.push('/enquiry/${enquiry.id}'),
      ),
    );
  }
}
