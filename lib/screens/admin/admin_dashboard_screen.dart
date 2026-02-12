import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../constants/app_theme.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        elevation: 0,
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
                      'Manage buses, drivers, routes and reports',
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
                ),
                _buildAdminCard(
                  icon: Icons.people,
                  title: 'Drivers',
                  subtitle: 'Manage drivers',
                ),
                _buildAdminCard(
                  icon: Icons.route,
                  title: 'Routes',
                  subtitle: 'Manage routes',
                ),
                _buildAdminCard(
                  icon: Icons.schedule,
                  title: 'Schedules',
                  subtitle: 'Manage schedules',
                ),
                _buildAdminCard(
                  icon: Icons.announcement,
                  title: 'Announcements',
                  subtitle: 'Create announcements',
                ),
                _buildAdminCard(
                  icon: Icons.notifications,
                  title: 'Notifications',
                  subtitle: 'Send push alerts',
                ),
                _buildAdminCard(
                  icon: Icons.report,
                  title: 'Reports',
                  subtitle: 'View reports',
                ),
                _buildAdminCard(
                  icon: Icons.analytics,
                  title: 'Analytics',
                  subtitle: 'View statistics',
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
  }) {
    return Card(
      child: InkWell(
        onTap: () {
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
