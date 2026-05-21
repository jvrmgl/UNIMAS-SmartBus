import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';

import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/bus_provider.dart';
import '../../providers/route_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/announcement_provider.dart';
import '../../widgets/common_widgets.dart';
import '../../providers/notification_prefs_provider.dart';
import '../../providers/dashboard_nav_provider.dart';
import '../../services/device_service.dart';
import '../../services/firestore_service.dart';
import '../../services/smart_notification_service.dart';
import '../../models/bus_stop_model.dart';
import '../../constants/app_constants.dart';
import '../../constants/app_theme.dart';
import '../../utils/map_marker_helper.dart';
import '../../utils/map_style.dart';
import '../../models/bus_model.dart';
import '../../models/route_model.dart';
import '../shared/bus_detail_screen.dart';
import '../shared/route_detail_screen.dart';

class GuestMapScreen extends StatefulWidget {
  const GuestMapScreen({super.key});

  @override
  State<GuestMapScreen> createState() => _GuestMapScreenState();
}

class _GuestMapScreenState extends State<GuestMapScreen> {
  final Completer<GoogleMapController> _mapController =
      Completer<GoogleMapController>();
  final FirestoreService _firestoreService = FirestoreService();
  final DeviceService _deviceService = DeviceService();
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  Marker? _originMarker;
  Marker? _destinationMarker;

  // Custom map marker icons (loaded asynchronously once)
  BitmapDescriptor? _busMarkerIcon;
  BitmapDescriptor? _stopMarkerIcon;
  BitmapDescriptor? _waitingStopMarkerIcon;
  final Map<String, LatLng> _animatedBusPositions = {};
  final Map<String, Timer> _busAnimationTimers = {};
  // Adaptive animation: duration computed from distance / assumed speed
  static const int _minBusAnimationMs = 200;
  static const int _maxBusAnimationMs = 2500;
  static const double _busSpeedMps = 10.0; // meters per second (tunable)
  BusProvider? _busProviderRef;

  LocationProvider? _locationProviderRef;
  DashboardNavProvider? _dashboardNavRef;
  Timer? _originDebounce;
  Timer? _destinationDebounce;
  List<String> _originSuggestions = [];
  List<String> _destinationSuggestions = [];
  bool _isDetectingLocation = false;
  bool _hasLocationPermission = false;

  // FocusNodes so we can detect when search bars gain/lose focus
  final FocusNode _originFocusNode = FocusNode();
  final FocusNode _destinationFocusNode = FocusNode();
  // Route suggestions shown when both From and To markers are placed
  List<BusRoute> _suggestedRoutes = [];

  // Controls which inline drawer is currently open ('buses', 'stops', or '')
  String _expandedDrawer = '';

