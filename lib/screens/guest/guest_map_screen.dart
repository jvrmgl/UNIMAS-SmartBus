import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'dart:convert';

import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../../providers/bus_provider.dart';
import '../../providers/route_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/announcement_provider.dart';
import '../../models/bus_stop_model.dart';
import '../../constants/app_constants.dart';
import '../../constants/app_theme.dart';

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
  Timer? _originDebounce;
  Timer? _destinationDebounce;
  List<String> _originSuggestions = [];
  List<String> _destinationSuggestions = [];
  bool _isDetectingLocation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBusesAndStops();
    });
  }

  void _loadBusesAndStops() async {
    // Load buses and routes
    final busProvider = context.read<BusProvider>();
    final routeProvider = context.read<RouteProvider>();
    final announcementProvider = context.read<AnnouncementProvider>();

    // Trigger initial data load
    await busProvider.fetchBuses();
    await routeProvider.fetchRoutes();
    await routeProvider.fetchBusStops();
    await announcementProvider.fetchAnnouncements();
  }

  Set<Marker> _buildMarkers(
    BusProvider busProvider,
    RouteProvider routeProvider,
  ) {
    Set<Marker> markers = {};

    // Add bus markers
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

    // Add bus stop markers
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

    if (_originMarker != null) {
      markers.add(_originMarker!);
    }
    if (_destinationMarker != null) {
      markers.add(_destinationMarker!);
    }

    return markers;
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
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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

  void _showNearbyStops(double userLat, double userLon, List<BusStop> nearbyStops) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.location_on, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    'Nearby Bus Stops',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
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
                    userLat,
                    userLon,
                    stop.latitude,
                    stop.longitude,
                  );
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primaryColor,
                      child: const Icon(Icons.bus_alert, color: Colors.white, size: 20),
                    ),
                    title: Text(stop.stopName),
                    subtitle: Text('${stop.stopCode} • ${distance.toStringAsFixed(2)} km away'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.pop(context);
                      _moveCamera(LatLng(stop.latitude, stop.longitude));
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
      final routeProvider = context.read<RouteProvider>();
      
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

      // Find nearby bus stops
      final nearbyStops = _findNearbyStops(
        position.latitude,
        position.longitude,
        routeProvider.busStops,
      );

      // Show nearby stops in bottom sheet
      _showNearbyStops(position.latitude, position.longitude, nearbyStops);

      setState(() => _isDetectingLocation = false);
    } catch (e) {
      if (!mounted) return;
      _showMessage('Error: ${e.toString()}');
      setState(() => _isDetectingLocation = false);
    }
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
                if (announcementProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (announcementProvider.announcements.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No announcements'),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
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
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
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
              final hasUnread = announcementProvider.announcements.isNotEmpty;
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
          // Map
          Consumer2<BusProvider, RouteProvider>(
            builder: (context, busProvider, routeProvider, _) {
              final markers = _buildMarkers(busProvider, routeProvider);
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
                color: Colors.white,
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
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Current location (type to search)',
                      prefixIcon: const Icon(Icons.my_location),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () => _handleSearch(isOrigin: true),
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
                  const Divider(height: 1),
                  TextField(
                    controller: _destinationController,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Enter destination (e.g. Faculty of Engineering)',
                      prefixIcon: const Icon(Icons.place),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () => _handleSearch(isOrigin: false),
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
    _originController.dispose();
    _destinationController.dispose();
    _originDebounce?.cancel();
    _destinationDebounce?.cancel();
    super.dispose();
  }
}
