import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_nav_provider.dart';
import 'guest_map_screen.dart';
import 'student_dashboard_screen.dart';
import 'settings_screen.dart';

class GuestHomeScreen extends StatefulWidget {
  const GuestHomeScreen({super.key});

  @override
  State<GuestHomeScreen> createState() => _GuestHomeScreenState();
}

class _GuestHomeScreenState extends State<GuestHomeScreen> {
  int _currentIndex = 0;
  DashboardNavProvider? _dashboardNavProviderRef;

  final List<Widget> _screens = const [
    GuestMapScreen(),
    StudentDashboardScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _dashboardNavProviderRef = context.read<DashboardNavProvider>();
      _dashboardNavProviderRef!.addListener(_onNavChange);
    });
  }

  @override
  void dispose() {
    _dashboardNavProviderRef?.removeListener(_onNavChange);
    super.dispose();
  }

  void _onNavChange() {
    if (!mounted) return;
    final nav = _dashboardNavProviderRef ?? context.read<DashboardNavProvider>();
    if (nav.shouldSwitchToHome && mounted) {
      setState(() => _currentIndex = 1);
      nav.consumeHomeSwitch();
    }
    if (nav.shouldSwitchToMap && mounted) {
      setState(() => _currentIndex = 0);
      nav.consumeMapSwitch();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) =>
            setState(() => _currentIndex = index),
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
