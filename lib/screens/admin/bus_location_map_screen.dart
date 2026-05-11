import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../constants/app_constants.dart';
import '../../providers/bus_provider.dart';
import '../../providers/route_provider.dart';
import '../../models/bus_model.dart';
import '../../models/bus_stop_model.dart';
import '../../utils/map_marker_helper.dart';
import '../../utils/map_style.dart';

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
  BitmapDescriptor? _busMarkerIcon;
  BitmapDescriptor? _busInactiveMarkerIcon;
  BitmapDescriptor? _stopMarkerIcon;

  @override
  void initState() {
    super.initState();
    _loadMarkerIcons();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BusProvider>().fetchBuses();
      context.read<RouteProvider>().fetchBusStops();
    });
  }

  Future<void> _loadMarkerIcons() async {
    final bus = await MapMarkerHelper.getBusMarker();
    final inactive = await MapMarkerHelper.getBusInactiveMarker();
    final stop = await MapMarkerHelper.getStopMarker();
    if (!mounted) return;
    setState(() {
      _busMarkerIcon = bus;
      _busInactiveMarkerIcon = inactive;
      _stopMarkerIcon = stop;
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
        icon: (bus.isActive ? _busMarkerIcon : _busInactiveMarkerIcon) ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        onTap: () {
          _showBusInfoSheet(bus);
        },
        // Removing native infoWindow to use modern bottom sheet instead
        zIndexInt: isSelected ? 2 : 1,
      ));
    }

    for (final stop in routeProvider.busStops) {
      markers.add(Marker(
        markerId: MarkerId('stop_${stop.stopId}'),
        position: LatLng(stop.latitude, stop.longitude),
        icon: _stopMarkerIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        onTap: () {
          _showStopInfoSheet(stop);
        },
      ));
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
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
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
                        Text('${bus.isActive ? 'Active' : 'Inactive'} • ${bus.currentOccupancy}/${bus.capacity} seats'),
                      ],
                    ),
                  ),
                ],
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
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
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
                        Text(stop.stopCode),
                      ],
                    ),
                  ),
                ],
              ),
              if (stop.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(stop.description, style: Theme.of(context).textTheme.bodyMedium),
              ]
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
        title: Text('Bus ${widget.bus.busNumber} — Location'),
      ),
      body: Consumer2<BusProvider, RouteProvider>(
        builder: (context, busProvider, routeProvider, _) {
          final markers = _buildMarkers(busProvider, routeProvider);
          final mapStyle =
              mapStyleForBrightness(Theme.of(context).brightness);
          return GoogleMap(
            style: mapStyle,
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
