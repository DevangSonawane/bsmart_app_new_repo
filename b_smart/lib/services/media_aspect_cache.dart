import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Global cache for media aspect ratios to avoid layout shifts and repeat work.
class MediaAspectCache {
  MediaAspectCache._();
  static final MediaAspectCache instance = MediaAspectCache._();

  final Map<String, double> _cache = {};
  Map<String, String> _authHeaders = const {};

  double? get(String url) => _cache[url];

  void setAuthHeaders(Map<String, String> headers) {
    _authHeaders = headers;
  }

  /// Resolve image aspect ratio once using ImageStreamListener.
  Future<double> resolveImageRatio(String url) async {
    if (_cache.containsKey(url)) return _cache[url]!;

    final completer = Completer<double>();
    final ImageStream stream = CachedNetworkImageProvider(
      url,
      headers: _authHeaders,
    ).resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener((ImageInfo info, bool _) {
      final ui.Image img = info.image;
      final ratio = _clamp(img.width / img.height);
      _cache[url] = ratio;
      completer.complete(ratio);
      stream.removeListener(listener);
    }, onError: (error, stack) {
      stream.removeListener(listener);
      completer.complete(4 / 5);
    });
    stream.addListener(listener);
    return completer.future;
  }

  double _clamp(double raw) {
    // Allow reel/story portrait aspect ratios (9:16) without forcing 4:5.
    // The previous 4:5 clamp caused portrait video thumbnails to be laid out
    // with the wrong aspect ratio, resulting in cropping/blur when scaled.
    const minPortrait = 9 / 16; // 0.5625
    const maxLandscape = 1.91; // 1.91:1
    if (raw.isNaN || raw <= 0) return 1.0;
    return raw.clamp(minPortrait, maxLandscape);
  }
}
