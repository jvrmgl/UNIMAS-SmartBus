import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/announcement_provider.dart';
import '../../providers/driver_shift_provider.dart';
import '../../providers/bus_provider.dart';
import '../../providers/route_provider.dart';
import '../../constants/app_theme.dart';
import '../../widgets/slide_button.dart';
import '../shared/route_detail_screen.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final authProvider = context.read<AuthProvider>();
      final shiftProvider = context.read<DriverShiftProvider>();
      
      // Initialize driver
      if (authProvider.currentUser != null) {
        shiftProvider.setDriverUid(authProvider.currentUser!.uid);
      }
      
      context.read<AnnouncementProvider>().fetchAnnouncements();
      context.read<BusProvider>().fetchBuses();
      context.read<RouteProvider>().fetchRoutes();
      context.read<RouteProvider>().fetchBusStops();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
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
      body: Column(
        children: [
          Consumer<AuthProvider>(
            builder: (context, authProvider, _) {
              return Container(
                padding: const EdgeInsets.all(16),
                color: AppTheme.primaryColor,
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, ${authProvider.currentUser?.fullName ?? "Driver"}!',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage your trips and bus information',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Expanded(
            child: Consumer<DriverShiftProvider>(
              builder: (context, shiftProvider, _) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Error message
                      if (shiftProvider.error != null)
                        Card(
                          color: Colors.red.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                const Icon(Icons.error, color: Colors.red),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    shiftProvider.error!,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () => shiftProvider.clearError(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      
                      // Bus Assignment Card
                      if (!shiftProvider.hasAssignedBus)
                        _buildBusSelectionCard()
                      else
                        _buildAssignedBusCard(shiftProvider),
                      
                      const SizedBox(height: 16),
                      
                      // Shift Control Card
                      if (shiftProvider.hasAssignedBus)
                        _buildShiftControlCard(shiftProvider),
                      
                      const SizedBox(height: 16),
                      
                      // Route Information
                      if (shiftProvider.hasAssignedBus && shiftProvider.assignedBus!.assignedRoute != null)
                        _buildRouteInfoCard(shiftProvider.assignedBus!.assignedRoute!),
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

  Widget _buildBusSelectionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.directions_bus, color: AppTheme.primaryColor),
                const SizedBox(width: 12),
                const Text(
                  'Select Your Bus',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('No bus assigned yet. Select a bus to start your shift.'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showBusSelectionDialog(),
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Select Bus'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignedBusCard(DriverShiftProvider shiftProvider) {
    final bus = shiftProvider.assignedBus!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.directions_bus,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bus ${bus.busNumber}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          bus.registrationNumber,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
                PopupMenuButton(
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'release',
                      child: Row(
                        children: [
                          Icon(Icons.remove_circle_outline, size: 18),
                          SizedBox(width: 8),
                          Text('Release Bus'),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'release') {
                      _confirmReleaseBus(shiftProvider);
                    }
                  },
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildBusStat('Capacity', '${bus.capacity}', Icons.event_seat),
                Column(
                  children: [
                    const Icon(Icons.people, color: Colors.blue, size: 24),
                    const SizedBox(height: 4),
                    Text(
                      '${bus.currentOccupancy}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (shiftProvider.isOnShift)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => _decrementOccupancy(shiftProvider),
                            icon: const Icon(Icons.remove_circle),
                            color: Colors.red,
                            iconSize: 28,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            onPressed: () => _incrementOccupancy(shiftProvider),
                            icon: const Icon(Icons.add_circle),
                            color: Colors.green,
                            iconSize: 28,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      )
                    else
                      Text(
                        'Passengers',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
                _buildBusStat(
                  'Status',
                  bus.isActive ? 'Active' : 'Inactive',
                  Icons.circle,
                  color: bus.isActive ? Colors.green : Colors.grey,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftControlCard(DriverShiftProvider shiftProvider) {
    return Card(
      color: shiftProvider.isOnShift ? Colors.green.shade50 : Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  shiftProvider.isOnShift ? Icons.check_circle : Icons.info,
                  color: shiftProvider.isOnShift ? Colors.green : Colors.blue,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    shiftProvider.isOnShift
                        ? 'Shift Active - GPS Tracking Enabled'
                        : 'Ready to Start Shift',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: shiftProvider.isOnShift ? Colors.green.shade900 : Colors.blue.shade900,
                    ),
                  ),
                ),
              ],
            ),
            if (shiftProvider.isOnShift)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Your location is being shared with passengers',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            SlideButton(
              text: shiftProvider.isOnShift ? 'Slide to End Shift' : 'Slide to Start Shift',
              onConfirm: () {
                if (shiftProvider.isOnShift) {
                  _endShift(shiftProvider);
                } else {
                  _startShift(shiftProvider);
                }
              },
              backgroundColor: shiftProvider.isOnShift ? Colors.red : Colors.green,
              icon: shiftProvider.isOnShift ? Icons.stop : Icons.play_arrow,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusStat(String label, String value, IconData icon, {Color? color}) {
    return Column(
      children: [
        Icon(icon, color: color ?? Colors.blue, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildRouteInfoCard(String routeId) {
    return Consumer<RouteProvider>(
      builder: (context, routeProvider, _) {
        final route = routeProvider.routes.firstWhere(
          (r) => r.routeId == routeId,
          orElse: () => routeProvider.routes.first,
        );
        
        return Card(
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RouteDetailScreen(route: route),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.route, color: AppTheme.primaryColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'My Route',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              route.routeName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.place, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${route.stopIds.length} stops',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        'Est. ${route.stopIds.length * 3} min',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Tap to view route details',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _incrementOccupancy(DriverShiftProvider shiftProvider) async {
    final bus = shiftProvider.assignedBus!;
    final newOccupancy = bus.currentOccupancy + 1;
    
    if (newOccupancy > bus.capacity) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bus is at full capacity'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    
    final busProvider = context.read<BusProvider>();
    await busProvider.updateBusOccupancy(
      busId: bus.busId,
      occupancy: newOccupancy,
    );
    await shiftProvider.refreshBusData();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Passengers: $newOccupancy'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _decrementOccupancy(DriverShiftProvider shiftProvider) async {
    final bus = shiftProvider.assignedBus!;
    final newOccupancy = (bus.currentOccupancy - 1).clamp(0, bus.capacity);
    
    final busProvider = context.read<BusProvider>();
    await busProvider.updateBusOccupancy(
      busId: bus.busId,
      occupancy: newOccupancy,
    );
    await shiftProvider.refreshBusData();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Passengers: $newOccupancy'),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _showBusSelectionDialog() {
    final authProvider = context.read<AuthProvider>();
    final shiftProvider = context.read<DriverShiftProvider>();
    final busProvider = context.read<BusProvider>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Select Your Bus'),
        content: SizedBox(
          width: double.maxFinite,
          child: busProvider.buses.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No buses available'),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: busProvider.buses.length,
                  itemBuilder: (context, index) {
                    final bus = busProvider.buses[index];
                    final isAssigned = bus.driverId != null && 
                                       bus.driverId != authProvider.currentUser?.uid;
                    return ListTile(
                      leading: Icon(
                        Icons.directions_bus,
                        color: isAssigned ? Colors.grey : Colors.blue,
                      ),
                      title: Text('Bus ${bus.busNumber}'),
                      subtitle: Text(
                        isAssigned
                            ? 'Assigned to ${bus.driverName}'
                            : bus.registrationNumber,
                      ),
                      enabled: !isAssigned,
                      onTap: isAssigned
                          ? null
                          : () async {
                              final success = await shiftProvider.selectBus(
                                bus,
                                authProvider.currentUser!.fullName,
                              );
                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext);
                              }
                              if (mounted && success) {
                                // ignore: use_build_context_synchronously
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Bus assigned successfully'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _confirmReleaseBus(DriverShiftProvider shiftProvider) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Release Bus'),
        content: const Text(
          'Are you sure you want to release this bus? You will need to select it again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await shiftProvider.releaseBus();
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Bus released'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Release'),
          ),
        ],
      ),
    );
  }

  Future<void> _startShift(DriverShiftProvider shiftProvider) async {
    final success = await shiftProvider.startShift();
    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Shift started - GPS tracking active'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _endShift(DriverShiftProvider shiftProvider) async {
    await shiftProvider.endShift();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Shift ended - GPS tracking stopped'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _showNotificationsDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
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
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
