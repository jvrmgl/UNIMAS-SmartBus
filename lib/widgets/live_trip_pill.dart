import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../models/bus_model.dart';
import '../models/student_trip_model.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/bus_provider.dart';
import '../services/device_service.dart';
import '../services/firestore_service.dart';
import '../screens/shared/bus_detail_screen.dart';
import '../screens/guest/student_trips_screen.dart';

class LiveTripPill extends StatefulWidget {
  final bool inAppBarArea;

  const LiveTripPill({super.key, this.inAppBarArea = false});

  @override
  State<LiveTripPill> createState() => _LiveTripPillState();
}

class _LiveTripPillState extends State<LiveTripPill>
    with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  final DeviceService _deviceService = DeviceService();
  String? _deviceId;
  Stream<StudentTrip?>? _tripStream;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeTripStream();
    });
  }

  Future<void> _initializeTripStream() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    if (user == null || user.role != UserRole.student) return;

    final deviceId = await _deviceService.getDeviceId();
    final studentUid = authProvider.firebaseUser?.uid;
    if (!mounted) return;

    setState(() {
      _deviceId = deviceId;
      _tripStream = _firestoreService.streamActiveTrip(
        deviceId: deviceId,
        studentUid: studentUid,
      );
    });
  }

  Future<void> _openActiveTrip(StudentTrip trip) async {
    Bus? bus;
    try {
      final busProvider = context.read<BusProvider>();
      bus = busProvider.buses.firstWhere((b) => b.busId == trip.busId);
    } catch (_) {
      bus = null;
    }

    bus ??= await _firestoreService.getBus(trip.busId);
    if (!mounted) return;

    if (bus != null) {
      final activeBus = bus;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => BusDetailScreen(bus: activeBus)),
      );
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const StudentTripsScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_tripStream == null || _deviceId == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<StudentTrip?>(
      stream: _tripStream,
      builder: (context, snapshot) {
        final trip = snapshot.data;
        if (trip == null) {
          return AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: const SizedBox(height: 0),
          );
        }

        final pill = AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          child: SizedBox(
            height: 52,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: 1,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
                child: Material(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => _openActiveTrip(trip),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.green.shade600,
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final showCta = constraints.maxHeight >= 44;
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade700,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _buildLabel(trip),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.chevron_right,
                                    size: 18,
                                    color: Colors.green.shade800,
                                  ),
                                ],
                              ),
                              if (showCta) ...[
                                const SizedBox(height: 2),
                                Center(
                                  child: Text(
                                    'Tap to manage',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.green.shade800,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        if (!widget.inAppBarArea) {
          return pill;
        }

        return Container(
          color: AppTheme.primaryColor,
          padding: const EdgeInsets.only(bottom: 6),
          child: pill,
        );
      },
    );
  }

  String _buildLabel(StudentTrip trip) {
    final minutes = DateTime.now().difference(trip.boardedAt).inMinutes;
    final duration = minutes <= 0 ? 'just now' : '${minutes}m';
    final route = trip.routeName != null ? ' • ${trip.routeName}' : '';
    return 'On Bus ${trip.busNumber}$route • $duration';
  }
}
