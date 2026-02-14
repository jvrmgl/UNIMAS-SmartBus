import 'package:cloud_firestore/cloud_firestore.dart';

DateTime _parseDateTime(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.contains('T') || trimmed.contains('-')) {
      return DateTime.tryParse(trimmed) ?? DateTime.now();
    }
    return _parseTimeString(trimmed);
  }
  return DateTime.now();
}

DateTime _parseTimeString(String value) {
  final now = DateTime.now();
  final lower = value.toLowerCase();
  final isPm = lower.contains('pm');
  final isAm = lower.contains('am');
  final cleaned = lower.replaceAll('am', '').replaceAll('pm', '').trim();
  final parts = cleaned.split(':');
  if (parts.length < 2) {
    return now;
  }
  int hour = int.tryParse(parts[0]) ?? 0;
  final minute = int.tryParse(parts[1]) ?? 0;
  if (isPm && hour < 12) {
    hour += 12;
  }
  if (isAm && hour == 12) {
    hour = 0;
  }
  return DateTime(now.year, now.month, now.day, hour, minute);
}

String _formatTime(DateTime value) {
  int hour = value.hour;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = hour >= 12 ? 'PM' : 'AM';
  hour = hour % 12;
  if (hour == 0) hour = 12;
  return '$hour:$minute $period';
}

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

  String get timeRange {
    return '${_formatTime(departureTime)} - ${_formatTime(arrivalTime)}';
  }

  Map<String, dynamic> toMap() {
    return {
      'scheduleId': scheduleId,
      'routeId': routeId,
      'busId': busId,
      'driverId': driverId,
      'departureTime': departureTime.toIso8601String(),
      'arrivalTime': arrivalTime.toIso8601String(),
      'startTime': _formatTime(departureTime),
      'endTime': _formatTime(arrivalTime),
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
      departureTime: _parseDateTime(
        map['departureTime'] ?? map['startTime'],
      ),
      arrivalTime: _parseDateTime(
        map['arrivalTime'] ?? map['endTime'],
      ),
      isActive: map['isActive'] as bool? ?? true,
      day: map['day'] as String? ?? 'All Days',
      createdAt: _parseDateTime(map['createdAt']),
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
