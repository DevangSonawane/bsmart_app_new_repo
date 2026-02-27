import 'api_client.dart';
import '../config/api_config.dart';

/// REST API wrapper for `/posts/reels` endpoints.
///
/// Endpoints:
///   POST /posts/reels          – Create a new reel (protected)
///   GET  /posts/reels          – List reels (protected, paginated)
///   GET  /posts/reels/{id}     – Get a reel by ID (protected)
class ReelsApi {
  static final ReelsApi _instance = ReelsApi._internal();
  factory ReelsApi() => _instance;
  ReelsApi._internal();

  final ApiClient _client = ApiClient();

  String get _basePath {
    final base =
        ApiConfig.baseUrl.toLowerCase().trim().replaceAll(RegExp(r'\/+$'), '');
    final endsWithApi = base.endsWith('/api');
    return endsWithApi ? '' : '/api';
  }

  /// Create a new reel.
  ///
  /// [media] is a list of media items matching the web payload:
  /// `{ fileName, type, fileUrl, timing?, thumbnail?, ... }`.
  Future<Map<String, dynamic>> createReel({
    required List<Map<String, dynamic>> media,
    String? caption,
    String? location,
    List<String>? tags,
    List<Map<String, dynamic>>? peopleTags,
    bool? hideLikesCount,
    bool? turnOffCommenting,
  }) async {
    final body = <String, dynamic>{
      'media': media,
    };
    if (caption != null) body['caption'] = caption;
    if (location != null) body['location'] = location;
    if (tags != null && tags.isNotEmpty) body['tags'] = tags;
    if (peopleTags != null && peopleTags.isNotEmpty) {
      body['people_tags'] = peopleTags;
    }
    if (hideLikesCount != null) body['hide_likes_count'] = hideLikesCount;
    if (turnOffCommenting != null) {
      body['turn_off_commenting'] = turnOffCommenting;
    }

    final res = await _client.post('$_basePath/posts/reels', body: body);
    return res as Map<String, dynamic>;
  }

  /// List reels (optionally paginated).
  Future<dynamic> listReels({int page = 1, int limit = 20}) async {
    final res = await _client.get(
      '$_basePath/posts/reels',
      queryParams: {
        'page': page.toString(),
        'limit': limit.toString(),
      },
    );
    return res;
  }

  /// Get a single reel by ID.
  Future<Map<String, dynamic>> getReel(String id) async {
    final res = await _client.get('$_basePath/posts/reels/$id');
    return res as Map<String, dynamic>;
  }
}

