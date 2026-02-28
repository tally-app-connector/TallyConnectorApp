class User {
  final int userId;
  final String email;
  final String fullName;
  final String? phone;  // Already nullable
  final bool isVerified;
  final DateTime createdAt;
  final DateTime? lastLogin;  // Already nullable

  User({
    required this.userId,
    required this.email,
    required this.fullName,
    this.phone,
    required this.isVerified,
    required this.createdAt,
    this.lastLogin,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['user_id'] as int,
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      phone: json['phone'] as String?,  // Safe cast
      isVerified: json['is_verified'] as bool? ?? false,  // Default to false if null
      createdAt: DateTime.parse(json['created_at'] as String),
      lastLogin: json['last_login'] != null 
          ? DateTime.parse(json['last_login'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'email': email,
      'full_name': fullName,
      'phone': phone,
      'is_verified': isVerified,
      'created_at': createdAt.toIso8601String(),
      'last_login': lastLogin?.toIso8601String(),
    };
  }
}