import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import '../../models/bus_model.dart';
import '../../models/route_model.dart';
import '../../models/bus_stop_model.dart';
import '../../providers/route_provider.dart';
import '../../services/firestore_service.dart';
import '../../constants/app_theme.dart';
import 'dart:math' show sin, cos, sqrt, asin;

class BusDetailScreen extends StatefulWidget {
  final Bus bus;

  const BusDetailScreen({super.key, required this.bus});

  @override
  State<BusDetailScreen> createState() => _BusDetailScreenState();
}

class _BusDetailScreenState extends State<BusDetailScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isTappedIn = false;
  bool _isUpdating = false;
  bool _isLoading = true;
  String? _deviceId;

  @override
  void initState() {
    super.initState();
    _initializeDeviceId();
  }

  Future<void> _initializeDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _deviceId = androidInfo.id; // This is the Android ID
        print('DEBUG: Android Device ID: $_deviceId');
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _deviceId = iosInfo.identifierForVendor; // Unique device ID
        print('DEBUG: iOS Device ID: $_deviceId');
      }
      
      if (_deviceId != null) {
        await _checkTapInStatus();
      } else {
        print('DEBUG: Could not get device ID');
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      print('DEBUG: Error getting device ID: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _checkTapInStatus() async {
    if (_deviceId == null) return;
    
    try {
      final activeBusId = await _firestoreService.getDeviceActiveBusId(_deviceId!);
      print('DEBUG: Checking tap-in status');
      print('DEBUG: Active bus ID from Firestore: $activeBusId');
      print('DEBUG: Current bus ID: ${widget.bus.busId}');
      print('DEBUG: Are they equal? ${activeBusId == widget.bus.busId}');
      
      if (mounted) {
        setState(() {
          _isTappedIn = activeBusId == widget.bus.busId;
          _isLoading = false;
        });
        print('DEBUG: After setState - _isTappedIn: $_isTappedIn, _isLoading: $_isLoading');
      }
    } catch (e) {
      print('DEBUG: Error checking tap-in status: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bus ${widget.bus.busNumber}'),
        elevation: 0,
      ),
      body: StreamBuilder<Bus?>(
        stream: _firestoreService.getBusStream(widget.bus.busId),
        builder: (context, snapshot) {
          final bus = snapshot.data ?? widget.bus;

          return SingleChildScrollView(
            child: Column(
              children: [
                // Bus Status Header
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
                      Icon(
                        Icons.directions_bus,
                        size: 80,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Bus ${bus.busNumber}',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        bus.registrationNumber,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Occupancy Display
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${bus.currentOccupancy}',
                            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: bus.isNearCapacity() ? Colors.orange.shade700 : Colors.green.shade700,
                            ),
                          ),
                          Text(
                            ' / ${bus.capacity}',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: Theme.of(context).brightness == Brightness.dark 
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Passengers',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).brightness == Brightness.dark 
                              ? Colors.grey.shade400
                              : Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Occupancy Progress Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: LinearProgressIndicator(
                          value: bus.getOccupancyPercentage() / 100,
                          minHeight: 20,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            bus.isNearCapacity() ? Colors.orange : Colors.green,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${bus.getOccupancyPercentage().toStringAsFixed(1)}% Full',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).brightness == Brightness.dark 
                              ? Colors.white
                              : Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Tap In/Out Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Builder(
                    builder: (context) {
                      print('DEBUG: Rendering buttons - _isTappedIn: $_isTappedIn, _isUpdating: $_isUpdating, _isLoading: $_isLoading');
                      return Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isTappedIn || _isUpdating || _isLoading
                                  ? null
                                  : () => _handleTapIn(bus),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: _isUpdating
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.login),
                              label: const Text(
                                'Tap In',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: !_isTappedIn || _isUpdating || _isLoading
                                  ? null
                                  : () => _handleTapOut(bus),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: _isUpdating
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.logout),
                          label: const Text(
                            'Tap Out',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                      );
                    },
                  ),
                ),

                const SizedBox(height: 32),

                // Bus Details Cards
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bus Details',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      Consumer<RouteProvider>(
                        builder: (context, routeProvider, _) {
                          BusRoute? route;
                          if (bus.assignedRoute != null) {
                            try {
                              route = routeProvider.routes.firstWhere(
                                (r) => r.routeId == bus.assignedRoute,
                              );
                            } catch (_) {}
                          }
                          return _buildDetailCard(
                            icon: Icons.route,
                            title: 'Current Route',
                            value: route?.routeName ?? 'Not assigned',
                          );
                        },
                      ),
                      Consumer<RouteProvider>(
                        builder: (context, routeProvider, _) {
                          // Find nearest bus stop
                          String locationText = 'Unknown location';
                          if (routeProvider.busStops.isNotEmpty) {
                            double minDistance = double.infinity;
                            BusStop? nearestStop;
                            
                            for (var stop in routeProvider.busStops) {
                              final distance = _calculateDistance(
                                bus.latitude,
                                bus.longitude,
                                stop.latitude,
                                stop.longitude,
                              );
                              if (distance < minDistance) {
                                minDistance = distance;
                                nearestStop = stop;
                              }
                            }
                            
                            if (nearestStop != null) {
                              if (minDistance < 0.1) {
                                locationText = 'At ${nearestStop.stopName}';
                              } else {
                                locationText = 'Near ${nearestStop.stopName} (${minDistance.toStringAsFixed(1)}km away)';
                              }
                            }
                          }
                          
                          return _buildDetailCard(
                            icon: Icons.location_on,
                            title: 'Current Location',
                            value: locationText,
                          );
                        },
                      ),
                      _buildDetailCard(
                        icon: Icons.info,
                        title: 'Status',
                        value: bus.isActive ? 'Active' : 'Inactive',
                        valueColor: bus.isActive ? Colors.green : Colors.red,
                      ),
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

  Widget _buildDetailCard({
    required IconData icon,
    required String title,
    required String value,
    Color? valueColor,
    Widget? trailing,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppTheme.primaryColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: valueColor,
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(height: 2),
                    trailing,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleTapIn(Bus bus) async {
    print('DEBUG: _handleTapIn called');
    
    if (_deviceId == null) {
      _showMessage('Could not identify device');
      return;
    }
    
    if (bus.currentOccupancy >= bus.capacity) {
      _showMessage('Bus is at full capacity');
      return;
    }

    print('DEBUG: Setting _isUpdating to true');
    setState(() => _isUpdating = true);

    // Tap in to bus (this will check for existing sessions)
    final tapInResult = await _firestoreService.tapInToBus(_deviceId!, bus.busId);
    
    if (tapInResult != null) {
      // Error occurred
      print('DEBUG: Tap in failed: $tapInResult');
      if (mounted) {
        setState(() => _isUpdating = false);
        _showMessage(tapInResult);
      }
      return;
    }

    print('DEBUG: Tap in successful, updating bus occupancy');
    // Update bus occupancy
    final busUpdateResult = await _firestoreService.updateBusLocation(
      busId: bus.busId,
      latitude: bus.latitude,
      longitude: bus.longitude,
      currentOccupancy: bus.currentOccupancy + 1,
    );

    if (!mounted) return;

    if (busUpdateResult == null) {
      print('DEBUG: Bus update successful');
      setState(() {
        _isUpdating = false;
        _isTappedIn = true;
      });
      print('DEBUG: State updated - _isTappedIn: $_isTappedIn, _isUpdating: $_isUpdating');
      _showMessage('Tapped in successfully!');
    } else {
      print('DEBUG: Bus update failed: $busUpdateResult');
      // Rollback the tap in
      await _firestoreService.tapOutFromBus(_deviceId!);
      setState(() => _isUpdating = false);
      _showMessage('Error: $busUpdateResult');
    }
  }

  Future<void> _handleTapOut(Bus bus) async {
    print('DEBUG: _handleTapOut called');
    
    if (_deviceId == null) {
      _showMessage('Could not identify device');
      return;
    }
    
    if (bus.currentOccupancy <= 0) {
      _showMessage('Occupancy cannot be negative');
      return;
    }

    print('DEBUG: Setting _isUpdating to true');
    setState(() => _isUpdating = true);

    print('DEBUG: Updating bus location...');
    final busUpdateResult = await _firestoreService.updateBusLocation(
      busId: bus.busId,
      latitude: bus.latitude,
      longitude: bus.longitude,
      currentOccupancy: bus.currentOccupancy - 1,
    );

    if (!mounted) return;

    if (busUpdateResult == null) {
      print('DEBUG: Bus update successful, tapping out from session');
      final tapOutResult = await _firestoreService.tapOutFromBus(_deviceId!);
      
      if (tapOutResult == null) {
        print('DEBUG: Tap out successful');
        setState(() {
          _isUpdating = false;
          _isTappedIn = false;
        });
        print('DEBUG: State updated - _isTappedIn: $_isTappedIn, _isUpdating: $_isUpdating');
        _showMessage('Tapped out successfully!');
      } else {
        print('DEBUG: Tap out session failed: $tapOutResult');
        setState(() => _isUpdating = false);
        _showMessage('Warning: $tapOutResult');
      }
    } else {
      print('DEBUG: Bus update failed: $busUpdateResult');
      setState(() => _isUpdating = false);
      _showMessage('Error: $busUpdateResult');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    // Simple distance calculation using Haversine formula
    const double earthRadius = 6371; // km
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    
    final c = 2 * asin(sqrt(a));
    return earthRadius * c;
  }
  
  double _degreesToRadians(double degrees) {
    return degrees * (3.14159265359 / 180);
  }
}
