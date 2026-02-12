import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../constants/app_theme.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
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
                      'Welcome, ${authProvider.currentUser?.fullName ?? "Driver"}!',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage your trips and bus information',
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
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildFeatureCard(
                  icon: Icons.directions_bus,
                  title: 'Active Trip',
                  subtitle: 'Start/End your current trip',
                ),
                _buildFeatureCard(
                  icon: Icons.people,
                  title: 'Update Occupancy',
                  subtitle: 'Update bus passenger count',
                ),
                _buildFeatureCard(
                  icon: Icons.location_on,
                  title: 'GPS Location',
                  subtitle: 'Share real-time location',
                ),
                _buildFeatureCard(
                  icon: Icons.route,
                  title: 'Route Details',
                  subtitle: 'View route information',
                ),
                _buildFeatureCard(
                  icon: Icons.person,
                  title: 'My Account',
                  subtitle: 'View/Update profile',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.primaryColor),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$title feature coming soon')),
          );
        },
      ),
    );
  }
}
