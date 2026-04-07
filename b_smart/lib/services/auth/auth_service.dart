import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../api/api.dart';
import '../../models/auth/auth_user_model.dart' as model;
import '../../models/auth/signup_session_model.dart';
import '../../utils/validators.dart';
import '../../utils/constants.dart';

class AuthLoginOutcome {
  final bool requires2fa;
  final String? email;
  final String? message;
  final model.AuthUser? user;

  const AuthLoginOutcome({
    required this.requires2fa,
    this.email,
    this.message,
    this.user,
  });
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  final AuthApi _authApi = AuthApi();
  final ApiClient _apiClient = ApiClient();
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'https://www.googleapis.com/auth/userinfo.profile'],
    serverClientId:
        '832065490130-97j2a560l5e30p3tu90j9miqfdkdctlv.apps.googleusercontent.com',
  );

  // In-memory storage for signup sessions during the flow
  final Map<String, SignupSession> _sessions = {};

  AuthService._internal();

  // ==================== SIGNUP METHODS ====================

  // Signup with email - Step 1
  Future<SignupSession> signupWithEmail(String email, String password) async {
    final sessionToken = _generateSessionToken();
    final now = DateTime.now();

    final session = SignupSession(
      id: sessionToken,
      sessionToken: sessionToken,
      identifierType: IdentifierType.email,
      identifierValue: email,
      verificationStatus: VerificationStatus.verified,
      step: 1,
      metadata: {
        'email': email,
        'password': password,
      },
      createdAt: now,
      expiresAt: now.add(const Duration(hours: 1)),
    );

    _sessions[sessionToken] = session;
    return session;
  }

  // Signup with phone - Step 1
  Future<SignupSession> signupWithPhone(String phone) async {
    final sessionToken = _generateSessionToken();
    final now = DateTime.now();

    final session = SignupSession(
      id: sessionToken,
      sessionToken: sessionToken,
      identifierType: IdentifierType.phone,
      identifierValue: phone,
      verificationStatus: VerificationStatus.verified,
      step: 1,
      metadata: {
        'phone': phone,
      },
      createdAt: now,
      expiresAt: now.add(const Duration(hours: 1)),
    );

    _sessions[sessionToken] = session;
    return session;
  }

  Future<String?> loginWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception('Google sign-in did not return an ID token.');
      }

      debugPrint(
        'Google sign-in success for ${googleUser.email}. Exchanging ID token with backend...',
      );
      final data = await _authApi.loginWithGoogle(idToken: idToken);
      final token = data['token'] as String?;
      if (token == null || token.isEmpty) {
        throw Exception(
          'Backend did not return app token after Google login. Response keys: ${data.keys.join(', ')}',
        );
      }
      return token;
    } on ApiException catch (e) {
      throw Exception(
        'Google login failed at backend exchange (HTTP ${e.statusCode}): ${e.message}',
      );
    } on PlatformException catch (e) {
      if (e.code == 'channel-error') {
        throw Exception(
          'Google login native channel is not connected (${e.code}). Rebuild the app fully (flutter clean + flutter pub get + reinstall app) and verify native Google config for this app id.',
        );
      }
      throw Exception(
        'Google login failed in Android/iOS SDK (${e.code}): ${e.message ?? e.details ?? 'Unknown platform error'}',
      );
    } catch (e) {
      throw Exception('Google login failed: ${e.toString()}');
    }
  }

  Future<SignupSession> signupWithGoogle() async {
    final token = await loginWithGoogle();
    if (token == null) {
      throw Exception('Sign up cancelled');
    }

    final now = DateTime.now();
    return SignupSession(
      id: 'google-session',
      sessionToken: token,
      identifierType: IdentifierType.email,
      identifierValue: _googleSignIn.currentUser?.email ?? 'google-user',
      verificationStatus: VerificationStatus.verified,
      step: 3, // Completed
      metadata: {},
      createdAt: now,
      expiresAt: now.add(const Duration(hours: 1)),
    );
  }

  // Verify OTP - Step 2
  Future<SignupSession> verifyOTP(String sessionToken, String otp) async {
    final session = _sessions[sessionToken];
    if (session == null) throw Exception('Session not found');

    final updatedSession = SignupSession(
      id: session.id,
      sessionToken: session.sessionToken,
      identifierType: session.identifierType,
      identifierValue: session.identifierValue,
      otpCode: otp,
      verificationStatus: VerificationStatus.verified,
      step: 2,
      metadata: session.metadata,
      createdAt: session.createdAt,
      expiresAt: session.expiresAt,
    );

    _sessions[sessionToken] = updatedSession;
    return updatedSession;
  }

  // Update session metadata (used in Account Setup)
  Future<void> updateSignupSession(
    String sessionToken,
    Map<String, dynamic> updates,
  ) async {
    final session = _sessions[sessionToken];
    if (session == null) throw Exception('Session not found');

    final newMetadata = Map<String, dynamic>.from(session.metadata);
    if (updates.containsKey('metadata')) {
      newMetadata.addAll(updates['metadata']);
    }

    final updatedSession = SignupSession(
      id: session.id,
      sessionToken: session.sessionToken,
      identifierType: session.identifierType,
      identifierValue: session.identifierValue,
      verificationStatus: session.verificationStatus,
      step: updates['step'] ?? session.step,
      metadata: newMetadata,
      createdAt: session.createdAt,
      expiresAt: session.expiresAt,
    );

    _sessions[sessionToken] = updatedSession;
  }

  // Check username availability
  Future<bool> checkUsernameAvailability(String username) async {
    // The new API doesn't have a dedicated username-check endpoint,
    // but a 400 on register means the username/email is taken.
    // For now, we keep the Supabase fallback or do a best-effort check
    // using the users API.
    try {
      // Try fetching user – if 404, username is available; if 200, taken.
      // This is a workaround; a dedicated endpoint would be better.
      return true; // Placeholder – server will reject duplicates on register.
    } catch (_) {
      return true;
    }
  }

  // Complete signup - Final Step
  Future<model.AuthUser> completeSignup(
    String sessionToken,
    String username,
    String? fullName,
    String? password,
    DateTime dateOfBirth,
  ) async {
    final session = _sessions[sessionToken];
    if (session == null) throw Exception('Session not found');

    try {
      final isUnder18 =
          Validators.calculateAge(dateOfBirth) < AuthConstants.restrictedAge;

      // For Google signups we don't ask the user for a password.
      // We derive a deterministic internal password from the Google email so
      // we can still satisfy the REST API's `email + password` requirement.
      String? email = session.metadata['email'] as String?;
      String? pass;

      if (session.identifierType == IdentifierType.google) {
        if (email == null) {
          throw Exception('Email is required for Google signup');
        }
        pass = _googlePasswordForEmail(email);
      } else {
        email ??= session.identifierValue;
        final storedPass = session.metadata['password'] as String?;
        pass = password ?? storedPass;
      }

      if (pass == null) {
        throw Exception('Email and password are required');
      }

      // Register via the new REST API.
      final data = await _authApi.register(
        email: email,
        password: pass,
        username: username,
        fullName: fullName,
        phone: session.metadata['phone'] as String?,
      );

      final user = data['user'] as Map<String, dynamic>? ?? {};

      // Clean up session.
      _sessions.remove(sessionToken);

      return model.AuthUser(
        id: user['id'] as String? ?? '',
        username: user['username'] as String? ?? username,
        email: user['email'] as String?,
        phone: user['phone'] as String?,
        fullName: user['full_name'] as String? ?? fullName,
        dateOfBirth: dateOfBirth,
        isUnder18: isUnder18,
        avatarUrl: user['avatar_url'] as String?,
        bio: null,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      throw Exception('Signup failed: $e');
    }
  }

  // ==================== LOGIN METHODS ====================

  Future<AuthLoginOutcome> login({
    required String identifier,
    required String password,
    String? otp,
  }) async {
    try {
      final data = await _authApi.login(
        email: identifier,
        password: password,
        otp: otp,
      );

      final requires2fa = data['requires_2fa'] == true;
      if (requires2fa) {
        return AuthLoginOutcome(
          requires2fa: true,
          email: (data['email'] ?? identifier).toString(),
          message: data['message']?.toString(),
        );
      }

      final user = data['user'] as Map<String, dynamic>? ?? {};
      return AuthLoginOutcome(
        requires2fa: false,
        user: _userFromApiMap(user),
      );
    } on ApiException catch (e) {
      throw Exception('Login failed: ${e.message}');
    } catch (e) {
      throw Exception('Login failed: ${e.toString()}');
    }
  }

  Future<model.AuthUser> loginWithEmail(String email, String password) async {
    try {
      final data = await _authApi.login(email: email, password: password);
      if (data['requires_2fa'] == true) {
        throw Exception('OTP required to complete login.');
      }
      final user = data['user'] as Map<String, dynamic>? ?? {};
      return _userFromApiMap(user);
    } on ApiException catch (e) {
      throw Exception('Login failed: ${e.message}');
    } catch (e) {
      throw Exception('Login failed: ${e.toString()}');
    }
  }

  Future<model.AuthUser> loginWithUsername(
    String username,
    String password,
  ) async {
    // The new API login endpoint uses email. If the user enters a username,
    // we pass it as email and let the server handle the lookup, or
    // fall back to the email field.
    try {
      final data = await _authApi.login(email: username, password: password);
      if (data['requires_2fa'] == true) {
        throw Exception('OTP required to complete login.');
      }
      final user = data['user'] as Map<String, dynamic>? ?? {};
      return _userFromApiMap(user);
    } on ApiException catch (e) {
      throw Exception('Login failed: ${e.message}');
    } catch (e) {
      throw Exception('Login failed: ${e.toString()}');
    }
  }

  Future<SignupSession> loginWithPhone(String phone) async {
    throw Exception(
      'Phone login is not currently supported. Please use Email or Google.',
    );
  }

  Future<void> completePhoneLogin(String sessionToken, String otp) async {
    throw Exception('Phone login is not currently supported.');
  }

  /// Fetch the current authenticated user profile from the REST API.
  Future<model.AuthUser?> fetchCurrentUser() async {
    try {
      final data = await _authApi.me();
      return _userFromApiMap(data);
    } catch (_) {
      return null;
    }
  }

  /// Logout – clears stored JWT.
  Future<void> logout() async {
    await _googleSignIn.signOut();
    await _authApi.logout();
  }

  /// Returns the current Google profile photo URL if the user is signed in
  /// with Google. Attempts a silent sign-in if needed.
  Future<String?> getGoogleProfilePhotoUrl({bool trySilent = true}) async {
    try {
      var user = _googleSignIn.currentUser;
      if (user == null && trySilent) {
        user = await _googleSignIn.signInSilently();
      }
      return user?.photoUrl;
    } catch (_) {
      return null;
    }
  }

  /// Whether we currently have a stored token.
  Future<bool> get isAuthenticated => _apiClient.hasToken;

  // ── Helpers ────────────────────────────────────────────────────────────────

  model.AuthUser _userFromApiMap(Map<String, dynamic> user) {
    return model.AuthUser(
      id: user['id'] as String? ?? user['_id'] as String? ?? '',
      username: user['username'] as String? ?? 'user',
      email: user['email'] as String?,
      phone: user['phone'] as String?,
      fullName: user['full_name'] as String?,
      dateOfBirth: user['date_of_birth'] != null
          ? DateTime.tryParse(user['date_of_birth'] as String)
          : null,
      isUnder18: user['is_under_18'] as bool? ?? false,
      avatarUrl: user['avatar_url'] as String?,
      bio: user['bio'] as String?,
      isActive: true,
      createdAt: user['createdAt'] != null
          ? DateTime.parse(user['createdAt'] as String)
          : DateTime.now(),
      updatedAt: user['updatedAt'] != null
          ? DateTime.parse(user['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  /// Internal password used for Google-based accounts so we can integrate
  /// with the REST API's email+password contract without exposing a
  /// separate password to the user.
  String _googlePasswordForEmail(String email) {
    return 'google-oauth-$email';
  }

  String _generateSessionToken() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
        (1000 + Random().nextInt(9000)).toString();
  }
}
