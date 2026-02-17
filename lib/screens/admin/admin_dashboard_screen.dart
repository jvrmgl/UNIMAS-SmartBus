import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/announcement_provider.dart';
import '../../constants/app_theme.dart';
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AnnouncementProvider>().fetchAnnouncements();
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
                    final announcement = announcementProvider.announcements[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              announcement.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              announcement.description,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
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
                    onPressed: () {
                      _showNotificationsDialog();
                    },
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
                          minWidth: 8,
                          minHeight: 8,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Consumer<AuthProvider>(
            builder: (context, authProvider, _) {
              return Container(
                padding: const EdgeInsets.all(16),
                color: AppTheme.primaryColor,
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, Admin!',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage buses, drivers, routes and more',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.all(16),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                _buildAdminCard(
                  icon: Icons.directions_bus,
                  title: 'Buses',
                  subtitle: 'Manage buses',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const BusesManagementScreen(),
                      ),
                    );
                  },
                ),
                _buildAdminCard(
                  icon: Icons.people,
                  title: 'Drivers',
                  subtitle: 'Manage drivers',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const DriversManagementScreen(),
                      ),
                    );
                  },
                ),
                _buildAdminCard(
                  icon: Icons.route,
                  title: 'Routes',
                  subtitle: 'Manage routes',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const RoutesManagementScreen(),
                      ),
                    );
                  },
                ),
                _buildAdminCard(
                  icon: Icons.schedule,
                  title: 'Schedules',
                  subtitle: 'Manage schedules',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ManageScheduleScreen(),
                      ),
                    );
                  },
                ),
                _buildAdminCard(
                  icon: Icons.notifications,
                  title: 'Notifications',
                  subtitle: 'Send announcements',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const NotificationsManagementScreen(),
                      ),
                    );
                  },
                ),
                _buildAdminCard(
                  icon: Icons.report,
                  title: 'Reports',
                  subtitle: 'View reports',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ReportsManagementScreen(),
                      ),
                    );
                  },
                ),
                _buildAdminCard(
                  icon: Icons.analytics,
                  title: 'Analytics',
                  subtitle: 'View statistics',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AnalyticsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminCard({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap ??
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$title feature coming soon')),
              );
            },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: AppTheme.primaryColor),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
