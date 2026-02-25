import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bus_provider.dart';
import '../../providers/route_provider.dart';
import '../../models/bus_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import 'bus_location_map_screen.dart';

class BusesManagementScreen extends StatefulWidget {
  const BusesManagementScreen({super.key});

  @override
  State<BusesManagementScreen> createState() => _BusesManagementScreenState();
}

class _BusesManagementScreenState extends State<BusesManagementScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  late BusProvider _busProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _busProvider = context.read<BusProvider>();
      _busProvider.listenToBuses(); // real-time stream
      context.read<RouteProvider>().fetchRoutes();
    });
  }

  @override
  void dispose() {
    // Use the saved reference — never call context.read() inside dispose().
    _busProvider.stopListeningToBuses();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Buses'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddBusDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Bus'),
      ),
      body: Consumer<BusProvider>(
        builder: (context, busProvider, _) {
          if (busProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (busProvider.buses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_bus_filled, 
                      size: 64, 
                      color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No buses available',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the + button to add a bus',
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
            itemCount: busProvider.buses.length,
            itemBuilder: (context, index) {
              final bus = busProvider.buses[index];
              final isActive = bus.isActive;
              final statusColor = isActive ? Colors.green : Colors.grey;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.directions_bus,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(
                            'Bus ${bus.busNumber}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: statusColor, width: 0.8),
                            ),
                            child: Text(
                              isActive ? 'Active' : 'Inactive',
                              style: TextStyle(
                                fontSize: 10,
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Reg: ${bus.registrationNumber}'),
                          Text(
                              'Capacity: ${bus.capacity} • Occupancy: ${bus.currentOccupancy}'),
                          if (bus.assignedRoute != null)
                            Builder(builder: (context) {
                              final route = context
                                  .read<RouteProvider>()
                                  .routes
                                  .where((r) => r.routeId == bus.assignedRoute)
                                  .firstOrNull;
                              final routeLabel =
                                  route?.routeName ?? bus.assignedRoute!;
                              return Text('Route: $routeLabel',
                                  style: const TextStyle(color: Colors.blue));
                            }),
                          // Driver info only shown for active buses
                          if (isActive)
                            Row(
                              children: [
                                Icon(Icons.person,
                                    size: 13, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  bus.driverName != null
                                      ? 'Driver: ${bus.driverName}'
                                      : 'No driver assigned',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: bus.driverName != null
                                        ? Colors.teal
                                        : Colors.grey[500],
                                    fontStyle: bus.driverName == null
                                        ? FontStyle.italic
                                        : FontStyle.normal,
                                  ),
                                ),
                              ],
                            ),
                        ],
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
                          PopupMenuItem(
                            value: 'toggle',
                            child: Row(
                              children: [
                                Icon(
                                  bus.isActive ? Icons.block : Icons.check_circle,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(bus.isActive ? 'Deactivate' : 'Activate'),
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
                            _showEditBusDialog(bus);
                          } else if (value == 'toggle') {
                            _toggleBusStatus(bus);
                          } else if (value == 'delete') {
                            _confirmDeleteBus(bus);
                          }
                        },
                      ),
                    ),
                    // Action buttons row
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showAssignDriverDialog(bus),
                              icon: Icon(
                                bus.driverId == null ? Icons.person_add : Icons.edit,
                                size: 18,
                              ),
                              label: Text(
                                bus.driverId == null
                                    ? 'Assign Driver'
                                    : 'Change Driver',
                                style: const TextStyle(fontSize: 12),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: bus.driverId == null
                                    ? Colors.blue
                                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                                foregroundColor: bus.driverId == null
                                    ? Colors.white
                                    : Theme.of(context).colorScheme.onSurfaceVariant,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showAssignRouteDialog(bus),
                              icon: Icon(
                                bus.assignedRoute == null ? Icons.route : Icons.edit,
                                size: 18,
                              ),
                              label: Text(
                                bus.assignedRoute == null
                                    ? 'Assign Route'
                                    : 'Change Route',
                                style: const TextStyle(fontSize: 12),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: bus.assignedRoute == null
                                    ? Colors.green
                                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                                foregroundColor: bus.assignedRoute == null
                                    ? Colors.white
                                    : Theme.of(context).colorScheme.onSurfaceVariant,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    BusLocationMapScreen(bus: bus),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.indigo),
                              foregroundColor: Colors.indigo,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              minimumSize: const Size(0, 40),
                            ),
                            child: const Icon(Icons.map_outlined, size: 20),
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

  Future<void> _showAssignDriverDialog(Bus bus) async {
    final scaffoldContext = context;
    final drivers = await _firestoreService.getUsersByRole(UserRole.driver);
    if (!mounted) return;

    String? selectedDriverId = bus.driverId;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Assign Driver'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Assign a driver to Bus ${bus.busNumber}'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    value: selectedDriverId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Driver',
                      prefixIcon: Icon(Icons.person),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('No driver'),
                      ),
                      ...drivers.map(
                        (driver) => DropdownMenuItem<String?>(
                          value: driver.uid,
                          child: Text('${driver.fullName} (${driver.email})',
                              overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setDialogState(() => selectedDriverId = value);
                    },
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
                String? error;
                if (selectedDriverId == null) {
                  error = await _firestoreService.removeDriverFromBus(bus.busId);
                } else {
                  final selectedDriver = drivers.firstWhere(
                    (driver) => driver.uid == selectedDriverId,
                  );
                  error = await _firestoreService.assignDriverToBus(
                    busId: bus.busId,
                    driverId: selectedDriver.uid,
                    driverName: selectedDriver.fullName,
                  );
                }

                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (!mounted) return;

                ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                  SnackBar(
                    content: Text(error == null
                        ? 'Driver assignment updated'
                        : 'Error: $error'),
                    backgroundColor: error == null ? Colors.green : Colors.red,
                  ),
                );
                // Stream auto-refreshes — no fetchBuses() needed.
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAssignRouteDialog(Bus bus) async {
    final scaffoldContext = context;
    final routes = await _firestoreService.getRoutes();
    if (!mounted) return;

    String? selectedRouteId = bus.assignedRoute;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Assign Route'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Assign a route to Bus ${bus.busNumber}'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                value: selectedRouteId,
                decoration: const InputDecoration(
                  labelText: 'Route',
                  prefixIcon: Icon(Icons.route),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('No route'),
                  ),
                  ...routes.map(
                    (route) => DropdownMenuItem<String?>(
                      value: route.routeId,
                      child: Text('${route.routeCode} - ${route.routeName}'),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setDialogState(() => selectedRouteId = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final error = selectedRouteId == null
                    ? await _firestoreService.removeRouteFromBus(bus.busId)
                    : await _firestoreService.assignRouteToBus(
                        busId: bus.busId,
                        routeId: selectedRouteId!,
                      );

                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (!mounted) return;

                ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                  SnackBar(
                    content: Text(error == null
                        ? 'Route assignment updated'
                        : 'Error: $error'),
                    backgroundColor: error == null ? Colors.green : Colors.red,
                  ),
                );
                // Stream auto-refreshes — no fetchBuses() needed.
                if (error == null) context.read<RouteProvider>().fetchRoutes();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddBusDialog() {
    final formKey = GlobalKey<FormState>();
    final busNumberController = TextEditingController();
    final regNumberController = TextEditingController();
    final capacityController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Bus'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: busNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Bus Number',
                    hintText: 'e.g., B001',
                  ),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: regNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Registration Number',
                    hintText: 'e.g., ABC-1234',
                  ),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: capacityController,
                  decoration: const InputDecoration(
                    labelText: 'Capacity',
                    hintText: 'e.g., 40',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Required';
                    if (int.tryParse(value!) == null) return 'Must be a number';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final busId = 'bus${DateTime.now().millisecondsSinceEpoch}';
                final bus = Bus(
                  busId: busId,
                  busNumber: busNumberController.text.trim(),
                  registrationNumber: regNumberController.text.trim(),
                  capacity: int.parse(capacityController.text.trim()),
                  currentOccupancy: 0,
                  lastUpdated: DateTime.now(),
                  isActive: false, // Start inactive until manually activated
                  latitude: 0.0,
                  longitude: 0.0,
                );

                // Capture context-dependent objects before async gap
                final navigator = Navigator.of(context);
                final scaffoldMessenger = ScaffoldMessenger.of(context);

                final error = await _firestoreService.addBus(bus);
                if (!mounted) return;

                if (error == null) {
                  navigator.pop();
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(content: Text('Bus added successfully')),
                  );
                  // Stream auto-refreshes — no fetchBuses() needed.
                } else {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('Error: $error')),
                  );
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditBusDialog(Bus bus) {
    final scaffoldContext = context;
    final formKey = GlobalKey<FormState>();
    final busNumberController = TextEditingController(text: bus.busNumber);
    final regNumberController = TextEditingController(text: bus.registrationNumber);
    final capacityController = TextEditingController(text: bus.capacity.toString());

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Bus'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: busNumberController,
                  decoration: const InputDecoration(labelText: 'Bus Number'),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: regNumberController,
                  decoration: const InputDecoration(labelText: 'Registration Number'),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: capacityController,
                  decoration: const InputDecoration(labelText: 'Capacity'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Required';
                    if (int.tryParse(value!) == null) return 'Must be a number';
                    return null;
                  },
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
                final updatedBus = bus.copyWith(
                  busNumber: busNumberController.text.trim(),
                  registrationNumber: regNumberController.text.trim(),
                  capacity: int.parse(capacityController.text.trim()),
                  lastUpdated: DateTime.now(),
                );

                final error = await _firestoreService.updateBus(updatedBus);
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (!mounted) return;

                ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                  SnackBar(
                    content: Text(error == null
                        ? 'Bus updated successfully'
                        : 'Error: $error'),
                    backgroundColor: error == null ? Colors.green : Colors.red,
                  ),
                );
                // Stream auto-refreshes — no fetchBuses() needed.
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleBusStatus(Bus bus) async {
    final wasActive = bus.isActive;

    // Guard: a bus may only be activated when it has both a driver and a route.
    if (!wasActive) {
      final missing = <String>[];
      if (bus.driverId == null) missing.add('an assigned driver');
      if (bus.assignedRoute == null) missing.add('an assigned route');
      if (missing.isNotEmpty) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Cannot activate bus'),
            content: Text(
              'This bus needs ${missing.join(' and ')} before it can be '
              'activated. Please assign ${missing.length == 1 ? 'it' : 'them'} '
              'first.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
    }

    // Pass admin name so the Cloud Function can include it in the driver
    // push notification when the bus is activated.
    final adminName = context.read<AuthProvider>().currentUser?.fullName;
    final error = await _firestoreService.setBusActiveStatus(
      busId: bus.busId,
      isActive: !wasActive,
      adminName: adminName,
    );

    // Stream auto-updates the UI with the new status badge immediately.
    // Snackbar removed to avoid context lifecycle crashes during rapid rebuilds.
    if (error != null) {
      // Only show error messages — success is already visible in the UI.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _confirmDeleteBus(Bus bus) {
    final scaffoldContext = context;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Bus'),
        content: Text('Are you sure you want to delete Bus ${bus.busNumber}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final error = await _firestoreService.deleteBus(bus.busId);
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              if (!mounted) return;

              ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                SnackBar(
                  content: Text(error == null
                      ? 'Bus deleted successfully'
                      : 'Error: $error'),
                  backgroundColor: error == null ? Colors.green : Colors.red,
                ),
              );
              // Stream auto-refreshes — no fetchBuses() needed.
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
