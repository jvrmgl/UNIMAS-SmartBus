class BusStop {
  final String stopId;
  final String stopName;
  final String stopCode;
  final double latitude;
  final double longitude;
  final String description;
  final List<String> facilities; // e.g., ['shelter', 'bench', 'lighting']
  final DateTime createdAt;
  final bool isActive;

  BusStop({
    required this.stopId,
    required this.stopName,
    required this.stopCode,
    required this.latitude,
    required this.longitude,
    required this.description,
    required this.facilities,
    required this.createdAt,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'stopId': stopId,
      'stopName': stopName,
      'stopCode': stopCode,
      'latitude': latitude,
      'longitude': longitude,
      'description': description,
      'facilities': facilities,
      'createdAt': createdAt.toIso8601String(),
      'isActive': isActive,
    };
  }

  factory BusStop.fromMap(Map<String, dynamic> map) {
    return BusStop(
      stopId: map['stopId'] as String,
      stopName: map['stopName'] as String,
      stopCode: map['stopCode'] as String,
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      description: map['description'] as String? ?? '',
      facilities: List<String>.from(map['facilities'] as List? ?? []),
      createdAt: DateTime.parse(map['createdAt'] as String),
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  BusStop copyWith({
    String? stopId,
    String? stopName,
    String? stopCode,
    double? latitude,
    double? longitude,
    String? description,
    List<String>? facilities,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return BusStop(
      stopId: stopId ?? this.stopId,
      stopName: stopName ?? this.stopName,
      stopCode: stopCode ?? this.stopCode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      description: description ?? this.description,
      facilities: facilities ?? this.facilities,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }
}
