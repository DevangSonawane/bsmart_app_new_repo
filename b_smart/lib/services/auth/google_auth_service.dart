// Mock Google Auth Service for development
// Replace with real Google Sign-In implementation when ready

class GoogleAuthService {
  static final GoogleAuthService _instance = GoogleAuthService._internal();
  factory GoogleAuthService() => _instance;

  GoogleAuthService._internal();

  // Mock Google sign-in
  Future<GoogleAuthResult> signIn() async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    // Mock successful sign-in
    return GoogleAuthResult(
      idToken: 'mock_google_id_token_${DateTime.now().millisecondsSinceEpoch}',
      accessToken: 'mock_google_access_token',
      email: 'mockuser@gmail.com',
      name: 'Mock Google User',
      photoUrl: null,
    );
  }

  // Sign out
  Future<void> signOut() async {
    // Mock sign out
    await Future.delayed(const Duration(milliseconds: 100));
  }
}

class GoogleAuthResult {
  final String idToken;
  final String accessToken;
  final String email;
  final String name;
  final String? photoUrl;

  GoogleAuthResult({
    required this.idToken,
    required this.accessToken,
    required this.email,
    required this.name,
    this.photoUrl,
  });
}
