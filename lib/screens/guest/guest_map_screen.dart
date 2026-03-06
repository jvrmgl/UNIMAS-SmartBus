import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'dart:convert';

import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/bus_provider.dart';
import '../../providers/route_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/announcement_provider.dart';
import '../../widgets/common_widgets.dart';
import '../../providers/notification_prefs_provider.dart';
import '../../providers/dashboard_nav_provider.dart';
import '../../services/smart_notification_service.dart';
import '../../models/bus_stop_model.dart';
import '../../constants/app_constants.dart';
import '../../constants/app_theme.dart';
import '../../utils/map_marker_helper.dart';
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
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  Marker? _originMarker;
  Marker? _destinationMarker;

  // Custom map marker icons (loaded asynchronously once)
  BitmapDescriptor? _busMarkerIcon;
  BitmapDescriptor? _stopMarkerIcon;
  BitmapDescriptor? _waitingStopMarkerIcon;

  LocationProvider? _locationProviderRef;
  DashboardNavProvider? _dashboardNavRef;
  Timer? _originDebounce;
  Timer? _destinationDebounce;
  List<String> _originSuggestions = [];
  List<String> _destinationSuggestions = [];
  bool _isDetectingLocation = false;

  // FocusNodes so we can detect when search bars gain/lose focus
  final FocusNode _originFocusNode = FocusNode();
  final FocusNode _destinationFocusNode = FocusNode();
  // Nearby stops shown inline in the search bars (clears once user types ≥3 chars)
  List<BusStop> _originNearbyStops = [];
  List<BusStop> _destinationNearbyStops = [];
  // Route suggestions shown when both From and To markers are placed
  List<BusRoute> _suggestedRoutes = [];

  @override
  void initState() {
    super.initState();
    _loadMarkerIcons();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBusesAndStops();
      // Auto-detect and pan to student's location on first map load.
      _detectMyLocation();
      // Listen to location updates for auto-detect waiting
      _locationProviderRef = context.read<LocationProvider>();
      _locationProviderRef!.addListener(_onLocationChanged);
      // Listen for map-focus requests from the student dashboard
      _dashboardNavRef = context.read<DashboardNavProvider>();
      _dashboardNavRef!.addListener(_onDashboardNavChange);
      // Clear nearby stop suggestions when search bars lose/gain focus.
      // On GAIN: immediately clear the *other* field's list (prevents split-second flash).
      // On LOSE: delayed clear so a suggestion tap can register before the list disappears.
      _originFocusNode.addListener(() {
        if (!mounted) return;
        if (_originFocusNode.hasFocus) {
          setState(() {
            _destinationNearbyStops = [];
            _destinationSuggestions = [];
          });
        } else {
          Future.delayed(const Duration(milliseconds: 200),
              () { if (mounted) setState(() => _originNearbyStops = []); });
        }
      });
      _destinationFocusNode.addListener(() {
        if (!mounted) return;
        if (_destinationFocusNode.hasFocus) {
          setState(() {
            _originNearbyStops = [];
            _originSuggestions = [];
          });
        } else {
          Future.delayed(const Duration(milliseconds: 200),
              () { if (mounted) setState(() => _destinationNearbyStops = []); });
        }
      });
    });
  }

  Future<void> _loadMarkerIcons() async {
    final bus  = await MapMarkerHelper.getBusMarker();
    final stop = await MapMarkerHelper.getStopMarker();
    final wait = await MapMarkerHelper.getWaitingStopMarker();
    if (mounted) {
      setState(() {
        _busMarkerIcon       = bus;
        _stopMarkerIcon      = stop;
        _waitingStopMarkerIcon = wait;
      });
    }
  }

  void _onLocationChanged() {
    if (!mounted) return;
    final pos   = _locationProviderRef?.currentPosition;
    final stops = context.read<RouteProvider>().busStops;
    final prefs = context.read<NotificationPrefsProvider>();
    if (pos != null) {
      context.read<SmartNotificationService>().onLocationUpdate(
        pos, stops, prefs.autoDetectWaiting);
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

    // Trigger initial data load for static-ish datasets.
    await routeProvider.fetchRoutes();
    await announcementProvider.fetchAnnouncements();
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
      markers.add(
        Marker(
          markerId: MarkerId('bus_${bus.busId}'),
          position: LatLng(bus.latitude, bus.longitude),
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
          ? (_waitingStopMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange))
          : (_stopMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen));
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
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.place, color: AppTheme.primaryColor),
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

  Future<LatLng?> _geocodeAddress(String address) async {
    final trimmed = address.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/geocode/json',
      {
        'address': trimmed,
        'key': AppConstants.googleMapsApiKey,
      },
    );

    final response = await http
        .get(uri)
        .timeout(const Duration(seconds: AppConstants.requestTimeoutSeconds));

    if (response.statusCode != 200) {
      return null;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['status'] != 'OK') {
      return null;
    }

    final result = (data['results'] as List).first as Map<String, dynamic>;
    final location = result['geometry']['location'] as Map<String, dynamic>;
    return LatLng(location['lat'] as double, location['lng'] as double);
  }

  Future<List<String>> _fetchSuggestions(String input) async {
    final trimmed = input.trim();
    if (trimmed.length < 3) return [];

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      {
        'input': trimmed,
        'key': AppConstants.googleMapsApiKey,
        'components': 'country:my',
        'location': '1.4655,110.3578',
        'radius': '50000',
      },
    );

    final response = await http
        .get(uri)
        .timeout(const Duration(seconds: AppConstants.requestTimeoutSeconds));

    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['status'] != 'OK') return [];

    final predictions = (data['predictions'] as List)
        .map((item) => item['description'] as String)
        .toList();

    return predictions.take(3).toList();
  }

  void _onOriginChanged(String value) {
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
      final pos = _locationProviderRef?.currentPosition;
      if (pos != null && mounted) {
        final stops = context.read<RouteProvider>().busStops;
        setState(() => _originNearbyStops =
            _findNearbyStops(pos.latitude, pos.longitude, stops));
      }
      return;
    }
    // User is typing a real location — reset stop hints, fetch address suggestions
    setState(() => _originNearbyStops = []);
    _originDebounce = Timer(const Duration(milliseconds: 350), () async {
      final suggestions = await _fetchSuggestions(value);
      if (!mounted) return;
      setState(() {
        _originSuggestions = suggestions;
      });
    });
  }

  void _onDestinationChanged(String value) {
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
      final pos = _locationProviderRef?.currentPosition;
      if (pos != null && mounted) {
        final stops = context.read<RouteProvider>().busStops;
        setState(() => _destinationNearbyStops =
            _findNearbyStops(pos.latitude, pos.longitude, stops));
      }
      return;
    }
    setState(() => _destinationNearbyStops = []);
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
    final query = isOrigin
        ? _originController.text
        : _destinationController.text;

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
    if (mounted) _updateRouteSuggestions();
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

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    // Use Geolocator's built-in distance calculation (returns meters)
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000; // Convert to km
  }
  
  List<BusStop> _findNearbyStops(double userLat, double userLon, List<BusStop> allStops) {
    final stopsWithDistance = allStops.map((stop) {
      final distance = _calculateDistance(userLat, userLon, stop.latitude, stop.longitude);
      return {'stop': stop, 'distance': distance};
    }).toList();

    stopsWithDistance.sort((a, b) => 
      (a['distance'] as double).compareTo(b['distance'] as double)
    );

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
        final dA = _calculateDistance(
            userLat, userLon, a.latitude, a.longitude);
        final dB = _calculateDistance(
            userLat, userLon, b.latitude, b.longitude);
        return dA.compareTo(dB);
      });
    return active.take(5).toList();
  }

  // Called from the “Stops Around Me” chip — tapping a stop navigates the map camera.
  void _showStopsNearMeSheet() {
    final pos = _locationProviderRef?.currentPosition;
    if (pos == null) {
      _showMessage('Location not available. Tap the detect button first.');
      return;
    }
    final allStops = context.read<RouteProvider>().busStops;
    // Show only the 3 closest stops
    final nearbyStops =
        _findNearbyStops(pos.latitude, pos.longitude, allStops).take(3).toList();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.place, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text('Stops Around Me',
                      style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
              const SizedBox(height: 16),
              if (nearbyStops.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: Text('No bus stops found nearby')),
                )
              else
                ...nearbyStops.map((stop) {
                  final distance = _calculateDistance(
                      pos.latitude, pos.longitude,
                      stop.latitude, stop.longitude);
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primaryColor,
                      child: const Icon(Icons.bus_alert,
                          color: Colors.white, size: 20),
                    ),
                    title: Text(stop.stopName),
                    subtitle: Text(
                        '${stop.stopCode} • ${distance.toStringAsFixed(2)} km away'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () async {
                      Navigator.pop(sheetCtx);
                      await _moveCamera(LatLng(stop.latitude, stop.longitude));
                      if (mounted) _showBusStopBottomSheet(stop);
                    },
                  );
                }),
            ],
          ),
        );
      },
    );
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
          _showMessage('Location permission denied');
          setState(() => _isDetectingLocation = false);
          return;
        }
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

      setState(() => _isDetectingLocation = false);
    } catch (e) {
      if (!mounted) return;
      _showMessage('Error: ${e.toString()}');
      setState(() => _isDetectingLocation = false);
    }
  }

  // ── Buses Around Me chip handler ───────────────────────────────────────────
  void _showNearbyBusesSheet() {
    final pos = _locationProviderRef?.currentPosition;
    if (pos == null) {
      _showMessage('Location not available. Tap the detect button first.');
      return;
    }
    final routeProvider = context.read<RouteProvider>();
    final nearby = _findNearestActiveBuses(
      pos.latitude,
      pos.longitude,
      context.read<BusProvider>().buses,
    );

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.directions_bus, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text('Buses Around Me',
                      style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
              const SizedBox(height: 16),
              if (nearby.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: Text('No active buses nearby')),
                )
              else
                ...nearby.map((bus) {
                  final dist = _calculateDistance(
                      pos.latitude, pos.longitude,
                      bus.latitude, bus.longitude);
                  String? routeName;
                  try {
                    if (bus.assignedRoute != null) {
                      routeName = routeProvider.routes
                          .firstWhere((r) => r.routeId == bus.assignedRoute)
                          .routeName;
                    }
                  } catch (_) {}
                  final parts = [
                    if (routeName != null) routeName,
                    '${bus.currentOccupancy}/${bus.capacity} seats',
                    '${dist.toStringAsFixed(1)} km away',
                  ];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade700,
                      child: const Icon(Icons.directions_bus,
                          color: Colors.white, size: 18),
                    ),
                    title: Text('Bus ${bus.busNumber}',
                        style:
                            const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(parts.join(' • ')),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () async {
                      Navigator.pop(sheetCtx);
                      await _moveCamera(LatLng(bus.latitude, bus.longitude));
                      if (!mounted) return;
                      _showBusInfoSheet(bus);
                    },
                  );
                }),
            ],
          ),
        );
      },
    );
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
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade700.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child:
                        Icon(Icons.directions_bus, color: Colors.blue.shade700),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: nearCap ? Colors.orange : Colors.green,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${bus.currentOccupancy}/${bus.capacity}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
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
                            color: Colors.blue,
                            fontWeight: FontWeight.w500)),
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
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => BusDetailScreen(bus: bus)));
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
            fromPos.latitude, fromPos.longitude,
            stop.latitude, stop.longitude);
        final dTo = Geolocator.distanceBetween(
            toPos.latitude, toPos.longitude,
            stop.latitude, stop.longitude);
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
              final hasUnread = announcementProvider.hasVisibleAnnouncementsFor('student');
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
              final markers = _buildMarkers(busProvider, routeProvider, smartNotif);
              return GoogleMap(
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
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                // Tapping the map background dismisses keyboard and suggestions.
                onTap: (_) {
                  FocusScope.of(context).unfocus();
                  setState(() {
                    _originNearbyStops = [];
                    _destinationNearbyStops = [];
                    _originSuggestions = [];
                    _destinationSuggestions = [];
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
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () => _handleSearch(isOrigin: true),
                      ),
                      border: InputBorder.none,
                    ),
                    onTap: () {
                      if (_originController.text.trim().length >= 3) return;
                      final pos = _locationProviderRef?.currentPosition;
                      if (pos == null) return;
                      final stops = context.read<RouteProvider>().busStops;
                      setState(() => _originNearbyStops =
                          _findNearbyStops(pos.latitude, pos.longitude, stops));
                    },
                    onChanged: _onOriginChanged,
                    onEditingComplete: () => _handleSearch(isOrigin: true),
                    onSubmitted: (_) => _handleSearch(isOrigin: true),
                  ),
                  if (_originNearbyStops.isNotEmpty &&
                      _originSuggestions.isEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding:
                              EdgeInsets.only(left: 8, top: 4, bottom: 2),
                          child: Text('Nearby stops',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey)),
                        ),
                        ..._originNearbyStops.map((stop) => ListTile(
                              dense: true,
                              leading: const Icon(Icons.place,
                                  size: 18, color: Colors.green),
                              title: Text(stop.stopName),
                              subtitle: Text(stop.stopCode),
                              onTap: () async {
                                _originController.text = stop.stopName;
                                _originFocusNode.unfocus();
                                setState(() {
                                  _originNearbyStops = [];
                                  _originSuggestions = [];
                                  _originMarker = Marker(
                                    markerId: const MarkerId('origin_search'),
                                    position: LatLng(stop.latitude, stop.longitude),
                                    infoWindow: InfoWindow(title: stop.stopName),
                                    icon: BitmapDescriptor.defaultMarkerWithHue(
                                        BitmapDescriptor.hueAzure),
                                  );
                                });
                                await _moveCamera(LatLng(stop.latitude, stop.longitude));
                                if (mounted) _updateRouteSuggestions();
                              },
                            )),
                      ],
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
                  const Divider(height: 1),
                  TextField(
                    controller: _destinationController,
                    focusNode: _destinationFocusNode,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Enter destination',
                      prefixIcon: const Icon(Icons.place),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () => _handleSearch(isOrigin: false),
                      ),
                      border: InputBorder.none,
                    ),
                    onTap: () {
                      if (_destinationController.text.trim().length >= 3) return;
                      final pos = _locationProviderRef?.currentPosition;
                      if (pos == null) return;
                      final stops = context.read<RouteProvider>().busStops;
                      setState(() => _destinationNearbyStops =
                          _findNearbyStops(pos.latitude, pos.longitude, stops));
                    },
                    onChanged: _onDestinationChanged,
                    onEditingComplete: () => _handleSearch(isOrigin: false),
                    onSubmitted: (_) => _handleSearch(isOrigin: false),
                  ),
                  if (_destinationNearbyStops.isNotEmpty &&
                      _destinationSuggestions.isEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding:
                              EdgeInsets.only(left: 8, top: 4, bottom: 2),
                          child: Text('Nearby stops',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey)),
                        ),
                        ..._destinationNearbyStops.map((stop) => ListTile(
                              dense: true,
                              leading: const Icon(Icons.place,
                                  size: 18, color: Colors.green),
                              title: Text(stop.stopName),
                              subtitle: Text(stop.stopCode),
                              onTap: () async {
                                _destinationController.text = stop.stopName;
                                _destinationFocusNode.unfocus();
                                setState(() {
                                  _destinationNearbyStops = [];
                                  _destinationSuggestions = [];
                                  _destinationMarker = Marker(
                                    markerId: const MarkerId('destination_search'),
                                    position: LatLng(stop.latitude, stop.longitude),
                                    infoWindow: InfoWindow(title: stop.stopName),
                                    icon: BitmapDescriptor.defaultMarkerWithHue(
                                        BitmapDescriptor.hueViolet),
                                  );
                                });
                                await _moveCamera(LatLng(stop.latitude, stop.longitude));
                                if (mounted) _updateRouteSuggestions();
                              },
                            )),
                      ],
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
                  Consumer3<BusProvider, RouteProvider,
                      LocationProvider>(
                    builder: (context, busProvider,
                        routeProvider, locationProvider, _) {
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
                                  onTap: _showNearbyBusesSheet,
                                  child: _statusChip(
                                    icon: Icons.directions_bus,
                                    label: pos != null
                                        ? '$nearbyBusCount Buses Around Me'
                                        : 'Buses Around Me',
                                    color: nearbyBusCount > 0
                                        ? Colors.blue
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Stops Around Me chip
                              Expanded(
                                child: GestureDetector(
                                  onTap: _showStopsNearMeSheet,
                                  child: _statusChip(
                                    icon: Icons.place,
                                    label: pos != null
                                        ? '$nearbyStopCount Stops Around Me'
                                        : 'Stops Around Me',
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                            ],
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
                              color: AppTheme.primaryColor
                                  .withValues(alpha: 0.07),
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
                                    size: 13,
                                    color: AppTheme.primaryColor),
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
    _originController.dispose();
    _destinationController.dispose();
    _originFocusNode.dispose();
    _destinationFocusNode.dispose();
    _originDebounce?.cancel();
    _destinationDebounce?.cancel();
    super.dispose();
  }
}
