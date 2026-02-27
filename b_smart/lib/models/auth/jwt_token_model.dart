class JWTToken {
  final String accessToken;
  final String refreshToken;
  final DateTime accessTokenExpiresAt;
  final DateTime refreshTokenExpiresAt;
  final String? deviceId;

  JWTToken({
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAt,
    required this.refreshTokenExpiresAt,
    this.deviceId,
  });

  factory JWTToken.fromJson(Map<String, dynamic> json) {
    return JWTToken(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      accessTokenExpiresAt:
          DateTime.parse(json['access_token_expires_at'] as String),
      refreshTokenExpiresAt:
          DateTime.parse(json['refresh_token_expires_at'] as String),
      deviceId: json['device_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'access_token_expires_at': accessTokenExpiresAt.toIso8601String(),
      'refresh_token_expires_at': refreshTokenExpiresAt.toIso8601String(),
      'device_id': deviceId,
    };
  }

  bool get isAccessTokenExpired =>
      DateTime.now().isAfter(accessTokenExpiresAt);
  bool get isRefreshTokenExpired =>
      DateTime.now().isAfter(refreshTokenExpiresAt);
  bool get isValid => !isAccessTokenExpired && !isRefreshTokenExpired;

  JWTToken copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? accessTokenExpiresAt,
    DateTime? refreshTokenExpiresAt,
    String? deviceId,
  }) {
    return JWTToken(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      accessTokenExpiresAt: accessTokenExpiresAt ?? this.accessTokenExpiresAt,
      refreshTokenExpiresAt:
          refreshTokenExpiresAt ?? this.refreshTokenExpiresAt,
      deviceId: deviceId ?? this.deviceId,
    );
  }
}

class JWTPayload {
  final String userId;
  final String username;
  final String authProvider;
  final String? deviceId;
  final DateTime issuedAt;
  final DateTime expiresAt;

  JWTPayload({
    required this.userId,
    required this.username,
    required this.authProvider,
    this.deviceId,
    required this.issuedAt,
    required this.expiresAt,
  });

  factory JWTPayload.fromJson(Map<String, dynamic> json) {
    return JWTPayload(
      userId: json['user_id'] as String,
      username: json['username'] as String,
      authProvider: json['auth_provider'] as String,
      deviceId: json['device_id'] as String?,
      issuedAt: DateTime.fromMillisecondsSinceEpoch(
          (json['iat'] as int) * 1000),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(
          (json['exp'] as int) * 1000),
    );
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
