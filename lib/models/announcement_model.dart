enum AnnouncementType { service, route, maintenance, emergency }

class Announcement {
  final String announcementId;
  final String title;
  final String description;
  final AnnouncementType type;
  final List<String> affectedRoutes; // Route IDs affected
  final DateTime createdAt;
  final DateTime expiryDate;
  final bool isActive;
  final String createdBy; // Admin ID

  Announcement({
    required this.announcementId,
    required this.title,
    required this.description,
    required this.type,
    required this.affectedRoutes,
    required this.createdAt,
    required this.expiryDate,
    required this.isActive,
    required this.createdBy,
  });

  // Check if announcement is expired
  bool isExpired() {
    return DateTime.now().isAfter(expiryDate);
  }

  Map<String, dynamic> toMap() {
    return {
      'announcementId': announcementId,
      'title': title,
      'description': description,
      'type': type.toString().split('.').last,
      'affectedRoutes': affectedRoutes,
      'createdAt': createdAt.toIso8601String(),
      'expiryDate': expiryDate.toIso8601String(),
      'isActive': isActive,
      'createdBy': createdBy,
    };
  }

  factory Announcement.fromMap(Map<String, dynamic> map) {
    return Announcement(
      announcementId: map['announcementId'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      type: AnnouncementType.values.firstWhere(
        (type) => type.toString().split('.').last == map['type'],
        orElse: () => AnnouncementType.service,
      ),
      affectedRoutes: List<String>.from(map['affectedRoutes'] as List? ?? []),
      createdAt: DateTime.parse(map['createdAt'] as String),
      expiryDate: DateTime.parse(map['expiryDate'] as String),
      isActive: map['isActive'] as bool? ?? true,
      createdBy: map['createdBy'] as String,
    );
  }

  Announcement copyWith({
    String? announcementId,
    String? title,
    String? description,
    AnnouncementType? type,
    List<String>? affectedRoutes,
    DateTime? createdAt,
    DateTime? expiryDate,
    bool? isActive,
    String? createdBy,
  }) {
    return Announcement(
      announcementId: announcementId ?? this.announcementId,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      affectedRoutes: affectedRoutes ?? this.affectedRoutes,
      createdAt: createdAt ?? this.createdAt,
      expiryDate: expiryDate ?? this.expiryDate,
      isActive: isActive ?? this.isActive,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}
