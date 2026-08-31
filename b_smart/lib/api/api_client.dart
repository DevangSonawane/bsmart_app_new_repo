import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';
import '../services/connectivity_service.dart';
import 'api_exceptions.dart';

typedef UploadProgressCallback = void Function(int sentBytes, int totalBytes);

class MultipartBytesFile {
  final List<int> bytes;
  final String filename;

  const MultipartBytesFile({
    required this.bytes,
    required this.filename,
  });
}

/// Centralised HTTP client for the REST API.
///
/// * Automatically attaches the stored JWT Bearer token.
/// * Parses responses and throws typed [ApiException] subclasses.
/// * Provides convenience helpers: [get], [post], [put], [delete], [multipartPost].
class ApiClient {
  // ── Singleton ──────────────────────────────────────────────────────────────
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  final http.Client _http = http.Client();
  late final FlutterSecureStorage _storage;
  final Map<String, String> _memoryStorage = {};

  /// In-memory cached token so we don't hit secure storage on every request.
  String? _cachedToken;

  ApiClient._internal() {
    if (kIsWeb) {
      _storage = const FlutterSecureStorage(
        webOptions: WebOptions(
          dbName: 'b_smart_secure',
          publicKey: 'b_smart_api',
        ),
      );
    } else {
      _storage = const FlutterSecureStorage();
    }
  }

  // ── Token management ───────────────────────────────────────────────────────

  static const String _tokenKey = 'api_jwt_token';

  /// Persist the JWT returned by `/auth/login` or `/auth/register`.
  Future<void> saveToken(String token) async {
    _cachedToken = token;
    try {
      await _storage.write(key: _tokenKey, value: token);
    } catch (_) {
      _memoryStorage[_tokenKey] = token;
    }
  }

