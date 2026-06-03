import 'api_client.dart';
import '../config/api_config.dart';
import 'upload_api.dart';

/// REST API wrapper for `/tweets` endpoints.
///
/// Endpoints (parity with React web):
///   POST   /tweets             – Create tweet (protected)
///   GET    /tweets/:id         – Get single tweet (protected)
///   DELETE /tweets/:id         – Delete tweet (protected)
///   POST   /tweets/:id/like    – Like tweet (protected)
///   POST   /tweets/:id/unlike  – Unlike tweet (protected)
///   POST   /upload/tweet       – Upload tweet media (protected, multipart/form-data)
class TweetsApi {
  static final TweetsApi _instance = TweetsApi._internal();
  factory TweetsApi() => _instance;
  TweetsApi._internal();

  final ApiClient _client = ApiClient();

  String get _basePath {
    final base =
        ApiConfig.baseUrl.toLowerCase().trim().replaceAll(RegExp(r'\/+$'), '');
    final endsWithApi = base.endsWith('/api');
    return endsWithApi ? '' : '/api';
  }

  Future<Map<String, dynamic>> createTweet({
    required String content,
    List<Map<String, dynamic>>? media,
    String audience = 'everyone',
  }) async {
    final body = <String, dynamic>{
      'content': content,
      'audience': audience,
    };
    if (media != null && media.isNotEmpty) body['media'] = media;
    final res = await _client.post('$_basePath/tweets', body: body);
    return res as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getTweet(String tweetId) async {
    final res = await _client.get('$_basePath/tweets/$tweetId');
    return res as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> deleteTweet(String tweetId) async {
    final res = await _client.delete('$_basePath/tweets/$tweetId');
    return res as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> likeTweet(String tweetId) async {
    final res = await _client.post('$_basePath/tweets/$tweetId/like');
    return res as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> unlikeTweet(String tweetId) async {
    final res = await _client.post('$_basePath/tweets/$tweetId/unlike');
    return res as Map<String, dynamic>;
  }

  /// Upload tweet media. Returns backend payload (shape may vary).
  Future<Map<String, dynamic>> uploadTweetMediaBytes({
    required List<int> bytes,
    required String filename,
  }) async {
    return UploadApi().uploadTweetBytes(
      bytes: bytes,
      filename: filename,
    );
  }
}
