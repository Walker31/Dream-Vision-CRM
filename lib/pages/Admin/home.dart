import 'package:dreamvision/pages/Admin/dashboard.dart';
import 'package:dreamvision/pages/Admin/profile/profile.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // 1. State variable to track the active tab index.
  int _selectedIndex = 0;

  // 2. List of the pages to be displayed.
  //    Make sure the order matches the BottomNavigationBarItem order.
  static const List<Widget> _pages = <Widget>[
    Dashboard(), // Your widget from dashboard_page.dart
    Profile(),   // Your widget from profile_page.dart
  ];

  // 3. Method to update the state when a tab is tapped.
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The body displays the widget from our list based on the current index.
      body: _pages.elementAt(_selectedIndex),
      
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex, // Highlights the active tab.
        selectedItemColor: Colors.blueAccent, // Color for the active tab.
        onTap: _onItemTapped, // Function called when a tab is tapped.
      ),
    );
  }
}