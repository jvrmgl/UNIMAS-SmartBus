import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../constants/app_constants.dart';
import '../../providers/bus_provider.dart';
import '../../providers/route_provider.dart';
import '../../providers/announcement_provider.dart';
import '../../models/report_model.dart';
import '../../services/firestore_service.dart';
import 'analytics_screen.dart';

class AdminMapScreen extends StatefulWidget {
  const AdminMapScreen({super.key});

  @override
  State<AdminMapScreen> createState() => _AdminMapScreenState();
}

class _AdminMapScreenState extends State<AdminMapScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() async {
    final busProvider = context.read<BusProvider>();
    final routeProvider = context.read<RouteProvider>();
    final announcementProvider = context.read<AnnouncementProvider>();

    await busProvider.fetchBuses();
    await routeProvider.fetchRoutes();
    await routeProvider.fetchBusStops();
    await announcementProvider.fetchAnnouncements();
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
                final visibleAnnouncements =
                    announcementProvider.visibleAnnouncementsFor('admin');
                if (announcementProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (visibleAnnouncements.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No announcements'),
                    ),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: visibleAnnouncements.length,
                  itemBuilder: (context, index) {
                    final announcement = visibleAnnouncements[index];
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
            Consumer<AnnouncementProvider>(
              builder: (context, announcementProvider, _) {
                final hasVisibleNotifications =
                    announcementProvider.hasVisibleAnnouncementsFor('admin');
                return TextButton(
                  onPressed: hasVisibleNotifications
                      ? () {
                          announcementProvider.clearAnnouncementsFor('admin');
                          Navigator.pop(context);
                        }
                      : null,
                  child: const Text('Clear Notifications'),
                );
              },
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Set<Marker> _buildMarkers(
    BusProvider busProvider,
    RouteProvider routeProvider,
  ) {
    Set<Marker> markers = {};

    for (var bus in busProvider.buses) {
      markers.add(
        Marker(
          markerId: MarkerId('bus_${bus.busId}'),
          position: LatLng(bus.latitude, bus.longitude),
          infoWindow: InfoWindow(
            title: bus.busNumber,
            snippet: 'Occupancy: ${bus.currentOccupancy}/${bus.capacity}',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueBlue,
          ),
        ),
      );
    }

    for (var stop in routeProvider.busStops) {
      markers.add(
        Marker(
          markerId: MarkerId('stop_${stop.stopId}'),
          position: LatLng(stop.latitude, stop.longitude),
          infoWindow: InfoWindow(
            title: stop.stopName,
            snippet: 'Bus Stop',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueRed,
          ),
        ),
      );
    }

    return markers;
  }

  Widget _buildCompactStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Map'),
        elevation: 0,
        actions: [
          Consumer<AnnouncementProvider>(
            builder: (context, announcementProvider, _) {
              final hasUnread = announcementProvider.hasVisibleAnnouncementsFor('admin');
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
      body: Stack(
        children: [
          Consumer2<BusProvider, RouteProvider>(
            builder: (context, busProvider, routeProvider, _) {
              final markers = _buildMarkers(busProvider, routeProvider);
              return GoogleMap(
                initialCameraPosition: const CameraPosition(
                  target: LatLng(1.4651, 110.4277),
                  zoom: AppConstants.defaultMapZoom,
                ),
                markers: markers,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
              );
            },
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Consumer2<BusProvider, RouteProvider>(
              builder: (context, busProvider, routeProvider, _) {
                final activeBuses =
                    busProvider.buses.where((bus) => bus.isActive).length;
                final totalBuses = busProvider.buses.length;
                final totalRoutes = routeProvider.routes.length;

                return InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                  ),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Expanded(
                          child: _buildCompactStat(
                            icon: Icons.directions_bus,
                            label: 'Active Buses',
                            value: '$activeBuses/$totalBuses',
                            color: Colors.blue,
                          ),
                        ),
                        Expanded(
                          child: _buildCompactStat(
                            icon: Icons.route,
                            label: 'Routes',
                            value: totalRoutes.toString(),
                            color: Colors.green,
                          ),
                        ),
                        Expanded(
                          child: StreamBuilder<int>(
                            stream: _firestoreService.getTodayCompletedTripsCountStream(),
                            builder: (context, snapshot) {
                              final count = snapshot.data ?? 0;
                              return _buildCompactStat(
                                icon: Icons.people,
                                label: 'Passengers Today',
                                value: count.toString(),
                                color: Colors.orange,
                              );
                            },
                          ),
                        ),
                        Expanded(
                          child: StreamBuilder<List<Report>>(
                            stream: _firestoreService.getReportsStream(),
                            builder: (context, snapshot) {
                              final pendingCount = snapshot.hasData
                                  ? snapshot.data!
                                      .where((r) => r.status == ReportStatus.pending)
                                      .length
                                  : 0;
                              return _buildCompactStat(
                                icon: Icons.report_problem,
                                label: 'Pending Reports',
                                value: pendingCount.toString(),
                                color: Colors.red,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
