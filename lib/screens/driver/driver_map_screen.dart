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
import '../../models/bus_stop_model.dart';
import '../../services/location_service.dart';
import '../../utils/map_marker_helper.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
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

    await busProvider.fetchBuses();
    await routeProvider.fetchRoutes();
    await routeProvider.fetchBusStops();
    await announcementProvider.fetchAnnouncements();
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
      markers.add(
        Marker(
          markerId: MarkerId('bus_${bus.busId}'),
          position: LatLng(bus.latitude, bus.longitude),
          infoWindow: InfoWindow(
            title: bus.busNumber,
            snippet: 'Occupancy: ${bus.currentOccupancy}/${bus.capacity}',
          ),
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
          infoWindow: InfoWindow(
            title: stop.stopName,
            snippet: 'Bus Stop',
          ),
          icon: _stopMarkerIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }

    return markers;
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
              return GoogleMap(
                initialCameraPosition: const CameraPosition(
                  target: LatLng(1.4651, 110.4277),
                  zoom: AppConstants.defaultMapZoom,
                ),
                onMapCreated: (controller) => _mapController.complete(controller),
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

                        final nextStopIndex = (currentStopIndex + 1) % stops.length;
                      final nextStop = stops[nextStopIndex];

                      final nextDistanceMeters = Geolocator.distanceBetween(
                        currentBus.latitude,
                        currentBus.longitude,
                        nextStop.latitude,
                        nextStop.longitude,
                      );

                      const estimatedSpeedKmH = 25.0;
                      final eta = ((nextDistanceMeters / 1000) / estimatedSpeedKmH * 60).ceil();

                      nextStopName = nextStop.stopName;
                      etaMinutes = '${eta <= 0 ? 1 : eta} min';
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
}
