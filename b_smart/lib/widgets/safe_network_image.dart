import 'dart:async';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;

/// A defensive network image widget that avoids crashing decoders on
/// unsupported/invalid formats (e.g. SVG/AVIF/HEIC or HTML error pages).
///
/// Heuristics:
/// - Uses URL extension when available.
/// - Otherwise performs a lightweight probe (HEAD → ranged GET) and inspects
///   `Content-Type` and magic bytes.
class SafeNetworkImage extends StatelessWidget {
  final String url;
  final Map<String, String>? headers;
  final BoxFit fit;
  final FilterQuality filterQuality;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;
  final String? cacheKey;
  final String? debugLabel;

  const SafeNetworkImage({
    super.key,
    required this.url,
    this.headers,
    this.fit = BoxFit.cover,
    this.filterQuality = FilterQuality.medium,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
    this.cacheKey,
    this.debugLabel,
  });

  static final Map<String, Future<_ProbeResult>> _probeCache =
      <String, Future<_ProbeResult>>{};

  @override
  Widget build(BuildContext context) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return _error();

    final ext = _extensionFor(trimmed);
    final kindFromExt = _kindFromExtension(ext);
    if (kindFromExt == _ImageKind.svg) {
      return _svg();
    }
    if (kindFromExt == _ImageKind.unsupported) {
      return _error();
    }
    if (kindFromExt == _ImageKind.raster) {
      return _cachedRaster();
    }

