enum UserRole { student, driver, admin }

class User {
  final String uid;
  final String email;
  final String fullName;
  final String phoneNumber;
  final UserRole role;
  final DateTime createdAt;
  final bool isActive;

  User({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.phoneNumber,
    required this.role,
    required this.createdAt,
    this.isActive = true,
  });

  // Convert to Map (for Firebase)
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'role': role.toString().split('.').last,
      'createdAt': createdAt.toIso8601String(),
      'isActive': isActive,
    };
  }

  // Create from Map (from Firebase)
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      uid: map['uid'] as String,
      email: map['email'] as String,
      fullName: map['fullName'] as String,
      phoneNumber: map['phoneNumber'] as String,
      role: UserRole.values.firstWhere(
        (role) => role.toString().split('.').last == map['role'],
        orElse: () => UserRole.student,
      ),
      createdAt: DateTime.parse(map['createdAt'] as String),
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  User copyWith({
    String? uid,
    String? email,
    String? fullName,
    String? phoneNumber,
    UserRole? role,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return User(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }
}

class DriverProfile extends User {
  final String licenseNumber;
  final DateTime licenseExpiryDate;
  final double rating;
  final int totalTrips;

  DriverProfile({
    required String uid,
    required String email,
    required String fullName,
    required String phoneNumber,
    required DateTime createdAt,
    required this.licenseNumber,
    required this.licenseExpiryDate,
    this.rating = 0.0,
    this.totalTrips = 0,
  }) : super(
    uid: uid,
    email: email,
    fullName: fullName,
    phoneNumber: phoneNumber,
    role: UserRole.driver,
    createdAt: createdAt,
  );

  @override
  Map<String, dynamic> toMap() {
    final baseMap = super.toMap();
    baseMap.addAll({
      'licenseNumber': licenseNumber,
      'licenseExpiryDate': licenseExpiryDate.toIso8601String(),
      'rating': rating,
      'totalTrips': totalTrips,
    });
    return baseMap;
  }

  factory DriverProfile.fromMap(Map<String, dynamic> map) {
    return DriverProfile(
      uid: map['uid'] as String,
      email: map['email'] as String,
      fullName: map['fullName'] as String,
      phoneNumber: map['phoneNumber'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      licenseNumber: map['licenseNumber'] as String,
      licenseExpiryDate: DateTime.parse(map['licenseExpiryDate'] as String),
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      totalTrips: map['totalTrips'] as int? ?? 0,
    );
  }
}
