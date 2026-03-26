import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/announcement_provider.dart';
import '../../providers/driver_shift_provider.dart';
import '../../providers/bus_provider.dart';
import '../../providers/route_provider.dart';
import '../../constants/app_theme.dart';
import '../../models/bus_stop_model.dart';
import '../../services/notification_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/slide_button.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  bool _isOccupancyEditorOpen = false;
  bool _showRouteError = false;
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final authProvider = context.read<AuthProvider>();
      final shiftProvider = context.read<DriverShiftProvider>();
      
      // Initialize driver
      if (authProvider.currentUser != null) {
        shiftProvider.setDriverUid(authProvider.currentUser!.uid);
        // Save driver FCM token keyed by userId so the shift-reminder
        // Cloud Function can target this device by driverId.
        NotificationService().saveDeviceToken(
          userId: authProvider.currentUser!.uid,
        );
      }
      
      context.read<AnnouncementProvider>().fetchAnnouncements();
      context.read<BusProvider>().listenToBuses(); // real-time stream
      context.read<RouteProvider>().fetchRoutes();
      context.read<RouteProvider>().fetchBusStops();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
        elevation: 0,
        actions: [
          Consumer<AnnouncementProvider>(
            builder: (context, announcementProvider, _) {
              final hasUnread =
                  announcementProvider.hasVisibleAnnouncementsFor('driver');
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
                      'Welcome, ${authProvider.currentUser?.fullName ?? "Driver"}!',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
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
            child: Consumer<DriverShiftProvider>(
              builder: (context, shiftProvider, _) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Error message
                      if (shiftProvider.error != null)
                        Card(
                          color: Colors.red.withValues(alpha: 0.12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                const Icon(Icons.error, color: Colors.red),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    shiftProvider.error!,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () => shiftProvider.clearError(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      
                      // Bus Assignment Card
                      if (!shiftProvider.hasAssignedBus)
                        _buildBusSelectionCard()
                      else
                        _buildAssignedBusCard(shiftProvider),
                      
                      const SizedBox(height: 16),
                      
                      // Shift Control Card
                      if (shiftProvider.hasAssignedBus)
                        _buildShiftControlCard(shiftProvider),
                      
                      const SizedBox(height: 16),

                      // Route Selection (no route assigned, not on shift)
                      if (shiftProvider.hasAssignedBus &&
                          shiftProvider.assignedBus!.assignedRoute == null &&
                          !shiftProvider.isOnShift)
                        _buildRouteSelectionCard(shiftProvider),

                      // Route Information
                      if (shiftProvider.hasAssignedBus && shiftProvider.assignedBus!.assignedRoute != null)
                        _buildRouteInfoCard(shiftProvider),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusSelectionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.directions_bus, color: AppTheme.primaryColor),
                const SizedBox(width: 12),
                const Text(
                  'Select Your Bus',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('No bus assigned yet. Select a bus to start your shift.'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _showBusSelectionDialog(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_circle_outline, color: Colors.white, size: 22),
                    SizedBox(width: 8),
                    Text('Select Bus', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignedBusCard(DriverShiftProvider shiftProvider) {
    final bus = shiftProvider.assignedBus!;
    final isBusOnline = shiftProvider.isOnShift && bus.isActive;
    final displayedOccupancy = isBusOnline ? bus.currentOccupancy : 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.directions_bus,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bus ${bus.busNumber}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          bus.registrationNumber,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
                PopupMenuButton(
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'release',
                      child: Row(
                        children: [
                          Icon(Icons.remove_circle_outline, size: 18),
                          SizedBox(width: 8),
                          Text('Release Bus'),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'release') {
                      _confirmReleaseBus(shiftProvider);
                    }
                  },
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildBusStat('Capacity', '${bus.capacity}', Icons.event_seat),
                Column(
                  children: [
                    const Icon(Icons.people, color: Colors.blue, size: 24),
                    const SizedBox(height: 4),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: shiftProvider.isOnShift
                          ? () {
                              setState(() {
                                _isOccupancyEditorOpen = !_isOccupancyEditorOpen;
                              });
                            }
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Text(
                          '$displayedOccupancy',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (shiftProvider.isOnShift)
                      InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          setState(() {
                            _isOccupancyEditorOpen = !_isOccupancyEditorOpen;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isOccupancyEditorOpen ? Icons.expand_less : Icons.tune,
                                size: 14,
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _isOccupancyEditorOpen ? 'Close editor' : 'Tap to edit',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Text(
                        'Passengers',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
                _buildBusStat(
                  'Status',
                  isBusOnline ? 'Active' : 'Inactive',
                  Icons.circle,
                  color: isBusOnline ? Colors.green : Colors.grey,
                ),
              ],
            ),
            if (shiftProvider.isOnShift && _isOccupancyEditorOpen) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.blue.withValues(alpha: 0.12)
                      : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: () => _decrementOccupancy(shiftProvider),
                          icon: const Icon(Icons.remove_circle),
                          color: Colors.red,
                          iconSize: 30,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${bus.currentOccupancy}/${bus.capacity}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _incrementOccupancy(shiftProvider),
                          icon: const Icon(Icons.add_circle),
                          color: Colors.green,
                          iconSize: 30,
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _isOccupancyEditorOpen = false;
                            });
                          },
                          icon: const Icon(Icons.close),
                          color: Colors.grey,
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Use manual adjustment only when students forgot to tap out.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.blue.shade100
                            : Colors.blue.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildShiftControlCard(DriverShiftProvider shiftProvider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      color: shiftProvider.isOnShift
          ? (isDark ? Colors.green.withValues(alpha: 0.12) : Colors.green.shade50)
          : (isDark ? Colors.blue.withValues(alpha: 0.12) : Colors.blue.shade50),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  shiftProvider.isOnShift ? Icons.check_circle : Icons.info,
                  color: shiftProvider.isOnShift ? Colors.green : Colors.blue,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    shiftProvider.isOnShift
                        ? 'Shift Active - GPS Tracking Enabled'
                        : 'Ready to Start Shift',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            if (shiftProvider.isOnShift)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Your location is being shared with passengers',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green,
                  ),
                ),
              ),
            if (!shiftProvider.isOnShift &&
                shiftProvider.assignedBus?.assignedRoute == null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_outlined,
                        size: 14, color: Colors.orange.shade700),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Please select a route below before starting your shift',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            SlideButton(
              text: shiftProvider.isOnShift ? 'Slide to End Shift' : 'Slide to Start Shift',
              onConfirm: () {
                if (shiftProvider.isOnShift) {
                  _endShift(shiftProvider);
                } else if (shiftProvider.assignedBus?.assignedRoute == null) {
                  setState(() => _showRouteError = true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please select a route before starting your shift'),
                      backgroundColor: Colors.orange,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } else {
                  _startShift(shiftProvider);
                }
              },
              backgroundColor: shiftProvider.isOnShift ? Colors.red : Colors.green,
              icon: shiftProvider.isOnShift ? Icons.stop : Icons.play_arrow,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusStat(String label, String value, IconData icon, {Color? color}) {
    return Column(
      children: [
        Icon(icon, color: color ?? Colors.blue, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildRouteSelectionCard(DriverShiftProvider shiftProvider) {
    return Consumer<RouteProvider>(
      builder: (context, routeProvider, _) {
        if (routeProvider.routes.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.route,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('No routes available — contact your admin.'),
                  ),
                ],
              ),
            ),
          );
        }
        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: _showRouteError
                  ? Colors.red
                  : Colors.orange.withValues(alpha: 0.4),
              width: _showRouteError ? 2.0 : 1.0,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.route, color: Colors.orange.shade700),
                    const SizedBox(width: 12),
                    Text(
                      'Select Route',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Your bus has no route assigned. Select one to proceed.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Route',
                    prefixIcon: Icon(Icons.map_outlined),
                    isDense: true,
                  ),
                  items: routeProvider.routes
                      .map(
                        (route) => DropdownMenuItem(
                          value: route.routeId,
                          child: Text(route.routeName,
                              overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (routeId) async {
                    if (routeId == null) return;
                    final bus = shiftProvider.assignedBus;
                    if (bus == null) return;
                    final busProvider = context.read<BusProvider>();
                    final messenger = ScaffoldMessenger.of(context);
                    final err = await _firestoreService.assignRouteToBus(
                      busId: bus.busId,
                      routeId: routeId,
                    );
                    if (!mounted) return;
                    if (err == null) {
                      busProvider.fetchBuses();
                      setState(() => _showRouteError = false);
                    messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Route selected — you can now start your shift'),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } else {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Error: $err'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRouteInfoCard(DriverShiftProvider shiftProvider) {
    final assignedBus = shiftProvider.assignedBus;
    final routeId = assignedBus?.assignedRoute;
    if (routeId == null) {
      return const SizedBox.shrink();
    }

    return Consumer<RouteProvider>(
      builder: (context, routeProvider, _) {
        if (routeProvider.routes.isEmpty) {
          return const SizedBox.shrink();
        }

        final route = routeProvider.routes.firstWhere(
          (r) => r.routeId == routeId,
          orElse: () => routeProvider.routes.first,
        );

        final stops = route.stopIds
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

        int? currentStopIndex;
        if (assignedBus != null && assignedBus.isActive && stops.isNotEmpty) {
          double minDistance = double.infinity;
          for (int i = 0; i < stops.length; i++) {
            final distance = _calculateDistance(
              assignedBus.latitude,
              assignedBus.longitude,
              stops[i].latitude,
              stops[i].longitude,
            );
            if (distance < minDistance) {
              minDistance = distance;
              currentStopIndex = i;
            }
          }
        }
        
        return Card(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ExpansionTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            collapsedShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.route, color: AppTheme.primaryColor),
            ),
            title: const Text(
              'My Route',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text('${route.routeName} • ${stops.length} stops'),
            children: [
              if (stops.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No stop data available',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Column(
                    children: stops.asMap().entries.map((entry) {
                      final stopIndex = entry.key;
                      final stop = entry.value;
                      return _buildRouteStopItem(
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
      },
    );
  }

  Widget _buildRouteStopItem({
    required BusStop stop,
    required bool isFirst,
    required bool isLast,
    required bool isCurrent,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              if (!isFirst)
                Container(
                  width: 2,
                  height: 16,
                  color: isCurrent ? Colors.green : Theme.of(context).dividerColor,
                ),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCurrent ? Colors.green : Theme.of(context).colorScheme.surface,
                  border: Border.all(
                    color: isCurrent ? Colors.green : Theme.of(context).colorScheme.outline,
                    width: 3,
                  ),
                ),
                child: isCurrent
                    ? const Icon(Icons.directions_bus, size: 10, color: Colors.white)
                    : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: Theme.of(context).dividerColor,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(10),
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
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isCurrent ? Colors.green : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        Text(
                          stop.stopCode,
                          style: TextStyle(
                            fontSize: 12,
                            color: isCurrent ? Colors.green : Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (stop.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        stop.description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (isCurrent) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Bus is near this stop',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
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
    final latDiff = lat1 - lat2;
    final lonDiff = lon1 - lon2;
    return (latDiff * latDiff + lonDiff * lonDiff);
  }

  void _incrementOccupancy(DriverShiftProvider shiftProvider) async {
    final bus = shiftProvider.assignedBus!;
    final newOccupancy = bus.currentOccupancy + 1;
    
    if (newOccupancy > bus.capacity) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bus is at full capacity'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    
    await shiftProvider.adjustOccupancy(newOccupancy);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Passengers: $newOccupancy'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _decrementOccupancy(DriverShiftProvider shiftProvider) async {
    final bus = shiftProvider.assignedBus!;
    final newOccupancy = (bus.currentOccupancy - 1).clamp(0, bus.capacity);
    
    await shiftProvider.adjustOccupancy(newOccupancy);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Passengers: $newOccupancy'),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _showBusSelectionDialog() {
    final authProvider = context.read<AuthProvider>();
    final shiftProvider = context.read<DriverShiftProvider>();
    final busProvider = context.read<BusProvider>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Select Your Bus'),
        content: SizedBox(
          width: double.maxFinite,
          child: busProvider.buses.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No buses available'),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: busProvider.buses.length,
                  itemBuilder: (context, index) {
                    final bus = busProvider.buses[index];
                    final isAssigned = bus.driverId != null && 
                                       bus.driverId != authProvider.currentUser?.uid;
                    return ListTile(
                      leading: Icon(
                        Icons.directions_bus,
                        color: isAssigned ? Colors.grey : Colors.blue,
                      ),
                      title: Text('Bus ${bus.busNumber}'),
                      subtitle: Text(
                        isAssigned
                            ? 'Assigned to ${bus.driverName}'
                            : bus.registrationNumber,
                      ),
                      enabled: !isAssigned,
                      onTap: isAssigned
                          ? null
                          : () async {
                              final success = await shiftProvider.selectBus(
                                bus,
                                authProvider.currentUser!.fullName,
                              );
                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext);
                              }
                              if (mounted && success) {
                                // ignore: use_build_context_synchronously
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Bus assigned successfully'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _confirmReleaseBus(DriverShiftProvider shiftProvider) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Release Bus'),
        content: const Text(
          'Are you sure you want to release this bus? You will need to select it again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await shiftProvider.releaseBus();
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Bus released'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Release'),
          ),
        ],
      ),
    );
  }

  Future<void> _startShift(DriverShiftProvider shiftProvider) async {
    final success = await shiftProvider.startShift();
    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Shift started - GPS tracking active'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _endShift(DriverShiftProvider shiftProvider) async {
    await shiftProvider.endShift();
    if (mounted) {
      setState(() {
        _isOccupancyEditorOpen = false;
      });
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Shift ended - GPS tracking stopped'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _showNotificationsDialog() {
    showAppNotificationsSheet(context, 'driver');
  }
}
