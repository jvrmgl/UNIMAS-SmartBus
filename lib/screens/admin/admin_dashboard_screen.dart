import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/announcement_provider.dart';
import '../../providers/bus_provider.dart';
import '../../providers/route_provider.dart';
import '../../constants/app_theme.dart';
import '../../models/report_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common_widgets.dart';
import 'reports_management_screen.dart';
import 'manage_schedule_screen.dart';
import 'buses_management_screen.dart';
import 'drivers_management_screen.dart';
import 'routes_management_screen.dart';
import 'notifications_management_screen.dart';
import 'analytics_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AnnouncementProvider>().fetchAnnouncements();
      context.read<BusProvider>().listenToBuses();
      context.read<RouteProvider>().fetchRoutes();
    });
  }

  void _showNotificationsDialog() {
    showAppNotificationsSheet(context, 'admin');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        elevation: 0,
        actions: [
          Consumer<AnnouncementProvider>(
            builder: (context, announcementProvider, _) {
              final hasUnread =
                  announcementProvider.hasVisibleAnnouncementsFor('admin');
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined),
                      onPressed: _showNotificationsDialog,
                    ),
                    if (hasUnread)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                              minWidth: 8, minHeight: 8),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Header
            Consumer<AuthProvider>(
              builder: (context, authProvider, _) {
                final name =
                    authProvider.currentUser?.fullName ?? 'Admin';
                return Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.primaryColor,
                        Color(0xFF0D47A1),
                      ],
                    ),
                  ),
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome, $name',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage buses, drivers, routes and more',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                );
              },
            ),

            // System Overview (tappable → AnalyticsScreen)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(
                'System Overview',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: InkWell(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const AnalyticsScreen())),
                borderRadius: BorderRadius.circular(12),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: Column(
                      children: [
                        Consumer2<BusProvider, RouteProvider>(
                          builder:
                              (context, busProvider, routeProvider, _) {
                            final totalBuses = busProvider.buses.length;
                            final activeBuses = busProvider.buses
                                .where((b) => b.isActive)
                                .length;
                            final totalRoutes =
                                routeProvider.routes.length;

                            return StreamBuilder<List<Report>>(
                              stream:
                                  _firestoreService.getReportsStream(),
                              builder: (context, reportSnapshot) {
                                final reports = reportSnapshot.data ?? [];
                                final pending = reports
                                    .where((r) =>
                                        r.status == ReportStatus.pending)
                                    .length;

                                return StreamBuilder<int>(
                                  stream: _firestoreService.getTodayCompletedTripsCountStream(),
                                  builder: (context, tripSnapshot) {
                                    final passengersToday = tripSnapshot.data ?? 0;

                                    return Column(
                                      children: [
                                        // Row 1: Buses + Routes
                                        Row(                                          crossAxisAlignment: CrossAxisAlignment.start,                                          children: [
                                            Expanded(
                                              child: _buildOverviewStat(
                                                icon: Icons.directions_bus,
                                                value: '$activeBuses/$totalBuses',
                                                label: 'Buses Active/Total',
                                                color: Colors.blue,
                                              ),
                                            ),
                                            Container(
                                              width: 1,
                                              height: 50,
                                              color: Theme.of(context).colorScheme.outlineVariant,
                                            ),
                                            Expanded(
                                              child: _buildOverviewStat(
                                                icon: Icons.route,
                                                value: totalRoutes.toString(),
                                                label: 'Routes',
                                                color: Colors.green,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Divider(
                                          height: 1,
                                          color: Theme.of(context).colorScheme.outlineVariant,
                                        ),
                                        // Row 2: Passengers + Pending
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: _buildOverviewStat(
                                                icon: Icons.people,
                                                value: passengersToday.toString(),
                                                label: 'Passengers Today',
                                                color: Colors.orange,
                                              ),
                                            ),
                                            Container(
                                              width: 1,
                                              height: 50,
                                              color: Theme.of(context).colorScheme.outlineVariant,
                                            ),
                                            Expanded(
                                              child: _buildOverviewStat(
                                                icon: Icons.report_problem,
                                                value: pending.toString(),
                                                label: 'Pending Reports',
                                                color: pending > 0
                                                    ? Colors.red
                                                    : Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.touch_app, size: 12, color: Colors.grey[600]),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Tap to View Analytics',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey[600],
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Management Grid (3-column)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Text(
                'Management',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
                  Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 6,
                crossAxisSpacing: 8,
                childAspectRatio: 1.25,
                children: [
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 0),
                    child: _buildAdminCard(
                      icon: Icons.directions_bus,
                      title: 'Buses',
                      color: Colors.blue,
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) =>
                                  const BusesManagementScreen())),
                    ),
                  ),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 60),
                    child: _buildAdminCard(
                      icon: Icons.people,
                      title: 'Drivers',
                      color: Colors.teal,
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) =>
                                  const DriversManagementScreen())),
                    ),
                  ),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 120),
                    child: _buildAdminCard(
                      icon: Icons.route,
                      title: 'Routes',
                      color: Colors.green,
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) =>
                                  const RoutesManagementScreen())),
                    ),
                  ),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 180),
                    child: _buildAdminCard(
                      icon: Icons.schedule,
                      title: 'Schedules',
                      color: Colors.purple,
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) =>
                                  const ManageScheduleScreen())),
                    ),
                  ),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 240),
                    child: _buildAdminCard(
                      icon: Icons.notifications,
                      title: 'Notifications',
                      color: Colors.orange,
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) =>
                                  const NotificationsManagementScreen())),
                    ),
                  ),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 300),
                    child: _buildAdminCard(
                      icon: Icons.report,
                      title: 'Reports',
                      color: Colors.red,
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => ReportsManagementScreen())),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewStat({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildAdminCard({
    required IconData icon,
    required String title,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 24, color: color),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

