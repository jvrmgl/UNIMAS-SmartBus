import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import '../../models/bus_model.dart';
import '../../models/route_model.dart';
import '../../models/bus_stop_model.dart';
import '../../providers/bus_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/route_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/smart_notification_service.dart';
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
        debugPrint('DEBUG: Android Device ID: $_deviceId');
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _deviceId = iosInfo.identifierForVendor; // Unique device ID
        debugPrint('DEBUG: iOS Device ID: $_deviceId');
      }
      
      if (_deviceId != null) {
        await _checkTapInStatus();
      } else {
        debugPrint('DEBUG: Could not get device ID');
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      debugPrint('DEBUG: Error getting device ID: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _checkTapInStatus() async {
    if (_deviceId == null) return;
    
    try {
      final activeBusId = await _firestoreService.getDeviceActiveBusId(_deviceId!);
      debugPrint('DEBUG: Checking tap-in status');
      debugPrint('DEBUG: Active bus ID from Firestore: $activeBusId');
      debugPrint('DEBUG: Current bus ID: ${widget.bus.busId}');
      debugPrint('DEBUG: Are they equal? ${activeBusId == widget.bus.busId}');
      
      if (mounted) {
        setState(() {
          _isTappedIn = activeBusId == widget.bus.busId;
          _isLoading = false;
        });
        debugPrint('DEBUG: After setState - _isTappedIn: $_isTappedIn, _isLoading: $_isLoading');
      }
    } catch (e) {
      debugPrint('DEBUG: Error checking tap-in status: $e');
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
        title: const Text('Bus Details'),
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
                      final isBusInactive = !bus.isActive;
                      debugPrint('DEBUG: Rendering buttons - _isTappedIn: $_isTappedIn, _isUpdating: $_isUpdating, _isLoading: $_isLoading');
                      return Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isTappedIn || _isUpdating || _isLoading || isBusInactive
                                  ? null
                                  : () => _handleTapIn(bus),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isBusInactive ? Colors.grey : Colors.green,
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
                              onPressed: !_isTappedIn || _isUpdating || _isLoading || isBusInactive
                                  ? null
                                  : () => _handleTapOut(bus),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isBusInactive ? Colors.grey : Colors.red,
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

                if (!bus.isActive)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                    child: Text(
                      'This bus is inactive. Boarding is disabled.',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
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
    debugPrint('DEBUG: _handleTapIn called');
    
    if (_deviceId == null) {
      _showMessage('Could not identify device');
      return;
    }
    
    if (bus.currentOccupancy >= bus.capacity) {
      _showMessage('Bus is at full capacity');
      return;
    }

    // ── Distance warning ───────────────────────────────────────────────────
    final position = context.read<LocationProvider>().currentPosition;
    if (position != null) {
      final distKm = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            bus.latitude,
            bus.longitude,
          ) /
          1000;
      if (distKm > 1.0) {
        if (!mounted) return;
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Bus is far away'),
            content: Text(
              'This bus is ${distKm.toStringAsFixed(1)} km from your current '
              'location. Are you sure you want to board?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Board anyway'),
              ),
            ],
          ),
        );
        if (proceed != true) return;
      }
    }
    // ──────────────────────────────────────────────────────────────────────

    debugPrint('DEBUG: Setting _isUpdating to true');
    setState(() => _isUpdating = true);

    // Tap in to bus (this will check for existing sessions)
    final tapInResult = await _firestoreService.tapInToBus(_deviceId!, bus.busId);
    
    if (tapInResult != null) {
      // Error occurred
      debugPrint('DEBUG: Tap in failed: $tapInResult');
      if (mounted) {
        setState(() => _isUpdating = false);
        _showMessage(tapInResult);
      }
      return;
    }

    debugPrint('DEBUG: Tap in successful, updating bus occupancy');
    // Update bus occupancy
    final busUpdateResult = await _firestoreService.updateBusLocation(
      busId: bus.busId,
      latitude: bus.latitude,
      longitude: bus.longitude,
      currentOccupancy: bus.currentOccupancy + 1,
    );

    if (!mounted) return;

    if (busUpdateResult == null) {
      debugPrint('DEBUG: Bus update successful');
      
      // Create student trip
      debugPrint('DEBUG: Creating student trip');
      await _firestoreService.createStudentTrip(
        deviceId: _deviceId!,
        busId: bus.busId,
      );
      
      setState(() {
        _isUpdating = false;
        _isTappedIn = true;
      });
      // Student is now on the bus — cancel any waiting-at-stop record
      if (mounted) {
        context.read<SmartNotificationService>().cancelWaiting();
      }
      // Push the updated occupancy directly into BusProvider so the
      // dashboard refreshes instantly without waiting for the stream.
      if (mounted) {
        context.read<BusProvider>().updateBusInList(
          bus.copyWith(currentOccupancy: bus.currentOccupancy + 1),
        );
      }
      debugPrint('DEBUG: State updated - _isTappedIn: $_isTappedIn, _isUpdating: $_isUpdating');
      _showMessage('Tapped in successfully!');
    } else {
      debugPrint('DEBUG: Bus update failed: $busUpdateResult');
      // Rollback the tap in
      await _firestoreService.tapOutFromBus(_deviceId!);
      setState(() => _isUpdating = false);
      _showMessage('Error: $busUpdateResult');
    }
  }

  Future<void> _handleTapOut(Bus bus) async {
    debugPrint('DEBUG: _handleTapOut called');
    
    if (_deviceId == null) {
      _showMessage('Could not identify device');
      return;
    }
    
    debugPrint('DEBUG: Setting _isUpdating to true');
    setState(() => _isUpdating = true);

    // Clamp to 0 — occupancy may already be 0 if driver ended shift early
    final newOccupancy = (bus.currentOccupancy - 1).clamp(0, bus.capacity);

    debugPrint('DEBUG: Updating bus location...');
    final busUpdateResult = await _firestoreService.updateBusLocation(
      busId: bus.busId,
      latitude: bus.latitude,
      longitude: bus.longitude,
      currentOccupancy: newOccupancy,
    );

    if (!mounted) return;

    if (busUpdateResult == null) {
      debugPrint('DEBUG: Bus update successful, tapping out from session');
      final tapOutResult = await _firestoreService.tapOutFromBus(_deviceId!);

      // Treat "no active session" as success — the session may have been
      // cleared already when the driver ended their shift.
      final sessionCleared =
          tapOutResult == null || tapOutResult.contains('No active session');

      if (sessionCleared) {
        debugPrint('DEBUG: Tap out successful');
        
        // Complete student trip
        debugPrint('DEBUG: Completing student trip');
        await _firestoreService.completeStudentTrip(_deviceId!);
        
        setState(() {
          _isUpdating = false;
          _isTappedIn = false;
        });
        // Push the updated occupancy directly into BusProvider so the
        // dashboard refreshes instantly without waiting for the stream.
        if (mounted) {
          context.read<BusProvider>().updateBusInList(
            bus.copyWith(currentOccupancy: newOccupancy),
          );
        }
        debugPrint('DEBUG: State updated - _isTappedIn: $_isTappedIn, _isUpdating: $_isUpdating');
        _showMessage('Tapped out successfully!');
      } else {
        debugPrint('DEBUG: Tap out session failed: $tapOutResult');
        setState(() => _isUpdating = false);
        _showMessage('Warning: $tapOutResult');
      }
    } else {
      debugPrint('DEBUG: Bus update failed: $busUpdateResult');
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
