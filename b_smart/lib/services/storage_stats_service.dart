import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class StorageStats {
  final int imageBytes;
  final int videoBytes;
  final int documentBytes;

  const StorageStats({
    required this.imageBytes,
    required this.videoBytes,
    required this.documentBytes,
  });

  const StorageStats.empty()
      : imageBytes = 0,
        videoBytes = 0,
        documentBytes = 0;

  int get totalBytes => imageBytes + videoBytes + documentBytes;

  double get imageMb => imageBytes / (1024 * 1024);
  double get videoMb => videoBytes / (1024 * 1024);
  double get documentMb => documentBytes / (1024 * 1024);
  double get totalMb => totalBytes / (1024 * 1024);
}

class StorageStatsService {
  StorageStatsService._();

  static final StorageStatsService instance = StorageStatsService._();

  StorageStats? _cached;
  DateTime? _cachedAt;
  Future<StorageStats>? _inFlight;

  Future<StorageStats> loadStats({bool forceRefresh = false}) async {
    if (!forceRefresh && _cached != null && _cachedAt != null) {
      if (DateTime.now().difference(_cachedAt!) < const Duration(minutes: 2)) {
        return _cached!;
      }
    }
    if (!forceRefresh && _inFlight != null) return _inFlight!;

    final future = _scanStats();
    _inFlight = future;
    try {
      final stats = await future;
      _cached = stats;
      _cachedAt = DateTime.now();
      return stats;
    } finally {
      if (identical(_inFlight, future)) {
        _inFlight = null;
      }
    }
  }

  Future<void> invalidate() async {
    _cached = null;
    _cachedAt = null;
  }

  Future<StorageStats> _scanStats() async {
    if (kIsWeb) return const StorageStats.empty();

    final roots = <String>{};
    Future<void> addRoot(Future<Directory> futureDir) async {
      try {
        final dir = await futureDir;
        final path = p.normalize(dir.absolute.path);
        roots.add(path);
      } catch (_) {}
    }

    await addRoot(getTemporaryDirectory());
    await addRoot(getApplicationCacheDirectory());

    final totals = <_StorageBucket, int>{
      _StorageBucket.image: 0,
      _StorageBucket.video: 0,
      _StorageBucket.document: 0,
    };

    for (final root in roots) {
      final dir = Directory(root);
      if (!await dir.exists()) continue;
      await for (final entity
          in dir.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        int size;
        try {
          size = await entity.length();
        } catch (_) {
          continue;
        }
        if (size <= 0) continue;
        final bucket = _bucketForPath(entity.path);
        totals[bucket] = (totals[bucket] ?? 0) + size;
      }
    }

    return StorageStats(
      imageBytes: totals[_StorageBucket.image] ?? 0,
      videoBytes: totals[_StorageBucket.video] ?? 0,
      documentBytes: totals[_StorageBucket.document] ?? 0,
    );
  }

  _StorageBucket _bucketForPath(String rawPath) {
    final path = rawPath.toLowerCase();
    final fileName = p.basename(path);
    final ext = p.extension(fileName).replaceFirst('.', '');

    const imageExts = {
      'jpg',
      'jpeg',
      'png',
      'gif',
      'webp',
      'bmp',
      'heic',
      'heif',
      'avif',
      'svg',
      'tiff',
      'tif',
    };
    const videoExts = {
      'mp4',
      'mov',
      'm4v',
      'webm',
      'mkv',
      'avi',
      'm3u8',
      'mpd',
      'ts',
      'flv',
    };

    if (imageExts.contains(ext)) return _StorageBucket.image;
    if (videoExts.contains(ext)) return _StorageBucket.video;
    if (path.contains('libcachedimagedata') ||
        path.contains('imagecache') ||
        path.contains('cachedimage')) {
      return _StorageBucket.image;
    }
    if (path.contains('betterplayercache') ||
        path.contains('videocache') ||
        path.contains('video')) {
      return _StorageBucket.video;
    }
    return _StorageBucket.document;
  }
}

enum _StorageBucket { image, video, document }
