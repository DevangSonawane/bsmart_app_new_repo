import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Global cache for media aspect ratios to avoid layout shifts and repeat work.
class MediaAspectCache {
  MediaAspectCache._();
  static final MediaAspectCache instance = MediaAspectCache._();

  final Map<String, double> _cache = {};

  double? get(String url) => _cache[url];

  /// Resolve image aspect ratio once using ImageStreamListener.
  Future<double> resolveImageRatio(String url) async {
    if (_cache.containsKey(url)) return _cache[url]!;

    final completer = Completer<double>();
    final ImageStream stream = NetworkImage(url).resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener((ImageInfo info, bool _) {
      final ui.Image img = info.image;
      final ratio = _clamp(img.width / img.height);
      _cache[url] = ratio;
      completer.complete(ratio);
      stream.removeListener(listener);
    }, onError: (error, stack) {
      stream.removeListener(listener);
      completer.complete(1.0); // safe fallback
    });
    stream.addListener(listener);
    return completer.future;
  }

  double _clamp(double raw) {
    const minPortrait = 0.8; // 4:5
    const maxLandscape = 1.91; // 1.91:1
    if (raw.isNaN || raw <= 0) return 1.0;
    return raw.clamp(minPortrait, maxLandscape);
  }
}
