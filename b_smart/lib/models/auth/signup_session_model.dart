import 'dart:convert';

enum IdentifierType {
  email,
  phone,
  google,
}

enum VerificationStatus {
  pending,
  verified,
  expired,
}

class SignupSession {
  final String id;
  final String sessionToken;
  final IdentifierType identifierType;
  final String identifierValue;
  final String? otpCode;
  final DateTime? otpExpiresAt;
  final VerificationStatus verificationStatus;
  final int step; // 1-5
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime expiresAt;

  SignupSession({
    required this.id,
    required this.sessionToken,
    required this.identifierType,
    required this.identifierValue,
    this.otpCode,
    this.otpExpiresAt,
    required this.verificationStatus,
    required this.step,
    required this.metadata,
    required this.createdAt,
    required this.expiresAt,
  });

  factory SignupSession.fromJson(Map<String, dynamic> json) {
    return SignupSession(
      id: json['id'] as String,
      sessionToken: json['session_token'] as String,
      identifierType: _identifierTypeFromString(json['identifier_type'] as String),
      identifierValue: json['identifier_value'] as String,
      otpCode: json['otp_code'] as String?,
      otpExpiresAt: json['otp_expires_at'] != null
          ? DateTime.parse(json['otp_expires_at'] as String)
          : null,
      verificationStatus: _verificationStatusFromString(
          json['verification_status'] as String),
      step: json['step'] as int,
      metadata: _parseMetadata(json['metadata']),
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session_token': sessionToken,
      'identifier_type': _identifierTypeToString(identifierType),
      'identifier_value': identifierValue,
      'otp_code': otpCode,
      'otp_expires_at': otpExpiresAt?.toIso8601String(),
      'verification_status': _verificationStatusToString(verificationStatus),
      'step': step,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
    };
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isVerified => verificationStatus == VerificationStatus.verified;
  bool get canProceed => isVerified && !isExpired;

  static IdentifierType _identifierTypeFromString(String value) {
    switch (value) {
      case 'email':
        return IdentifierType.email;
      case 'phone':
        return IdentifierType.phone;
      case 'google':
        return IdentifierType.google;
      default:
        return IdentifierType.email;
    }
  }

  static String _identifierTypeToString(IdentifierType type) {
    switch (type) {
      case IdentifierType.email:
        return 'email';
      case IdentifierType.phone:
        return 'phone';
      case IdentifierType.google:
        return 'google';
    }
  }

  static VerificationStatus _verificationStatusFromString(String value) {
    switch (value) {
      case 'pending':
        return VerificationStatus.pending;
      case 'verified':
        return VerificationStatus.verified;
      case 'expired':
        return VerificationStatus.expired;
      default:
        return VerificationStatus.pending;
    }
  }

  static String _verificationStatusToString(VerificationStatus status) {
    switch (status) {
      case VerificationStatus.pending:
        return 'pending';
      case VerificationStatus.verified:
        return 'verified';
      case VerificationStatus.expired:
        return       'expired';
    }
  }

  static Map<String, dynamic> _parseMetadata(dynamic metadata) {
    if (metadata == null) return {};
    if (metadata is Map<String, dynamic>) return metadata;
    if (metadata is String) {
      try {
        return jsonDecode(metadata) as Map<String, dynamic>;
      } catch (e) {
        return {};
      }
    }
    return {};
  }
}
