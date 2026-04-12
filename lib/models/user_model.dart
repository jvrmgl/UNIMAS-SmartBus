enum UserRole { student, driver, admin }

class User {
  final String uid;
  final String email;
  final String fullName;
  final UserRole role;
  final DateTime createdAt;
  final bool isActive;

  User({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.role,
    required this.createdAt,
    this.isActive = true,
  });

  // Convert to Map (for Firebase)
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'normalizedEmail': email.trim().toLowerCase(),
      'fullName': fullName,
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
    UserRole? role,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return User(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }
}

class DriverProfile extends User {
  final String licenseNumber;
  final DateTime licenseExpiryDate;

  DriverProfile({
    required super.uid,
    required super.email,
    required super.fullName,
    required super.createdAt,
    required this.licenseNumber,
    required this.licenseExpiryDate,
  }) : super(
          role: UserRole.driver,
        );

  @override
  Map<String, dynamic> toMap() {
    final baseMap = super.toMap();
    baseMap.addAll({
      'licenseNumber': licenseNumber,
      'licenseExpiryDate': licenseExpiryDate.toIso8601String(),
    });
    return baseMap;
  }

  factory DriverProfile.fromMap(Map<String, dynamic> map) {
    return DriverProfile(
      uid: map['uid'] as String,
      email: map['email'] as String,
      fullName: map['fullName'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      licenseNumber: map['licenseNumber'] as String,
      licenseExpiryDate: DateTime.parse(map['licenseExpiryDate'] as String),
    );
  }
}
