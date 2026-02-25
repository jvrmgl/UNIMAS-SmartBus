import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bus_provider.dart';
import '../../providers/route_provider.dart';
import '../../providers/announcement_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/dashboard_nav_provider.dart';
import '../../constants/app_theme.dart';
import '../../models/bus_model.dart';
import '../../models/bus_stop_model.dart';
import '../../models/schedule_image_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common_widgets.dart';
import 'report_screen.dart';
import 'student_trips_screen.dart';
import '../shared/bus_detail_screen.dart';

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirestoreService _firestoreService = FirestoreService();
  DashboardNavProvider? _dashboardNavProvider;
  int? _expandedStopIndex;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);

    // Load initial data after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<BusProvider>().listenToBuses(); // real-time stream
      context.read<RouteProvider>().fetchRoutes();
      context.read<RouteProvider>().fetchBusStops();
      context.read<AnnouncementProvider>().fetchAnnouncements();
      // Store ref before adding listener so dispose() can safely use it
      _dashboardNavProvider = context.read<DashboardNavProvider>();
      _dashboardNavProvider!.addListener(_onNavChange);
    });
  }

  void _onNavChange() {
    final nav = context.read<DashboardNavProvider>();
    final tab = nav.pendingDashboardTab;
    if (tab != null && mounted) {
      _tabController.animateTo(tab);
      nav.consumeDashboardTab();
    }
  }

  @override
  void dispose() {
    _dashboardNavProvider?.removeListener(_onNavChange);
    context.read<BusProvider>().stopListeningToBuses();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UNIMAS SmartBus'),
        elevation: 0,
        actions: [
          Consumer<AnnouncementProvider>(
            builder: (context, announcementProvider, _) {
              final hasUnread =
                  announcementProvider.hasVisibleAnnouncementsFor('student');
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
          // User Welcome Card
          Consumer<AuthProvider>(
            builder: (context, authProvider, _) {
              return Container(
                padding: const EdgeInsets.all(20),
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
                      'Welcome, ${authProvider.currentUser?.fullName ?? "User"}!',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'View real-time bus schedules',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          // Tab Bar
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: AppTheme.primaryColor,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: Colors.grey,
            labelStyle: const TextStyle(fontSize: 12),
            tabs: const [
              Tab(icon: Icon(Icons.schedule, size: 20), text: 'Schedules'),
              Tab(icon: Icon(Icons.directions_bus, size: 20), text: 'Buses'),
              Tab(icon: Icon(Icons.route, size: 20), text: 'Routes'),
              Tab(icon: Icon(Icons.card_travel, size: 20), text: 'Trips'),
              Tab(icon: Icon(Icons.report, size: 20), text: 'Reports'),
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
                const StudentTripsScreen(),
                _buildReportsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchedulesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Bus Schedule Images Carousel - Dynamic from Firestore
        StreamBuilder<List<ScheduleImage>>(
          stream: _firestoreService.streamScheduleImages(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Card(
                elevation: 4,
                child: SizedBox(
                  height: 400,
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return Card(
                elevation: 4,
                child: SizedBox(
                  height: 400,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading schedules',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.red.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${snapshot.error}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            final scheduleImages = snapshot.data ?? [];

            if (scheduleImages.isEmpty) {
              return Card(
                elevation: 4,
                child: SizedBox(
                  height: 400,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No schedule images available',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Schedule images will appear here when admin uploads them',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            return Card(
              elevation: 4,
              clipBehavior: Clip.antiAlias,
              child: CarouselSlider(
                options: CarouselOptions(
                  height: 400,
                  viewportFraction: 1.0,
                  enableInfiniteScroll: scheduleImages.length > 1,
                  autoPlay: scheduleImages.length > 1,
                  autoPlayInterval: const Duration(seconds: 10),
                  autoPlayAnimationDuration: const Duration(milliseconds: 800),
                  enlargeCenterPage: false,
                ),
                items: scheduleImages.map((scheduleImage) {
                  return _buildNetworkScheduleImage(
                    scheduleImage.imageUrl,
                    scheduleImage.title,
                  );
                }).toList(),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        // Info card about schedules
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Bus schedules are managed by administrators. Check back regularly for updates.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBusesTab() {
    return Consumer3<BusProvider, RouteProvider, LocationProvider>(
      builder: (context, busProvider, routeProvider, locationProvider, _) {
        final activeBuses = busProvider.buses.where((bus) => bus.isActive).toList();

        if (busProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (activeBuses.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.directions_bus_filled, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'No active buses available',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          );
        }

        // Find nearest active bus to user
        Bus? nearestBus;
        double? nearestBusKm;
        final pos = locationProvider.currentPosition;
        if (pos != null) {
          double minDist = double.infinity;
          for (final b in activeBuses) {
            final d = Geolocator.distanceBetween(
                  pos.latitude, pos.longitude, b.latitude, b.longitude) /
                1000;
            if (d < minDist) {
              minDist = d;
              nearestBus = b;
              nearestBusKm = minDist;
            }
          }
        }

        String? getBusRouteName(Bus bus) {
          if (bus.assignedRoute == null) return null;
          try {
            return routeProvider.routes
                .firstWhere((r) => r.routeId == bus.assignedRoute)
                .routeName;
          } catch (_) {
            return null;
          }
        }

        Widget buildBusCard(Bus bus, {String? distanceLabel}) {
          final routeName = getBusRouteName(bus);
          final occupancyPercent = bus.getOccupancyPercentage();
          final isNearCapacity = bus.isNearCapacity();
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Bus ${bus.busNumber}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                if (distanceLabel != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      distanceLabel,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.primaryColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.confirmation_number,
                                    size: 14,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color),
                                const SizedBox(width: 4),
                                Text(
                                  bus.registrationNumber,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            if (routeName != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.route,
                                      size: 14, color: Colors.blue),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      routeName,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue,
                                          fontWeight: FontWeight.w500),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isNearCapacity ? Colors.orange : Colors.green,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${bus.currentOccupancy}/${bus.capacity}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: occupancyPercent / 100,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          isNearCapacity ? Colors.orange : Colors.green),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.map_outlined, size: 16),
                          label: const Text('View Bus on Map',
                              style: TextStyle(fontSize: 12)),
                          onPressed: () {
                            context
                                .read<DashboardNavProvider>()
                                .navigateToMapWithFocus(
                                    bus.latitude, bus.longitude);
                          },
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => BusDetailScreen(bus: bus)),
                        ),
                        child: const Text('Board Bus'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Near you section ──────────────────────────────────────
            if (nearestBus != null) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.near_me, size: 16, color: AppTheme.primaryColor),
                    const SizedBox(width: 6),
                    Text(
                      'Bus near you',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
              buildBusCard(
                nearestBus,
                distanceLabel:
                    '${nearestBusKm!.toStringAsFixed(1)} km away',
              ),
              const SizedBox(height: 4),
              const Divider(),
              const SizedBox(height: 4),
            ],
            // ── All buses ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.directions_bus,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    'All buses',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            ...activeBuses.map((bus) => buildBusCard(bus)),
          ],
        );
      },
    );
  }

  Widget _buildRoutesTab() {
    return Consumer3<RouteProvider, BusProvider, LocationProvider>(
      builder: (context, routeProvider, busProvider, locationProvider, _) {
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

        // Find 3 closest bus stops to user
        final List<({BusStop stop, double km})> top3Stops = [];
        final pos = locationProvider.currentPosition;
        if (pos != null && routeProvider.busStops.isNotEmpty) {
          final sorted = [...routeProvider.busStops]..sort((a, b) {
            final da = Geolocator.distanceBetween(
                pos.latitude, pos.longitude, a.latitude, a.longitude);
            final db = Geolocator.distanceBetween(
                pos.latitude, pos.longitude, b.latitude, b.longitude);
            return da.compareTo(db);
          });
          for (final s in sorted.take(3)) {
            final km = Geolocator.distanceBetween(
                    pos.latitude, pos.longitude, s.latitude, s.longitude) /
                1000;
            top3Stops.add((stop: s, km: km));
          }
        }

        Widget buildRouteCard(int index) {
          final route = routeProvider.routes[index];
          final stops = route.stopIds
              .map((stopId) {
                try {
                  return routeProvider.busStops
                      .firstWhere((stop) => stop.stopId == stopId);
                } catch (_) {
                  return null;
                }
              })
              .where((stop) => stop != null)
              .cast<BusStop>()
              .toList();

          Bus? currentBus;
          try {
            currentBus = busProvider.buses.firstWhere(
              (bus) => bus.assignedRoute == route.routeId && bus.isActive,
            );
          } catch (_) {
            currentBus = null;
          }

          int? currentStopIndex;
          if (currentBus != null && stops.isNotEmpty) {
            double minDistance = double.infinity;
            for (int i = 0; i < stops.length; i++) {
              final distance = _calculateDistance(
                currentBus.latitude, currentBus.longitude,
                stops[i].latitude, stops[i].longitude,
              );
              if (distance < minDistance) {
                minDistance = distance;
                currentStopIndex = i;
              }
            }
          }

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            clipBehavior: Clip.hardEdge,
            child: ExpansionTile(
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
                    fontSize: 12,
                  ),
                ),
              ),
              title: Text(route.routeName,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: currentBus != null
                  ? Row(
                      children: [
                        Icon(Icons.directions_bus,
                            size: 14, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          'Bus ${currentBus.busNumber} active • ${route.stopIds.length} stops',
                          style: const TextStyle(
                              color: Colors.green, fontSize: 12),
                        ),
                      ],
                    )
                  : Text('${route.stopIds.length} stops'),
              children: [
                if (stops.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No stop data available',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: stops.asMap().entries.map((entry) {
                        final stopIndex = entry.key;
                        final stop = entry.value;
                        return _buildStopItem(
                          stop: stop,
                          isFirst: stopIndex == 0,
                          isLast: stopIndex == stops.length - 1,
                          isCurrent: stopIndex == currentStopIndex,
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Stops Near You ────────────────────────────────────────
            if (top3Stops.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.near_me, size: 16, color: AppTheme.primaryColor),
                    const SizedBox(width: 6),
                    Text(
                      'Stops Near You',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
              ...top3Stops.asMap().entries.map((e) {
                final i = e.key;
                final entry = e.value;
                return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    clipBehavior: Clip.hardEdge,
                    child: ExpansionTile(
                      key: ValueKey(
                          _expandedStopIndex == i ? 'open_$i' : 'closed_$i'),
                      initiallyExpanded: _expandedStopIndex == i,
                      onExpansionChanged: (expanded) {
                        setState(() {
                          _expandedStopIndex = expanded ? i : null;
                        });
                      },
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primaryColor,
                        child: const Icon(Icons.bus_alert,
                            color: Colors.white, size: 20),
                      ),
                      title: Text(entry.stop.stopName,
                          style:
                              const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                          '${entry.stop.stopCode} • ${entry.km.toStringAsFixed(1)} km away'),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => _guideMeThere(entry.stop),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.navigation, size: 18),
                                  SizedBox(width: 8),
                                  Text('Guide Me There'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
              }),
              const Divider(),
              const SizedBox(height: 4),
            ],
            // ── All routes ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.route,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    'All routes',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            ...List.generate(
                routeProvider.routes.length, (i) => buildRouteCard(i)),
          ],
        );
      },
    );
  }

  Widget _buildStopItem({
    required BusStop stop,
    required bool isFirst,
    required bool isLast,
    required bool isCurrent,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          Column(
            children: [
              // Top line
              if (!isFirst)
                Container(
                  width: 2,
                  height: 20,
                  color: isCurrent ? Colors.green : Theme.of(context).dividerColor,
                ),
              
              // Stop indicator
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCurrent ? Colors.green : Theme.of(context).colorScheme.surface,
                  border: Border.all(
                    color: isCurrent ? Colors.green : Theme.of(context).colorScheme.outline,
                    width: 3,
                  ),
                ),
                child: isCurrent
                    ? const Icon(
                        Icons.directions_bus,
                        size: 12,
                        color: Colors.white,
                      )
                    : null,
              ),
              
              // Bottom line
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: Theme.of(context).dividerColor,
                  ),
                ),
            ],
          ),

          const SizedBox(width: 16),

          // Stop details
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? (Theme.of(context).brightness == Brightness.dark
                          ? Colors.green.withValues(alpha: 0.12)
                          : Colors.green.shade50)
                      : (Theme.of(context).brightness == Brightness.dark
                          ? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6)
                          : Colors.grey.shade50),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isCurrent ? Colors.green : Theme.of(context).dividerColor,
                    width: isCurrent ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            stop.stopName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isCurrent ? Colors.green : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? Colors.green
                                : AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            stop.stopCode,
                            style: TextStyle(
                              color: isCurrent ? Colors.white : AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (stop.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        stop.description,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (isCurrent) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Bus is near this stop',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    // Simple Euclidean distance for approximation
    final latDiff = lat1 - lat2;
    final lonDiff = lon1 - lon2;
    return (latDiff * latDiff + lonDiff * lonDiff);
  }

  Future<void> _guideMeThere(BusStop stop) async {
    final lat = stop.latitude;
    final lng = stop.longitude;
    final name = Uri.encodeComponent(stop.stopName);
    // geo: URI — Android shows a chooser (Google Maps, Waze, etc.)
    final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng($name)');
    try {
      await launchUrl(geoUri);
      return;
    } catch (_) {
      // No app handles geo: — fall through to web fallback
    }
    // Fallback: Google Maps web
    final webUri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    await launchUrl(webUri, mode: LaunchMode.externalApplication);
  }

  Widget _buildReportsTab() {
    return const ReportScreen();
  }

  void _showNotificationsDialog() {
    showAppNotificationsSheet(context, 'student');
  }

  Widget _buildNetworkScheduleImage(String imageUrl, String title) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
      ),
      child: SizedBox(
        width: double.infinity,
        child: Image.network(
        imageUrl,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return ColoredBox(
            color: Colors.grey.shade100,
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return ColoredBox(
            color: Colors.grey.shade100,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.broken_image,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Failed to load image',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          );
        },
      ), // closes Image.network
    ), // closes SizedBox
  ); // closes DecoratedBox
}

}
