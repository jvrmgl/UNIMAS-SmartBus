import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../../constants/app_constants.dart';
import '../../providers/bus_provider.dart';
import '../../providers/route_provider.dart';
import '../../providers/announcement_provider.dart';
import '../../widgets/common_widgets.dart';
import '../../providers/driver_shift_provider.dart';
import '../../models/bus_model.dart';
import '../../models/bus_stop_model.dart';
import '../../services/location_service.dart';
import '../../utils/map_marker_helper.dart';
import '../../utils/map_style.dart';

class DriverMapScreen extends StatefulWidget {
  const DriverMapScreen({super.key});

  @override
  State<DriverMapScreen> createState() => _DriverMapScreenState();
}

class _DriverMapScreenState extends State<DriverMapScreen> {
  final Completer<GoogleMapController> _mapController = Completer<GoogleMapController>();
  BitmapDescriptor? _busMarkerIcon;
  BitmapDescriptor? _busInactiveMarkerIcon;
  BitmapDescriptor? _stopMarkerIcon;
  final Map<String, LatLng> _animatedBusPositions = {};
  final Map<String, Timer> _busAnimationTimers = {};
  // Adaptive animation: duration computed from distance / assumed speed
  static const int _minBusAnimationMs = 200;
  static const int _maxBusAnimationMs = 2500;
  static const double _busSpeedMps = 10.0; // meters per second (tunable)
  BusProvider? _busProviderRef;
  double? _smoothedSpeedKmH;
  double? _lastBusLat;
  double? _lastBusLng;
  DateTime? _lastBusUpdatedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _busProviderRef = context.read<BusProvider>();
      _busProviderRef!.addListener(_onBusProviderUpdate);
      _loadData();
      _loadMarkerIcons();
    });
  }

  Future<void> _loadMarkerIcons() async {
    final bus      = await MapMarkerHelper.getBusMarker();
    final inactive = await MapMarkerHelper.getBusInactiveMarker();
    final stop     = await MapMarkerHelper.getStopMarker();
    if (!mounted) return;
    setState(() {
      _busMarkerIcon         = bus;
      _busInactiveMarkerIcon = inactive;
      _stopMarkerIcon        = stop;
    });
  }

  void _loadData() async {
    final busProvider = context.read<BusProvider>();
    final routeProvider = context.read<RouteProvider>();
    final announcementProvider = context.read<AnnouncementProvider>();

    busProvider.listenToBuses();
    routeProvider.listenToBusStops();
    await Future.wait([
      routeProvider.fetchRoutes(),
      announcementProvider.fetchAnnouncements(),
    ]);
    _syncBusMarkerPositions(busProvider.buses);
  }

  void _onBusProviderUpdate() {
    if (!mounted) return;
    final busProvider = _busProviderRef;
    if (busProvider == null) return;
    _syncBusMarkerPositions(busProvider.buses);
  }

  void _syncBusMarkerPositions(List<Bus> buses) {
    final activeIds = buses.map((bus) => bus.busId).toSet();
    final staleIds = _animatedBusPositions.keys
        .where((id) => !activeIds.contains(id))
        .toList();

    for (final id in staleIds) {
      _busAnimationTimers[id]?.cancel();
      _busAnimationTimers.remove(id);
      _animatedBusPositions.remove(id);
    }

    for (final bus in buses) {
      _animateBusMarker(bus);
    }
  }
  // Keep previous server-reported positions and timestamps to compute observed speed
  final Map<String, LatLng> _lastServerPositions = {};
  final Map<String, DateTime> _lastServerTimestamps = {};
  final Map<String, double> _smoothedSpeeds = {}; // m/s (EMA)

  void _animateBusMarker(Bus bus) {
    final busId = bus.busId;
    final target = LatLng(bus.latitude, bus.longitude);
    final start = _animatedBusPositions[busId];
    if (start == null) {
      _animatedBusPositions[busId] = target;
      if (mounted) {
        setState(() {});
      }
      // Record server position/timestamp
      _lastServerPositions[busId] = target;
      _lastServerTimestamps[busId] = bus.lastUpdated;
      return;
    }

    if (start.latitude == target.latitude && start.longitude == target.longitude) {
      return;
    }

    _busAnimationTimers[busId]?.cancel();
    const steps = 30;
    int tick = 0;

    // Compute distance (meters) and adapt duration
    final distanceMeters = Geolocator.distanceBetween(
      start.latitude,
      start.longitude,
      target.latitude,
      target.longitude,
    );

    // Teleport guard: large jumps should snap instead of slow crawl
    const double teleportThresholdMeters = 1000.0;
    if (distanceMeters > teleportThresholdMeters) {
      _busAnimationTimers[busId]?.cancel();
      _animatedBusPositions[busId] = target;
      // update server record
      _lastServerPositions[busId] = target;
      _lastServerTimestamps[busId] = bus.lastUpdated;
      if (mounted) setState(() {});
      return;
    }

    // Try to compute observed speed from server updates
    int durationMs;
    final prevPos = _lastServerPositions[busId];
    final prevTs = _lastServerTimestamps[busId];
    double? observedSpeed;
    if (prevPos != null && prevTs != null) {
      final serverDeltaMeters = Geolocator.distanceBetween(
        prevPos.latitude,
        prevPos.longitude,
        target.latitude,
        target.longitude,
      );
      final deltaSecs = bus.lastUpdated.difference(prevTs).inMilliseconds / 1000.0;
      if (deltaSecs > 0 && deltaSecs <= 120) {
        observedSpeed = serverDeltaMeters / deltaSecs; // m/s
        // sanity bounds
        if (observedSpeed < 0.5 || observedSpeed > 40.0) {
          observedSpeed = null;
        }
      }
    }

    double useSpeed = _busSpeedMps;
    if (observedSpeed != null) {
      // EMA smoothing
      final prevSmooth = _smoothedSpeeds[busId] ?? observedSpeed;
      const alpha = 0.18;
      final smooth = prevSmooth * (1 - alpha) + observedSpeed * alpha;
      _smoothedSpeeds[busId] = smooth;
      useSpeed = smooth;
    } else if (_smoothedSpeeds.containsKey(busId)) {
      useSpeed = _smoothedSpeeds[busId]!;
    }

    durationMs = (distanceMeters / useSpeed * 1000).round();
    if (durationMs < _minBusAnimationMs) durationMs = _minBusAnimationMs;
    if (durationMs > _maxBusAnimationMs) durationMs = _maxBusAnimationMs;

    // Update server-record cache
    _lastServerPositions[busId] = target;
    _lastServerTimestamps[busId] = bus.lastUpdated;

    _busAnimationTimers[busId] = Timer.periodic(
      Duration(milliseconds: (durationMs / steps).round().clamp(16, durationMs)),
      (timer) {
        tick += 1;
        final t = (tick / steps).clamp(0, 1).toDouble();
        final easedT = _easeInOutQuad(t);
        final nextLat = start.latitude + (target.latitude - start.latitude) * easedT;
        final nextLng = start.longitude + (target.longitude - start.longitude) * easedT;
        _animatedBusPositions[busId] = LatLng(nextLat, nextLng);
        if (mounted) setState(() {});
        if (tick >= steps) {
          timer.cancel();
          _busAnimationTimers.remove(busId);
          _animatedBusPositions[busId] = target;
        }
      },
    );
  }

  double _easeInOutQuad(double t) {
    return t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t;
  }

  Future<void> _goToCurrentLocation() async {
    final position = await LocationService.getCurrentPosition();
    if (position == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to get current location')),
        );
      }
      return;
    }

    final controller = await _mapController.future;
    controller.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(position.latitude, position.longitude),
        16.0,
      ),
    );
  }

  void _showNotificationsDialog() {
    showAppNotificationsSheet(context, 'driver');
  }

  Set<Marker> _buildMarkers(
    BusProvider busProvider,
    RouteProvider routeProvider,
  ) {
    Set<Marker> markers = {};

    for (var bus in busProvider.buses) {
      final position =
          _animatedBusPositions[bus.busId] ?? LatLng(bus.latitude, bus.longitude);
      markers.add(
        Marker(
          markerId: MarkerId('bus_${bus.busId}'),
          position: position,
          onTap: () => _showBusInfoSheet(bus),
          icon: (bus.isActive ? _busMarkerIcon : _busInactiveMarkerIcon) ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }

    for (var stop in routeProvider.busStops) {
      markers.add(
        Marker(
          markerId: MarkerId('stop_${stop.stopId}'),
          position: LatLng(stop.latitude, stop.longitude),
          onTap: () => _showStopInfoSheet(stop),
          icon: _stopMarkerIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }

    return markers;
  }

  void _showBusInfoSheet(Bus bus) {
    showModalBottomSheet(
      context: context,
      barrierColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.blue.shade100,
                    child: Icon(Icons.directions_bus, color: Colors.blue.shade700),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bus ${bus.busNumber}',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text(
                          '${bus.isActive ? 'Active' : 'Inactive'} '
                          '• ${bus.currentOccupancy}/${bus.capacity} seats',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: bus.getOccupancyPercentage() / 100,
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      bus.isNearCapacity() ? Colors.orange : Colors.green),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showStopInfoSheet(BusStop stop) {
    showModalBottomSheet(
      context: context,
      barrierColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.green.shade100,
                    child: Icon(Icons.place, color: Colors.green.shade700),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(stop.stopName,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text(stop.stopCode),
                      ],
                    ),
                  ),
                ],
              ),
              if (stop.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(stop.description,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Map'),
        elevation: 0,
        actions: [
          Consumer<AnnouncementProvider>(
            builder: (context, announcementProvider, _) {
              final hasUnread = announcementProvider.hasVisibleAnnouncementsFor('driver');
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
      body: Stack(
        children: [
          Consumer3<BusProvider, RouteProvider, DriverShiftProvider>(
            builder: (context, busProvider, routeProvider, shiftProvider, _) {
              final markers = _buildMarkers(busProvider, routeProvider);
              final mapStyle =
                  mapStyleForBrightness(Theme.of(context).brightness);
              return GoogleMap(
                style: mapStyle,
                initialCameraPosition: const CameraPosition(
                  target: LatLng(1.4651, 110.4277),
                  zoom: AppConstants.defaultMapZoom,
                ),
                onMapCreated: (controller) {
                  if (!_mapController.isCompleted) {
                    _mapController.complete(controller);
                  }
                },
                markers: markers,
                // On shift: hide the blue dot — the bus icon from DriverTrackingService
                // serves as the live position indicator.
                // Off shift: restore the blue dot so the driver can see themselves.
                myLocationEnabled: !shiftProvider.isOnShift,
                myLocationButtonEnabled: false,
              );
            },
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Consumer3<DriverShiftProvider, RouteProvider, BusProvider>(
              builder: (context, shiftProvider, routeProvider, busProvider, _) {
                final assignedBus = shiftProvider.assignedBus;
                if (assignedBus != null) {
                  _updateDynamicSpeed(assignedBus);
                }

                String nextStopName = '--';
                String etaMinutes = '--';
                if (assignedBus?.assignedRoute != null) {
                  try {
                    final currentBus = assignedBus!;
                    final route = routeProvider.routes.firstWhere(
                      (r) => r.routeId == currentBus.assignedRoute,
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

                    if (stops.isNotEmpty) {
                      int currentStopIndex = 0;
                      double minDistanceMeters = double.infinity;

                      for (int i = 0; i < stops.length; i++) {
                        final distanceMeters = Geolocator.distanceBetween(
                          currentBus.latitude,
                          currentBus.longitude,
                          stops[i].latitude,
                          stops[i].longitude,
                        );
                        if (distanceMeters < minDistanceMeters) {
                          minDistanceMeters = distanceMeters;
                          currentStopIndex = i;
                        }
                      }

                      final isAtCurrentStop = minDistanceMeters <= 80;
                      final nextStopIndex = isAtCurrentStop
                          ? (currentStopIndex + 1) % stops.length
                          : currentStopIndex;
                      final nextStop = stops[nextStopIndex];
                      final legDistances =
                          routeProvider.getRouteLegDistances(route.routeId);
                      final eta = _estimateRouteStopEtaMinutes(
                        bus: currentBus,
                        orderedStops: stops,
                        targetIndex: nextStopIndex,
                        legDistancesMeters: legDistances,
                      );
                      final displayEta = eta == null || eta <= 0 ? 1 : eta;

                      nextStopName = nextStop.stopName;
                      etaMinutes = '$displayEta min';
                    }
                  } catch (_) {}
                }

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Expanded(
                            child: _buildCompactStat(
                              icon: Icons.people,
                              label: 'Passengers',
                              value: assignedBus != null
                                  ? '${assignedBus.currentOccupancy}/${assignedBus.capacity}'
                                  : '--',
                              color: Colors.blue,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                          Expanded(
                            child: _buildCompactStat(
                              icon: Icons.flag,
                              label: 'Next Stop',
                              value: nextStopName,
                              color: Colors.green,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                          Expanded(
                            child: _buildCompactStat(
                              icon: Icons.schedule,
                              label: 'ETA',
                              value: etaMinutes,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      if (!shiftProvider.isOnShift)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.orange.withValues(alpha: 0.12)
                                : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.orange.shade200,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: Colors.orange.shade700,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Start your shift to begin tracking',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          Positioned(
            right: 8,
            bottom: 110,
            child: Material(
              elevation: 4,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _goToCurrentLocation,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.my_location,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _busProviderRef?.removeListener(_onBusProviderUpdate);
    for (final timer in _busAnimationTimers.values) {
      timer.cancel();
    }
    _busAnimationTimers.clear();
    super.dispose();
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
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  void _updateDynamicSpeed(Bus bus) {
    final currentUpdatedAt = bus.lastUpdated;

    if (_lastBusLat != null &&
        _lastBusLng != null &&
        _lastBusUpdatedAt != null &&
        currentUpdatedAt.isAfter(_lastBusUpdatedAt!)) {
      final distanceMeters = Geolocator.distanceBetween(
        _lastBusLat!,
        _lastBusLng!,
        bus.latitude,
        bus.longitude,
      );
      final elapsedSeconds =
          currentUpdatedAt.difference(_lastBusUpdatedAt!).inSeconds;

      if (elapsedSeconds > 0) {
        final rawSpeedKmH =
            (distanceMeters / elapsedSeconds) * 3.6; // m/s -> km/h

        // Ignore noisy GPS jumps and near-zero drift while idling.
        if (rawSpeedKmH >= 3 && rawSpeedKmH <= 90) {
          _smoothedSpeedKmH = _smoothedSpeedKmH == null
              ? rawSpeedKmH
              : (_smoothedSpeedKmH! * 0.7) + (rawSpeedKmH * 0.3);
        }
      }
    }

    _lastBusLat = bus.latitude;
    _lastBusLng = bus.longitude;
    _lastBusUpdatedAt = currentUpdatedAt;
  }

  int _estimateEtaMinutes(double distanceMeters) {
    final speedKmH = (_smoothedSpeedKmH ?? 25).clamp(8, 50).toDouble();
    return ((distanceMeters / 1000) / speedKmH * 60).ceil();
  }

  int? _estimateRouteStopEtaMinutes({
    required Bus bus,
    required List<BusStop> orderedStops,
    required int targetIndex,
    List<double>? legDistancesMeters,
  }) {
    if (orderedStops.isEmpty) return null;

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
      legDistancesMeters: legDistancesMeters,
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
    {List<double>? legDistancesMeters,}
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
}
