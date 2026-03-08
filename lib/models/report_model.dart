enum ReportStatus { pending, reviewed, resolved, rejected }
enum ReportCategory { cleanliness, safety, delay, behavior, other }
enum ReportMessageSender { guest, admin }

class Report {
  final String reportId;
  final String? deviceId; // Can be anonymous
  final String? busId;
  final String? routeId;
  final ReportCategory category;
  final String description;
  final List<String>? imageUrls;
  final ReportStatus status;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? adminNotes;

  Report({
    required this.reportId,
    this.deviceId,
    this.busId,
    this.routeId,
    required this.category,
    required this.description,
    this.imageUrls,
    required this.status,
    required this.createdAt,
    this.resolvedAt,
    this.adminNotes,
  });

  Map<String, dynamic> toMap() {
    return {
      'reportId': reportId,
      // Keep legacy studentId for backward compatibility with existing queries.
      'studentId': deviceId,
      'deviceId': deviceId,
      'busId': busId,
      'routeId': routeId,
      'category': category.toString().split('.').last,
      'description': description,
      'imageUrls': imageUrls,
      'status': status.toString().split('.').last,
      'createdAt': createdAt.toIso8601String(),
      'resolvedAt': resolvedAt?.toIso8601String(),
      'adminNotes': adminNotes,
    };
  }

  factory Report.fromMap(Map<String, dynamic> map) {
    return Report(
      reportId: map['reportId'] as String,
      // Prefer deviceId, fallback to legacy studentId.
      deviceId: (map['deviceId'] ?? map['studentId']) as String?,
      busId: map['busId'] as String?,
      routeId: map['routeId'] as String?,
      category: ReportCategory.values.firstWhere(
        (cat) => cat.toString().split('.').last == map['category'],
        orElse: () => ReportCategory.other,
      ),
      description: map['description'] as String,
      imageUrls: List<String>.from(map['imageUrls'] as List? ?? []),
      status: ReportStatus.values.firstWhere(
        (status) => status.toString().split('.').last == map['status'],
        orElse: () => ReportStatus.pending,
      ),
      createdAt: DateTime.parse(map['createdAt'] as String),
      resolvedAt: map['resolvedAt'] != null ? DateTime.parse(map['resolvedAt'] as String) : null,
      adminNotes: map['adminNotes'] as String?,
    );
  }

  Report copyWith({
    String? reportId,
    String? deviceId,
    String? busId,
    String? routeId,
    ReportCategory? category,
    String? description,
    List<String>? imageUrls,
    ReportStatus? status,
    DateTime? createdAt,
    DateTime? resolvedAt,
    String? adminNotes,
  }) {
    return Report(
      reportId: reportId ?? this.reportId,
      deviceId: deviceId ?? this.deviceId,
      busId: busId ?? this.busId,
      routeId: routeId ?? this.routeId,
      category: category ?? this.category,
      description: description ?? this.description,
      imageUrls: imageUrls ?? this.imageUrls,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      adminNotes: adminNotes ?? this.adminNotes,
    );
  }
}

class ReportMessage {
  final String senderId; // deviceId for guest, uid for admin
  final ReportMessageSender senderType;
  final String message;
  final DateTime createdAt;

  ReportMessage({
    required this.senderId,
    required this.senderType,
    required this.message,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderType': senderType.toString().split('.').last,
      'message': message,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ReportMessage.fromMap(Map<String, dynamic> map) {
    return ReportMessage(
      senderId: map['senderId'] as String,
      senderType: ReportMessageSender.values.firstWhere(
        (type) => type.toString().split('.').last == map['senderType'],
        orElse: () => ReportMessageSender.guest,
      ),
      message: map['message'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}
