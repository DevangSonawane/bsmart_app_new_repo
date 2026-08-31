import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../models/auth/apple_authentication_result.dart';

class AppleAuthService {
  static final AppleAuthService _instance = AppleAuthService._internal();
  factory AppleAuthService() => _instance;

  AppleAuthService._internal();

  Future<AppleAuthenticationResult?> authenticate() async {
    debugPrint('[apple-sign-in] native Apple login started');

    final available = await SignInWithApple.isAvailable();
    if (!available) {
      throw Exception('Sign in with Apple is not available on this device.');
    }

    final rawNonce = generateNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();
    final state = generateNonce(length: 16);

    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
        state: state,
      );
      debugPrint('[apple-sign-in] credential received');

      final identityToken = credential.identityToken;
      debugPrint(
        '[apple-sign-in] identity token present: ${identityToken != null && identityToken.trim().isNotEmpty}',
      );
      debugPrint(
        '[apple-sign-in] identity token length: ${identityToken?.length ?? 0}',
      );
      debugPrint(
        '[apple-sign-in] email present: ${credential.email != null && credential.email!.trim().isNotEmpty}',
      );
      debugPrint(
        '[apple-sign-in] full name present: ${(credential.givenName != null && credential.givenName!.trim().isNotEmpty) || (credential.familyName != null && credential.familyName!.trim().isNotEmpty)}',
      );

      if (identityToken == null || identityToken.trim().isEmpty) {
        throw Exception(
          'Apple sign-in did not return an identity token.',
        );
      }

      final authorizationCode = credential.authorizationCode;
      if (authorizationCode.trim().isEmpty) {
        throw Exception(
          'Apple sign-in did not return an authorization code.',
        );
      }
      final userIdentifier = credential.userIdentifier;
      if (userIdentifier == null || userIdentifier.trim().isEmpty) {
        throw Exception(
          'Apple sign-in did not return a user identifier.',
        );
      }

      return AppleAuthenticationResult(
        userIdentifier: userIdentifier,
        email: credential.email,
        givenName: credential.givenName,
        familyName: credential.familyName,
        identityToken: identityToken,
        authorizationCode: authorizationCode,
        state: credential.state ?? state,
        rawNonce: rawNonce,
        hashedNonce: hashedNonce,
        authenticatedAt: DateTime.now(),
      );
    } on SignInWithAppleAuthorizationException catch (e, st) {
      debugPrint(
        '[apple-sign-in] native Apple auth exception type: ${e.runtimeType}',
      );
      debugPrint('[apple-sign-in] native Apple auth exception message: $e');
      debugPrint('[apple-sign-in] native Apple auth stack trace:\n$st');
      if (e.code == AuthorizationErrorCode.canceled) {
        return null;
      }
      throw Exception('Apple sign-in failed: ${e.message}');
    } on SignInWithAppleException catch (e, st) {
      debugPrint(
        '[apple-sign-in] native Apple auth exception type: ${e.runtimeType}',
      );
      debugPrint('[apple-sign-in] native Apple auth exception message: $e');
      debugPrint('[apple-sign-in] native Apple auth stack trace:\n$st');
      throw Exception('Apple sign-in failed: $e');
    } catch (e, st) {
      debugPrint('[apple-sign-in] native Apple auth exception type: ${e.runtimeType}');
      debugPrint('[apple-sign-in] native Apple auth exception message: $e');
      debugPrint('[apple-sign-in] native Apple auth stack trace:\n$st');
      rethrow;
    }
  }
}
