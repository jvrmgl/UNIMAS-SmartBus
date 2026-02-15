class ScheduleImage {
  final String imageId;
  final String imageUrl;
  final String title;
  final int order;
  final DateTime uploadedAt;
  final bool isActive;

  ScheduleImage({
    required this.imageId,
    required this.imageUrl,
    required this.title,
    required this.order,
    required this.uploadedAt,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'imageId': imageId,
      'imageUrl': imageUrl,
      'title': title,
      'order': order,
      'uploadedAt': uploadedAt.toIso8601String(),
      'isActive': isActive,
    };
  }

  factory ScheduleImage.fromMap(Map<String, dynamic> map) {
    return ScheduleImage(
      imageId: map['imageId'] as String,
      imageUrl: map['imageUrl'] as String,
      title: map['title'] as String? ?? '',
      order: map['order'] as int? ?? 0,
      uploadedAt: _parseDateTime(map['uploadedAt']),
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    
    // Handle Firestore Timestamp
    if (value.runtimeType.toString() == 'Timestamp') {
      try {
        return (value as dynamic).toDate();
      } catch (e) {
        print('Error parsing Timestamp: $e');
        return DateTime.now();
      }
    }
    
    // Handle DateTime object
    if (value is DateTime) return value;
    
    // Handle String (ISO8601)
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    
    // Handle milliseconds since epoch
    if (value is int) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(value);
      } catch (e) {
        return DateTime.now();
      }
    }
    
    return DateTime.now();
  }

  ScheduleImage copyWith({
    String? imageId,
    String? imageUrl,
    String? title,
    int? order,
    DateTime? uploadedAt,
    bool? isActive,
  }) {
    return ScheduleImage(
      imageId: imageId ?? this.imageId,
      imageUrl: imageUrl ?? this.imageUrl,
      title: title ?? this.title,
      order: order ?? this.order,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      isActive: isActive ?? this.isActive,
    );
  }
}
