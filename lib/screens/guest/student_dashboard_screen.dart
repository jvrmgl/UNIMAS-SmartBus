import 'dart:async';
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
import '../../models/route_model.dart';
import '../../models/schedule_image_model.dart';
import '../../services/device_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/live_trip_pill.dart';
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
  final DeviceService _deviceService = DeviceService();
  DashboardNavProvider? _dashboardNavProvider;
  final CarouselSliderController _scheduleCarouselController =
      CarouselSliderController();
  Timer? _scheduleAutoTimer;
  int _scheduleCarouselIndex = 0;
  bool _scheduleCarouselForward = true;
  int _scheduleImageCount = 0;
  // no expansion state needed

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);

    // Load initial data after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _busProviderRef = context.read<BusProvider>();
      _busProviderRef!.listenToBuses(); // real-time stream
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

  BusProvider? _busProviderRef;

  void _configureScheduleAutoPlay(int itemCount) {
    if (_scheduleImageCount == itemCount) return;
    _scheduleImageCount = itemCount;
    _scheduleAutoTimer?.cancel();
    if (itemCount <= 1) return;

    _scheduleCarouselIndex =
      _scheduleCarouselIndex.clamp(0, itemCount - 1).toInt();
    _scheduleCarouselForward = _scheduleCarouselIndex == 0;

    _scheduleAutoTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted || _scheduleImageCount <= 1) return;

      var nextIndex = _scheduleCarouselForward
          ? _scheduleCarouselIndex + 1
          : _scheduleCarouselIndex - 1;

      if (nextIndex >= _scheduleImageCount) {
        _scheduleCarouselForward = false;
        nextIndex = _scheduleImageCount - 2;
      } else if (nextIndex < 0) {
        _scheduleCarouselForward = true;
        nextIndex = 1;
      }

      if (nextIndex < 0 || nextIndex >= _scheduleImageCount) return;
      _scheduleCarouselIndex = nextIndex;
      _scheduleCarouselController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> _openBusDetailsGuarded(Bus selectedBus) async {
    final deviceId = await _deviceService.getDeviceId();
    final activeBusId = await _firestoreService.getDeviceActiveBusId(deviceId);

    if (!mounted) return;

    if (activeBusId != null && activeBusId != selectedBus.busId) {
      final busProvider = context.read<BusProvider>();
      Bus? activeBus;
      try {
        activeBus = busProvider.buses.firstWhere((b) => b.busId == activeBusId);
      } catch (_) {
        activeBus = null;
      }

      final goToActiveBus = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Active bus session detected'),
          content: Text(
            activeBus != null
                ? 'You are currently tapped into Bus ${activeBus.busNumber}. Please tap out first before selecting another bus.'
                : 'You are currently tapped into another bus. Please tap out first before selecting another bus.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            if (activeBus != null)
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Go to active bus'),
              ),
          ],
        ),
      );

      if (goToActiveBus == true && activeBus != null && mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => BusDetailScreen(bus: activeBus!)),
        );
      }
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BusDetailScreen(bus: selectedBus)),
    );
  }

  @override
  void dispose() {
    _dashboardNavProvider?.removeListener(_onNavChange);
    _busProviderRef?.stopListeningToBuses();
    _scheduleAutoTimer?.cancel();
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
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined),
                      onPressed: () {
                        _showNotificationsDialog();
                      },
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
                          minWidth: 8,
                          minHeight: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const LiveTripPill(inAppBarArea: true),
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
            indicatorColor: AppTheme.primaryColor,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: Colors.grey,
            labelStyle: const TextStyle(fontSize: 11),
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

            _configureScheduleAutoPlay(scheduleImages.length);

            return Card(
              elevation: 4,
              clipBehavior: Clip.antiAlias,
              child: CarouselSlider(
                carouselController: _scheduleCarouselController,
                options: CarouselOptions(
                  height: 400,
                  viewportFraction: 1.0,
                  enableInfiniteScroll: false,
                  scrollPhysics: const BouncingScrollPhysics(),
                  autoPlay: false,
                  autoPlayInterval: const Duration(seconds: 10),
                  autoPlayAnimationDuration: const Duration(milliseconds: 800),
                  enlargeCenterPage: false,
                  onPageChanged: (index, reason) {
                    final previousIndex = _scheduleCarouselIndex;
                    _scheduleCarouselIndex = index;
                    if (reason == CarouselPageChangedReason.manual) {
                      _scheduleCarouselForward = index >= previousIndex;
                    }
                    if (index <= 0) _scheduleCarouselForward = true;
                    if (index >= scheduleImages.length - 1) {
                      _scheduleCarouselForward = false;
                    }
                  },
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
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: 4,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    const SkeletonBox(height: 56, width: 56, borderRadius: BorderRadius.all(Radius.circular(12))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          SkeletonBox(height: 16),
                          SizedBox(height: 8),
                          SkeletonBox(height: 12, width: 120),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
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
                        onPressed: () => _openBusDetailsGuarded(bus),
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

        // Find all bus stops (sorted by distance to user)
        final List<({BusStop stop, double km})> nearbyStops = [];
        final pos = locationProvider.currentPosition;
        if (pos != null && routeProvider.busStops.isNotEmpty) {
          final sorted = [...routeProvider.busStops]..sort((a, b) {
            final da = Geolocator.distanceBetween(
                pos.latitude, pos.longitude, a.latitude, a.longitude);
            final db = Geolocator.distanceBetween(
                pos.latitude, pos.longitude, b.latitude, b.longitude);
            return da.compareTo(db);
          });
          for (final s in sorted) {
            final km = Geolocator.distanceBetween(
                    pos.latitude, pos.longitude, s.latitude, s.longitude) /
                1000;
            nearbyStops.add((stop: s, km: km));
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
            if (nearbyStops.isNotEmpty) ...[
              Card(
                margin: const EdgeInsets.only(bottom: 16),
                clipBehavior: Clip.hardEdge,
                child: ExpansionTile(
                  initiallyExpanded: false,
                  leading: Icon(Icons.near_me, color: AppTheme.primaryColor),
                  title: Text(
                    'Stops Around You',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  children: [
                    ...nearbyStops.asMap().entries.map((e) {
                      final entry = e.value;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.primaryColor,
                              child: const Icon(Icons.bus_alert,
                                  color: Colors.white, size: 20),
                            ),
                            title: Text(entry.stop.stopName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text(
                                '${entry.stop.stopCode} • ${entry.km.toStringAsFixed(1)} km away'),
                            trailing: Builder(
                              builder: (context) {
                                final busText = _getStopBusNumber(
                                      stop: entry.stop,
                                      buses: busProvider.buses,
                                      routes: routeProvider.routes,
                                      routeProvider: routeProvider,
                                    );
                                final etaText = _getStopEtaMinutes(
                                      stop: entry.stop,
                                      buses: busProvider.buses,
                                      routes: routeProvider.routes,
                                      routeProvider: routeProvider,
                                    );
                                final hasBus = busText != 'No active bus';
                                final textColor = hasBus ? Colors.green.shade700 : Colors.grey.shade600;
                                
                                return ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    minWidth: 84,
                                    maxWidth: 108,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        busText,
                                        textAlign: TextAlign.right,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: textColor,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        etaText,
                                        textAlign: TextAlign.right,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              color: textColor,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            ),
                          ),
                          // Card actions row
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            child: Row(
                              children: [
                                OutlinedButton.icon(
                                  icon: Icon(Icons.map_outlined,
                                      size: 16, color: AppTheme.primaryColor),
                                  label: Text('View on Map',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.primaryColor)),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 4),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.5)),
                                  ),
                                  onPressed: () {
                                    context
                                        .read<DashboardNavProvider>()
                                        .navigateToMapWithFocus(
                                          entry.stop.latitude,
                                          entry.stop.longitude,
                                        );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Showing ${entry.stop.stopName} on map'),
                                        duration: const Duration(seconds: 2),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  icon: Icon(Icons.navigation,
                                      size: 16,
                                      color: Colors.green.shade600),
                                  label: Text('Navigate',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.green.shade600)),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 4),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    side: BorderSide(color: Colors.green.shade600.withValues(alpha: 0.5)),
                                  ),
                                  onPressed: () =>
                                      _guideMeThere(entry.stop),
                                ),
                              ],
                            ),
                          ),
                          if (e.key != nearbyStops.length - 1)
                            const Divider(height: 1),
                        ],
                      );
                    }),
                  ],
                ),
              ),
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

  String _getStopBusNumber({
    required BusStop stop,
    required List<Bus> buses,
    required List<BusRoute> routes,
    required RouteProvider routeProvider,
  }) {
    Bus? bestBus;
    int? bestEtaMinutes;

    for (final bus in buses) {
      if (!bus.isActive || bus.assignedRoute == null) continue;

      BusRoute? route;
      try {
        route = routes.firstWhere((r) => r.routeId == bus.assignedRoute);
      } catch (_) {
        route = null;
      }
      if (route == null || !route.stopIds.contains(stop.stopId)) continue;

      final orderedStops = _orderedStopsForRoute(route, routeProvider);
      final targetIndex = orderedStops.indexWhere(
        (routeStop) => routeStop.stopId == stop.stopId,
      );
      if (targetIndex == -1) continue;
      final legDistances = routeProvider.getRouteLegDistances(route.routeId);

      final etaMinutes = _estimateRouteStopEtaMinutes(
        bus: bus,
        orderedStops: orderedStops,
        targetIndex: targetIndex,
        legDistancesMeters: legDistances,
      );
      if (etaMinutes == null) continue;

      if (bestEtaMinutes == null || etaMinutes < bestEtaMinutes) {
        bestEtaMinutes = etaMinutes;
        bestBus = bus;
      }
    }

    if (bestBus == null) {
      return 'No active bus';
    }

    return 'Bus ${bestBus.busNumber}';
  }

  String _getStopEtaMinutes({
    required BusStop stop,
    required List<Bus> buses,
    required List<BusRoute> routes,
    required RouteProvider routeProvider,
  }) {
    int? bestEtaMinutes;

    for (final bus in buses) {
      if (!bus.isActive || bus.assignedRoute == null) continue;

      BusRoute? route;
      try {
        route = routes.firstWhere((r) => r.routeId == bus.assignedRoute);
      } catch (_) {
        route = null;
      }
      if (route == null || !route.stopIds.contains(stop.stopId)) continue;

      final orderedStops = _orderedStopsForRoute(route, routeProvider);
      final targetIndex = orderedStops.indexWhere(
        (routeStop) => routeStop.stopId == stop.stopId,
      );
      if (targetIndex == -1) continue;
      final legDistances = routeProvider.getRouteLegDistances(route.routeId);

      final etaMinutes = _estimateRouteStopEtaMinutes(
        bus: bus,
        orderedStops: orderedStops,
        targetIndex: targetIndex,
        legDistancesMeters: legDistances,
      );
      if (etaMinutes == null) continue;

      if (bestEtaMinutes == null || etaMinutes < bestEtaMinutes) {
        bestEtaMinutes = etaMinutes;
      }
    }

    if (bestEtaMinutes == null) {
      return '--';
    }

    return '$bestEtaMinutes min';
  }

  List<BusStop> _orderedStopsForRoute(
    BusRoute route,
    RouteProvider routeProvider,
  ) {
    return route.stopIds
        .map((stopId) {
          try {
            return routeProvider.busStops.firstWhere(
                  (stop) => stop.stopId == stopId,
                );
          } catch (_) {
            return null;
          }
        })
        .where((stop) => stop != null)
        .cast<BusStop>()
        .toList();
  }

  int? _estimateRouteStopEtaMinutes({
    required Bus bus,
    required List<BusStop> orderedStops,
    required int targetIndex,
    List<double>? legDistancesMeters,
  }) {
    if (orderedStops.isEmpty) return null;

    final targetStop = orderedStops[targetIndex];

    // Priority 1: Check for Live Traffic ETA (Distance Matrix)
    if (bus.liveEtaByStopId != null && bus.liveEtaUpdatedAt != null) {
      final age = DateTime.now().difference(bus.liveEtaUpdatedAt!);
      if (age.inMinutes < 5) {
        final liveEta = bus.liveEtaByStopId![targetStop.stopId];
        if (liveEta != null) {
          return liveEta;
        }
      }
    }

    // Priority 2: Fallback to mathematical distance estimate
    final currentIndex = _nearestRouteStopIndex(bus, orderedStops);
    final directToCurrentMeters = Geolocator.distanceBetween(
      bus.latitude,
      bus.longitude,
      orderedStops[currentIndex].latitude,
      orderedStops[currentIndex].longitude,
    );

    final routeMeters = _routePathDistanceMeters(
      orderedStops,
      currentIndex,
      targetIndex,
      legDistancesMeters,
    );

    final totalMeters = targetIndex == currentIndex
        ? Geolocator.distanceBetween(
            bus.latitude,
            bus.longitude,
            orderedStops[targetIndex].latitude,
            orderedStops[targetIndex].longitude,
          )
        : directToCurrentMeters + routeMeters;

    return _estimateEtaMinutes(totalMeters);
  }

  int _nearestRouteStopIndex(Bus bus, List<BusStop> orderedStops) {
    int nearestIndex = 0;
    double minDistance = double.infinity;

    for (int i = 0; i < orderedStops.length; i++) {
      final distance = Geolocator.distanceBetween(
        bus.latitude,
        bus.longitude,
        orderedStops[i].latitude,
        orderedStops[i].longitude,
      );
      if (distance < minDistance) {
        minDistance = distance;
        nearestIndex = i;
      }
    }

    return nearestIndex;
  }

  double _routePathDistanceMeters(
    List<BusStop> orderedStops,
    int fromIndex,
    int toIndex,
    List<double>? legDistancesMeters,
  ) {
    if (orderedStops.isEmpty || fromIndex == toIndex) return 0;

    double totalMeters = 0;
    int currentIndex = fromIndex;

    while (currentIndex != toIndex) {
      final nextIndex = (currentIndex + 1) % orderedStops.length;
      final canUseLegDistance =
          legDistancesMeters != null &&
          legDistancesMeters.isNotEmpty &&
          currentIndex < legDistancesMeters.length;
      if (canUseLegDistance) {
        totalMeters += legDistancesMeters[currentIndex];
      } else {
        totalMeters += Geolocator.distanceBetween(
          orderedStops[currentIndex].latitude,
          orderedStops[currentIndex].longitude,
          orderedStops[nextIndex].latitude,
          orderedStops[nextIndex].longitude,
        );
      }
      currentIndex = nextIndex;
    }

    return totalMeters;
  }

  int _estimateEtaMinutes(double distanceMeters) {
    const estimatedSpeedKmH = 25.0;
    final eta = ((distanceMeters / 1000) / estimatedSpeedKmH * 60).ceil();
    return eta <= 0 ? 1 : eta;
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

  void _openScheduleImageFullscreen(String imageUrl, String title) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog.fullscreen(
          child: Scaffold(
            backgroundColor: Colors.black,
            body: SafeArea(
              child: Stack(
                children: [
                  Center(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return InteractiveViewer(
                          minScale: 1,
                          maxScale: 6,
                          boundaryMargin: const EdgeInsets.all(120),
                          constrained: false,
                          child: SizedBox(
                            width: constraints.maxWidth,
                            height: constraints.maxHeight,
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.contain,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.broken_image,
                                      size: 64,
                                      color: Colors.white70,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Unable to load $title',
                                      style:
                                          const TextStyle(color: Colors.white70),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNetworkScheduleImage(String imageUrl, String title) {
    final surfaceColor = Theme.of(context).colorScheme.surface;
    final placeholderColor =
      Theme.of(context).colorScheme.surfaceContainerHighest;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaceColor,
      ),
      child: SizedBox(
        width: double.infinity,
        child: InkWell(
          onTap: () => _openScheduleImageFullscreen(imageUrl, title),
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return ColoredBox(
                      color: placeholderColor,
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
                      color: placeholderColor,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image,
                            size: 64,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.7),
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Failed to load image',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.6),
                                ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const Positioned(
                right: 10,
                bottom: 10,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0x88000000),
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.zoom_in, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Tap to zoom',
                          style: TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
