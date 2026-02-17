import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/route_provider.dart';
import '../../models/route_model.dart';
import '../../models/bus_stop_model.dart';

class RoutesManagementScreen extends StatefulWidget {
  const RoutesManagementScreen({super.key});

  @override
  State<RoutesManagementScreen> createState() => _RoutesManagementScreenState();
}

class _RoutesManagementScreenState extends State<RoutesManagementScreen> {
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddRouteDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Route'),
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
                child: ExpansionTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      route.routeCode,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    route.routeName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('${route.stopIds.length} stops'),
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
                  children: [
                    if (stops.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'No stops assigned to this route',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      )
                    else
                      ...stops.asMap().entries.map((entry) {
                        final stopIndex = entry.key;
                        final stop = entry.value;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue,
                            radius: 16,
                            child: Text(
                              '${stopIndex + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          title: Text(stop.stopName),
                          subtitle: Text(stop.stopCode),
                          dense: true,
                        );
                      }),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddRouteDialog() {
    final formKey = GlobalKey<FormState>();
    final routeCodeController = TextEditingController();
    final routeNameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Route creation feature coming soon'),
                  ),
                );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showEditRouteDialog(BusRoute route) {
    final formKey = GlobalKey<FormState>();
    final routeCodeController = TextEditingController(text: route.routeCode);
    final routeNameController = TextEditingController(text: route.routeName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
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

  void _confirmDeleteRoute(BusRoute route) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Route'),
        content: Text('Are you sure you want to delete ${route.routeName}?'),
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

  void _showManageStopsScreen() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
                    subtitle: Text(stop.stopCode),
                  );
                },
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Add bus stop feature coming soon'),
                ),
              );
            },
            child: const Text('Add Stop'),
          ),
        ],
      ),
    );
  }
}