    final authKey = headers?['Authorization'] ?? '';
    final cacheKey = '$trimmed#$authKey';
    final future =
        _probeCache.putIfAbsent(cacheKey, () => _probe(trimmed, headers));
    return FutureBuilder<_ProbeResult>(
      future: future,
      builder: (context, snap) {
        final result = snap.data;
        if (result == null) {
          return _placeholder();
        }
        switch (result.kind) {
          case _ImageKind.svg:
            return _svg();
          case _ImageKind.unsupported:
            return _error();
          case _ImageKind.raster:
          case _ImageKind.unknown:
            return _cachedRaster();
        }
      },
    );
  }

  Widget _placeholder() =>
      placeholder ??
      SizedBox(width: width, height: height, child: const SizedBox());

  Widget _error() =>
      errorWidget ??
      SizedBox(width: width, height: height, child: const SizedBox());

  Widget _svg() {
    return SvgPicture.network(
      url,
      headers: headers,
      width: width,
      height: height,
      fit: fit,
      placeholderBuilder: (_) => _placeholder(),
    );
  }

  Widget _cachedRaster() {
    return CachedNetworkImage(
      imageUrl: url,
      httpHeaders: headers,
      cacheKey: cacheKey,
      width: width,
      height: height,
      fit: fit,
      imageBuilder: (context, imageProvider) => Image(
        image: imageProvider,
        width: width,
        height: height,
        fit: fit,
        filterQuality: filterQuality,
        gaplessPlayback: true,
      ),
      placeholder: (_, __) => _placeholder(),
      errorWidget: (_, __, error) {
        assert(() {
          debugPrint(
            'SafeNetworkImage decode failed label=$debugLabel url=$url error=$error',
          );
          return true;
        }());
        return _error();
      },
    );
  }

  static String _extensionFor(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path.toLowerCase();
      final dot = path.lastIndexOf('.');
      if (dot == -1 || dot == path.length - 1) return '';
      return path.substring(dot + 1);
    } catch (_) {
      final lower = url.toLowerCase();
      final q = lower.indexOf('?');
      final path = q == -1 ? lower : lower.substring(0, q);
      final dot = path.lastIndexOf('.');
      if (dot == -1 || dot == path.length - 1) return '';
      return path.substring(dot + 1);
    }
  }

  static _ImageKind _kindFromExtension(String ext) {
    if (ext.isEmpty) return _ImageKind.unknown;
    if (ext == 'svg') return _ImageKind.svg;
    if (ext == 'm3u8' ||
        ext == 'mp4' ||
        ext == 'mov' ||
        ext == 'm4v' ||
        ext == 'mkv' ||
        ext == 'webm') {
      // Video / playlist URLs sometimes get mistakenly used as thumbnails.
      return _ImageKind.unsupported;
    }
    if (ext == 'avif' || ext == 'heic' || ext == 'heif') {
      return _ImageKind.unsupported;
    }
    if (ext == 'png' ||
        ext == 'jpg' ||
        ext == 'jpeg' ||
        ext == 'webp' ||
        ext == 'gif' ||
        ext == 'bmp') {
      return _ImageKind.raster;
    }
    return _ImageKind.unknown;
  }

  static Future<_ProbeResult> _probe(
    String url,
    Map<String, String>? headers,
  ) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return const _ProbeResult(_ImageKind.unknown);

    // Try HEAD first; some servers do not support it.
    try {
      final head = await http
          .head(uri, headers: _probeHeaders(headers))
          .timeout(const Duration(seconds: 4));
      final fromHeader = _kindFromContentType(head.headers['content-type']);
      if (fromHeader != _ImageKind.unknown) return _ProbeResult(fromHeader);
    } catch (_) {
      // ignore
    }

    // Fallback: small ranged GET (also helps sniff bytes).
    try {
      final res = await http
          .get(
            uri,
            headers: _probeHeaders(headers, extra: const <String, String>{
              'Range': 'bytes=0-255',
            }),
          )
          .timeout(const Duration(seconds: 6));

      final fromHeader = _kindFromContentType(res.headers['content-type']);
      if (fromHeader != _ImageKind.unknown) return _ProbeResult(fromHeader);

      final bytes = res.bodyBytes;
      final fromBytes = _kindFromMagicBytes(bytes);
      return _ProbeResult(fromBytes);
    } catch (_) {
      return const _ProbeResult(_ImageKind.unknown);
    }
  }

  static Map<String, String> _probeHeaders(
    Map<String, String>? authHeaders, {
    Map<String, String>? extra,
  }) {
    final result = <String, String>{
      'Accept': '*/*',
      'User-Agent': 'b_smart',
    };
    if (authHeaders != null && authHeaders.isNotEmpty) {
      result.addAll(authHeaders);
    }
    if (extra != null) result.addAll(extra);
    return result;
  }

  static _ImageKind _kindFromContentType(String? contentType) {
    final ct = (contentType ?? '').toLowerCase();
    if (ct.contains('image/svg')) return _ImageKind.svg;
    if (ct.contains('application/vnd.apple.mpegurl') ||
        ct.contains('application/x-mpegurl') ||
        ct.contains('audio/mpegurl') ||
        ct.contains('audio/x-mpegurl') ||
        ct.contains('video/')) {
      return _ImageKind.unsupported;
    }
    if (ct.contains('image/avif') ||
        ct.contains('image/heic') ||
        ct.contains('image/heif')) {
      return _ImageKind.unsupported;
    }
    if (ct.startsWith('image/')) return _ImageKind.raster;
    return _ImageKind.unknown;
  }

  static _ImageKind _kindFromMagicBytes(Uint8List bytes) {
    if (bytes.isEmpty) return _ImageKind.unknown;

    // SVG is usually XML/text.
    final headText = _asciiPrefix(bytes, 120).toLowerCase();
    if (headText.startsWith('#extm3u')) {
      return _ImageKind.unsupported;
    }
    if (headText.contains('<svg') || headText.contains('<?xml')) {
      return _ImageKind.svg;
    }

    // ISO BMFF: look for "ftyp" + brand.
    if (bytes.length >= 16) {
      final box = _asciiAt(bytes, 4, 4);
      if (box == 'ftyp') {
        final brand = _asciiAt(bytes, 8, 4).toLowerCase();
        if (brand == 'avif' || brand == 'avis') return _ImageKind.unsupported;
        if (brand == 'heic' || brand == 'heif') return _ImageKind.unsupported;
      }
    }

    return _ImageKind.unknown;
  }

  static String _asciiPrefix(Uint8List bytes, int maxLen) {
    final len = bytes.length < maxLen ? bytes.length : maxLen;
    final codes = <int>[];
    for (var i = 0; i < len; i++) {
      final b = bytes[i];
      if (b == 0) break;
      codes.add(b);
    }
    return String.fromCharCodes(codes);
  }

  static String _asciiAt(Uint8List bytes, int offset, int length) {
    if (bytes.length < offset + length) return '';
    return String.fromCharCodes(bytes.sublist(offset, offset + length));
  }
}

enum _ImageKind { raster, svg, unsupported, unknown }

class _ProbeResult {
  final _ImageKind kind;
  const _ProbeResult(this.kind);
}
