import '../config/api_config.dart';

class UrlHelper {
  static String absoluteUrl(String url) {
    if (url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    
    final base = ApiConfig.baseUrl;
    final baseUri = Uri.parse(base);
    final origin = '${baseUri.scheme}://${baseUri.host}${baseUri.hasPort ? ':${baseUri.port}' : ''}';
    
    String path = url;
    if (!path.startsWith('/')) {
      path = '/$path';
    }
    
    // Avoid double /api/ prefix if baseUrl already has it or path has it
    String result = '$origin$path';
    if (result.contains('/api//api/')) {
      result = result.replaceFirst('/api//api/', '/api/');
    }
    
    return result;
  }

  static String normalizeUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    
    var u = url.trim();
    u = u.replaceAll('\\', '/');
    
    final lower = u.toLowerCase();
    final isLikelyFile = lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.contains('.m3u8');

    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      if (!u.startsWith('/')) {
        if (isLikelyFile) {
          // If it's a file but doesn't have uploads/ or api/ prefix, add uploads/
          if (!u.contains('uploads/') && !u.contains('api/')) {
            u = 'uploads/$u';
          }
        }
      }
    }
    
    return absoluteUrl(u);
  }
}
