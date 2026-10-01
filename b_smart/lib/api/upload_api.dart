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
  static const Duration _videoUploadTimeout = Duration(minutes: 2);

  String _pathFor(String segment) {
    final base =
        ApiConfig.baseUrl.toLowerCase().trim().replaceAll(RegExp(r'\/+$'), '');
    final endsWithApi = base.endsWith('/api');
    return endsWithApi ? '/upload/$segment' : '/api/upload/$segment';
  }

  bool _looksLikeVideo(String name) {
    final n = name.toLowerCase();
    return n.endsWith('.mp4') ||
        n.endsWith('.mov') ||
        n.endsWith('.m4v') ||
        n.endsWith('.3gp') ||
        n.endsWith('.webm') ||
        n.endsWith('.mkv');
  }

  Duration _timeoutForFilename(String name) {
    return _looksLikeVideo(name) ? _videoUploadTimeout : ApiConfig.timeout;
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
    Duration? timeout,
    UploadProgressCallback? onSendProgress,
  }) async {
    final res = await _client.multipartPostBytes(
      path,
      bytes: bytes,
      filename: filename,
      fileField: fileField,
      timeout: timeout,
      onSendProgress: onSendProgress,
    );
    return (res as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> _uploadFile(
    String path, {
    required String filePath,
    String fileField = 'file',
    Duration? timeout,
    UploadProgressCallback? onSendProgress,
  }) async {
    final res = await _client.multipartPost(
      path,
      filePath: filePath,
      fileField: fileField,
      timeout: timeout,
      onSendProgress: onSendProgress,
    );
    return (res as Map).cast<String, dynamic>();
  }

  /// Upload a story media file.
  Future<Map<String, dynamic>> uploadStoryBytes({
    required List<int> bytes,
    required String filename,
    UploadProgressCallback? onSendProgress,
  }) async {
    return _uploadBytes(
      _pathFor('story'),
      bytes: bytes,
      filename: filename,
      timeout: _timeoutForFilename(filename),
      onSendProgress: onSendProgress,
    );
  }

  Future<Map<String, dynamic>> uploadStoryFile(String filePath) async {
    return _uploadFile(
      _pathFor('story'),
      filePath: filePath,
      timeout: _timeoutForFilename(filePath),
    );
  }

  /// Upload a post media file.
  Future<Map<String, dynamic>> uploadPostBytes({
    required List<int> bytes,
    required String filename,
    UploadProgressCallback? onSendProgress,
  }) async {
    return _uploadBytes(
      _pathFor('post'),
      bytes: bytes,
      filename: filename,
      timeout: _timeoutForFilename(filename),
      onSendProgress: onSendProgress,
    );
  }

  Future<Map<String, dynamic>> uploadPostFile(String filePath) async {
    return _uploadFile(
      _pathFor('post'),
      filePath: filePath,
      timeout: _timeoutForFilename(filePath),
    );
  }

  /// Upload a reel media file.
  Future<Map<String, dynamic>> uploadReelBytes({
    required List<int> bytes,
    required String filename,
    UploadProgressCallback? onSendProgress,
  }) async {
    return _uploadBytes(
      _pathFor('reel'),
      bytes: bytes,
      filename: filename,
      timeout: _timeoutForFilename(filename),
      onSendProgress: onSendProgress,
    );
  }

  Future<Map<String, dynamic>> uploadReelFile(String filePath) async {
    return _uploadFile(
      _pathFor('reel'),
      filePath: filePath,
      timeout: _timeoutForFilename(filePath),
    );
  }

  /// Upload a promoted reel media file.
  Future<Map<String, dynamic>> uploadPromoteBytes({
    required List<int> bytes,
    required String filename,
    UploadProgressCallback? onSendProgress,
  }) async {
    return _uploadBytes(
      _pathFor('promote'),
      bytes: bytes,
      filename: filename,
      timeout: _timeoutForFilename(filename),
      onSendProgress: onSendProgress,
    );
  }

  Future<Map<String, dynamic>> uploadPromoteFile(String filePath) async {
    return _uploadFile(
      _pathFor('promote'),
      filePath: filePath,
      timeout: _timeoutForFilename(filePath),
    );
  }

  /// Upload a promoted product image.
  Future<Map<String, dynamic>> uploadPromoteProductBytes({
    required List<int> bytes,
    required String filename,
    UploadProgressCallback? onSendProgress,
  }) async {
    return _uploadBytes(
      _pathFor('promote-product'),
      bytes: bytes,
      filename: filename,
      timeout: _timeoutForFilename(filename),
      onSendProgress: onSendProgress,
    );
  }

  Future<Map<String, dynamic>> uploadPromoteProductFile(String filePath) async {
    return _uploadFile(
      _pathFor('promote-product'),
      filePath: filePath,
      timeout: _timeoutForFilename(filePath),
    );
  }

  /// Upload a tweet media file.
  Future<Map<String, dynamic>> uploadTweetBytes({
    required List<int> bytes,
    required String filename,
    UploadProgressCallback? onSendProgress,
  }) async {
    return _uploadBytes(
      _pathFor('tweet'),
      bytes: bytes,
      filename: filename,
      timeout: _timeoutForFilename(filename),
      onSendProgress: onSendProgress,
    );
  }

  Future<Map<String, dynamic>> uploadTweetFile(String filePath) async {
    return _uploadFile(
      _pathFor('tweet'),
      filePath: filePath,
      timeout: _timeoutForFilename(filePath),
    );
  }

  /// Backward-compatible generic upload helper.
  ///
  /// Prefer the explicit `uploadStory*`, `uploadPost*`, `uploadReel*`,
  /// `uploadPromote*`, or `uploadTweet*` methods for new code.
  Future<Map<String, dynamic>> uploadFile(String filePath) async {
    return _uploadFile(
      _genericPath,
      filePath: filePath,
      timeout: _timeoutForFilename(filePath),
    );
  }

  /// Backward-compatible generic upload helper.
  Future<Map<String, dynamic>> uploadFileBytes({
    required List<int> bytes,
    required String filename,
    UploadProgressCallback? onSendProgress,
  }) async {
    return _uploadBytes(
      _genericPath,
      bytes: bytes,
      filename: filename,
      timeout: _timeoutForFilename(filename),
      onSendProgress: onSendProgress,
    );
  }

  /// Upload a thumbnail image (JPEG/PNG) for a reel.
  ///
  /// Mirrors the web client's `/api/upload/thumbnail` usage.
  /// Returns `{ thumbnails: [...] }`.
  Future<Map<String, dynamic>> uploadThumbnailBytes({
    required List<int> bytes,
    required String filename,
    UploadProgressCallback? onSendProgress,
  }) async {
    return _uploadBytes(
      _pathFor('thumbnail'),
      bytes: bytes,
      filename: filename,
      timeout: _timeoutForFilename(filename),
      onSendProgress: onSendProgress,
    );
  }

  /// Upload a cropped avatar image.
  ///
  /// Mirrors the web client's `/api/upload/avatar` usage.
  /// Returns `{ avatar_url: String }` or `{ url: String }` depending on backend.
  Future<Map<String, dynamic>> uploadAvatarBytes({
    required List<int> bytes,
    required String filename,
    UploadProgressCallback? onSendProgress,
  }) async {
    return _uploadBytes(
      _pathFor('avatar'),
      bytes: bytes,
      filename: filename,
      timeout: _timeoutForFilename(filename),
      onSendProgress: onSendProgress,
    );
  }

  /// Upload one or more images for an influencer product listing.
  ///
  /// POST multipart `/upload/influencer-product` with every file under the
  /// `files` field. Returns the real fileName/fileUrl pairs — drop them
  /// straight into POST `/influencer-products`' `images` field. The backend
  /// rejects anything that isn't a real image.
  Future<List<UploadedImage>> uploadInfluencerProductImages({
    List<String>? filePaths,
    List<MultipartBytesFile>? byteFiles,
    UploadProgressCallback? onSendProgress,
  }) {
    return _uploadInfluencerImages(
      _pathFor('influencer-product'),
      filePaths: filePaths,
      byteFiles: byteFiles,
      onSendProgress: onSendProgress,
    );
  }

  /// Upload one or more images for an influencer service listing.
  ///
  /// POST multipart `/upload/influencer-service` with every file under the
  /// `files` field. Returns the real fileName/fileUrl pairs — drop them
  /// straight into POST `/influencer-services`' `images` field.
  Future<List<UploadedImage>> uploadInfluencerServiceImages({
    List<String>? filePaths,
    List<MultipartBytesFile>? byteFiles,
    UploadProgressCallback? onSendProgress,
  }) {
    return _uploadInfluencerImages(
      _pathFor('influencer-service'),
      filePaths: filePaths,
      byteFiles: byteFiles,
      onSendProgress: onSendProgress,
    );
  }

  Future<List<UploadedImage>> _uploadInfluencerImages(
    String path, {
    List<String>? filePaths,
    List<MultipartBytesFile>? byteFiles,
    UploadProgressCallback? onSendProgress,
  }) async {
    final paths = filePaths ?? const <String>[];
    final files = byteFiles ?? const <MultipartBytesFile>[];
    if (paths.isEmpty && files.isEmpty) {
      throw ArgumentError('No files selected for upload.');
    }
    dynamic res;
    if (files.isNotEmpty) {
      res = await _client.multipartPostManyBytes(
        path,
        files: files,
        fileField: 'files',
        onSendProgress: onSendProgress,
      );
    } else {
      res = await _client.multipartPostManyPaths(
        path,
        filePaths: paths,
        fileField: 'files',
        onSendProgress: onSendProgress,
      );
    }
    final images = UploadedImage.listOf(res);
    if (images.isEmpty) {
      throw StateError('Upload succeeded but returned no images.');
    }
    return images;
  }
}

/// A real uploaded image: `{fileName, fileUrl}` as returned by the
/// influencer upload endpoints. Use [fileUrl] for display and for the
/// listing `images` payload.
/// Picks an upload filename for an image-picker result.
///
/// The server infers the multipart content type from the extension, so the
/// name must end in a known image extension; anything else becomes `.jpg`.
/// [name] is preferred because it survives `content://` URIs, which carry no
/// extension to copy from [path].
String influencerUploadFilename(String name, String path) {
  const known = ['.jpg', '.jpeg', '.png', '.webp', '.gif', '.heic'];
  final trimmed = name.trim().toLowerCase();
  for (final ext in known) {
    if (trimmed.endsWith(ext)) return trimmed;
  }
  final lowerPath = path.toLowerCase();
  for (final ext in known) {
    if (lowerPath.endsWith(ext)) return 'product_image$ext';
  }
  return 'product_image.jpg';
}

class UploadedImage {
  final String fileName;
  final String fileUrl;

  const UploadedImage({required this.fileName, required this.fileUrl});

  Map<String, String> toJson() => {'fileName': fileName, 'fileUrl': fileUrl};

  static List<UploadedImage> listOf(dynamic res) {
    final raw = _imagesOf(res);
    return raw.map((entry) {
      final fileUrl = entry['fileUrl'] ??
          entry['file_url'] ??
          entry['url'] ??
          entry['path'] ??
          '';
      final fileName = entry['fileName'] ??
          entry['file_name'] ??
          entry['filename'] ??
          fileUrl.toString().split('/').last;
      return UploadedImage(
        fileName: fileName.toString(),
        fileUrl: fileUrl.toString(),
      );
    }).where((img) => img.fileUrl.isNotEmpty).toList();
  }

  static List<Map<String, dynamic>> _imagesOf(dynamic res) {
    if (res is Map) {
      final map = res.map((k, v) => MapEntry(k.toString(), v));
      for (final key in ['images', 'data', 'files', 'result']) {
        final value = map[key];
        if (value is List) {
          final list = value
              .whereType<Map>()
              .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
              .toList();
          if (key != 'images') {
            // `data`/`result` may wrap the images list one level deeper.
            for (final entry in list) {
              final nested = entry['images'];
              if (nested is List) {
                return nested
                    .whereType<Map>()
                    .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
                    .toList();
              }
            }
          }
          if (list.isNotEmpty || key == 'images') return list;
        }
        if (value is Map) {
          final nested = value.map((k, v) => MapEntry(k.toString(), v));
          final images = nested['images'];
          if (images is List) {
            return images
                .whereType<Map>()
                .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
                .toList();
          }
        }
      }
    }
    if (res is List) {
      return res
          .whereType<Map>()
          .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
          .toList();
    }
    return const [];
  }
}