import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../constants/app_constants.dart';
import '../../providers/bus_provider.dart';
import '../../providers/route_provider.dart';

class AdminMapScreen extends StatefulWidget {
  const AdminMapScreen({super.key});

  @override
  State<AdminMapScreen> createState() => _AdminMapScreenState();
}

class _AdminMapScreenState extends State<AdminMapScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() async {
    final busProvider = context.read<BusProvider>();
    final routeProvider = context.read<RouteProvider>();

    await busProvider.fetchBuses();
    await routeProvider.fetchRoutes();
    await routeProvider.fetchBusStops();
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
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueBlue,
          ),
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
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueRed,
          ),
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Map'),
        elevation: 0,
      ),
      body: Stack(
        children: [
          Consumer2<BusProvider, RouteProvider>(
            builder: (context, busProvider, routeProvider, _) {
              final markers = _buildMarkers(busProvider, routeProvider);
              return GoogleMap(
                initialCameraPosition: const CameraPosition(
                  target: LatLng(1.4651, 110.4277),
                  zoom: AppConstants.defaultMapZoom,
                ),
                markers: markers,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
              );
            },
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Consumer2<BusProvider, RouteProvider>(
              builder: (context, busProvider, routeProvider, _) {
                final activeBuses =
                    busProvider.buses.where((bus) => bus.isActive).length;
                final textStyle = Theme.of(context).textTheme.bodyMedium;
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Active buses: $activeBuses', style: textStyle),
                      Text('Routes: ${routeProvider.routes.length}', style: textStyle),
                      Text('Reports: --', style: textStyle),
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
