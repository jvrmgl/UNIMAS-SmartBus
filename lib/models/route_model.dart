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

class BusRoute {
  final String routeId;
  final String routeName;
  final String routeCode;
  final List<String> stopIds; // List of bus stop IDs in order
  final List<double>? legDistancesMeters; // Precomputed route legs in stop order
  final String? routePolyline; // Encoded polyline cached from Directions API
  final DateTime createdAt;
  final bool isActive;
  final String description;

  BusRoute({
    required this.routeId,
    required this.routeName,
    required this.routeCode,
    required this.stopIds,
    this.legDistancesMeters,
    this.routePolyline,
    required this.createdAt,
    required this.isActive,
    required this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'routeId': routeId,
      'routeName': routeName,
      'routeCode': routeCode,
      'stopIds': stopIds,
      if (legDistancesMeters != null) 'legDistancesMeters': legDistancesMeters,
      if (routePolyline != null) 'routePolyline': routePolyline,
      'createdAt': createdAt.toIso8601String(),
      'isActive': isActive,
      'description': description,
    };
  }

  factory BusRoute.fromMap(Map<String, dynamic> map) {
    return BusRoute(
      routeId: map['routeId'] as String,
      routeName: map['routeName'] as String,
      routeCode: map['routeCode'] as String,
      stopIds: List<String>.from(map['stopIds'] as List? ?? []),
      legDistancesMeters: (map['legDistancesMeters'] as List?)
          ?.map((v) => (v as num).toDouble())
          .toList(),
      routePolyline: map['routePolyline'] as String?,
      createdAt: _parseDateTime(map['createdAt']),
      isActive: map['isActive'] as bool? ?? true,
      description: map['description'] as String? ?? '',
    );
  }

  BusRoute copyWith({
    String? routeId,
    String? routeName,
    String? routeCode,
    List<String>? stopIds,
    List<double>? legDistancesMeters,
    String? routePolyline,
    DateTime? createdAt,
    bool? isActive,
    String? description,
  }) {
    return BusRoute(
      routeId: routeId ?? this.routeId,
      routeName: routeName ?? this.routeName,
      routeCode: routeCode ?? this.routeCode,
      stopIds: stopIds ?? this.stopIds,
      legDistancesMeters: legDistancesMeters ?? this.legDistancesMeters,
      routePolyline: routePolyline ?? this.routePolyline,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      description: description ?? this.description,
    );
  }
}
