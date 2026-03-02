import '../config/api_config.dart';

class UrlHelper {
  static String absoluteUrl(String url) {
    String u = url.trim();
    if (u.isEmpty || u == 'file:///' || u == 'null') return '';
    
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
    
    // If it's a relative path and doesn't have a folder prefix, add uploads
    if (!u.startsWith('http') && !u.startsWith('/') && 
        !u.contains('uploads/') && !u.contains('api/')) {
      u = 'uploads/$u';
    }
    
    return absoluteUrl(u);
  }
}