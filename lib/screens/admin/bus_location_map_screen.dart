import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../constants/app_constants.dart';
import '../../providers/bus_provider.dart';
import '../../providers/route_provider.dart';
import '../../models/bus_model.dart';

/// Shows a full-screen map centred on [bus], with all buses and stops visible.
class BusLocationMapScreen extends StatefulWidget {
  final Bus bus;

  const BusLocationMapScreen({super.key, required this.bus});

  @override
  State<BusLocationMapScreen> createState() => _BusLocationMapScreenState();
}

class _BusLocationMapScreenState extends State<BusLocationMapScreen> {
  final Completer<GoogleMapController> _mapController =
      Completer<GoogleMapController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BusProvider>().fetchBuses();
      context.read<RouteProvider>().fetchBusStops();
    });
  }

  Set<Marker> _buildMarkers(
      BusProvider busProvider, RouteProvider routeProvider) {
    final markers = <Marker>{};

    for (final bus in busProvider.buses) {
      final isSelected = bus.busId == widget.bus.busId;
      markers.add(Marker(
        markerId: MarkerId('bus_${bus.busId}'),
        position: LatLng(bus.latitude, bus.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          isSelected
              ? BitmapDescriptor.hueAzure
              : (bus.isActive
                  ? BitmapDescriptor.hueBlue
                  : BitmapDescriptor.hueViolet),
        ),
        infoWindow: InfoWindow(
          title: 'Bus ${bus.busNumber}${isSelected ? ' ★' : ''}',
          snippet:
              '${bus.isActive ? 'Active' : 'Inactive'} · ${bus.currentOccupancy}/${bus.capacity}',
        ),
        zIndexInt: isSelected ? 2 : 1,
      ));
    }

    for (final stop in routeProvider.busStops) {
      markers.add(Marker(
        markerId: MarkerId('stop_${stop.stopId}'),
        position: LatLng(stop.latitude, stop.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: stop.stopName,
          snippet: stop.stopCode,
        ),
      ));
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bus ${widget.bus.busNumber} — Location'),
      ),
      body: Consumer2<BusProvider, RouteProvider>(
        builder: (context, busProvider, routeProvider, _) {
          final markers = _buildMarkers(busProvider, routeProvider);
          return GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(widget.bus.latitude, widget.bus.longitude),
              zoom: AppConstants.defaultMapZoom + 2,
            ),
            onMapCreated: (ctrl) {
              if (!_mapController.isCompleted) _mapController.complete(ctrl);
            },
            markers: markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          );
        },
      ),
    );
  }
}