  /// Retrieve the stored JWT (from cache → secure storage → memory fallback).
  Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;
    try {
      _cachedToken =
          await _storage.read(key: _tokenKey) ?? _memoryStorage[_tokenKey];
    } catch (_) {
      _cachedToken = _memoryStorage[_tokenKey];
    }
    return _cachedToken;
  }

  /// Clear stored JWT (logout).
  Future<void> clearToken() async {
    _cachedToken = null;
    try {
      await _storage.delete(key: _tokenKey);
    } catch (_) {}
    _memoryStorage.remove(_tokenKey);
  }

  /// Whether we currently hold a token.
  Future<bool> get hasToken async => (await getToken()) != null;

  static const int _maxTransientRetries = 1;

  // ── Request helpers ────────────────────────────────────────────────────────

  Uri _uri(String path, [Map<String, String>? queryParams]) {
    final base = ApiConfig.baseUrl.endsWith('/')
        ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
        : ApiConfig.baseUrl;
    final fullPath = path.startsWith('/') ? '$base$path' : '$base/$path';
    return Uri.parse(fullPath).replace(queryParameters: queryParams);
  }

  Future<T> _withTransientRetry<T>(Future<T> Function() action) async {
    if (!await ConnectivityService.instance.isOnline()) {
      throw NetworkException(
        message:
            'You are offline. Please check your internet connection and try again.',
      );
    }
    Object? lastError;
    StackTrace? lastStack;
    for (var attempt = 0; attempt <= _maxTransientRetries; attempt++) {
      try {
        return await action();
      } catch (e, st) {
        lastError = e;
        lastStack = st;
        final retryable = e is SocketException || e is TimeoutException;
        if (!retryable || attempt >= _maxTransientRetries) {
          if (e is TimeoutException) {
            throw NetworkException(
              message:
                  'The connection is slow right now. Please try again in a moment.',
            );
          }
          if (e is SocketException) {
            throw NetworkException(
              message:
                  'No internet connection. Please check your connection and try again.',
            );
          }
          Error.throwWithStackTrace(e, st);
        }
        await Future.delayed(Duration(milliseconds: 350 * (attempt + 1)));
      }
    }
    if (lastError != null) {
      Error.throwWithStackTrace(lastError, lastStack ?? StackTrace.current);
    }
    throw NetworkException();
  }

  Future<Map<String, String>> _headers({
    bool json = true,
    Map<String, String>? extraHeaders,
  }) async {
    final headers = <String, String>{};
    headers['Accept'] = 'application/json';
    if (json) headers['Content-Type'] = 'application/json';
    final token = await getToken();
    if (token != null) headers['Authorization'] = 'Bearer $token';
    if (extraHeaders != null && extraHeaders.isNotEmpty) {
      headers.addAll(extraHeaders);
    }
    return headers;
  }

  // ── Public HTTP methods ────────────────────────────────────────────────────

  /// `GET <baseUrl>/<path>?queryParams`
  Future<dynamic> get(
    String path, {
    Map<String, String>? queryParams,
    Map<String, String>? extraHeaders,
  }) async {
    return _withTransientRetry(() async {
      final response = await _http
          .get(
            _uri(path, queryParams),
            headers: await _headers(extraHeaders: extraHeaders),
          )
          .timeout(ApiConfig.timeout);
      return _handleResponse(response);
    });
  }

  /// `POST <baseUrl>/<path>` with JSON body.
  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? extraHeaders,
  }) async {
    return _withTransientRetry(() async {
      final response = await _http
          .post(
            _uri(path),
            headers: await _headers(extraHeaders: extraHeaders),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(ApiConfig.timeout);
      if (path.contains('/auth/apple/token')) {
        debugPrint('[apple-sign-in] backend status code: ${response.statusCode}');
        debugPrint(
          '[apple-sign-in] backend response: ${_sanitizeAppleDebugBody(response.body)}',
        );
      }
      return _handleResponse(response);
    });
  }

  /// `PUT <baseUrl>/<path>` with JSON body.
  Future<dynamic> put(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? extraHeaders,
  }) async {
    return _withTransientRetry(() async {
      final response = await _http
          .put(
            _uri(path),
            headers: await _headers(extraHeaders: extraHeaders),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(ApiConfig.timeout);
      return _handleResponse(response);
    });
  }

  /// `PATCH <baseUrl>/<path>` with JSON body.
  Future<dynamic> patch(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? extraHeaders,
  }) async {
    return _withTransientRetry(() async {
      final response = await _http
          .patch(
            _uri(path),
            headers: await _headers(extraHeaders: extraHeaders),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(ApiConfig.timeout);
      return _handleResponse(response);
    });
  }

  /// `DELETE <baseUrl>/<path>`
  Future<dynamic> delete(String path,
      {Map<String, String>? extraHeaders}) async {
    return _withTransientRetry(() async {
      final response = await _http
          .delete(
            _uri(path),
            headers: await _headers(json: false, extraHeaders: extraHeaders),
          )
          .timeout(ApiConfig.timeout);
      return _handleResponse(response);
    });
  }

  /// Multipart `POST` for file uploads.
  ///
  /// [fileField] is the form field name (defaults to `"file"`).
  /// [filePath] is the local file path to upload.
  Future<dynamic> multipartPost(
    String path, {
    required String filePath,
    String fileField = 'file',
    Map<String, String>? fields,
    Duration? timeout,
    UploadProgressCallback? onSendProgress,
  }) async {
    return _withTransientRetry(() async {
      final request = http.MultipartRequest('POST', _uri(path));
      final token = await getToken();
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      if (fields != null) request.fields.addAll(fields);
      final filename = filePath.split(Platform.pathSeparator).last;
      final ct = _contentTypeForFilename(filename);
      request.files.add(await http.MultipartFile.fromPath(
        fileField,
        filePath,
        contentType: ct,
      ));
      final streamed = await _sendMultipartRequest(
        request,
        timeout: timeout ?? ApiConfig.timeout,
        onSendProgress: onSendProgress,
      );
      final response = await http.Response.fromStream(streamed);
      return _handleResponse(response);
    });
  }

  /// Multipart `POST` from bytes (useful for image picker results).
  Future<dynamic> multipartPostBytes(
    String path, {
    required List<int> bytes,
    required String filename,
    String fileField = 'file',
    Map<String, String>? fields,
    Map<String, String>? extraFields,
    Duration? timeout,
    UploadProgressCallback? onSendProgress,
  }) async {
    return _withTransientRetry(() async {
      final request = http.MultipartRequest('POST', _uri(path));
      final token = await getToken();
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      if (fields != null) request.fields.addAll(fields);
      if (extraFields != null) request.fields.addAll(extraFields);
      final ct = _contentTypeForFilename(filename);
      request.files.add(http.MultipartFile.fromBytes(
        fileField,
        bytes,
        filename: filename,
        contentType: ct,
      ));
      final streamed = await _sendMultipartRequest(
        request,
        timeout: timeout ?? ApiConfig.timeout,
        onSendProgress: onSendProgress,
      );
      final response = await http.Response.fromStream(streamed);
      return _handleResponse(response);
    });
  }

  /// Multipart `POST` from multiple files (as bytes).
  ///
  /// Matches the React web app behaviour: send multiple `fileField` parts.
  Future<dynamic> multipartPostManyBytes(
    String path, {
    required List<MultipartBytesFile> files,
    String fileField = 'file',
    Map<String, String>? fields,
    Map<String, String>? extraFields,
    Duration? timeout,
    UploadProgressCallback? onSendProgress,
  }) async {
    if (files.isEmpty) return <String, dynamic>{};
    return _withTransientRetry(() async {
      final request = http.MultipartRequest('POST', _uri(path));
      final token = await getToken();
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      if (fields != null) request.fields.addAll(fields);
      if (extraFields != null) request.fields.addAll(extraFields);

      for (final f in files) {
        if (f.bytes.isEmpty) continue;
        final ct = _contentTypeForFilename(f.filename);
        request.files.add(http.MultipartFile.fromBytes(
          fileField,
          f.bytes,
          filename: f.filename,
          contentType: ct,
        ));
      }

      final streamed = await _sendMultipartRequest(
        request,
        timeout: timeout ?? ApiConfig.timeout,
        onSendProgress: onSendProgress,
      );
      final response = await http.Response.fromStream(streamed);
      return _handleResponse(response);
    });
  }

  Future<http.StreamedResponse> _sendMultipartRequest(
    http.MultipartRequest request, {
    required Duration timeout,
    UploadProgressCallback? onSendProgress,
  }) async {
    final totalBytes = request.contentLength;
    final body = request.finalize();
    final streamedRequest = http.StreamedRequest(request.method, request.url);
    streamedRequest.followRedirects = request.followRedirects;
    streamedRequest.maxRedirects = request.maxRedirects;
    streamedRequest.persistentConnection = request.persistentConnection;
    streamedRequest.headers.addAll(request.headers);
    streamedRequest.contentLength = totalBytes;

    int sentBytes = 0;
    final progressStream = body.transform(
      StreamTransformer<List<int>, List<int>>.fromHandlers(
        handleData: (chunk, sink) {
          sentBytes += chunk.length;
          onSendProgress?.call(sentBytes, totalBytes);
          sink.add(chunk);
        },
      ),
    );

    unawaited(streamedRequest.sink.addStream(progressStream).then((_) {
      return streamedRequest.sink.close();
    }));

    return _http.send(streamedRequest).timeout(timeout);
  }

  // ── Response handling ──────────────────────────────────────────────────────

  dynamic _handleResponse(http.Response response) {
    final dynamic decoded = _tryDecodeJson(response.body);
    final Map<String, dynamic>? body =
        decoded is Map<String, dynamic> ? decoded : null;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded ?? response.body;
    }

    // Extract detailed error message
    String? message = body?['message'] as String?;
    final error = body?['error'] as String?;

    if (message == null) {
      final raw = response.body.trim();
      final ct = response.headers['content-type'] ?? '';
      final isHtml = ct.contains('text/html') || _looksLikeHtml(raw);
      if (isHtml) {
        final title = _extractHtmlTitle(raw);
        message = title?.isNotEmpty == true
            ? title
            : (response.reasonPhrase ?? 'HTTP ${response.statusCode}');
      } else {
        message = raw.isNotEmpty
            ? raw
            : (error ?? response.reasonPhrase ?? 'Unknown error');
      }
    } else if (error != null && message != error) {
      // Append detailed error if available
      message = '$message: $error';
    }

    final safeMessage = message ?? (response.reasonPhrase ?? 'Unknown error');
    switch (response.statusCode) {
      case 400:
        throw BadRequestException(message: safeMessage, body: body);
      case 401:
        throw UnauthorizedException(message: safeMessage, body: body);
      case 403:
        throw ForbiddenException(message: safeMessage, body: body);
      case 404:
        throw NotFoundException(message: safeMessage, body: body);
      default:
        if (response.statusCode >= 500) {
          throw ServerException(message: safeMessage, body: body);
        }
        throw ApiException(
            statusCode: response.statusCode, message: safeMessage, body: body);
    }
  }

  dynamic _tryDecodeJson(String source) {
    try {
      final decoded = jsonDecode(source);
      return decoded;
    } catch (_) {
      return null;
    }
  }

  bool _looksLikeHtml(String source) {
    final s = source.trimLeft();
    if (s.isEmpty) return false;
    if (s.startsWith('<!DOCTYPE html') || s.startsWith('<html')) return true;
    if (s.contains('<html') || s.contains('<body')) return true;
    return false;
  }

  String? _extractHtmlTitle(String source) {
    final match = RegExp(r'<title[^>]*>(.*?)<\/title>',
            caseSensitive: false, dotAll: true)
        .firstMatch(source);
    final t = match?.group(1)?.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t;
  }

  String _sanitizeAppleDebugBody(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return '<empty>';

    final decoded = _tryDecodeJson(trimmed);
    if (decoded is Map<String, dynamic>) {
      return jsonEncode(_redactSensitiveValues(decoded));
    }
    if (decoded is List) {
      return jsonEncode(_redactSensitiveValues(decoded));
    }

    if (trimmed.length <= 500) return trimmed;
    return '${trimmed.substring(0, 500)}...';
  }

  dynamic _redactSensitiveValues(dynamic value) {
    const sensitiveKeys = {
      'token',
      'jwt',
      'access_token',
      'accessToken',
      'identity_token',
      'authorization_code',
      'id_token',
    };

    if (value is Map) {
      return value.map((key, dynamic val) {
        final keyText = key.toString();
        if (sensitiveKeys.contains(keyText)) {
          return MapEntry(key, '<redacted>');
        }
        return MapEntry(key, _redactSensitiveValues(val));
      });
    }
    if (value is List) {
      return value.map(_redactSensitiveValues).toList();
    }
    return value;
  }

  MediaType? _contentTypeForFilename(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.jpg') || n.endsWith('.jpeg')) {
      return MediaType('image', 'jpeg');
    }
    if (n.endsWith('.png')) return MediaType('image', 'png');
    if (n.endsWith('.gif')) return MediaType('image', 'gif');
    if (n.endsWith('.mp4')) return MediaType('video', 'mp4');
    if (n.endsWith('.mov')) return MediaType('video', 'quicktime');
    if (n.endsWith('.aac')) return MediaType('audio', 'aac');
    if (n.endsWith('.m4a')) return MediaType('audio', 'mp4');
    if (n.endsWith('.mp3')) return MediaType('audio', 'mpeg');
    if (n.endsWith('.wav')) return MediaType('audio', 'wav');
    if (n.endsWith('.ogg') || n.endsWith('.oga')) {
      return MediaType('audio', 'ogg');
    }
    return null;
  }
}
