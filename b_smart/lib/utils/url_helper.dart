import '../config/api_config.dart';

class UrlHelper {
  static const Set<String> _placeholderTokens = {
    'string',
    'null',
    'undefined',
    'nan',
    'none',
    '(null)',
  };

  static bool _isPlaceholderToken(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.isEmpty || _placeholderTokens.contains(normalized);
  }

  static bool _hasPlaceholderPathToken(String value) {
    var s = value.trim();
    if (s.isEmpty) return true;
    final q = s.indexOf('?');
    if (q != -1) s = s.substring(0, q);
    final h = s.indexOf('#');
    if (h != -1) s = s.substring(0, h);
    final parts =
        s.split('/').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return true;
    return _isPlaceholderToken(parts.last);
  }

  static String _repairScheme(String value) {
    var fixed = value.trim();
    if (fixed.startsWith('http:/') && !fixed.startsWith('http://')) {
      fixed = fixed.replaceFirst('http:/', 'http://');
    } else if (fixed.startsWith('https:/') && !fixed.startsWith('https://')) {
      fixed = fixed.replaceFirst('https:/', 'https://');
    }
    return fixed;
  }

  static String _extractFromObjectLike(String value) {
    String extractCandidate(String source) {
      final pattern = RegExp(
        r'(fileUrl|file_url|url|path)\s*:\s*([^,}]+)',
        caseSensitive: false,
      );
      final match = pattern.firstMatch(source);
      if (match == null) return '';
      return match.group(2)?.trim().replaceAll('"', '').replaceAll("'", '') ??
          '';
    }

    final raw = value.trim();
    var extracted = '';
    String? objectPayload;
    if (raw.startsWith('{') && raw.endsWith('}')) {
      objectPayload = raw;
    } else {
      final braceStart = raw.indexOf('{');
      final braceEnd = raw.lastIndexOf('}');
      if (braceStart != -1 && braceEnd > braceStart) {
        objectPayload = raw.substring(braceStart, braceEnd + 1);
      }
    }

    if (objectPayload != null && objectPayload.isNotEmpty) {
      extracted = extractCandidate(objectPayload);
    }

    if (extracted.isEmpty) {
      try {
        final decoded = Uri.decodeFull(raw);
        if (decoded != raw) {
          String? decodedPayload;
          if (decoded.startsWith('{') && decoded.endsWith('}')) {
            decodedPayload = decoded;
          } else {
            final dStart = decoded.indexOf('{');
            final dEnd = decoded.lastIndexOf('}');
            if (dStart != -1 && dEnd > dStart) {
              decodedPayload = decoded.substring(dStart, dEnd + 1);
            }
          }
          if (decodedPayload != null && decodedPayload.isNotEmpty) {
            extracted = extractCandidate(decodedPayload);
          }
        }
      } catch (_) {
        // keep original if percent decoding fails
      }
    }
    return extracted.isEmpty ? raw : extracted;
  }

  static String absoluteUrl(String url) {
    String u = _extractFromObjectLike(url.trim());
    u = _repairScheme(u);
    if (u == 'file:///') return '';
    if (_isPlaceholderToken(u) || _hasPlaceholderPathToken(u)) return '';

    // If it's already a full URL, return it
    if (u.startsWith('http://') || u.startsWith('https://')) return u;

    // Clean the base URL
    String base = ApiConfig.baseUrl;
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);

    // Ensure path starts with exactly one slash
    if (!u.startsWith('/')) u = '/$u';

    // Combine and fix common double-prefixing issues
    String result = '$base$u';

    // Cleanup internal double slashes (except the one after http:)
    result = result.replaceFirst('://', '###');
    result = result.replaceAll('//', '/');
    result = result.replaceFirst('###', '://');

    return result;
  }

  static String normalizeUrl(String? url) {
    if (url == null || url.isEmpty) return '';

    var u = _extractFromObjectLike(url.trim()).replaceAll('\\', '/');
    u = _repairScheme(u);
    if (_isPlaceholderToken(u) || _hasPlaceholderPathToken(u)) return '';

    // If it's a relative path and doesn't have a folder prefix, add uploads
    if (!u.startsWith('http') &&
        !u.startsWith('/') &&
        !u.contains('uploads/') &&
        !u.contains('api/')) {
      u = 'uploads/$u';
    }

    return absoluteUrl(u);
  }

  static bool shouldAttachAuthHeader(String url) {
    final raw = url.trim();
    if (raw.isEmpty) return false;
    try {
      final uri = Uri.parse(raw);
      final scheme = uri.scheme.toLowerCase();
      if (scheme != 'http' && scheme != 'https') return false;

      final host = uri.host.toLowerCase();
      if (host.isEmpty) return false;
      if (host == 'localhost' || host == '127.0.0.1' || host == '10.0.2.2') {
        return true;
      }

      final baseUri = Uri.parse(ApiConfig.baseUrl);
      final baseHost = baseUri.host.toLowerCase();
      if (baseHost.isEmpty) return false;
      if (host == baseHost) return true;

      return _rootDomain(host) == _rootDomain(baseHost);
    } catch (_) {
      return false;
    }
  }

  static String _rootDomain(String host) {
    final parts = host.split('.').where((e) => e.isNotEmpty).toList();
    if (parts.length < 2) return host;
    return '${parts[parts.length - 2]}.${parts[parts.length - 1]}';
  }
}
