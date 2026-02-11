enum TripStatus { scheduled, inProgress, completed, cancelled }

class Trip {
  final String tripId;
  final String busId;
  final String driverId;
  final String routeId;
  final DateTime startTime;
  final DateTime? endTime;
  final TripStatus status;
  final int passengerCount;
  final DateTime createdAt;

  Trip({
    required this.tripId,
    required this.busId,
    required this.driverId,
    required this.routeId,
    required this.startTime,
    this.endTime,
    required this.status,
    required this.passengerCount,
    required this.createdAt,
  });

  // Calculate trip duration
  Duration? getTripDuration() {
    if (endTime == null) return null;
    return endTime!.difference(startTime);
  }

  Map<String, dynamic> toMap() {
    return {
      'tripId': tripId,
      'busId': busId,
      'driverId': driverId,
      'routeId': routeId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'status': status.toString().split('.').last,
      'passengerCount': passengerCount,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Trip.fromMap(Map<String, dynamic> map) {
    return Trip(
      tripId: map['tripId'] as String,
      busId: map['busId'] as String,
      driverId: map['driverId'] as String,
      routeId: map['routeId'] as String,
      startTime: DateTime.parse(map['startTime'] as String),
      endTime: map['endTime'] != null ? DateTime.parse(map['endTime'] as String) : null,
      status: TripStatus.values.firstWhere(
        (status) => status.toString().split('.').last == map['status'],
        orElse: () => TripStatus.scheduled,
      ),
      passengerCount: map['passengerCount'] as int? ?? 0,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  Trip copyWith({
    String? tripId,
    String? busId,
    String? driverId,
    String? routeId,
    DateTime? startTime,
    DateTime? endTime,
    TripStatus? status,
    int? passengerCount,
    DateTime? createdAt,
  }) {
    return Trip(
      tripId: tripId ?? this.tripId,
      busId: busId ?? this.busId,
      driverId: driverId ?? this.driverId,
      routeId: routeId ?? this.routeId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      passengerCount: passengerCount ?? this.passengerCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
