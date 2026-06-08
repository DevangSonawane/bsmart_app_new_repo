import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/url_helper.dart';

class ChatMediaAutoSaveService {
  ChatMediaAutoSaveService._internal();

  static final ChatMediaAutoSaveService instance =
      ChatMediaAutoSaveService._internal();

  static const String _keyAutoImages = 'messaging_auto_download_images';
  static const String _keyAutoVideos = 'messaging_auto_download_videos';
  static const String _keyAutoDocs = 'messaging_auto_download_documents';
  static const String _keyDataSaver = 'messaging_data_saver_mode';
  static const String _keyEnabledAt = 'messaging_auto_download_enabled_at';
  static const String _keySavedIds = 'chat_auto_saved_media_ids';

  SharedPreferences? _prefs;
  bool _autoImages = false;
  bool _autoVideos = false;
  bool _autoDocs = false;
  bool _dataSaverMode = false;
  int _enabledAtMillis = 0;
  final Connectivity _connectivity = Connectivity();
  final ValueNotifier<bool> dataSaverModeNotifier = ValueNotifier<bool>(false);

  Future<SharedPreferences> _ensurePrefs() async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    return prefs;
  }

  Future<void> load() async {
    final prefs = await _ensurePrefs();
    _autoImages = prefs.getBool(_keyAutoImages) ?? false;
    _autoVideos = prefs.getBool(_keyAutoVideos) ?? false;
    _autoDocs = prefs.getBool(_keyAutoDocs) ?? false;
    _dataSaverMode = prefs.getBool(_keyDataSaver) ?? false;
    dataSaverModeNotifier.value = _dataSaverMode;
    _enabledAtMillis = prefs.getInt(_keyEnabledAt) ?? 0;
    await _syncEnabledAt(prefs);
  }

  bool get autoDownloadImages => _autoImages;
  bool get autoDownloadVideos => _autoVideos;
  bool get autoDownloadDocuments => _autoDocs;
  bool get dataSaverMode => _dataSaverMode;
  DateTime? get autoDownloadEnabledAt => _enabledAtMillis > 0
      ? DateTime.fromMillisecondsSinceEpoch(_enabledAtMillis)
      : null;

  bool get hasAnyAutoDownloadEnabled =>
      _autoImages || _autoVideos || _autoDocs;

  Future<void> setAutoDownloadImages(bool value) async {
    _autoImages = value;
    final prefs = await _ensurePrefs();
    await prefs.setBool(_keyAutoImages, value);
    await _syncEnabledAt(prefs);
  }

  Future<void> setAutoDownloadVideos(bool value) async {
    _autoVideos = value;
    final prefs = await _ensurePrefs();
    await prefs.setBool(_keyAutoVideos, value);
    await _syncEnabledAt(prefs);
  }

  Future<void> setAutoDownloadDocuments(bool value) async {
    _autoDocs = value;
    final prefs = await _ensurePrefs();
    await prefs.setBool(_keyAutoDocs, value);
    await _syncEnabledAt(prefs);
  }

  Future<void> setDataSaverMode(bool value) async {
    _dataSaverMode = value;
    dataSaverModeNotifier.value = value;
    final prefs = await _ensurePrefs();
    await prefs.setBool(_keyDataSaver, value);
  }

  Future<void> _syncEnabledAt(SharedPreferences prefs) async {
    if (!hasAnyAutoDownloadEnabled) {
      _enabledAtMillis = 0;
      await prefs.remove(_keyEnabledAt);
      return;
    }

    if (_enabledAtMillis <= 0) {
      _enabledAtMillis = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt(_keyEnabledAt, _enabledAtMillis);
    }
  }

  Future<Set<String>> _savedIds(SharedPreferences prefs) async {
    return (prefs.getStringList(_keySavedIds) ?? const <String>[])
        .toSet();
  }

  Future<void> _markSaved(SharedPreferences prefs, String messageId) async {
    final ids = await _savedIds(prefs);
    if (ids.add(messageId)) {
      await prefs.setStringList(_keySavedIds, ids.toList(growable: false));
    }
  }

  Future<void> maybeAutoSaveMessages({
    required List<Map<String, dynamic>> messages,
    required String currentUserId,
  }) async {
    await load();
    if (!hasAnyAutoDownloadEnabled) return;
    if (!await _isAutoSaveAllowedOnCurrentNetwork()) return;

    final prefs = await _ensurePrefs();
    final savedIds = await _savedIds(prefs);
    final cutoff = _enabledAtMillis;
    final uid = currentUserId.trim();

    for (final message in messages) {
      final messageId = _messageId(message);
      if (messageId.isEmpty || savedIds.contains(messageId)) continue;

      final senderId = _senderId(message);
      if (uid.isNotEmpty && senderId.isNotEmpty && senderId == uid) continue;

      final createdAt = _createdAtMillis(message);
      if (createdAt > 0 && cutoff > 0 && createdAt < cutoff) continue;

      final mediaUrl = _mediaUrl(message);
      if (mediaUrl.isEmpty) continue;

      final mediaType = _mediaType(message);
      final kind = _kindFor(mediaUrl, mediaType);
      if (kind == _AutoSaveKind.unknown) continue;

      try {
        final ok = switch (kind) {
          _AutoSaveKind.image => await _saveImage(mediaUrl, messageId),
          _AutoSaveKind.video => await _saveVideo(mediaUrl, messageId),
          _AutoSaveKind.document => await _saveDocument(mediaUrl, messageId),
          _AutoSaveKind.unknown => false,
        };
        if (ok) {
          await _markSaved(prefs, messageId);
          savedIds.add(messageId);
        }
      } catch (e) {
        debugPrint('Auto-save failed for $messageId: $e');
      }
    }
  }

  Future<bool> _isAutoSaveAllowedOnCurrentNetwork() async {
    if (!_dataSaverMode) return true;
    final results = await _connectivity.checkConnectivity();
    if (results.contains(ConnectivityResult.none)) return false;
    if (results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet)) {
      return true;
    }
    return false;
  }

  String _messageId(Map<String, dynamic> message) {
    return (message['_id'] ?? message['id'] ?? '').toString().trim();
  }

  String _senderId(Map<String, dynamic> message) {
    final sender = message['sender'];
    final raw = sender is Map
        ? (sender['_id'] ?? sender['id'] ?? sender['user_id'])
        : sender;
    return (raw ?? '').toString().trim();
  }

  int _createdAtMillis(Map<String, dynamic> message) {
    final raw =
        (message['createdAt'] ?? message['created_at'] ?? '').toString().trim();
    if (raw.isEmpty) return 0;
    return DateTime.tryParse(raw)?.millisecondsSinceEpoch ?? 0;
  }

  String _mediaUrl(Map<String, dynamic> message) {
    final raw = (message['mediaUrl'] ??
            message['media_url'] ??
            message['fileUrl'] ??
            message['file_url'] ??
            '')
        .toString()
        .trim();
    return UrlHelper.normalizeUrl(raw);
  }

  String _mediaType(Map<String, dynamic> message) {
    return (message['mediaType'] ?? message['media_type'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
  }

  _AutoSaveKind _kindFor(String url, String mediaType) {
    final lower = url.toLowerCase();
    if (mediaType.contains('audio')) return _AutoSaveKind.unknown;
    if (mediaType.contains('document') ||
        mediaType.contains('pdf') ||
        mediaType.contains('file')) {
      return _AutoSaveKind.document;
    }
    if (mediaType.contains('video') ||
        lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m4v') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.webm') ||
        lower.contains('.mp4?') ||
        lower.contains('.mov?') ||
        lower.contains('.m4v?') ||
        lower.contains('.mkv?') ||
        lower.contains('.webm?')) {
      return _AutoSaveKind.video;
    }
    if (mediaType.contains('image') ||
        lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.bmp') ||
        lower.contains('.png?') ||
        lower.contains('.jpg?') ||
        lower.contains('.jpeg?') ||
        lower.contains('.webp?') ||
        lower.contains('.gif?') ||
        lower.contains('.bmp?')) {
      return _AutoSaveKind.image;
    }
    if (lower.endsWith('.pdf') || lower.contains('.pdf?')) {
      return _AutoSaveKind.document;
    }
    return _AutoSaveKind.unknown;
  }

  Future<bool> _saveImage(String url, String messageId) async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) return false;

    final res = await http.get(Uri.parse(url));
    if (res.statusCode < 200 || res.statusCode >= 300) return false;

    final stamp = DateTime.now().millisecondsSinceEpoch;
    final title = 'bsmart_chat_${messageId}_$stamp';
    await PhotoManager.editor.saveImage(
      res.bodyBytes,
      title: title,
      filename: '$title.jpg',
    );
    return true;
  }

  Future<bool> _saveVideo(String url, String messageId) async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) return false;

    final res = await http.get(Uri.parse(url));
    if (res.statusCode < 200 || res.statusCode >= 300) return false;

    final stamp = DateTime.now().millisecondsSinceEpoch;
    final title = 'bsmart_chat_${messageId}_$stamp';
    final tmp = File('${Directory.systemTemp.path}/$title.mp4');
    await tmp.writeAsBytes(res.bodyBytes, flush: true);
    await PhotoManager.editor.saveVideo(tmp, title: title);
    return true;
  }

  Future<bool> _saveDocument(String url, String messageId) async {
    final res = await http.get(Uri.parse(url));
    if (res.statusCode < 200 || res.statusCode >= 300) return false;

    final docs = await getApplicationDocumentsDirectory();
    final folder = Directory('${docs.path}/bsmart_chat_documents');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    final stamp = DateTime.now().millisecondsSinceEpoch;
    final ext = _extensionFor(url);
    final safeExt = ext.isEmpty ? 'bin' : ext;
    final file = File(
      '${folder.path}/bsmart_chat_${messageId}_$stamp.$safeExt',
    );
    await file.writeAsBytes(res.bodyBytes, flush: true);
    return true;
  }

  String _extensionFor(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path.toLowerCase();
      final dot = path.lastIndexOf('.');
      if (dot == -1 || dot == path.length - 1) return '';
      return path.substring(dot + 1);
    } catch (_) {
      return '';
    }
  }
}

enum _AutoSaveKind { image, video, document, unknown }
