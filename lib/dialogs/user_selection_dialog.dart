
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import '../services/enquiry_service.dart';

class UserSelectionDialog extends StatefulWidget {
  final String role;
  final EnquiryService enquiryService;

  const UserSelectionDialog({super.key, 
    required this.role,
    required this.enquiryService,
  });

  @override
  State<UserSelectionDialog> createState() => _UserSelectionDialogState();
}

class _UserSelectionDialogState extends State<UserSelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _users = [];
  List<dynamic> _filteredUsers = [];
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _debounce;
  Logger logger = Logger();

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchUsers({String? query}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final fetchedUsers = await widget.enquiryService.getAssignableUsers(
        role: widget.role,
        query: query,
      );
      if (mounted) {
        setState(() {
          _users = fetchedUsers;
          _filteredUsers = fetchedUsers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error fetching users: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final query = _searchController.text.toLowerCase();
      setState(() {
        _filteredUsers = _users.where((user) {
          final name = (user['full_name'] ?? user['username'] ?? '')
              .toLowerCase();
          return name.contains(query);
        }).toList();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Assign ${widget.role}'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search by name...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
            const SizedBox(height: 16),
            _buildUserList(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _buildUserList() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
      );
    }
    if (_filteredUsers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        child: Text(
          _searchController.text.isEmpty
              ? 'No ${widget.role}s found.'
              : 'No ${widget.role}s found matching "${_searchController.text}".',
        ),
      );
    }

    return SizedBox(
      height: 300,
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _filteredUsers.length,
        itemBuilder: (context, index) {
          final details = _filteredUsers[index];
          final user = details['user'];
          logger.d(user);
          final userName =
              user['full_name'] ?? user['username'] ?? 'Unnamed User';
          final userId = details['id'];

          return ListTile(
            title: Text(userName),
            onTap: () {
              Navigator.of(context).pop(userId);
            },
          );
        },
      ),
    );
  }
}