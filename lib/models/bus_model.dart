class Bus {
  final String busId;
  final String busNumber;
  final String registrationNumber;
  final String model;
  final int capacity;
  final int currentOccupancy;
  final DateTime lastUpdated;
  final bool isActive;
  final double latitude;
  final double longitude;

  Bus({
    required this.busId,
    required this.busNumber,
    required this.registrationNumber,
    required this.model,
    required this.capacity,
    required this.currentOccupancy,
    required this.lastUpdated,
    required this.isActive,
    required this.latitude,
    required this.longitude,
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

  Map<String, dynamic> toMap() {
    return {
      'busId': busId,
      'busNumber': busNumber,
      'registrationNumber': registrationNumber,
      'model': model,
      'capacity': capacity,
      'currentOccupancy': currentOccupancy,
      'lastUpdated': lastUpdated.toIso8601String(),
      'isActive': isActive,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  factory Bus.fromMap(Map<String, dynamic> map) {
    return Bus(
      busId: map['busId'] as String,
      busNumber: map['busNumber'] as String,
      registrationNumber: map['registrationNumber'] as String,
      model: map['model'] as String,
      capacity: map['capacity'] as int,
      currentOccupancy: map['currentOccupancy'] as int? ?? 0,
      lastUpdated: DateTime.parse(map['lastUpdated'] as String? ?? DateTime.now().toIso8601String()),
      isActive: map['isActive'] as bool? ?? true,
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Bus copyWith({
    String? busId,
    String? busNumber,
    String? registrationNumber,
    String? model,
    int? capacity,
    int? currentOccupancy,
    DateTime? lastUpdated,
    bool? isActive,
    double? latitude,
    double? longitude,
  }) {
    return Bus(
      busId: busId ?? this.busId,
      busNumber: busNumber ?? this.busNumber,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      model: model ?? this.model,
      capacity: capacity ?? this.capacity,
      currentOccupancy: currentOccupancy ?? this.currentOccupancy,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isActive: isActive ?? this.isActive,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}
