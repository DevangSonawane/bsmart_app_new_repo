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

  static String absoluteUrl(String url) {
    String u = url.trim();
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

    var u = url.trim().replaceAll('\\', '/');
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
}
