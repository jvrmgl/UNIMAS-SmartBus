import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'dart:convert';

import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../../providers/bus_provider.dart';
import '../../providers/route_provider.dart';
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

    // Trigger initial data load
    await busProvider.fetchBuses();
    await routeProvider.fetchRoutes();
    await routeProvider.fetchBusStops();
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
    if (location == null) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UNIMAS SmartBus'),
        centerTitle: true,
        elevation: 0,
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
                    color: Colors.black.withOpacity(0.1),
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
                    decoration: const InputDecoration(
                      hintText: 'Current location (type to search)',
                      prefixIcon: Icon(Icons.my_location),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _handleSearch(isOrigin: true),
                  ),
                  const Divider(height: 1),
                  TextField(
                    controller: _destinationController,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      hintText: 'Enter destination (e.g. Faculty of Engineering)',
                      prefixIcon: Icon(Icons.place),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _handleSearch(isOrigin: false),
                  ),
                ],
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
    super.dispose();
  }
}
