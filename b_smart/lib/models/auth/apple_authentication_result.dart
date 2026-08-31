import 'package:meta/meta.dart';

@immutable
class AppleAuthenticationResult {
  final String userIdentifier;
  final String? email;
  final String? givenName;
  final String? familyName;
  final String identityToken;
  final String authorizationCode;
  final String? state;
  final String rawNonce;
  final String hashedNonce;
  final DateTime authenticatedAt;

  const AppleAuthenticationResult({
    required this.userIdentifier,
    required this.email,
    required this.givenName,
    required this.familyName,
    required this.identityToken,
    required this.authorizationCode,
    required this.state,
    required this.rawNonce,
    required this.hashedNonce,
    required this.authenticatedAt,
  });

  String? get displayName {
    final parts = <String>[
      if (givenName != null && givenName!.trim().isNotEmpty) givenName!.trim(),
      if (familyName != null && familyName!.trim().isNotEmpty)
        familyName!.trim(),
    ];
    if (parts.isEmpty) return null;
    return parts.join(' ');
  }

  String get backendFullName => displayName ?? '';

  Map<String, dynamic> toBackendPayload() {
    return {
      'identity_token': identityToken,
      'full_name': backendFullName,
      'email': email ?? '',
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'user_identifier': userIdentifier,
      'email': email,
      'given_name': givenName,
      'family_name': familyName,
      'identity_token': identityToken,
      'authorization_code': authorizationCode,
      'state': state,
      'nonce': rawNonce,
      'hashed_nonce': hashedNonce,
      'authenticated_at': authenticatedAt.toIso8601String(),
    };
  }

  AppleAuthenticationResult copyWith({
    String? userIdentifier,
    String? email,
    String? givenName,
    String? familyName,
    String? identityToken,
    String? authorizationCode,
    String? state,
    String? rawNonce,
    String? hashedNonce,
    DateTime? authenticatedAt,
  }) {
    return AppleAuthenticationResult(
      userIdentifier: userIdentifier ?? this.userIdentifier,
      email: email ?? this.email,
      givenName: givenName ?? this.givenName,
      familyName: familyName ?? this.familyName,
      identityToken: identityToken ?? this.identityToken,
      authorizationCode: authorizationCode ?? this.authorizationCode,
      state: state ?? this.state,
      rawNonce: rawNonce ?? this.rawNonce,
      hashedNonce: hashedNonce ?? this.hashedNonce,
      authenticatedAt: authenticatedAt ?? this.authenticatedAt,
    );
  }
}
