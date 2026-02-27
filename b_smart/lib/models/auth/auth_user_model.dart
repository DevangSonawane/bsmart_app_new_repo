class AuthUser {
  final String id;
  final String username;
  final String? email;
  final String? phone;
  final String? fullName;
  final DateTime? dateOfBirth;
  final bool isUnder18;
  final String? avatarUrl;
  final String? bio;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  AuthUser({
    required this.id,
    required this.username,
    this.email,
    this.phone,
    this.fullName,
    this.dateOfBirth,
    required this.isUnder18,
    this.avatarUrl,
    this.bio,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      username: json['username'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      fullName: json['full_name'] as String?,
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.parse(json['date_of_birth'] as String)
          : null,
      isUnder18: json['is_under_18'] as bool? ?? false,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      isActive: json['is_active'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'phone': phone,
      'full_name': fullName,
      'date_of_birth': dateOfBirth?.toIso8601String(),
      'is_under_18': isUnder18,
      'avatar_url': avatarUrl,
      'bio': bio,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  AuthUser copyWith({
    String? id,
    String? username,
    String? email,
    String? phone,
    String? fullName,
    DateTime? dateOfBirth,
    bool? isUnder18,
    String? avatarUrl,
    String? bio,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AuthUser(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      fullName: fullName ?? this.fullName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      isUnder18: isUnder18 ?? this.isUnder18,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
