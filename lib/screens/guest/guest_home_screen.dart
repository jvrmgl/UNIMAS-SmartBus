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

  final List<Widget> _screens = const [
    GuestMapScreen(),
    StudentDashboardScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardNavProvider>().addListener(_onNavChange);
    });
  }

  @override
  void dispose() {
    context.read<DashboardNavProvider>().removeListener(_onNavChange);
    super.dispose();
  }

  void _onNavChange() {
    final nav = context.read<DashboardNavProvider>();
    if (nav.shouldSwitchToHome && mounted) {
      setState(() => _currentIndex = 1);
      nav.consumeHomeSwitch();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
