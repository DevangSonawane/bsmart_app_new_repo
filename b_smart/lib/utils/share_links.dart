import '../config/api_config.dart';

class ShareLinks {
  ShareLinks._();

  static String origin() {
    // Prefer the web-app origin. If the API base URL is customized, keep the
    // default share origin unless the caller overrides this file.
    // Web parity uses `window.location.origin`.
    const fallback = 'https://app.bebsmart.online';
    try {
      final base = ApiConfig.baseUrl.trim();
      if (base.isEmpty) return fallback;
      final uri = Uri.tryParse(base);
      if (uri == null || !uri.hasScheme || uri.host.isEmpty) return fallback;
      // API is typically https://api.bebsmart.online/api → share origin should be app.
      return fallback;
    } catch (_) {
      return fallback;
    }
  }

  static String urlForContent({
    required String contentType,
    required String contentId,
  }) {
    final type = contentType.trim().toLowerCase();
    final id = Uri.encodeComponent(contentId.trim());
    if (id.isEmpty) return origin();
    final o = origin();

    if (type == 'reel') return '$o/reels/$id';
    if (type == 'tweet') return '$o/post/$id?type=tweet';
    if (type == 'ad') return '$o/ads/$id/details';
    if (type == 'promote' || type == 'promote_reel' || type == 'promote-reel') {
      // Web app currently routes to `/promote` (full-screen page). Use a query
      // param so the receiver can deep-link if supported.
      return '$o/promote?reelId=$id';
    }
    // React uses `/posts/:id` for post share/report URLs.
    return '$o/posts/$id';
  }
}