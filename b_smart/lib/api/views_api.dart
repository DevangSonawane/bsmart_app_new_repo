import 'api_client.dart';
import '../config/api_config.dart';

/// REST API wrapper for reel view tracking endpoints.
///
/// Endpoints (from API audit):
/// - POST /views           Add a view for a reel
/// - POST /views/complete  Complete a view for a reel and reward user
class ViewsApi {
  static final ViewsApi _instance = ViewsApi._internal();
  factory ViewsApi() => _instance;
  ViewsApi._internal();

  final ApiClient _client = ApiClient();

  String get _basePath {
    final base =
        ApiConfig.baseUrl.toLowerCase().trim().replaceAll(RegExp(r'\/+$'), '');
    final endsWithApi = base.endsWith('/api');
    return endsWithApi ? '' : '/api';
  }

  /// Record a reel view start.
  ///
  /// Backend payload shapes vary; this sends common key names so server can
  /// accept either `{ reelId }`, `{ reel_id }`, or `{ postId }` styles.
  Future<Map<String, dynamic>> addView({
    required String reelId,
    Map<String, dynamic>? extra,
  }) async {
    final id = reelId.trim();
    if (id.isEmpty) throw ArgumentError('reelId cannot be empty');
    final res = await _client.post(
      '$_basePath/views',
      body: <String, dynamic>{
        'reelId': id,
        'reel_id': id,
        'postId': id,
        if (extra != null && extra.isNotEmpty) ...extra,
      },
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  /// Mark a reel view as complete (eligible for reward).
  Future<Map<String, dynamic>> complete({
    required String reelId,
    int? watchedMs,
    Map<String, dynamic>? extra,
  }) async {
    final id = reelId.trim();
    if (id.isEmpty) throw ArgumentError('reelId cannot be empty');
    final body = <String, dynamic>{
      'reelId': id,
      'reel_id': id,
      'postId': id,
      if (watchedMs != null) 'watchedMs': watchedMs,
      if (watchedMs != null) 'watchDurationMs': watchedMs,
      if (watchedMs != null) 'durationMs': watchedMs,
      if (extra != null && extra.isNotEmpty) ...extra,
    };
    final res = await _client.post('$_basePath/views/complete', body: body);
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }
}

