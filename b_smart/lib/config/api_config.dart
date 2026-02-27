/// REST API configuration values.
///
/// Call `ApiConfig.init(...)` early in `main()` (after loading any env files)
/// to override defaults. The base URL should point to the deployed backend,
/// e.g. `https://bsmart.asynk.store/api`.
class ApiConfig {
  // Use HTTPS to avoid 301 redirects from the server.
  static String _baseUrl = 'https://bsmart.asynk.store/api';
  static Duration _timeout = const Duration(seconds: 30);

  /// Initialize runtime values (call after loading dotenv in `main()`).
  static void init({
    String? baseUrl,
    Duration? timeout,
  }) {
    if (baseUrl != null && baseUrl.isNotEmpty) _baseUrl = baseUrl;
    if (timeout != null) _timeout = timeout;
  }

  /// The REST API base URL (e.g. `http://localhost:5000/api`).
  static String get baseUrl => _baseUrl;

  /// HTTP request timeout.
  static Duration get timeout => _timeout;
}
