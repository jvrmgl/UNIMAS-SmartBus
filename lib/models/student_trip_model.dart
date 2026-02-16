import 'package:cloud_firestore/cloud_firestore.dart';

class StudentTrip {
  final String tripId;
  final String deviceId;
  final String busId;
  final String busNumber;
  final String busRegistrationNumber;
  final String? routeId;
  final String? routeName;
  final DateTime boardedAt;
  final DateTime? offBoardedAt;
  final String status; // 'active' or 'completed'

  StudentTrip({
    required this.tripId,
    required this.deviceId,
    required this.busId,
    required this.busNumber,
    required this.busRegistrationNumber,
    this.routeId,
    this.routeName,
    required this.boardedAt,
    this.offBoardedAt,
    required this.status,
  });

  // Convert to Map for Firebase
  Map<String, dynamic> toMap() {
    return {
      'tripId': tripId,
      'deviceId': deviceId,
      'busId': busId,
      'busNumber': busNumber,
      'busRegistrationNumber': busRegistrationNumber,
      'routeId': routeId,
      'routeName': routeName,
      'boardedAt': Timestamp.fromDate(boardedAt),
      'offBoardedAt': offBoardedAt != null ? Timestamp.fromDate(offBoardedAt!) : null,
      'status': status,
    };
  }

  // Create from Map
  factory StudentTrip.fromMap(Map<String, dynamic> map) {
    return StudentTrip(
      tripId: map['tripId'] as String,
      deviceId: map['deviceId'] as String,
      busId: map['busId'] as String,
      busNumber: map['busNumber'] as String,
      busRegistrationNumber: map['busRegistrationNumber'] as String,
      routeId: map['routeId'] as String?,
      routeName: map['routeName'] as String?,
      boardedAt: (map['boardedAt'] as Timestamp).toDate(),
      offBoardedAt: map['offBoardedAt'] != null 
          ? (map['offBoardedAt'] as Timestamp).toDate() 
          : null,
      status: map['status'] as String,
    );
  }

  // Get duration if trip is completed
  Duration? getDuration() {
    if (offBoardedAt != null) {
      return offBoardedAt!.difference(boardedAt);
    }
    return null;
  }

  // Get formatted duration
  String getFormattedDuration() {
    final duration = getDuration();
    if (duration == null) return 'In progress';
    
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  // Check if trip is active
  bool get isActive => status == 'active';
}
