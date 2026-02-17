import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/bus_provider.dart';
import '../../models/bus_model.dart';
import '../../services/firestore_service.dart';

class BusesManagementScreen extends StatefulWidget {
  const BusesManagementScreen({super.key});

  @override
  State<BusesManagementScreen> createState() => _BusesManagementScreenState();
}

class _BusesManagementScreenState extends State<BusesManagementScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<BusProvider>().fetchBuses();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Buses'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
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
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: bus.isActive ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.directions_bus,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  title: Text(
                    'Bus ${bus.busNumber}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Reg: ${bus.registrationNumber}'),
                      Text('Capacity: ${bus.capacity} • Occupancy: ${bus.currentOccupancy}'),
                      if (bus.assignedRoute != null)
                        Text('Route: ${bus.assignedRoute}',
                            style: const TextStyle(color: Colors.blue)),
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
              );
            },
          );
        },
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
                  isActive: true,
                  latitude: 0.0,
                  longitude: 0.0,
                );

                // Capture context-dependent objects before async gap
                final navigator = Navigator.of(context);
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                final busProvider = context.read<BusProvider>();

                final error = await _firestoreService.addBus(bus);
                if (!mounted) return;

                if (error == null) {
                  navigator.pop();
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(content: Text('Bus added successfully')),
                  );
                  busProvider.fetchBuses();
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
    final formKey = GlobalKey<FormState>();
    final busNumberController = TextEditingController(text: bus.busNumber);
    final regNumberController = TextEditingController(text: bus.registrationNumber);
    final capacityController = TextEditingController(text: bus.capacity.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
         ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                // Update logic would go here
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Update feature coming soon')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _toggleBusStatus(Bus bus) {
    // Toggle logic would go here
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Toggle feature coming soon')),
    );
  }

  void _confirmDeleteBus(Bus bus) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Bus'),
        content: Text('Are you sure you want to delete Bus ${bus.busNumber}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Delete feature coming soon')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
