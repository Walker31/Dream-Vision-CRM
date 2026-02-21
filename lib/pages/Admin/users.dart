// ignore_for_file: use_build_context_synchronously

import 'package:dreamvision/widgets/back_button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_model.dart';
import '../../services/admin_user.dart';
import '../../utils/global_error_handler.dart';

class UserListPage extends StatefulWidget {
  const UserListPage({super.key});
  @override
  State<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> {
  final AdminUserService _adminUserService = AdminUserService();
  final _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late SharedPreferences _prefs;
  
  List<User> _allUsers = [];
  List<User> _filteredUsers = [];
  bool _isLoading = true;
  String? _error;
  Logger logger = Logger();

  static const String _searchStorageKey = 'users_search';
  static const String _scrollPositionStorageKey = 'users_scroll_position';

  @override
  void initState() {
    super.initState();
    _initializeAndLoad();
    _searchController.addListener(_filterUsers);
  }

  Future<void> _initializeAndLoad() async {
    _prefs = await SharedPreferences.getInstance();
    
    // Restore search from storage
    final savedSearch = _prefs.getString(_searchStorageKey) ?? '';
    if (mounted && savedSearch.isNotEmpty) {
      _searchController.text = savedSearch;
    }
    
    await _refreshUsers();
    
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
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshUsers() async {
    if (!_isLoading) setState(() => _isLoading = true);
    setState(() => _error = null);
    try {
      final responseData = await _adminUserService.listUsers();
      final users = responseData
          .map((u) => User.fromJson(u as Map<String, dynamic>))
          .toList();
      if (mounted) {
        setState(() {
          _allUsers = users;
          _filterUsers();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to load users: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    _saveSearchToStorage(_searchController.text);
    setState(() {
      _filteredUsers = query.isEmpty
          ? _allUsers
          : _allUsers.where((user) {
              return user.name.toLowerCase().contains(query) ||
                  user.email.toLowerCase().contains(query) ||
                  user.username.toLowerCase().contains(query);
            }).toList();
    });
  }

  Future<void> _navigateToAddUser() async {
    final result = await context.push('/add-user');
    if (result == true && mounted) _refreshUsers();
  }

  // Optimized: Handles errors properly so the UI doesn't lie to the user
  Future<void> _deleteUser(User user) async {
    try {
      await _adminUserService.deleteUser(user.userId);

      if (mounted) {
        setState(() {
          _allUsers.removeWhere((u) => u.userId == user.userId);
          _filterUsers();
        });
        GlobalErrorHandler.show(
          '${user.name} removed successfully.',
          type: AppMessageType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        GlobalErrorHandler.show(e.toString(), type: AppMessageType.error);

        logger.e("Delete operation failed: $e");
      }
    }
  }

  void _showDeleteConfirmationDialog(User user) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text('Delete ${user.name}? This cannot be undone.'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Delete'),
              onPressed: () {
                Navigator.pop(context); // Close dialog first
                _deleteUser(user); // Then call delete
              },
            ),
          ],
        );
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
        leading: const BackButtonIos(),
        title: const Text('Manage Users'),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        shape: const CircleBorder(),
        onPressed: _navigateToAddUser,
        child: const Icon(Icons.person_add_alt_1),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _SearchBar(controller: _searchController),
            const SizedBox(height: 16),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final cs = Theme.of(context).colorScheme;

    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.error),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: _refreshUsers,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_filteredUsers.isEmpty) return _buildEmptyState();
    return RefreshIndicator(onRefresh: _refreshUsers, child: _buildUserList());
  }

  Widget _buildUserList() {
    final cs = Theme.of(context).colorScheme;

    return ListView.separated(
      controller: _scrollController,
      itemCount: _filteredUsers.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final user = _filteredUsers[index];
        return Card(
          elevation: 0,
          color: cs.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            leading: CircleAvatar(
              backgroundColor: cs.primaryContainer,
              foregroundColor: cs.onPrimaryContainer,
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
              ),
            ),
            title: Text(
              user.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.email, style: TextStyle(color: cs.onSurfaceVariant)),
                Text(
                  'Role: ${user.role}',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  color: cs.primary,
                  tooltip: "Edit User",
                  onPressed: () async {
                    final result = await context.push('/add-user', extra: user);
                    if (result == true && mounted) _refreshUsers();
                  },
                ),

                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: cs.error,
                  tooltip: "Delete User",
                  onPressed: () => _showDeleteConfirmationDialog(user),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: cs.outline),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isEmpty
                ? 'No Users Found'
                : 'No users match your search',
            style: TextStyle(fontSize: 18, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: 'Search users...',
        hintStyle: TextStyle(color: cs.onSurfaceVariant),
        prefixIcon: Icon(Icons.search, color: cs.onSurfaceVariant),
        filled: true,
        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 12,
        ),
      ),
    );
  }
}
