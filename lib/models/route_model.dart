class BusRoute {
  final String routeId;
  final String routeName;
  final String routeCode;
  final List<String> stopIds; // List of bus stop IDs in order
  final DateTime createdAt;
  final bool isActive;
  final String description;
  final int estimatedDuration; // in minutes

  BusRoute({
    required this.routeId,
    required this.routeName,
    required this.routeCode,
    required this.stopIds,
    required this.createdAt,
    required this.isActive,
    required this.description,
    required this.estimatedDuration,
  });

  Map<String, dynamic> toMap() {
    return {
      'routeId': routeId,
      'routeName': routeName,
      'routeCode': routeCode,
      'stopIds': stopIds,
      'createdAt': createdAt.toIso8601String(),
      'isActive': isActive,
      'description': description,
      'estimatedDuration': estimatedDuration,
    };
  }

  factory BusRoute.fromMap(Map<String, dynamic> map) {
    return BusRoute(
      routeId: map['routeId'] as String,
      routeName: map['routeName'] as String,
      routeCode: map['routeCode'] as String,
      stopIds: List<String>.from(map['stopIds'] as List? ?? []),
      createdAt: DateTime.parse(map['createdAt'] as String),
      isActive: map['isActive'] as bool? ?? true,
      description: map['description'] as String? ?? '',
      estimatedDuration: map['estimatedDuration'] as int? ?? 0,
    );
  }

  BusRoute copyWith({
    String? routeId,
    String? routeName,
    String? routeCode,
    List<String>? stopIds,
    DateTime? createdAt,
    bool? isActive,
    String? description,
    int? estimatedDuration,
  }) {
    return BusRoute(
      routeId: routeId ?? this.routeId,
      routeName: routeName ?? this.routeName,
      routeCode: routeCode ?? this.routeCode,
      stopIds: stopIds ?? this.stopIds,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      description: description ?? this.description,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
    );
  }
}
