import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/bus_provider.dart';
import '../../providers/route_provider.dart';
import '../../models/report_model.dart';
import '../../services/firestore_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<BusProvider>().fetchBuses();
      context.read<RouteProvider>().fetchRoutes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics & Statistics'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overview Section
            Text(
              'System Overview',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildOverviewCards(),
            
            const SizedBox(height: 24),
            
            // Bus Usage Section
            Text(
              'Bus Usage Statistics',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildBusUsageSection(),
            
            const SizedBox(height: 24),
            
            // Route Popularity
            Text(
              'Route Popularity',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildRoutePopularitySection(),
            
            const SizedBox(height: 24),
            
            // Reports Summary
            Text(
              'Reports Summary',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildReportsSummary(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCards() {
    return Consumer2<BusProvider, RouteProvider>(
      builder: (context, busProvider, routeProvider, _) {
        final totalBuses = busProvider.buses.length;
        final activeBuses = busProvider.buses.where((b) => b.isActive).length;
        final totalRoutes = routeProvider.routes.length;

        return StreamBuilder<List<Report>>(
          stream: _firestoreService.getReportsStream(),
          builder: (context, reportSnapshot) {
            final reports = reportSnapshot.data ?? [];
            final pending = reports
                .where((r) => r.status == ReportStatus.pending)
                .length;

            return StreamBuilder<int>(
              stream: _firestoreService.getTodayCompletedTripsCountStream(),
              builder: (context, tripSnapshot) {
                final passengersToday = tripSnapshot.data ?? 0;

                return Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Expanded(
                          child: _buildCompactOverviewStat(
                            icon: Icons.directions_bus,
                            value: '$activeBuses/$totalBuses',
                            label: 'Buses\nActive/Total',
                            color: Colors.blue,
                          ),
                        ),
                        _buildVerticalDivider(),
                        Expanded(
                          child: _buildCompactOverviewStat(
                            icon: Icons.route,
                            value: totalRoutes.toString(),
                            label: 'Routes',
                            color: Colors.green,
                          ),
                        ),
                        _buildVerticalDivider(),
                        Expanded(
                          child: _buildCompactOverviewStat(
                            icon: Icons.people,
                            value: passengersToday.toString(),
                            label: 'Passengers\nToday',
                            color: Colors.orange,
                          ),
                        ),
                        _buildVerticalDivider(),
                        Expanded(
                          child: _buildCompactOverviewStat(
                            icon: Icons.report_problem,
                            value: pending.toString(),
                            label: 'Pending\nReports',
                            color: pending > 0 ? Colors.red : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCompactOverviewStat({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
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

  Widget _buildVerticalDivider() {
    return Container(
      height: 60,
      width: 1,
      color: Colors.grey.shade300,
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  Widget _buildBusUsageSection() {
    return Consumer<BusProvider>(
      builder: (context, busProvider, _) {
        if (busProvider.buses.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No bus data available',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ),
          );
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ...busProvider.buses.take(5).map((bus) {
                  final occupancyPercent = bus.getOccupancyPercentage();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Bus ${bus.busNumber}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${bus.currentOccupancy}/${bus.capacity}',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: occupancyPercent / 100,
                            minHeight: 8,
                            backgroundColor: Colors.grey.shade300,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              bus.isNearCapacity()
                                  ? Colors.orange
                                  : Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                if (busProvider.buses.length > 5)
                  TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('View all feature coming soon'),
                        ),
                      );
                    },
                    child: const Text('View all buses'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRoutePopularitySection() {
    return Consumer<RouteProvider>(
      builder: (context, routeProvider, _) {
        if (routeProvider.routes.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No route data available',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ),
          );
        }

        return Card(
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: routeProvider.routes.length,
            itemBuilder: (context, index) {
              final route = routeProvider.routes[index];
              // Placeholder popularity data
              final popularity = (100 - (index * 15)).clamp(0, 100);
              
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Text(
                    route.routeCode,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                title: Text(route.routeName),
                subtitle: Text('${route.stopIds.length} stops'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$popularity%',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'popularity',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildReportsSummary() {
    return StreamBuilder<List<Report>>(
      stream: _firestoreService.getReportsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        final reports = snapshot.data ?? [];
        final pending =
            reports.where((r) => r.status == ReportStatus.pending).length;
        final reviewed =
            reports.where((r) => r.status == ReportStatus.reviewed).length;
        final resolved =
            reports.where((r) => r.status == ReportStatus.resolved).length;
        final total = reports.length;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildReportRow('Pending', pending.toString(),
                    Colors.orange, Icons.pending),
                const Divider(height: 24),
                _buildReportRow('In Review', reviewed.toString(),
                    Colors.blue, Icons.sync),
                const Divider(height: 24),
                _buildReportRow('Resolved', resolved.toString(),
                    Colors.green, Icons.check_circle),
                const Divider(height: 24),
                _buildReportRow(
                    'Total Reports', total.toString(), Colors.grey, Icons.report),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReportRow(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
