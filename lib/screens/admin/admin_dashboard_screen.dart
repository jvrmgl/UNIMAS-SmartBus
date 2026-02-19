import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/announcement_provider.dart';
import '../../providers/bus_provider.dart';
import '../../providers/route_provider.dart';
import '../../constants/app_theme.dart';
import '../../models/report_model.dart';
import '../../services/firestore_service.dart';
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
      context.read<BusProvider>().fetchBuses();
      context.read<RouteProvider>().fetchRoutes();
    });
  }

  void _showNotificationsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Notifications'),
          content: SizedBox(
            width: double.maxFinite,
            child: Consumer<AnnouncementProvider>(
              builder: (context, announcementProvider, _) {
                if (announcementProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (announcementProvider.announcements.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No announcements'),
                    ),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: announcementProvider.announcements.length,
                  itemBuilder: (context, index) {
                    final announcement =
                        announcementProvider.announcements[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(announcement.title,
                                style:
                                    Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            Text(announcement.description,
                                style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
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
        title: const Text('Admin Dashboard'),
        elevation: 0,
        actions: [
          Consumer<AnnouncementProvider>(
            builder: (context, announcementProvider, _) {
              final hasUnread = announcementProvider.announcements.isNotEmpty;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications),
                    onPressed: _showNotificationsDialog,
                  ),
                  if (hasUnread)
                    Positioned(
                      right: 8,
                      top: 8,
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
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // â”€â”€ Welcome Header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            Consumer<AuthProvider>(
              builder: (context, authProvider, _) {
                final name =
                    authProvider.currentUser?.fullName ?? 'Admin';
                return Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  color: AppTheme.primaryColor,
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

            // â”€â”€ System Overview (tappable â†’ AnalyticsScreen) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
                    padding: const EdgeInsets.all(16),
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
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceAround,
                                          children: [
                                            _buildOverviewStat(
                                              icon: Icons.directions_bus,
                                              value: '$activeBuses/$totalBuses',
                                              label: 'Buses\nActive/Total',
                                              color: Colors.blue,
                                            ),
                                            _buildDivider(),
                                            _buildOverviewStat(
                                              icon: Icons.route,
                                              value: totalRoutes.toString(),
                                              label: 'Routes',
                                              color: Colors.green,
                                            ),
                                            _buildDivider(),
                                            _buildOverviewStat(
                                              icon: Icons.people,
                                              value: passengersToday.toString(),
                                              label: 'Passengers\nToday',
                                              color: Colors.orange,
                                            ),
                                            _buildDivider(),
                                            _buildOverviewStat(
                                              icon: Icons.report_problem,
                                              value: pending.toString(),
                                              label: 'Pending\nReports',
                                              color: pending > 0
                                                  ? Colors.red
                                                  : Colors.grey,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.touch_app, size: 14, color: Colors.grey[600]),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Tap to View Analytics',
                                              style: TextStyle(
                                                fontSize: 12,
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

            // â”€â”€ Management Grid (3-column) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
              padding: const EdgeInsets.all(16),
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.9,
                children: [
                  _buildAdminCard(
                    icon: Icons.directions_bus,
                    title: 'Buses',
                    color: Colors.blue,
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) =>
                                const BusesManagementScreen())),
                  ),
                  _buildAdminCard(
                    icon: Icons.people,
                    title: 'Drivers',
                    color: Colors.teal,
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) =>
                                const DriversManagementScreen())),
                  ),
                  _buildAdminCard(
                    icon: Icons.route,
                    title: 'Routes',
                    color: Colors.green,
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) =>
                                const RoutesManagementScreen())),
                  ),
                  _buildAdminCard(
                    icon: Icons.schedule,
                    title: 'Schedules',
                    color: Colors.purple,
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) =>
                                const ManageScheduleScreen())),
                  ),
                  _buildAdminCard(
                    icon: Icons.notifications,
                    title: 'Notifications',
                    color: Colors.orange,
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) =>
                                const NotificationsManagementScreen())),
                  ),
                  _buildAdminCard(
                    icon: Icons.report,
                    title: 'Reports',
                    color: Colors.red,
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => ReportsManagementScreen())),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 6),
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
            fontSize: 11,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 48,
      width: 1,
      color: Colors.grey.shade200,
    );
  }

  Widget _buildAdminCard({
    required IconData icon,
    required String title,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 26, color: color),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
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

