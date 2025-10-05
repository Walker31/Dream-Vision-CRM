import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// A simple data model for a user.
class User {
  final int id;
  final String name;
  final String email;

  User({required this.id, required this.name, required this.email});
}

class UserListPage extends StatefulWidget {
  const UserListPage({super.key}); 

  @override
  State<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> {
  // Master list of all users.
  final List<User> _allUsers = [
    User(id: 1, name: 'Aarav Sharma', email: 'aarav.sharma@example.com'),
    User(id: 2, name: 'Diya Patel', email: 'diya.patel@example.com'),
    User(id: 3, name: 'Rohan Kumar', email: 'rohan.kumar@example.com'),
    User(id: 4, name: 'Isha Singh', email: 'isha.singh@example.com'),
    User(id: 5, name: 'Vikram Reddy', email: 'vikram.reddy@example.com'),
  ];

  // The list of users that is actually displayed on the screen.
  late List<User> _filteredUsers;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredUsers = _allUsers;
    _searchController.addListener(_filterUsers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Filters the user list based on the search query.
  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredUsers = _allUsers.where((user) {
        final nameLower = user.name.toLowerCase();
        final emailLower = user.email.toLowerCase();
        return nameLower.contains(query) || emailLower.contains(query);
      }).toList();
    });
  }

  void _deleteUser(User user) {
    setState(() {
      _allUsers.removeWhere((u) => u.id == user.id);
      _filterUsers(); // Re-apply the filter after deleting
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${user.name} has been deleted.'),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  void _showDeleteConfirmationDialog(User user) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete ${user.name}?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error),
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
        leading: IconButton(onPressed: () {
          context.pop();
        }, icon: Icon(Icons.arrow_back_ios_new)),
        title: const Text('Manage Users'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Implement logic to add a new user
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Add New User action tapped!')),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // --- Search Bar ---
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search Users',
                hintText: 'Search by name or email...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // --- User List ---
            Expanded(
              child: _filteredUsers.isEmpty
                  ? _buildEmptyState()
                  : _buildUserList(),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the list of users.
  Widget _buildUserList() {
    return ListView.builder(
      itemCount: _filteredUsers.length,
      itemBuilder: (context, index) {
        final user = _filteredUsers[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6.0),
          child: ListTile(
            leading: CircleAvatar(
              child: Text(user.name[0]),
            ),
            title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(user.email),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.bar_chart_outlined),
                  tooltip: 'View Statistics',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Viewing stats for ${user.name}')),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: Theme.of(context).colorScheme.error,
                  tooltip: 'Delete User',
                  onPressed: () => _showDeleteConfirmationDialog(user),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Builds the widget to display when the list is empty.
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Users Found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}