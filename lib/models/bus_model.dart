import 'package:cloud_firestore/cloud_firestore.dart';

DateTime _parseDateTime(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.now();
  }
  return DateTime.now();
}

class Bus {
  final String busId;
  final String busNumber;
  final String registrationNumber;
  final int capacity;
  final int currentOccupancy;
  final DateTime lastUpdated;
  final bool isActive;
  final double latitude;
  final double longitude;
  final String? assignedRoute;
  final String? driverId;    // UID of the assigned driver
  final String? driverName;  // Display name of the assigned driver
  
  // Live ETA fields
  final Map<String, int>? liveEtaByStopId;
  final DateTime? liveEtaUpdatedAt;
  final String? liveEtaSource;

  Bus({
    required this.busId,
    required this.busNumber,
    required this.registrationNumber,
    required this.capacity,
    required this.currentOccupancy,
    required this.lastUpdated,
    required this.isActive,
    required this.latitude,
    required this.longitude,
    this.assignedRoute,
    this.driverId,
    this.driverName,
    this.liveEtaByStopId,
    this.liveEtaUpdatedAt,
    this.liveEtaSource,
  });

  // Calculate occupancy percentage
  double getOccupancyPercentage() {
    if (capacity == 0) return 0;
    return (currentOccupancy / capacity) * 100;
  }

  // Check if bus is near full
  bool isNearCapacity({double threshold = 80}) {
    return getOccupancyPercentage() >= threshold;
  }

  // A bus is considered location-ready once it has moved away from the
  // default placeholder coordinate used at creation time.
  bool get hasReportedLocation {
    return latitude != 0.0 || longitude != 0.0;
  }

  Map<String, dynamic> toMap() {
    return {
      'busId': busId,
      'busNumber': busNumber,
      'registrationNumber': registrationNumber,
      'capacity': capacity,
      'currentOccupancy': currentOccupancy,
      'lastUpdated': lastUpdated.toIso8601String(),
      'isActive': isActive,
      'latitude': latitude,
      'longitude': longitude,
      'assignedRoute': assignedRoute,
      'driverId': driverId,
      'driverName': driverName,
      'liveEtaByStopId': liveEtaByStopId,
      'liveEtaUpdatedAt': liveEtaUpdatedAt?.toIso8601String(),
      'liveEtaSource': liveEtaSource,
    };
  }

  factory Bus.fromMap(Map<String, dynamic> map) {
    return Bus(
      busId: map['busId'] as String,
      busNumber: map['busNumber'] as String,
      registrationNumber: map['registrationNumber'] as String,
      capacity: map['capacity'] as int,
      currentOccupancy: map['currentOccupancy'] as int? ?? 0,
      lastUpdated: _parseDateTime(map['lastUpdated']),
      isActive: map['isActive'] as bool? ?? true,
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      assignedRoute: map['assignedRoute'] as String?,
      driverId: map['driverId'] as String?,
      driverName: map['driverName'] as String?,
      liveEtaByStopId: map['liveEtaByStopId'] != null 
          ? Map<String, int>.from(map['liveEtaByStopId'] as Map)
          : null,
      liveEtaUpdatedAt: map['liveEtaUpdatedAt'] != null 
          ? _parseDateTime(map['liveEtaUpdatedAt']) 
          : null,
      liveEtaSource: map['liveEtaSource'] as String?,
    );
  }

  Bus copyWith({
    String? busId,
    String? busNumber,
    String? registrationNumber,
    int? capacity,
    int? currentOccupancy,
    DateTime? lastUpdated,
    bool? isActive,
    double? latitude,
    double? longitude,
    String? assignedRoute,
    String? driverId,
    String? driverName,
    Map<String, int>? liveEtaByStopId,
    DateTime? liveEtaUpdatedAt,
    String? liveEtaSource,
  }) {
    return Bus(
      busId: busId ?? this.busId,
      busNumber: busNumber ?? this.busNumber,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      capacity: capacity ?? this.capacity,
      currentOccupancy: currentOccupancy ?? this.currentOccupancy,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isActive: isActive ?? this.isActive,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      assignedRoute: assignedRoute ?? this.assignedRoute,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      liveEtaByStopId: liveEtaByStopId ?? this.liveEtaByStopId,
      liveEtaUpdatedAt: liveEtaUpdatedAt ?? this.liveEtaUpdatedAt,
      liveEtaSource: liveEtaSource ?? this.liveEtaSource,
    );
  }
}
