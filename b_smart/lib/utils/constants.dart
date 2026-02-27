class AuthConstants {
  // Token expiry times
  static const Duration accessTokenExpiry = Duration(minutes: 15);
  static const Duration refreshTokenExpiry = Duration(days: 30);

  // OTP settings
  static const Duration otpExpiry = Duration(minutes: 10);
  static const int otpLength = 6;
  static const int maxOtpAttempts = 3;
  static const Duration otpResendCooldown = Duration(minutes: 1);

  // Signup session expiry
  static const Duration signupSessionExpiry = Duration(hours: 24);

  // Rate limiting
  static const int maxLoginAttempts = 5;
  static const Duration loginAttemptWindow = Duration(minutes: 15);
  static const int maxUsernameCheckAttempts = 10;
  static const Duration usernameCheckCooldown = Duration(seconds: 1);

  // Password requirements
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 128;

  // Username requirements
  static const int minUsernameLength = 3;
  static const int maxUsernameLength = 30;

  // Age restrictions
  static const int minimumAge = 13;
  static const int restrictedAge = 18;

  // Storage keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String deviceIdKey = 'device_id';
  static const String userIdKey = 'user_id';
  static const String signupSessionKey = 'signup_session';

  // Error messages
  static const String networkError = 'Network error. Please check your connection.';
  static const String serverError = 'Server error. Please try again later.';
  static const String invalidCredentials = 'Invalid email or password.';
  static const String userNotFound = 'User not found.';
  static const String usernameTaken = 'This username is already taken.';
  static const String emailExists = 'An account with this email already exists.';
  static const String phoneExists = 'An account with this phone number already exists.';
  static const String invalidOTP = 'Invalid OTP. Please try again.';
  static const String otpExpired = 'OTP has expired. Please request a new one.';
  static const String sessionExpired = 'Session expired. Please start again.';
  static const String tokenExpired = 'Your session has expired. Please login again.';
}
