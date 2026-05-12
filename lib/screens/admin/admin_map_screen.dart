import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../constants/app_constants.dart';
import '../../constants/app_theme.dart';
import '../../providers/bus_provider.dart';
import '../../providers/route_provider.dart';
import '../../providers/announcement_provider.dart';
import '../../models/bus_model.dart';
import '../../models/bus_stop_model.dart';
import '../../models/route_model.dart';
import '../../models/report_model.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../utils/map_marker_helper.dart';
import '../../utils/map_style.dart';
import '../../widgets/common_widgets.dart';

class AdminMapScreen extends StatefulWidget {
  const AdminMapScreen({super.key});

  @override
  State<AdminMapScreen> createState() => _AdminMapScreenState();
}

class _AdminMapScreenState extends State<AdminMapScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final Completer<GoogleMapController> _mapController =
      Completer<GoogleMapController>();
  Set<Polyline> _highlightedPolylines = {};
  BusRoute? _selectedRoute;
  BitmapDescriptor? _busMarkerIcon;
  BitmapDescriptor? _busInactiveMarkerIcon;
  BitmapDescriptor? _stopMarkerIcon;
  late RouteProvider _routeProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _routeProvider = context.read<RouteProvider>();
      _routeProvider.addListener(_onRouteProviderUpdate);
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

  @override
  void dispose() {
    _routeProvider.removeListener(_onRouteProviderUpdate);
    context.read<BusProvider>().stopListeningToBuses();
    context.read<RouteProvider>().stopListeningToBusStops();
    super.dispose();
  }

  // Re-draw the polyline whenever RouteProvider notifies (e.g. after a stop
  // location is updated and fetchBusStops() refreshes the coordinates).
  void _onRouteProviderUpdate() {
    if (_selectedRoute != null) {
      _highlightRoute(_selectedRoute!);
    }
  }

  void _loadData() async {
    final busProvider = context.read<BusProvider>();
    final routeProvider = context.read<RouteProvider>();
    final announcementProvider = context.read<AnnouncementProvider>();

    busProvider.listenToBuses();
    routeProvider.listenToBusStops();
    await routeProvider.fetchRoutes();
    await announcementProvider.fetchAnnouncements();
  }

  // ── Animate camera to a specific bus ──────────────────────────────────────
  Future<void> _animateToBus(Bus bus) async {
    final ctrl = await _mapController.future;
    ctrl.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(bus.latitude, bus.longitude), 18),
    );
  }

  // ── Highlight a route as a polyline on the map ────────────────────────────
  Future<void> _highlightRoute(BusRoute route) async {
    _selectedRoute = route;
    final allStops = context.read<RouteProvider>().busStops;
    final stopPoints = route.stopIds
        .map((id) {
          try {
            return allStops.firstWhere((s) => s.stopId == id);
          } catch (_) {
            return null;
          }
        })
        .where((s) => s != null)
        .map((s) => LatLng(s!.latitude, s.longitude))
        .toList();
    if (stopPoints.isEmpty) return;

    // Prefer cached polyline from backend; fall back to Directions API or straight lines
    List<LatLng> points;
    if (route.routePolyline != null && route.routePolyline!.isNotEmpty) {
      points = _decodePolyline(route.routePolyline!);
      if (points.isEmpty) {
        points = stopPoints;
      }
    } else {
      try {
        points = await _fetchRoutePolyline(stopPoints);
      } catch (_) {
        points = stopPoints;
      }
    }

    if (!mounted) return;
    setState(() {
      _highlightedPolylines = {
        Polyline(
          polylineId: const PolylineId('route_highlight'),
          points: points,
          color: AppTheme.primaryColor,
          width: 5,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      };
    });

    _mapController.future.then((ctrl) {
      double minLat = stopPoints.fold(
          stopPoints.first.latitude, (m, p) => p.latitude < m ? p.latitude : m);
      double maxLat = stopPoints.fold(
          stopPoints.first.latitude, (m, p) => p.latitude > m ? p.latitude : m);
      double minLng = stopPoints.fold(
          stopPoints.first.longitude, (m, p) => p.longitude < m ? p.longitude : m);
      double maxLng = stopPoints.fold(
          stopPoints.first.longitude, (m, p) => p.longitude > m ? p.longitude : m);
      ctrl.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat - 0.005, minLng - 0.005),
            northeast: LatLng(maxLat + 0.005, maxLng + 0.005),
          ),
          60,
        ),
      );
    });
  }

  Future<List<LatLng>> _fetchRoutePolyline(List<LatLng> stopPoints) async {
    // Only attempt API call if Directions API is enabled AND API key is available.
    // If API key is not available, skip and use straight lines.
    // In production, routes should have polylines pre-cached server-side.
    if (!AppConstants.enableDirectionsApi) {
      return stopPoints;
    }
    
    if (AppConstants.googleMapsApiKey.isEmpty) {
      // API key not injected at runtime — polylines should be server-cached
      return stopPoints;
    }

    if (stopPoints.length < 2) return stopPoints;

    // Prefer a single request when within waypoint limits.
    if (stopPoints.length <= 25) {
      final points = await _fetchDirectionsPath(stopPoints);
      if (points.isNotEmpty) return points;
    }

    // Fallback: stitch per-leg polylines to avoid waypoint limits.
    final List<LatLng> stitched = [];
    for (var i = 0; i < stopPoints.length - 1; i++) {
      final segment =
          await _fetchDirectionsLeg(stopPoints[i], stopPoints[i + 1]);
      if (segment.isEmpty) {
        if (stitched.isEmpty || stitched.last != stopPoints[i]) {
          stitched.add(stopPoints[i]);
        }
        stitched.add(stopPoints[i + 1]);
        continue;
      }

      if (stitched.isNotEmpty && segment.first == stitched.last) {
        stitched.addAll(segment.skip(1));
      } else {
        stitched.addAll(segment);
      }
    }

    return stitched.isEmpty ? stopPoints : stitched;
  }

  Future<List<LatLng>> _fetchDirectionsPath(List<LatLng> stopPoints) async {
    final origin =
        '${stopPoints.first.latitude},${stopPoints.first.longitude}';
    final destination =
        '${stopPoints.last.latitude},${stopPoints.last.longitude}';
    final waypointList = stopPoints.length > 2
        ? stopPoints
            .sublist(1, stopPoints.length - 1)
            .map((p) => '${p.latitude},${p.longitude}')
            .join('|')
        : null;

    final params = <String, String>{
      'origin': origin,
      'destination': destination,
      'mode': 'driving',
      'key': AppConstants.googleMapsApiKey,
      if (waypointList != null) 'waypoints': 'optimize:false|$waypointList',
    };

    final uri =
        Uri.https('maps.googleapis.com', '/maps/api/directions/json', params);
    try {
      final response =
          await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') return [];

      final encoded =
          data['routes'][0]['overview_polyline']['points'] as String;
      return _decodePolyline(encoded);
    } catch (_) {
      return [];
    }
  }

  Future<List<LatLng>> _fetchDirectionsLeg(
    LatLng origin,
    LatLng destination,
  ) async {
    final params = <String, String>{
      'origin': '${origin.latitude},${origin.longitude}',
      'destination': '${destination.latitude},${destination.longitude}',
      'mode': 'driving',
      'key': AppConstants.googleMapsApiKey,
    };

    final uri =
        Uri.https('maps.googleapis.com', '/maps/api/directions/json', params);
    try {
      final response =
          await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') return [];

      final encoded =
          data['routes'][0]['overview_polyline']['points'] as String;
      return _decodePolyline(encoded);
    } catch (_) {
      return [];
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> points = [];
    int index = 0;
    final int len = encoded.length;
    int lat = 0, lng = 0;
    while (index < len) {
      int shift = 0, result = 0, b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
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

  // ── Bottom sheet: active buses list ───────────────────────────────────────
  void _showActiveBusesSheet() {
    final activeBuses = context
        .read<BusProvider>()
        .buses
        .where((b) => b.isActive)
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.45,
        maxChildSize: 0.85,
        minChildSize: 0.3,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  const Icon(Icons.directions_bus, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    'Active Buses (${activeBuses.length})',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (activeBuses.isEmpty)
              const Expanded(
                child: Center(
                  child: Text('No active buses',
                      style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  itemCount: activeBuses.length,
                  itemBuilder: (_, i) {
                    final bus = activeBuses[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue,
                        child: Text(
                          bus.busNumber,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text('Bus ${bus.busNumber}'),
                      subtitle: Text(
                        '${bus.currentOccupancy}/${bus.capacity} seats'
                        '${bus.driverName != null ? ' • ${bus.driverName}' : ''}',
                      ),
                      trailing:
                          const Icon(Icons.location_on, color: Colors.blue),
                      onTap: () {
                        Navigator.pop(ctx);
                        _animateToBus(bus);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Bottom sheet: routes list ─────────────────────────────────────────────
  void _showRoutesSheet() {
    final routes = context.read<RouteProvider>().routes;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.45,
        maxChildSize: 0.85,
        minChildSize: 0.3,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  const Icon(Icons.route, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    'Routes (${routes.length})',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Spacer(),
                  if (_highlightedPolylines.isNotEmpty)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _highlightedPolylines = {};
                          _selectedRoute = null;
                        });
                        Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.clear, size: 16),
                      label: const Text('Clear route'),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (routes.isEmpty)
              const Expanded(
                child: Center(
                    child: Text('No routes',
                        style: TextStyle(color: Colors.grey))),
              )
            else
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  itemCount: routes.length,
                  itemBuilder: (_, i) {
                    final route = routes[i];
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          route.routeCode,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      title: Text(route.routeName),
                      subtitle: Text('${route.stopIds.length} stops'),
                      trailing:
                          const Icon(Icons.polyline, color: Colors.green),
                      onTap: () {
                        Navigator.pop(ctx);
                        _highlightRoute(route);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showNotificationsDialog() {
    showAppNotificationsSheet(context, 'admin');
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
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text('${bus.isActive ? 'Active' : 'Inactive'} • ${bus.currentOccupancy}/${bus.capacity} seats'),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: bus.isActive ? Colors.green.shade600 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('${bus.currentOccupancy}/${bus.capacity}',
                        style: TextStyle(color: bus.isActive ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
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
                  valueColor: AlwaysStoppedAnimation<Color>(bus.isNearCapacity() ? Colors.orange : Colors.green),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).pushNamed('/admin/manage_bus', arguments: bus.busId);
                  },
                  child: const Text('Manage Bus'),
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
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text(stop.stopCode),
                      ],
                    ),
                  ),
                ],
              ),
              if (stop.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(stop.description, style: Theme.of(context).textTheme.bodyMedium),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).pushNamed('/admin/manage_route', arguments: stop.stopId);
                  },
                  child: const Text('Manage Stop'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompactStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Column(
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
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              softWrap: true,
            ),
            if (onTap != null)
              Icon(Icons.keyboard_arrow_down,
                  size: 12, color: Colors.grey[500]),
          ],
        ),
      ),
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
          Consumer2<BusProvider, RouteProvider>(
            builder: (context, busProvider, routeProvider, _) {
              final markers = _buildMarkers(busProvider, routeProvider);
              final mapStyle =
                  mapStyleForBrightness(Theme.of(context).brightness);
              return GoogleMap(
                style: mapStyle,
                initialCameraPosition: const CameraPosition(
                  target: LatLng(1.4651, 110.4277),
                  zoom: AppConstants.defaultMapZoom,
                ),
                onMapCreated: (ctrl) {
                  if (!_mapController.isCompleted) _mapController.complete(ctrl);
                },
                markers: markers,
                polylines: _highlightedPolylines,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
              );
            },
          ),
          // My Location FAB
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

                return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 16,
                          spreadRadius: 0,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildCompactStat(
                            icon: Icons.directions_bus,
                            label: 'Active Buses',
                            value: '$activeBuses/$totalBuses',
                            color: Colors.blue,
                            onTap: () => _showActiveBusesSheet(),
                          ),
                        ),
                        Expanded(
                          child: _buildCompactStat(
                            icon: Icons.route,
                            label: 'Routes',
                            value: totalRoutes.toString(),
                            color: Colors.green,
                            onTap: () => _showRoutesSheet(),
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
                  );
              },
            ),
          ),
        ],
      ),
    );
  }
}
