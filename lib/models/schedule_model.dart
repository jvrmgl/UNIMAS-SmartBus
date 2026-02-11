class BusSchedule {
  final String scheduleId;
  final String routeId;
  final String busId;
  final String driverId;
  final DateTime departureTime;
  final DateTime arrivalTime;
  final bool isActive;
  final String day; // e.g., 'Monday', 'Tuesday', 'All Days'
  final DateTime createdAt;

  BusSchedule({
    required this.scheduleId,
    required this.routeId,
    required this.busId,
    required this.driverId,
    required this.departureTime,
    required this.arrivalTime,
    required this.isActive,
    required this.day,
    required this.createdAt,
  });

  // Get duration in minutes
  int getDurationInMinutes() {
    return arrivalTime.difference(departureTime).inMinutes;
  }

  Map<String, dynamic> toMap() {
    return {
      'scheduleId': scheduleId,
      'routeId': routeId,
      'busId': busId,
      'driverId': driverId,
      'departureTime': departureTime.toIso8601String(),
      'arrivalTime': arrivalTime.toIso8601String(),
      'isActive': isActive,
      'day': day,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory BusSchedule.fromMap(Map<String, dynamic> map) {
    return BusSchedule(
      scheduleId: map['scheduleId'] as String,
      routeId: map['routeId'] as String,
      busId: map['busId'] as String,
      driverId: map['driverId'] as String,
      departureTime: DateTime.parse(map['departureTime'] as String),
      arrivalTime: DateTime.parse(map['arrivalTime'] as String),
      isActive: map['isActive'] as bool? ?? true,
      day: map['day'] as String? ?? 'All Days',
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  BusSchedule copyWith({
    String? scheduleId,
    String? routeId,
    String? busId,
    String? driverId,
    DateTime? departureTime,
    DateTime? arrivalTime,
    bool? isActive,
    String? day,
    DateTime? createdAt,
  }) {
    return BusSchedule(
      scheduleId: scheduleId ?? this.scheduleId,
      routeId: routeId ?? this.routeId,
      busId: busId ?? this.busId,
      driverId: driverId ?? this.driverId,
      departureTime: departureTime ?? this.departureTime,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      isActive: isActive ?? this.isActive,
      day: day ?? this.day,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
