import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../providers/route_provider.dart';
import '../../models/route_model.dart';
import '../../models/bus_stop_model.dart';
import '../../constants/app_constants.dart';
import '../../services/firestore_service.dart';

class RoutesManagementScreen extends StatefulWidget {
  const RoutesManagementScreen({super.key});

  @override
  State<RoutesManagementScreen> createState() => _RoutesManagementScreenState();
}

class _RoutesManagementScreenState extends State<RoutesManagementScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isFabExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<RouteProvider>().fetchRoutes();
      context.read<RouteProvider>().fetchBusStops();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Routes'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.location_on),
            onPressed: () => _showManageStopsScreen(),
            tooltip: 'Manage Bus Stops',
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_isFabExpanded) ...[
            FloatingActionButton.extended(
              heroTag: 'addRouteFab',
              onPressed: () {
                setState(() => _isFabExpanded = false);
                _showAddRouteDialog();
              },
              icon: const Icon(Icons.route),
              label: const Text('Add Route'),
            ),
            const SizedBox(height: 10),
            FloatingActionButton.extended(
              heroTag: 'addBusStopFab',
              onPressed: () {
                setState(() => _isFabExpanded = false);
                _showAddBusStopMapDialog(context);
              },
              icon: const Icon(Icons.add_location_alt),
              label: const Text('Add Bus Stops'),
            ),
            const SizedBox(height: 10),
          ],
          FloatingActionButton.extended(
            heroTag: 'mainFab',
            onPressed: () {
              setState(() => _isFabExpanded = !_isFabExpanded);
            },
            icon: Icon(_isFabExpanded ? Icons.close : Icons.add),
            label: const Text('Add'),
          ),
        ],
      ),
      body: Consumer<RouteProvider>(
        builder: (context, routeProvider, _) {
          if (routeProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (routeProvider.routes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.route, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No routes available',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the + button to add a route',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: routeProvider.routes.length,
            itemBuilder: (context, index) {
              final route = routeProvider.routes[index];
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

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.route,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(
                            route.routeName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.blue, width: 0.8),
                            ),
                            child: Text(
                              route.routeCode,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.blue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text('${route.stopIds.length} stops'),
                          ],
                        ),
                      ),
                      trailing: PopupMenuButton(
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 18),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 18, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Delete', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showEditRouteDialog(route);
                          } else if (value == 'delete') {
                            _confirmDeleteRoute(route);
                          }
                        },
                      ),
                    ),
                    if (stops.isNotEmpty)
                      ExpansionTile(
                        title: const Text(
                          'View Stops',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        initiallyExpanded: false,
                        children: stops.asMap().entries.map((entry) {
                          final stopIndex = entry.key;
                          final stop = entry.value;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue.withValues(alpha: 0.2),
                              radius: 16,
                              child: Text(
                                '${stopIndex + 1}',
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(stop.stopName),
                            subtitle: Text(stop.stopCode),
                            trailing: SizedBox(
                              width: 96,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 20),
                                    tooltip: 'Edit stop',
                                    onPressed: () =>
                                        _showEditBusStopDialog(stop),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        size: 20, color: Colors.red),
                                    tooltip: 'Delete stop',
                                    onPressed: () =>
                                        _confirmDeleteBusStop(stop),
                                  ),
                                ],
                              ),
                            ),
                            dense: true,
                          );
                        }).toList(),
                      ),
                    // Action buttons row
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showAddBusesToRouteDialog(route),
                              icon: const Icon(Icons.directions_bus, size: 18),
                              label: const Text(
                                'Add Buses',
                                style: TextStyle(fontSize: 12),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showAddStopsToRouteDialog(route),
                              icon: const Icon(Icons.add_location, size: 18),
                              label: const Text(
                                'Add Stops',
                                style: TextStyle(fontSize: 12),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showAddBusesToRouteDialog(BusRoute route) async {
    final scaffoldContext = context;
    final buses = await _firestoreService.getBuses();
    if (!mounted) return;

    final selectedBusIds = buses
        .where((bus) => bus.assignedRoute == route.routeId)
        .map((bus) => bus.busId)
        .toSet();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Add Buses to Route'),
          content: SizedBox(
            width: double.maxFinite,
            child: buses.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No buses available'),
                  )
                : ListView(
                    shrinkWrap: true,
                    children: buses.map((bus) {
                      return CheckboxListTile(
                        value: selectedBusIds.contains(bus.busId),
                        title: Text('Bus ${bus.busNumber}'),
                        subtitle: Text(bus.registrationNumber),
                        onChanged: (checked) {
                          setDialogState(() {
                            if (checked == true) {
                              selectedBusIds.add(bus.busId);
                            } else {
                              selectedBusIds.remove(bus.busId);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                for (final bus in buses) {
                  final shouldAssign = selectedBusIds.contains(bus.busId);
                  final isAssignedToThisRoute = bus.assignedRoute == route.routeId;

                  if (shouldAssign && !isAssignedToThisRoute) {
                    await _firestoreService.assignRouteToBus(
                      busId: bus.busId,
                      routeId: route.routeId,
                    );
                  } else if (!shouldAssign && isAssignedToThisRoute) {
                    await _firestoreService.removeRouteFromBus(bus.busId);
                  }
                }

                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (!mounted) return;

                ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                  const SnackBar(
                    content: Text('Route bus assignments updated'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddStopsToRouteDialog(BusRoute route) {
    final scaffoldContext = context;
    final allStops = context.read<RouteProvider>().busStops;
    final selectedStopIds = route.stopIds.toSet();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Add Stops to Route'),
          content: SizedBox(
            width: double.maxFinite,
            child: allStops.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No bus stops available'),
                  )
                : ListView(
                    shrinkWrap: true,
                    children: allStops.map((stop) {
                      return CheckboxListTile(
                        value: selectedStopIds.contains(stop.stopId),
                        title: Text(stop.stopName),
                        subtitle: Text(stop.stopCode),
                        onChanged: (checked) {
                          setDialogState(() {
                            if (checked == true) {
                              selectedStopIds.add(stop.stopId);
                            } else {
                              selectedStopIds.remove(stop.stopId);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final orderedStops = allStops
                    .where((stop) => selectedStopIds.contains(stop.stopId))
                    .map((stop) => stop.stopId)
                    .toList();

                final error = await _firestoreService.updateRouteStops(
                  routeId: route.routeId,
                  stopIds: orderedStops,
                );
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (!mounted) return;

                ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                  SnackBar(
                    content: Text(error == null
                        ? 'Route stops updated'
                        : 'Error: $error'),
                    backgroundColor: error == null ? Colors.green : Colors.red,
                  ),
                );
                if (error == null) {
                  context.read<RouteProvider>().fetchRoutes();
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddRouteDialog() {
    final scaffoldContext = context;
    final formKey = GlobalKey<FormState>();
    final routeCodeController = TextEditingController();
    final routeNameController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add New Route'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: routeCodeController,
                  decoration: const InputDecoration(
                    labelText: 'Route Code',
                    hintText: 'e.g., R1',
                  ),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: routeNameController,
                  decoration: const InputDecoration(
                    labelText: 'Route Name',
                    hintText: 'e.g., Campus to City',
                  ),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Required' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final routeId = 'route${DateTime.now().millisecondsSinceEpoch}';
                final route = BusRoute(
                  routeId: routeId,
                  routeCode: routeCodeController.text.trim(),
                  routeName: routeNameController.text.trim(),
                  stopIds: const [],
                  createdAt: DateTime.now(),
                  isActive: true,
                  description: '',
                );

                final error = await _firestoreService.addRoute(route);
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (!mounted) return;

                ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                  SnackBar(
                    content: Text(error == null
                        ? 'Route created successfully'
                        : 'Error: $error'),
                    backgroundColor: error == null ? Colors.green : Colors.red,
                  ),
                );
                if (error == null) {
                  context.read<RouteProvider>().fetchRoutes();
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showEditRouteDialog(BusRoute route) {
    final scaffoldContext = context;
    final formKey = GlobalKey<FormState>();
    final routeCodeController = TextEditingController(text: route.routeCode);
    final routeNameController = TextEditingController(text: route.routeName);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Route'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: routeCodeController,
                  decoration: const InputDecoration(labelText: 'Route Code'),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: routeNameController,
                  decoration: const InputDecoration(labelText: 'Route Name'),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Required' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final updatedRoute = route.copyWith(
                  routeCode: routeCodeController.text.trim(),
                  routeName: routeNameController.text.trim(),
                );
                final error = await _firestoreService.updateRoute(updatedRoute);
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (!mounted) return;

                ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                  SnackBar(
                    content: Text(error == null
                        ? 'Route updated successfully'
                        : 'Error: $error'),
                    backgroundColor: error == null ? Colors.green : Colors.red,
                  ),
                );
                if (error == null) {
                  context.read<RouteProvider>().fetchRoutes();
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteRoute(BusRoute route) {
    final scaffoldContext = context;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Route'),
        content: Text('Are you sure you want to delete ${route.routeName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final error = await _firestoreService.deleteRoute(route.routeId);
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              if (!mounted) return;

              ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                SnackBar(
                  content: Text(error == null
                      ? 'Route deleted successfully'
                      : 'Error: $error'),
                  backgroundColor: error == null ? Colors.green : Colors.red,
                ),
              );
              if (error == null) {
                context.read<RouteProvider>().fetchRoutes();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showManageStopsScreen() {
    final scaffoldContext = context;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Manage Bus Stops'),
        content: Consumer<RouteProvider>(
          builder: (context, routeProvider, _) {
            if (routeProvider.busStops.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No bus stops available'),
              );
            }

            return SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: routeProvider.busStops.length,
                itemBuilder: (context, index) {
                  final stop = routeProvider.busStops[index];
                  return ListTile(
                    leading: const Icon(Icons.location_on),
                    title: Text(stop.stopName),
                    subtitle: Text(
                      '${stop.stopCode} • ${stop.latitude.toStringAsFixed(5)}, ${stop.longitude.toStringAsFixed(5)}',
                    ),
                    trailing: SizedBox(
                      width: 96,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            tooltip: 'Edit stop',
                            onPressed: () {
                              Navigator.pop(dialogContext);
                              _showEditBusStopDialog(stop);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete,
                                size: 20, color: Colors.red),
                            tooltip: 'Delete stop',
                            onPressed: () {
                              Navigator.pop(dialogContext);
                              _confirmDeleteBusStop(stop);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _showAddBusStopDialog(scaffoldContext);
            },
            child: const Text('Add Stop'),
          ),
        ],
      ),
    );
  }

  void _showEditBusStopDialog(BusStop stop) {
    final scaffoldContext = context;
    final formKey = GlobalKey<FormState>();
    final stopNameController = TextEditingController(text: stop.stopName);
    final stopCodeController = TextEditingController(text: stop.stopCode);
    final descriptionController = TextEditingController(text: stop.description);
    LatLng selectedLatLng = LatLng(stop.latitude, stop.longitude);

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Edit Bus Stop'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 220,
                    width: double.maxFinite,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: selectedLatLng,
                          zoom: 15,
                        ),
                        onTap: (latLng) {
                          setDialogState(() => selectedLatLng = latLng);
                        },
                        markers: {
                          Marker(
                            markerId: const MarkerId('edit_bus_stop_pin'),
                            position: selectedLatLng,
                          ),
                        },
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tap to reposition: ${selectedLatLng.latitude.toStringAsFixed(6)}, ${selectedLatLng.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: stopNameController,
                    decoration: const InputDecoration(labelText: 'Stop Name'),
                    validator: (value) =>
                        value?.trim().isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: stopCodeController,
                    decoration: const InputDecoration(labelText: 'Stop Code'),
                    validator: (value) =>
                        value?.trim().isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                final updatedStop = stop.copyWith(
                  stopName: stopNameController.text.trim(),
                  stopCode: stopCodeController.text.trim(),
                  latitude: selectedLatLng.latitude,
                  longitude: selectedLatLng.longitude,
                  description: descriptionController.text.trim(),
                );

                final error = await _firestoreService.updateBusStop(updatedStop);
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (!mounted) return;

                ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                  SnackBar(
                    content: Text(
                        error == null ? 'Bus stop updated successfully' : 'Error: $error'),
                    backgroundColor: error == null ? Colors.green : Colors.red,
                  ),
                );

                if (error == null) {
                  context.read<RouteProvider>().fetchBusStops();
                  context.read<RouteProvider>().fetchRoutes();
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteBusStop(BusStop stop) {
    final scaffoldContext = context;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Bus Stop'),
        content: Text(
          'Delete ${stop.stopName}? This will also remove it from all routes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final error = await _firestoreService.deleteBusStop(stop.stopId);
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              if (!mounted) return;

              ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                SnackBar(
                  content: Text(
                    error == null
                        ? 'Bus stop deleted successfully'
                        : 'Error: $error',
                  ),
                  backgroundColor: error == null ? Colors.green : Colors.red,
                ),
              );

              if (error == null) {
                context.read<RouteProvider>().fetchBusStops();
                context.read<RouteProvider>().fetchRoutes();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddBusStopDialog(BuildContext scaffoldContext) {
    final formKey = GlobalKey<FormState>();
    final stopNameController = TextEditingController();
    final stopCodeController = TextEditingController();
    final latitudeController = TextEditingController();
    final longitudeController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Bus Stop'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: stopNameController,
                  decoration: const InputDecoration(labelText: 'Stop Name'),
                  validator: (value) =>
                      value?.trim().isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: stopCodeController,
                  decoration: const InputDecoration(labelText: 'Stop Code'),
                  validator: (value) =>
                      value?.trim().isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: latitudeController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Latitude (optional)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: longitudeController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'Longitude (optional)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              final stopId = 'stop${DateTime.now().millisecondsSinceEpoch}';
              final stop = BusStop(
                stopId: stopId,
                stopName: stopNameController.text.trim(),
                stopCode: stopCodeController.text.trim(),
                latitude: double.tryParse(latitudeController.text.trim()) ?? 0,
                longitude: double.tryParse(longitudeController.text.trim()) ?? 0,
                description: descriptionController.text.trim(),
                createdAt: DateTime.now(),
              );

              final error = await _firestoreService.addBusStop(stop);
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              if (!mounted) return;

              ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                SnackBar(
                  content: Text(error == null
                      ? 'Bus stop added successfully'
                      : 'Error: $error'),
                  backgroundColor: error == null ? Colors.green : Colors.red,
                ),
              );
              if (error == null) {
                context.read<RouteProvider>().fetchBusStops();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showAddBusStopMapDialog(BuildContext scaffoldContext) {
    final formKey = GlobalKey<FormState>();
    final stopNameController = TextEditingController();
    final stopCodeController = TextEditingController();
    final descriptionController = TextEditingController();
    LatLng? selectedLatLng;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Add Bus Stop by Pin'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 220,
                    width: double.maxFinite,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: GoogleMap(
                        initialCameraPosition: const CameraPosition(
                          target: LatLng(1.4651, 110.4277),
                          zoom: AppConstants.defaultMapZoom,
                        ),
                        onTap: (latLng) {
                          setDialogState(() => selectedLatLng = latLng);
                        },
                        markers: {
                          if (selectedLatLng != null)
                            Marker(
                              markerId: const MarkerId('new_bus_stop_pin'),
                              position: selectedLatLng!,
                            ),
                        },
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    selectedLatLng == null
                        ? 'Tap the map to drop a bus stop pin'
                        : 'Selected: ${selectedLatLng!.latitude.toStringAsFixed(6)}, ${selectedLatLng!.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: stopNameController,
                    decoration: const InputDecoration(labelText: 'Stop Name'),
                    validator: (value) =>
                        value?.trim().isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: stopCodeController,
                    decoration: const InputDecoration(labelText: 'Stop Code'),
                    validator: (value) =>
                        value?.trim().isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                if (selectedLatLng == null) {
                  ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                    const SnackBar(
                      content: Text('Please drop a pin on the map first'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final stopId = 'stop${DateTime.now().millisecondsSinceEpoch}';
                final stop = BusStop(
                  stopId: stopId,
                  stopName: stopNameController.text.trim(),
                  stopCode: stopCodeController.text.trim(),
                  latitude: selectedLatLng!.latitude,
                  longitude: selectedLatLng!.longitude,
                  description: descriptionController.text.trim(),
                  createdAt: DateTime.now(),
                );

                final error = await _firestoreService.addBusStop(stop);
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (!mounted) return;

                ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                  SnackBar(
                    content: Text(
                        error == null ? 'Bus stop added successfully' : 'Error: $error'),
                    backgroundColor: error == null ? Colors.green : Colors.red,
                  ),
                );
                if (error == null) {
                  context.read<RouteProvider>().fetchBusStops();
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}
