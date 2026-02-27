import 'api_client.dart';
import '../config/api_config.dart';

/// REST API wrapper for upload endpoints.
///
/// Endpoints:
///   POST /upload             – Upload a single file (protected, multipart/form-data)
///   POST /upload/thumbnail   – Upload thumbnail image(s) for reels
class UploadApi {
  static final UploadApi _instance = UploadApi._internal();
  factory UploadApi() => _instance;
  UploadApi._internal();

  final ApiClient _client = ApiClient();

  String get _path {
    final base =
        ApiConfig.baseUrl.toLowerCase().trim().replaceAll(RegExp(r'\/+$'), '');
    final endsWithApi = base.endsWith('/api');
    return endsWithApi ? '/upload' : '/api/upload';
  }

  String get _thumbnailPath {
    final base =
        ApiConfig.baseUrl.toLowerCase().trim().replaceAll(RegExp(r'\/+$'), '');
    final endsWithApi = base.endsWith('/api');
    return endsWithApi ? '/upload/thumbnail' : '/api/upload/thumbnail';
  }

  /// Upload a file from a local path.
  ///
  /// Returns `{ fileName: String, fileUrl: String }`.
  Future<Map<String, dynamic>> uploadFile(String filePath) async {
    final res = await _client.multipartPost(
      _path,
      filePath: filePath,
      fileField: 'file',
    );
    return res as Map<String, dynamic>;
  }

  /// Upload a file from raw bytes (e.g. from image picker).
  ///
  /// Returns `{ fileName: String, fileUrl: String }`.
  Future<Map<String, dynamic>> uploadFileBytes({
    required List<int> bytes,
    required String filename,
  }) async {
    final res = await _client.multipartPostBytes(
      _path,
      bytes: bytes,
      filename: filename,
      fileField: 'file',
    );
    return res as Map<String, dynamic>;
  }

  /// Upload a thumbnail image (JPEG/PNG) for a reel.
  ///
  /// Mirrors the web client's `/api/upload/thumbnail` usage.
  /// Returns `{ thumbnails: [...] }`.
  Future<Map<String, dynamic>> uploadThumbnailBytes({
    required List<int> bytes,
    required String filename,
  }) async {
    final res = await _client.multipartPostBytes(
      _thumbnailPath,
      bytes: bytes,
      filename: filename,
      fileField: 'file',
    );
    return res as Map<String, dynamic>;
  }
}
