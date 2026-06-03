import 'api_client.dart';
import '../config/api_config.dart';

/// REST API wrapper for upload endpoints.
///
/// Endpoints:
///   POST /upload/story       – Upload story media
///   POST /upload/post        – Upload post media
///   POST /upload/reel        – Upload reel media
///   POST /upload/promote     – Upload promoted reel media
///   POST /upload/tweet       – Upload tweet media
///   POST /upload/avatar      – Upload avatar image
///   POST /upload/thumbnail   – Upload reel thumbnail image(s)
class UploadApi {
  static final UploadApi _instance = UploadApi._internal();
  factory UploadApi() => _instance;
  UploadApi._internal();

  final ApiClient _client = ApiClient();

  String _pathFor(String segment) {
    final base =
        ApiConfig.baseUrl.toLowerCase().trim().replaceAll(RegExp(r'\/+$'), '');
    final endsWithApi = base.endsWith('/api');
    return endsWithApi ? '/upload/$segment' : '/api/upload/$segment';
  }

  String get _genericPath {
    final base =
        ApiConfig.baseUrl.toLowerCase().trim().replaceAll(RegExp(r'\/+$'), '');
    final endsWithApi = base.endsWith('/api');
    return endsWithApi ? '/upload' : '/api/upload';
  }

  Future<Map<String, dynamic>> _uploadBytes(
    String path, {
    required List<int> bytes,
    required String filename,
    String fileField = 'file',
  }) async {
    final res = await _client.multipartPostBytes(
      path,
      bytes: bytes,
      filename: filename,
      fileField: fileField,
    );
    return (res as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> _uploadFile(
    String path, {
    required String filePath,
    String fileField = 'file',
  }) async {
    final res = await _client.multipartPost(
      path,
      filePath: filePath,
      fileField: fileField,
    );
    return (res as Map).cast<String, dynamic>();
  }

  /// Upload a story media file.
  Future<Map<String, dynamic>> uploadStoryBytes({
    required List<int> bytes,
    required String filename,
  }) async {
    return _uploadBytes(
      _pathFor('story'),
      bytes: bytes,
      filename: filename,
    );
  }

  Future<Map<String, dynamic>> uploadStoryFile(String filePath) async {
    return _uploadFile(_pathFor('story'), filePath: filePath);
  }

  /// Upload a post media file.
  Future<Map<String, dynamic>> uploadPostBytes({
    required List<int> bytes,
    required String filename,
  }) async {
    return _uploadBytes(
      _pathFor('post'),
      bytes: bytes,
      filename: filename,
    );
  }

  Future<Map<String, dynamic>> uploadPostFile(String filePath) async {
    return _uploadFile(_pathFor('post'), filePath: filePath);
  }

  /// Upload a reel media file.
  Future<Map<String, dynamic>> uploadReelBytes({
    required List<int> bytes,
    required String filename,
  }) async {
    return _uploadBytes(
      _pathFor('reel'),
      bytes: bytes,
      filename: filename,
    );
  }

  Future<Map<String, dynamic>> uploadReelFile(String filePath) async {
    return _uploadFile(_pathFor('reel'), filePath: filePath);
  }

  /// Upload a promoted reel media file.
  Future<Map<String, dynamic>> uploadPromoteBytes({
    required List<int> bytes,
    required String filename,
  }) async {
    return _uploadBytes(
      _pathFor('promote'),
      bytes: bytes,
      filename: filename,
    );
  }

  Future<Map<String, dynamic>> uploadPromoteFile(String filePath) async {
    return _uploadFile(_pathFor('promote'), filePath: filePath);
  }

  /// Upload a tweet media file.
  Future<Map<String, dynamic>> uploadTweetBytes({
    required List<int> bytes,
    required String filename,
  }) async {
    return _uploadBytes(
      _pathFor('tweet'),
      bytes: bytes,
      filename: filename,
    );
  }

  Future<Map<String, dynamic>> uploadTweetFile(String filePath) async {
    return _uploadFile(_pathFor('tweet'), filePath: filePath);
  }

  /// Backward-compatible generic upload helper.
  ///
  /// Prefer the explicit `uploadStory*`, `uploadPost*`, `uploadReel*`,
  /// `uploadPromote*`, or `uploadTweet*` methods for new code.
  Future<Map<String, dynamic>> uploadFile(String filePath) async {
    return _uploadFile(_genericPath, filePath: filePath);
  }

  /// Backward-compatible generic upload helper.
  Future<Map<String, dynamic>> uploadFileBytes({
    required List<int> bytes,
    required String filename,
  }) async {
    return _uploadBytes(
      _genericPath,
      bytes: bytes,
      filename: filename,
    );
  }

  /// Upload a thumbnail image (JPEG/PNG) for a reel.
  ///
  /// Mirrors the web client's `/api/upload/thumbnail` usage.
  /// Returns `{ thumbnails: [...] }`.
  Future<Map<String, dynamic>> uploadThumbnailBytes({
    required List<int> bytes,
    required String filename,
  }) async {
    return _uploadBytes(
      _pathFor('thumbnail'),
      bytes: bytes,
      filename: filename,
    );
  }

  /// Upload a cropped avatar image.
  ///
  /// Mirrors the web client's `/api/upload/avatar` usage.
  /// Returns `{ avatar_url: String }` or `{ url: String }` depending on backend.
  Future<Map<String, dynamic>> uploadAvatarBytes({
    required List<int> bytes,
    required String filename,
  }) async {
    return _uploadBytes(
      _pathFor('avatar'),
      bytes: bytes,
      filename: filename,
    );
  }
}
