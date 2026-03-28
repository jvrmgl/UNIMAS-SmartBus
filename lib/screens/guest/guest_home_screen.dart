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
  final List<Widget?> _screens = List<Widget?>.filled(3, null);

  Widget _buildScreen(int index) {
    switch (index) {
      case 0:
        return const GuestMapScreen();
      case 1:
        return const StudentDashboardScreen();
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
      setState(() {
        _currentIndex = 1;
        _ensureScreenCreated(_currentIndex);
      });
      nav.consumeHomeSwitch();
    }
    if (nav.shouldSwitchToMap && mounted) {
      setState(() {
        _currentIndex = 0;
        _ensureScreenCreated(_currentIndex);
      });
      nav.consumeMapSwitch();
    }
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
