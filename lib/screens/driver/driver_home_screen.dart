import 'package:flutter/material.dart';
import '../guest/settings_screen.dart';
import 'driver_dashboard_screen.dart';
import 'driver_map_screen.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  int _currentIndex = 0;
  final List<Widget?> _screens = List<Widget?>.filled(3, null);

  Widget _buildScreen(int index) {
    switch (index) {
      case 0:
        return const DriverMapScreen();
      case 1:
        return const DriverDashboardScreen();
      case 2:
        return const SettingsScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  void _ensureScreenCreated(int index) {
    _screens[index] ??= _buildScreen(index);
  }

  @override
  void initState() {
    super.initState();
    _ensureScreenCreated(_currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    _ensureScreenCreated(_currentIndex);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: List<Widget>.generate(
          3,
          (i) => _screens[i] ?? const SizedBox.shrink(),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() {
          _currentIndex = index;
          _ensureScreenCreated(_currentIndex);
        }),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
