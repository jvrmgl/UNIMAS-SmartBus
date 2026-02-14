import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bus_provider.dart';
import '../../providers/route_provider.dart';
import '../../providers/announcement_provider.dart';
import '../../constants/app_theme.dart';
import '../../models/schedule_model.dart';
import '../../models/route_model.dart';
import '../../services/firestore_service.dart';
import 'report_screen.dart';

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirestoreService _firestoreService = FirestoreService();
  String? _selectedRouteId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    // Load initial data after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<BusProvider>().fetchBuses();
      context.read<RouteProvider>().fetchRoutes();
      context.read<RouteProvider>().fetchBusStops();
      context.read<AnnouncementProvider>().fetchAnnouncements();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UNIMAS SmartBus'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // User Welcome Card
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
                      'Welcome, ${authProvider.currentUser?.fullName ?? "User"}!',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'View real-time bus schedules',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ReportScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            'Report',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          // Tab Bar
          TabBar(
            controller: _tabController,
            indicatorColor: AppTheme.primaryColor,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(icon: Icon(Icons.schedule), text: 'Schedules'),
              Tab(icon: Icon(Icons.directions_bus), text: 'Buses'),
              Tab(icon: Icon(Icons.route), text: 'Routes'),
              Tab(icon: Icon(Icons.notifications), text: 'News'),
            ],
          ),
          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSchedulesTab(),
                _buildBusesTab(),
                _buildRoutesTab(),
                _buildAnnouncementsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchedulesTab() {
    return Consumer<RouteProvider>(
      builder: (context, routeProvider, _) {
        return FutureBuilder<List<BusSchedule>>(
          future: _firestoreService.getSchedules(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final schedules = snapshot.data ?? [];
            if (schedules.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.schedule, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      'No schedules available',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              );
            }

            final filteredSchedules = _selectedRouteId == null
                ? schedules
                : schedules
                    .where((schedule) => schedule.routeId == _selectedRouteId)
                    .toList();

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedRouteId,
                  decoration: const InputDecoration(
                    labelText: 'Filter by Route',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All Routes'),
                    ),
                    ...routeProvider.routes.map(
                      (route) => DropdownMenuItem(
                        value: route.routeId,
                        child: Text(route.routeName),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedRouteId = value);
                  },
                ),
                const SizedBox(height: 16),
                if (filteredSchedules.isEmpty)
                  Center(
                    child: Text(
                      'No schedules available',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                else
                  ...filteredSchedules.map((schedule) {
                    BusRoute? route;
                    try {
                      route = routeProvider.routes.firstWhere(
                        (route) => route.routeId == schedule.routeId,
                      );
                    } catch (_) {
                      route = null;
                    }
                    final routeLabel = route?.routeName ?? schedule.routeId;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              routeLabel,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              schedule.day,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              schedule.timeRange,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBusesTab() {
    return Consumer<BusProvider>(
      builder: (context, busProvider, _) {
        if (busProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (busProvider.buses.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.directions_bus_filled, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'No buses available',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: busProvider.buses.length,
          itemBuilder: (context, index) {
            final bus = busProvider.buses[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bus ${bus.busNumber}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              bus.registrationNumber,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: bus.isNearCapacity()
                                ? Colors.orange.shade100
                                : Colors.green.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${bus.currentOccupancy}/${bus.capacity}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Occupancy Progress
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: bus.getOccupancyPercentage() / 100,
                        minHeight: 8,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          bus.isNearCapacity() ? Colors.orange : Colors.green,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Occupancy: ${bus.getOccupancyPercentage().toStringAsFixed(1)}%',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        TextButton(
                          onPressed: () {
                            busProvider.selectBus(bus);
                            // Navigate to bus details
                          },
                          child: const Text('View Details'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRoutesTab() {
    return Consumer<RouteProvider>(
      builder: (context, routeProvider, _) {
        if (routeProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (routeProvider.routes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.route, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'No routes available',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: routeProvider.routes.length,
          itemBuilder: (context, index) {
            final route = routeProvider.routes[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    route.routeCode,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(route.routeName),
                subtitle: Text('${route.stopIds.length} stops'),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () {
                  routeProvider.selectRoute(route);
                  // Navigate to route details
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAnnouncementsTab() {
    return Consumer<AnnouncementProvider>(
      builder: (context, announcementProvider, _) {
        if (announcementProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (announcementProvider.announcements.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'No announcements',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            announcement.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            announcement.type.toString().split('.').last,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
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
    );
  }

}
