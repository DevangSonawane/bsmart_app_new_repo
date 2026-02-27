import '../../utils/constants.dart';

class OTPService {
  static final OTPService _instance = OTPService._internal();
  factory OTPService() => _instance;

  final Map<String, DateTime> _lastOtpSent = {};
  final Map<String, int> _otpAttempts = {};
  final Map<String, String> _sessionOtps = {}; // sessionToken -> OTP code
  final Map<String, String> _identifierToSession = {}; // identifier -> sessionToken

  // Mock OTP code for testing (always "123456")
  static const String _mockOtpCode = '123456';

  OTPService._internal();

  // Send OTP via email
  Future<bool> sendEmailOTP(String email, {String? sessionToken}) async {
    try {
      // Check rate limiting
      if (_isRateLimited(email)) {
        throw Exception('Please wait before requesting another OTP');
      }

      // Store OTP for this session (mock - always use "123456")
      if (sessionToken != null) {
        _sessionOtps[sessionToken] = _mockOtpCode;
        _identifierToSession[email] = sessionToken;
      }

      _lastOtpSent[email] = DateTime.now();
      // In a real app, you would send the OTP via email here
      // For mock, we just store it and the user can enter "123456"
      return true;
    } catch (e) {
      rethrow;
    }
  }

  // Send OTP via phone
  Future<bool> sendPhoneOTP(String phone, {String? sessionToken}) async {
    try {
      // Check rate limiting
      if (_isRateLimited(phone)) {
        throw Exception('Please wait before requesting another OTP');
      }

      // Store OTP for this session (mock - always use "123456")
      if (sessionToken != null) {
        _sessionOtps[sessionToken] = _mockOtpCode;
        _identifierToSession[phone] = sessionToken;
      }

      _lastOtpSent[phone] = DateTime.now();
      // In a real app, you would send the OTP via SMS here
      // For mock, we just store it and the user can enter "123456"
      return true;
    } catch (e) {
      rethrow;
    }
  }

  // Verify OTP for signup session
  Future<bool> verifyOTP(String sessionToken, String otp) async {
    try {
      // Get stored OTP for this session
      final storedOtp = _sessionOtps[sessionToken];
      if (storedOtp == null) {
        throw Exception('Invalid session');
      }

      // Verify OTP (mock - always accept "123456")
      if (otp == storedOtp || otp == _mockOtpCode) {
        // Clear attempts on success
        final sessionTokenForIdentifier = _identifierToSession.entries
            .firstWhere((e) => e.value == sessionToken, orElse: () => MapEntry('', ''));
        if (sessionTokenForIdentifier.key.isNotEmpty) {
          _otpAttempts[sessionTokenForIdentifier.key] = 0;
        }
        return true;
      }

      // Increment attempts
      final sessionTokenForIdentifier = _identifierToSession.entries
          .firstWhere((e) => e.value == sessionToken, orElse: () => MapEntry('', ''));
      if (sessionTokenForIdentifier.key.isNotEmpty) {
        _otpAttempts[sessionTokenForIdentifier.key] = 
            (_otpAttempts[sessionTokenForIdentifier.key] ?? 0) + 1;

        // Check if max attempts reached
        if ((_otpAttempts[sessionTokenForIdentifier.key] ?? 0) >= AuthConstants.maxOtpAttempts) {
          throw Exception('Maximum OTP attempts reached. Please start again.');
        }
      }

      return false;
    } catch (e) {
      rethrow;
    }
  }

  // Resend OTP
  Future<bool> resendOTP(String sessionToken) async {
    try {
      // Find identifier for this session
      final entry = _identifierToSession.entries
          .firstWhere((e) => e.value == sessionToken, orElse: () => MapEntry('', ''));
      
      if (entry.key.isEmpty) {
        throw Exception('Invalid session');
      }

      final identifier = entry.key;

      // Check cooldown
      final lastSent = _lastOtpSent[identifier];
      if (lastSent != null) {
        final timeSinceLastSent = DateTime.now().difference(lastSent);
        if (timeSinceLastSent < AuthConstants.otpResendCooldown) {
          final remainingSeconds = 
              (AuthConstants.otpResendCooldown - timeSinceLastSent).inSeconds;
          throw Exception(
              'Please wait $remainingSeconds seconds before requesting another OTP');
        }
      }

      // Resend OTP (determine if email or phone by checking format)
      if (identifier.contains('@')) {
        return await sendEmailOTP(identifier, sessionToken: sessionToken);
      } else {
        return await sendPhoneOTP(identifier, sessionToken: sessionToken);
      }
    } catch (e) {
      rethrow;
    }
  }

  // Check rate limiting
  bool _isRateLimited(String identifier) {
    final lastSent = _lastOtpSent[identifier];
    if (lastSent == null) return false;

    final timeSinceLastSent = DateTime.now().difference(lastSent);
    return timeSinceLastSent < AuthConstants.otpResendCooldown;
  }

  // Clear OTP attempts (called after successful verification)
  void clearAttempts(String identifier) {
    _otpAttempts.remove(identifier);
    _lastOtpSent.remove(identifier);
  }
}
