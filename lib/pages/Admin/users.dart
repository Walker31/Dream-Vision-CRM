import 'package:dreamvision/widgets/back_button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';

import '../../services/admin_user.dart';

// The User model should be updated to match the API response
class User {
  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String? staffId;
  final String role;

  String get name => '$firstName $lastName'.trim();

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.staffId,
    required this.role,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final userData = json['user'] as Map<String, dynamic>? ?? {};
    return User(
      id: userData['id'] ?? 0,
      username: userData['username'] ?? 'N/A',
      email: userData['email'] ?? 'N/A',
      firstName: userData['first_name'] ?? '',
      lastName: userData['last_name'] ?? '',
      staffId: json['staff_id'] as String?,
      role: json['role'] ?? 'Unknown',
    );
  }
}

class UserListPage extends StatefulWidget {
  const UserListPage({super.key});

  @override
  State<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> {
  final AdminUserService _adminUserService = AdminUserService();
  final _searchController = TextEditingController();

  List<User> _allUsers = [];
  List<User> _filteredUsers = [];
  bool _isLoading = true;
  String? _error;
  Logger logger = Logger();

  @override
  void initState() {
    super.initState();
    _refreshUsers();
    _searchController.addListener(_filterUsers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshUsers() async {
    if (!_isLoading) setState(() => _isLoading = true);
    setState(() => _error = null);

    try {
      final responseData = await _adminUserService.listUsers(); // Correctly call the method
      logger.d(responseData);
      
      final users = responseData
          .map((userData) => User.fromJson(userData as Map<String, dynamic>))
          .toList();
          
      setState(() {
        _allUsers = users;
        _filterUsers();
      });
    } catch (e) {
      setState(() => _error = 'Failed to load users: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = _allUsers;
      } else {
        _filteredUsers = _allUsers.where((user) {
          final nameLower = user.name.toLowerCase();
          final emailLower = user.email.toLowerCase();
          final usernameLower = user.username.toLowerCase();
          return nameLower.contains(query) || emailLower.contains(query) || usernameLower.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _navigateToAddUser() async {
    final result = await context.push('/add-user');
    if (result == true && mounted) {
      _refreshUsers(); // Re-fetch the list from the API on success
    }
  }
  
  void _deleteUser(User user) {
    _adminUserService.deleteUser(user.id);
    setState(() {
      _allUsers.removeWhere((u) => u.id == user.id);
      _filterUsers();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${user.name} has been deleted.'),
        backgroundColor: Colors.orange[700],
      ),
    );
  }

  void _showDeleteConfirmationDialog(User user) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete ${user.name}? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              child: const Text('Delete'),
              onPressed: () {
                _deleteUser(user);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButtonIos(),
        title: const Text('Manage Users'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddUser,
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search Users',
                hintText: 'Search by name, email, username...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _refreshUsers, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_filteredUsers.isEmpty) {
      return _buildEmptyState();
    }
    return RefreshIndicator(
      onRefresh: _refreshUsers,
      child: _buildUserList(),
    );
  }

  Widget _buildUserList() {
    return ListView.builder(
      itemCount: _filteredUsers.length,
      itemBuilder: (context, index) {
        final user = _filteredUsers[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6.0),
          child: ListTile(
            leading: CircleAvatar(child: Text(user.name.isNotEmpty ? user.name[0] : '?')),
            title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.email),
                Text('Role: ${user.role}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              color: Theme.of(context).colorScheme.error,
              tooltip: 'Delete User',
              onPressed: () => _showDeleteConfirmationDialog(user),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isEmpty ? 'No Users Found' : 'No users match your search',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

