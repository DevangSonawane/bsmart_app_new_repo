class AppleCredential {
  final String userIdentifier;
  final String? identityToken;
  final String? authorizationCode;
  final String? email;
  final String? givenName;
  final String? familyName;
  final String? state;

  const AppleCredential({
    required this.userIdentifier,
    this.identityToken,
    this.authorizationCode,
    this.email,
    this.givenName,
    this.familyName,
    this.state,
  });

  bool get hasIdentityToken =>
      identityToken != null && identityToken!.trim().isNotEmpty;

  bool get hasAuthorizationCode =>
      authorizationCode != null && authorizationCode!.trim().isNotEmpty;

  bool get isPrivateRelayEmail =>
      email != null &&
      email!.toLowerCase().contains('privaterelay.appleid.com');

  Map<String, dynamic> toJson() {
    return {
      'user_identifier': userIdentifier,
      'identity_token': identityToken,
      'authorization_code': authorizationCode,
      'email': email,
      'given_name': givenName,
      'family_name': familyName,
      'state': state,
    };
  }
}

class AppleAuthenticationResult {
  final AppleCredential credential;
  final String rawNonce;
  final String hashedNonce;
  final DateTime authenticatedAt;

  const AppleAuthenticationResult({
    required this.credential,
    required this.rawNonce,
    required this.hashedNonce,
    required this.authenticatedAt,
  });

  Map<String, dynamic> toPendingBackendPayload() {
    return <String, dynamic>{
      'apple_credential': credential.toJson(),
      'raw_nonce': rawNonce,
      'hashed_nonce': hashedNonce,
      'authenticated_at': authenticatedAt.toIso8601String(),
    };
  }

  String get summaryLabel {
    final email = credential.email?.trim();
    if (email != null && email.isNotEmpty) return email;
    final name = [credential.givenName, credential.familyName]
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .join(' ');
    if (name.isNotEmpty) return name;
    return credential.userIdentifier;
  }
}