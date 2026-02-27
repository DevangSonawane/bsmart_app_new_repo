class DeviceSession {
  final String id;
  final String userId;
  final String deviceId;
  final String? deviceName;
  final String? deviceType;
  final DateTime lastActiveAt;
  final bool isTrusted;
  final DateTime createdAt;

  DeviceSession({
    required this.id,
    required this.userId,
    required this.deviceId,
    this.deviceName,
    this.deviceType,
    required this.lastActiveAt,
    required this.isTrusted,
    required this.createdAt,
  });

  factory DeviceSession.fromJson(Map<String, dynamic> json) {
    return DeviceSession(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      deviceId: json['device_id'] as String,
      deviceName: json['device_name'] as String?,
      deviceType: json['device_type'] as String?,
      lastActiveAt: DateTime.parse(json['last_active_at'] as String),
      isTrusted: json['is_trusted'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'device_id': deviceId,
      'device_name': deviceName,
      'device_type': deviceType,
      'last_active_at': lastActiveAt.toIso8601String(),
      'is_trusted': isTrusted,
      'created_at': createdAt.toIso8601String(),
    };
  }

  DeviceSession copyWith({
    String? id,
    String? userId,
    String? deviceId,
    String? deviceName,
    String? deviceType,
    DateTime? lastActiveAt,
    bool? isTrusted,
    DateTime? createdAt,
  }) {
    return DeviceSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      deviceType: deviceType ?? this.deviceType,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      isTrusted: isTrusted ?? this.isTrusted,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class DeviceInfo {
  final String deviceId;
  final String deviceName;
  final String deviceType;
  final String? deviceFingerprint;
  final String? ipAddress;
  final String? userAgent;

  DeviceInfo({
    required this.deviceId,
    required this.deviceName,
    required this.deviceType,
    this.deviceFingerprint,
    this.ipAddress,
    this.userAgent,
  });

  Map<String, dynamic> toJson() {
    return {
      'device_id': deviceId,
      'device_name': deviceName,
      'device_type': deviceType,
      'device_fingerprint': deviceFingerprint,
      'ip_address': ipAddress,
      'user_agent': userAgent,
    };
  }
}