  @override
  void initState() {
    super.initState();
    _loadMarkerIcons();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _busProviderRef = context.read<BusProvider>();
      _busProviderRef!.addListener(_onBusProviderUpdate);
      _loadBusesAndStops();
      // Auto-detect and pan to student's location on first map load.
      _detectMyLocation();
      // Listen to location updates for auto-detect waiting
      _locationProviderRef = context.read<LocationProvider>();
      _locationProviderRef!.addListener(_onLocationChanged);
      // Listen for map-focus requests from the student dashboard
      _dashboardNavRef = context.read<DashboardNavProvider>();
      _dashboardNavRef!.addListener(_onDashboardNavChange);
      
      _originFocusNode.addListener(() {
        if (!mounted) return;
        if (_originFocusNode.hasFocus) {
          setState(() {
            _destinationSuggestions = [];
          });
        }
      });
      _destinationFocusNode.addListener(() {
        if (!mounted) return;
        if (_destinationFocusNode.hasFocus) {
          setState(() {
            _originSuggestions = [];
          });
        }
      });
    });
  }

  Future<void> _loadMarkerIcons() async {
    final bus = await MapMarkerHelper.getBusMarker();
    final stop = await MapMarkerHelper.getStopMarker();
    final wait = await MapMarkerHelper.getWaitingStopMarker();
    if (mounted) {
      setState(() {
        _busMarkerIcon = bus;
        _stopMarkerIcon = stop;
        _waitingStopMarkerIcon = wait;
      });
    }
  }

  void _onLocationChanged() {
    if (!mounted) return;
    final pos = _locationProviderRef?.currentPosition;
    final stops = context.read<RouteProvider>().busStops;
    final prefs = context.read<NotificationPrefsProvider>();
    if (pos != null) {
      context
          .read<SmartNotificationService>()
          .onLocationUpdate(pos, stops, prefs.autoDetectWaiting);
    }
  }

  void _onDashboardNavChange() async {
    if (!mounted) return;
    final nav = _dashboardNavRef;
    if (nav == null) return;
    final lat = nav.pendingMapLatitude;
    final lng = nav.pendingMapLongitude;
    if (lat != null && lng != null) {
      nav.consumeMapFocus();
      final ctrl = await _mapController.future;
      if (mounted) {
        ctrl.animateCamera(CameraUpdate.newLatLngZoom(LatLng(lat, lng), 18));
      }
    }
  }

  void _loadBusesAndStops() async {
    // Load buses and routes
    final busProvider = context.read<BusProvider>();
    final routeProvider = context.read<RouteProvider>();
    final announcementProvider = context.read<AnnouncementProvider>();

    // Keep buses and stops live so chips/sheets update without manual refresh.
    busProvider.listenToBuses();
    routeProvider.listenToBusStops();

    // Trigger initial data load for static-ish datasets in parallel.
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
  // Server caches for observed-speed calculation
  final Map<String, LatLng> _lastServerPositions = {};
  final Map<String, DateTime> _lastServerTimestamps = {};
  final Map<String, double> _smoothedSpeeds = {};

  void _animateBusMarker(Bus bus) {
    final busId = bus.busId;
    final target = LatLng(bus.latitude, bus.longitude);
    final start = _animatedBusPositions[busId];
    if (start == null) {
      _animatedBusPositions[busId] = target;
      if (mounted) {
        setState(() {});
      }
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
    const double teleportThresholdMeters = 1000.0;
    if (distanceMeters > teleportThresholdMeters) {
      _animatedBusPositions[busId] = target;
      _lastServerPositions[busId] = target;
      _lastServerTimestamps[busId] = bus.lastUpdated;
      if (mounted) setState(() {});
      return;
    }

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
        observedSpeed = serverDeltaMeters / deltaSecs;
        if (observedSpeed < 0.5 || observedSpeed > 40.0) observedSpeed = null;
      }
    }

    double useSpeed = _busSpeedMps;
    if (observedSpeed != null) {
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
        if (mounted) {
          setState(() {});
        }
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

  Set<Marker> _buildMarkers(
    BusProvider busProvider,
    RouteProvider routeProvider,
    SmartNotificationService smartNotif,
  ) {
    Set<Marker> markers = {};

    // Bus markers — active buses only (inactive buses are hidden from students/guests)
    for (var bus in busProvider.buses) {
      if (!bus.isActive) continue;
      final position =
          _animatedBusPositions[bus.busId] ?? LatLng(bus.latitude, bus.longitude);
      markers.add(
        Marker(
          markerId: MarkerId('bus_${bus.busId}'),
          position: position,
          icon: _busMarkerIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          onTap: () => _showBusInfoSheet(bus),
        ),
      );
    }

    // Bus-stop markers — highlighted orange if the student is waiting there
    for (var stop in routeProvider.busStops) {
      final isWaitingHere = smartNotif.waitingStopId == stop.stopId;
      final icon = isWaitingHere
          ? (_waitingStopMarkerIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange))
          : (_stopMarkerIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen));
      markers.add(
        Marker(
          markerId: MarkerId('stop_${stop.stopId}'),
          position: LatLng(stop.latitude, stop.longitude),
          icon: icon,
          // Custom bottom sheet instead of default info-window
          onTap: () => _showBusStopBottomSheet(stop),
        ),
      );
    }

    if (_originMarker != null) markers.add(_originMarker!);
    if (_destinationMarker != null) markers.add(_destinationMarker!);

    return markers;
  }

  // ── Launch external navigation app to a bus stop ──────────────────────────
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

  void _showBusStopBottomSheet(BusStop stop) {
    showModalBottomSheet(
      context: context,
      barrierColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
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
                        Text(
                          stop.stopName,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          stop.stopCode,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (stop.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(stop.description,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _guideMeThere(stop);
                  },
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
            ],
          ),
        );
      },
    );
  }

  Widget _buildBusesInlineList(
      BusProvider busProvider, RouteProvider routeProvider, Position pos) {
    final activeBuses = _findNearestActiveBuses(pos.latitude, pos.longitude, busProvider.buses);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (activeBuses.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Text('No active buses found nearby.', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.only(top: 8),
      itemCount: activeBuses.length,
      itemBuilder: (context, index) {
        final bus = activeBuses[index];
        String routeName = 'No Route';
        if (bus.assignedRoute != null) {
          try {
            final route = routeProvider.routes.firstWhere((r) => r.routeId == bus.assignedRoute);
            routeName = route.routeName;
          } catch (_) {}
        }
        final distance = _calculateDistance(pos.latitude, pos.longitude, bus.latitude, bus.longitude);

        return Card(
          elevation: 0,
          color: isDark ? const Color(0xFF1E293B) : Colors.blue.shade50,
          margin: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isDark ? BorderSide(color: Colors.blue.shade900, width: 1) : BorderSide.none,
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.directions_bus, color: isDark ? Colors.blue.shade300 : Colors.blue.shade700, size: 20),
            ),
            title: Text('Bus ${bus.busNumber}', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            subtitle: Text('$routeName • ${distance.toStringAsFixed(2)} km away', style: TextStyle(color: isDark ? Colors.blue.shade200 : Colors.blue.shade800, fontSize: 12)),
            trailing: Icon(Icons.chevron_right, color: isDark ? Colors.grey.shade400 : Colors.grey, size: 20),
            onTap: () {
              FocusScope.of(context).unfocus();
              setState(() => _expandedDrawer = '');
              _moveCamera(LatLng(bus.latitude, bus.longitude));
              _showBusInfoSheet(bus);
            },
          ),
        );
      },
    );
  }

  Widget _buildStopsInlineList(RouteProvider routeProvider, Position pos) {
    final nearbyStops = _findNearbyStops(pos.latitude, pos.longitude, routeProvider.busStops).take(4).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (nearbyStops.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Text('No bus stops found near you.', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.only(top: 8),
      itemCount: nearbyStops.length,
      itemBuilder: (context, index) {
        final stop = nearbyStops[index];
        final distance = _calculateDistance(pos.latitude, pos.longitude, stop.latitude, stop.longitude);

        return Card(
          elevation: 0,
          color: isDark ? const Color(0xFF14532D).withValues(alpha: 0.3) : Colors.green.shade50,
          margin: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isDark ? BorderSide(color: Colors.green.shade900, width: 1) : BorderSide.none,
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? Colors.green.withValues(alpha: 0.2) : Colors.green.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.place, color: isDark ? Colors.green.shade300 : Colors.green.shade700, size: 20),
            ),
            title: Text(stop.stopName, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            subtitle: Text('${stop.stopCode} • ${distance.toStringAsFixed(2)} km away', style: TextStyle(color: isDark ? Colors.green.shade200 : Colors.green.shade800, fontSize: 12)),
            trailing: Icon(Icons.chevron_right, color: isDark ? Colors.grey.shade400 : Colors.grey, size: 20),
            onTap: () {
              FocusScope.of(context).unfocus();
              setState(() => _expandedDrawer = '');
              _moveCamera(LatLng(stop.latitude, stop.longitude));
              _showBusStopBottomSheet(stop);
            },
          ),
        );
      },
    );
  }

  Future<LatLng?> _geocodeAddress(String address) async {
    if (!AppConstants.enableGeocodingApi) {
      return null;
    }

    final trimmed = address.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final location = await _firestoreService.searchPlaceCoordinates(trimmed);
    if (location == null) return null;

    final latitude = location['latitude'];
    final longitude = location['longitude'];
    if (latitude == null || longitude == null) return null;

    return LatLng(latitude, longitude);
  }

  Future<List<String>> _fetchSuggestions(String input) async {
    if (!AppConstants.enablePlacesAutocompleteApi) {
      return [];
    }

    final trimmed = input.trim();
    if (trimmed.length < 3) return [];

    return _firestoreService.fetchPlaceAutocompleteSuggestions(
      trimmed,
      limit: 3,
    );
  }

  void _onOriginChanged(String value) {
    setState(() {}); // Update the clear button visibility
    _originDebounce?.cancel();
    if (value.trim().length < 3) {
      // Text too short — show nearby stops instead of address suggestions
      setState(() {
        _originSuggestions = [];
        // Clear the marker (and route suggestions) when the field is emptied.
        if (value.trim().isEmpty) {
          _originMarker = null;
          _suggestedRoutes = [];
        }
      });
      return;
    }
    // User is typing a real location — reset stop hints, fetch address suggestions
    _originDebounce = Timer(const Duration(milliseconds: 350), () async {
      final suggestions = await _fetchSuggestions(value);
      if (!mounted) return;
      setState(() {
        _originSuggestions = suggestions;
      });
    });
  }

  void _onDestinationChanged(String value) {
    setState(() {}); // Update the clear button visibility
    _destinationDebounce?.cancel();
    if (value.trim().length < 3) {
      setState(() {
        _destinationSuggestions = [];
        // Clear the marker (and route suggestions) when the field is emptied.
        if (value.trim().isEmpty) {
          _destinationMarker = null;
          _suggestedRoutes = [];
        }
      });
      return;
    }
    _destinationDebounce = Timer(const Duration(milliseconds: 350), () async {
      final suggestions = await _fetchSuggestions(value);
      if (!mounted) return;
      setState(() {
        _destinationSuggestions = suggestions;
      });
    });
  }

  Future<void> _moveCamera(LatLng target) async {
    if (!_mapController.isCompleted) {
      return;
    }
    final controller = await _mapController.future;
    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(target, AppConstants.defaultMapZoom),
    );
  }

  Future<void> _handleSearch({required bool isOrigin}) async {
    if (!AppConstants.enableGeocodingApi) {
      _showMessage('Search is temporarily disabled to reduce map costs.');
      return;
    }

    final query =
        isOrigin ? _originController.text : _destinationController.text;

    final location = await _geocodeAddress(query);
    if (!mounted) return;

    if (location == null) {
      _showMessage('Location not found. Try a more specific name.');
      return;
    }

    setState(() {
      if (isOrigin) {
        _originMarker = Marker(
          markerId: const MarkerId('origin_search'),
          position: location,
          infoWindow: const InfoWindow(title: 'Current Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        );
      } else {
        _destinationMarker = Marker(
          markerId: const MarkerId('destination_search'),
          position: location,
          infoWindow: const InfoWindow(title: 'Destination'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueViolet,
          ),
        );
      }
    });

    await _moveCamera(location);
    if (mounted) {
      _updateRouteSuggestions();
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _statusChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    // Use Geolocator's built-in distance calculation (returns meters)
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) /
        1000; // Convert to km
  }

  List<BusStop> _findNearbyStops(
      double userLat, double userLon, List<BusStop> allStops) {
    final stopsWithDistance = allStops.map((stop) {
      final distance =
          _calculateDistance(userLat, userLon, stop.latitude, stop.longitude);
      return {'stop': stop, 'distance': distance};
    }).toList();

    stopsWithDistance.sort(
        (a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

    return stopsWithDistance
        .take(5)
        .map((item) => item['stop'] as BusStop)
        .toList();
  }

  List<Bus> _findNearestActiveBuses(
    double userLat,
    double userLon,
    List<Bus> allBuses,
  ) {
    final active = allBuses.where((b) => b.isActive).toList()
      ..sort((a, b) {
        final dA =
            _calculateDistance(userLat, userLon, a.latitude, a.longitude);
        final dB =
            _calculateDistance(userLat, userLon, b.latitude, b.longitude);
        return dA.compareTo(dB);
      });
    return active.take(5).toList();
  }



  Future<void> _detectMyLocation() async {
    setState(() => _isDetectingLocation = true);

    try {
      // Read providers before any async operations
      final locationProvider = context.read<LocationProvider>();

      // Check and request permission if needed
      final hasPermission = await locationProvider.checkLocationPermission();
      if (!mounted) return;

      if (!hasPermission) {
        final granted = await locationProvider.requestLocationPermission();
        if (!mounted) return;

        if (!granted) {
          setState(() => _hasLocationPermission = false);
          _showMessage('Location permission denied');
          setState(() => _isDetectingLocation = false);
          return;
        }
        setState(() => _hasLocationPermission = true);
      } else {
        setState(() => _hasLocationPermission = true);
      }

      // Get current location
      await locationProvider.getCurrentLocation();
      if (!mounted) return;

      final position = locationProvider.currentPosition;

      if (position == null) {
        _showMessage('Could not get your location');
        setState(() => _isDetectingLocation = false);
        return;
      }

      // Move camera to user location
      final userLocation = LatLng(position.latitude, position.longitude);
      await _moveCamera(userLocation);
      if (!mounted) return;

      setState(() {
        _isDetectingLocation = false;
        _originController.text = 'Current Location';
        _originMarker = Marker(
          markerId: const MarkerId('origin_search'),
          position: userLocation,
          infoWindow: const InfoWindow(title: 'Current Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        );
      });
      _updateRouteSuggestions();
    } catch (e) {
      if (!mounted) return;
      _showMessage('Error: ${e.toString()}');
      setState(() => _isDetectingLocation = false);
    }
  }

  // ── Bus info sheet (shown after camera navigates to a bus) ─────────────────
  void _showBusInfoSheet(Bus bus) {
    final routeProvider = context.read<RouteProvider>();
    String? routeName;
    try {
      if (bus.assignedRoute != null) {
        routeName = routeProvider.routes
            .firstWhere((r) => r.routeId == bus.assignedRoute)
            .routeName;
      }
    } catch (_) {}
    final pct = bus.getOccupancyPercentage();
    final nearCap = bus.isNearCapacity();

    showModalBottomSheet(
      context: context,
      barrierColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
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
                        Text(bus.registrationNumber,
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: nearCap ? Colors.orange : Colors.green,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${bus.currentOccupancy}/${bus.capacity}',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              if (routeName != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.route, size: 16, color: Colors.blue),
                    const SizedBox(width: 6),
                    Text(routeName,
                        style: const TextStyle(
                            color: Colors.blue, fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct / 100,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      nearCap ? Colors.orange : Colors.green),
                ),
              ),
              const SizedBox(height: 4),
              Text('${pct.toStringAsFixed(0)}% full',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.info_outline),
                  label: const Text('Bus Details'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.pop(sheetCtx);
                    _openBusDetailsGuarded(bus);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Compute route suggestions after both From and To markers are placed ─────
  void _updateRouteSuggestions() {
    if (_originMarker == null || _destinationMarker == null) {
      if (_suggestedRoutes.isNotEmpty) setState(() => _suggestedRoutes = []);
      return;
    }
    final routeProvider = context.read<RouteProvider>();
    final allStops = routeProvider.busStops;
    final fromPos = _originMarker!.position;
    final toPos = _destinationMarker!.position;

    final scored = <BusRoute, double>{};
    for (final route in routeProvider.routes) {
      final stops = route.stopIds
          .map((id) {
            try {
              return allStops.firstWhere((s) => s.stopId == id);
            } catch (_) {
              return null;
            }
          })
          .where((s) => s != null)
          .cast<BusStop>()
          .toList();
      if (stops.isEmpty) continue;
      double minFrom = double.infinity;
      double minTo = double.infinity;
      for (final stop in stops) {
        final dFrom = Geolocator.distanceBetween(
            fromPos.latitude, fromPos.longitude, stop.latitude, stop.longitude);
        final dTo = Geolocator.distanceBetween(
            toPos.latitude, toPos.longitude, stop.latitude, stop.longitude);
        if (dFrom < minFrom) minFrom = dFrom;
        if (dTo < minTo) minTo = dTo;
      }
      scored[route] = minFrom + minTo;
    }

    final sorted = scored.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    setState(() {
      _suggestedRoutes = sorted.take(3).map((e) => e.key).toList();
    });
  }

  void _showNotificationsDialog() {
    showAppNotificationsSheet(context, 'student');
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UNIMAS SmartBus'),
        centerTitle: true,
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
      body: Stack(
        children: [
          // Map
          Consumer3<BusProvider, RouteProvider, SmartNotificationService>(
            builder: (context, busProvider, routeProvider, smartNotif, _) {
              final markers =
                  _buildMarkers(busProvider, routeProvider, smartNotif);
              final mapStyle =
                  mapStyleForBrightness(Theme.of(context).brightness);
              return GoogleMap(
                style: mapStyle,
                onMapCreated: (controller) {
                  if (!_mapController.isCompleted) {
                    _mapController.complete(controller);
                  }
                },
                initialCameraPosition: const CameraPosition(
                  target: LatLng(1.4651, 110.4277), // UNIMAS, Kota Samarahan
                  zoom: AppConstants.defaultMapZoom,
                ),
                markers: markers,
                myLocationEnabled: _hasLocationPermission,
                myLocationButtonEnabled: _hasLocationPermission,
                // Tapping the map background dismisses keyboard and suggestions.
                onTap: (_) {
                  FocusScope.of(context).unfocus();
                  setState(() {
                    _originSuggestions = [];
                    _destinationSuggestions = [];
                    _expandedDrawer = '';
                  });
                },
              );
            },
          ),

          // Search fields at the top
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _originController,
                    focusNode: _originFocusNode,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Current location',
                      prefixIcon: const Icon(Icons.my_location),
                      suffixIcon: _originController.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _originController.clear();
                                _onOriginChanged('');
                              },
                            ),
                      border: InputBorder.none,
                    ),
                    onChanged: _onOriginChanged,
                    onEditingComplete: () => _handleSearch(isOrigin: true),
                    onSubmitted: (_) => _handleSearch(isOrigin: true),
                  ),
                  if (_originSuggestions.isNotEmpty)
                    Column(
                      children: _originSuggestions
                          .map(
                            (suggestion) => ListTile(
                              dense: true,
                              title: Text(suggestion),
                              onTap: () {
                                _originController.text = suggestion;
                                setState(() => _originSuggestions = []);
                                _handleSearch(isOrigin: true);
                              },
                            ),
                          )
                          .toList(),
                    ),
                  const Divider(height: 16, thickness: 1),
                  TextField(
                    controller: _destinationController,
                    focusNode: _destinationFocusNode,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Enter destination',
                      prefixIcon: const Icon(Icons.place),
                      suffixIcon: _destinationController.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _destinationController.clear();
                                _onDestinationChanged('');
                              },
                            ),
                      border: InputBorder.none,
                    ),
                    onChanged: _onDestinationChanged,
                    onEditingComplete: () => _handleSearch(isOrigin: false),
                    onSubmitted: (_) => _handleSearch(isOrigin: false),
                  ),
                  if (_destinationSuggestions.isNotEmpty)
                    Column(
                      children: _destinationSuggestions
                          .map(
                            (suggestion) => ListTile(
                              dense: true,
                              title: Text(suggestion),
                              onTap: () {
                                _destinationController.text = suggestion;
                                setState(() => _destinationSuggestions = []);
                                _handleSearch(isOrigin: false);
                              },
                            ),
                          )
                          .toList(),
                    ),

                  // ── Live status strip ──────────────────────────────────
                  Consumer3<BusProvider, RouteProvider, LocationProvider>(
                    builder: (context, busProvider, routeProvider,
                        locationProvider, _) {
                      final pos = locationProvider.currentPosition;

                      // Keep chip count consistent with the bottom sheet list.
                      final nearbyBusCount = pos == null
                          ? 0
                          : _findNearestActiveBuses(
                              pos.latitude,
                              pos.longitude,
                              busProvider.buses,
                            ).length;

                      // Keep chip count consistent with the bottom sheet list.
                      final nearbyStopCount = pos == null
                          ? 0
                          : _findNearbyStops(
                              pos.latitude,
                              pos.longitude,
                              routeProvider.busStops,
                            ).take(3).length;

                      return Column(
                        children: [
                          const Divider(height: 12, thickness: 0.8),
                          Row(
                            children: [
                              // Buses Around Me chip
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    final pos = locationProvider.currentPosition;
                                    if (pos == null) {
                                      _showMessage('Location not available. Tap the detect button first.');
                                      return;
                                    }
                                    setState(() {
                                      _expandedDrawer = _expandedDrawer == 'buses' ? '' : 'buses';
                                    });
                                  },
                                  child: _statusChip(
                                    icon: Icons.directions_bus,
                                    label: pos != null
                                        ? '$nearbyBusCount Buses Around Me'
                                        : 'Buses Around Me',
                                    color: _expandedDrawer == 'buses'
                                        ? Colors.blue.shade700
                                        : (nearbyBusCount > 0 ? Colors.blue : Colors.grey),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Stops Around Me chip
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    final pos = locationProvider.currentPosition;
                                    if (pos == null) {
                                      _showMessage('Location not available. Tap the detect button first.');
                                      return;
                                    }
                                    setState(() {
                                      _expandedDrawer = _expandedDrawer == 'stops' ? '' : 'stops';
                                    });
                                  },
                                  child: _statusChip(
                                    icon: Icons.place,
                                    label: pos != null
                                        ? '$nearbyStopCount Stops Around Me'
                                        : 'Stops Around Me',
                                    color: _expandedDrawer == 'stops'
                                        ? Colors.green.shade700
                                        : Colors.green,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            child: _expandedDrawer.isEmpty
                                ? const SizedBox.shrink()
                                : Container(
                                    margin: const EdgeInsets.only(top: 8),
                                    constraints: BoxConstraints(
                                      maxHeight: MediaQuery.of(context).size.height * 0.4, // Limits max height to not overflow
                                    ),
                                    child: _expandedDrawer == 'buses'
                                        ? _buildBusesInlineList(busProvider, routeProvider, pos!)
                                        : _buildStopsInlineList(routeProvider, pos!),
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
                  // ── Suggested routes when both From and To are set ─────────
                  if (_suggestedRoutes.isNotEmpty) ...[
                    const Divider(height: 12),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(Icons.route,
                              size: 14, color: AppTheme.primaryColor),
                          const SizedBox(width: 6),
                          Text('Suggested routes',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryColor)),
                        ],
                      ),
                    ),
                    ..._suggestedRoutes.map((route) => InkWell(
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      RouteDetailScreen(route: route))),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.primaryColor.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: AppTheme.primaryColor
                                      .withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(route.routeCode,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(route.routeName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w500),
                                      overflow: TextOverflow.ellipsis),
                                ),
                                Icon(Icons.arrow_forward_ios,
                                    size: 13, color: AppTheme.primaryColor),
                              ],
                            ),
                          ),
                        )),
                  ],
                ],
              ),
            ),
          ),

          // Location detection button
          Positioned(
            right: 8,
            bottom: 110,
            child: Material(
              elevation: 4,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _isDetectingLocation ? null : _detectMyLocation,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _isDetectingLocation
                        ? Colors.grey
                        : AppTheme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: _isDetectingLocation
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
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
    _locationProviderRef?.removeListener(_onLocationChanged);
    _dashboardNavRef?.removeListener(_onDashboardNavChange);
    _busProviderRef?.removeListener(_onBusProviderUpdate);
    for (final timer in _busAnimationTimers.values) {
      timer.cancel();
    }
    _busAnimationTimers.clear();
    _originController.dispose();
    _destinationController.dispose();
    _originFocusNode.dispose();
    _destinationFocusNode.dispose();
    _originDebounce?.cancel();
    _destinationDebounce?.cancel();
    super.dispose();
  }
}
