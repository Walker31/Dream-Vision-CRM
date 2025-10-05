import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';

// It's a common convention to name screen widgets with a "Page" or "Screen" suffix.
class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  // Data for the menu list. This makes adding/removing items trivial.
  final List<Map<String, dynamic>> _menuItems = [
    // --- NEW ITEM ADDED ---
    {'icon': Icons.badge_outlined, 'title': 'Employee Details', 'route': '/profile/details'},
    {'icon': Icons.leaderboard_outlined, 'title': 'Leads', 'route': '/leads'},
    {'icon': Icons.task_alt_outlined, 'title': 'Tasks', 'route': '/tasks'},
    {'icon': Icons.analytics_outlined, 'title': 'Report/Analysis', 'route': '/reports'},
    {'icon': Icons.favorite_border_outlined, 'title': 'Favorites', 'route': '/favorites'},
    {'icon': Icons.contacts_outlined, 'title': 'Contacts', 'route': '/contacts'},
  ];

  Logger logger = Logger();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        elevation: 0, // No shadow for a flatter look.
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_border_outlined),
            onPressed: () {
              // Action for the bookmark icon
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              _buildProfileHeader(),
              const SizedBox(height: 24),
              _buildStatsRow(),
              const SizedBox(height: 24),
              _buildActionList(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the top section with the profile picture, name, and ID.
  Widget _buildProfileHeader() {
    return Column(
      children: [
        const CircleAvatar(
          radius: 50,
          backgroundColor: Colors.blueAccent,
          // You can use a NetworkImage here for a real profile picture.
          // backgroundImage: NetworkImage('https://...'),
          child: Icon(Icons.person, size: 50, color: Colors.white),
        ),
        const SizedBox(height: 12),
        Text(
          'Aditya Janga',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Employee ID: 107',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
        ),
      ],
    );
  }

  /// Builds the row with "Products" and "Team Projects" stats.
  Widget _buildStatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatItem(Icons.inventory_2_outlined, 'Products'),
        _buildStatItem(Icons.group_work_outlined, 'Team Projects'),
      ],
    );
  }

  /// Helper widget for an individual stat item.
  Widget _buildStatItem(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, size: 30, color: Colors.blueAccent),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[700],
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// Builds the list of actionable items like Leads, Tasks, etc.
  Widget _buildActionList() {
    return Column(
      children: _menuItems.map((item) {
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6.0),
          elevation: 1.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: Icon(item['icon'], color: Colors.blueAccent),
            title: Text(
              item['title'],
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey,
            ),
            onTap: () {
              // --- UPDATED: Handle navigation or action for each item ---
              final route = item['route'];
              if (route != null) {
                context.push(route);
              } else {
                logger.d('Tapped on ${item['title']}');
              }
            },
          ),
        );
      }).toList(),
    );
  }
}
