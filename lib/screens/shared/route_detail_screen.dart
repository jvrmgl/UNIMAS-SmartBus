import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/route_model.dart';
import '../../models/bus_stop_model.dart';
import '../../models/bus_model.dart';
import '../../providers/route_provider.dart';
import '../../providers/bus_provider.dart';
import '../../constants/app_theme.dart';

class RouteDetailScreen extends StatelessWidget {
  final BusRoute route;

  const RouteDetailScreen({super.key, required this.route});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(route.routeName),
        elevation: 0,
      ),
      body: Consumer2<RouteProvider, BusProvider>(
        builder: (context, routeProvider, busProvider, _) {
          // Get stops for this route
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

          // Find bus currently on this route
          Bus? currentBus;
          try {
            currentBus = busProvider.buses.firstWhere(
              (bus) => bus.assignedRoute == route.routeId,
            );
          } catch (_) {
            currentBus = null;
          }

          // Find which stop the bus is closest to
          int? currentStopIndex;
          if (currentBus != null && stops.isNotEmpty) {
            double minDistance = double.infinity;
            for (int i = 0; i < stops.length; i++) {
              final distance = _calculateDistance(
                currentBus.latitude,
                currentBus.longitude,
                stops[i].latitude,
                stops[i].longitude,
              );
              if (distance < minDistance) {
                minDistance = distance;
                currentStopIndex = i;
              }
            }
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                // Route Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          route.routeCode,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        route.routeName,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        route.description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildInfoChip(
                            context,
                            icon: Icons.location_on,
                            label: '${stops.length} Stops',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Current Bus Info
                if (currentBus != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Card(
                      color: Colors.green.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.directions_bus,
                              color: Colors.green,
                              size: 32,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Bus ${currentBus.busNumber} is on this route',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Occupancy: ${currentBus.currentOccupancy}/${currentBus.capacity}',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // Bus Stops List with Timeline
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bus Stops',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Timeline of stops
                      if (stops.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              'No stops data available',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        )
                      else
                        ...stops.asMap().entries.map((entry) {
                          final index = entry.key;
                          final stop = entry.value;
                          final isFirst = index == 0;
                          final isLast = index == stops.length - 1;
                          final isCurrent = index == currentStopIndex;

                          return _buildStopItem(
                            context,
                            stop: stop,
                            isFirst: isFirst,
                            isLast: isLast,
                            isCurrent: isCurrent,
                          );
                        }),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoChip(BuildContext context, {required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStopItem(
    BuildContext context, {
    required BusStop stop,
    required bool isFirst,
    required bool isLast,
    required bool isCurrent,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          Column(
            children: [
              // Top line
              if (!isFirst)
                Container(
                  width: 2,
                  height: 20,
                  color: isCurrent ? Colors.green : Colors.grey.shade300,
                ),
              
              // Stop indicator
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCurrent ? Colors.green : Colors.white,
                  border: Border.all(
                    color: isCurrent ? Colors.green : Colors.grey.shade400,
                    width: 3,
                  ),
                ),
                child: isCurrent
                    ? const Icon(
                        Icons.directions_bus,
                        size: 12,
                        color: Colors.white,
                      )
                    : null,
              ),
              
              // Bottom line
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: Colors.grey.shade300,
                  ),
                ),
            ],
          ),

          const SizedBox(width: 16),

          // Stop details
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Card(
                elevation: isCurrent ? 4 : 1,
                color: isCurrent ? Colors.green.shade50 : null,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              stop.stopName,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? Colors.green
                                  : AppTheme.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              stop.stopCode,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: isCurrent ? Colors.white : AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (stop.description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          stop.description,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                      if (isCurrent) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 16,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Bus is near this stop',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    // Simple Euclidean distance for approximation
    final latDiff = lat1 - lat2;
    final lonDiff = lon1 - lon2;
    return (latDiff * latDiff + lonDiff * lonDiff);
  }
}
