import 'dart:collection';

class CacheEntry {
  final String data;
  final DateTime timestamp;
  final Duration ttl;

  CacheEntry({
    required this.data,
    required this.timestamp,
    required this.ttl,
  });

  bool get isExpired => DateTime.now().difference(timestamp) > ttl;
}

class PageCacheService {
  static final PageCacheService _instance = PageCacheService._internal();
  factory PageCacheService() => _instance;

  PageCacheService._internal();

  static const int _maxEntries = 30;
  static const int _maxEntryBytes = 500 * 1024;
  static const int _schemaVersion = 1;

  bool enablePageCache = true;

  final LinkedHashMap<String, CacheEntry> _cache =
      LinkedHashMap<String, CacheEntry>();

  String _buildKey(String pageGroup, String userId, Map<String, dynamic> params) {
    final paramsKey = params.keys
        .where((k) => params[k] != null)
        .map((k) => '${k}=${params[k]}')
        .join('&');
    return '${pageGroup}_v$_schemaVersion _$userId ${paramsKey}'.trim();
  }

  Future<String?> get(String pageGroup, String userId,
      Map<String, dynamic> params) async {
    if (!enablePageCache) return null;
    final key = _buildKey(pageGroup, userId, params);
    final entry = _cache[key];
    if (entry == null) return null;
    if (entry.isExpired) {
      _cache.remove(key);
      return null;
    }
    return entry.data;
  }

  Future<void> set(
      String pageGroup, String userId, Map<String, dynamic> params, String data) async {
    if (!enablePageCache) return;
    if (data.length > _maxEntryBytes) return;

    final key = _buildKey(pageGroup, userId, params);

    _cache[key] = CacheEntry(
      data: data,
      timestamp: DateTime.now(),
      ttl: _ttlForPageGroup(pageGroup),
    );

    if (_cache.length > _maxEntries) {
      _evictOldest();
    }
  }

  Future<void> invalidate(String pageGroup, String userId) async {
    final keys = _cache.keys.where((k) => k.startsWith('$pageGroup')).toList();
    for (final key in keys) {
      _cache.remove(key);
    }
  }

  Future<void> invalidateAll(List<String> pageGroups, String userId) async {
    for (final group in pageGroups) {
      await invalidate(group, userId);
    }
  }

  Future<void> clearAll() async {
    _cache.clear();
  }

  Duration _ttlForPageGroup(String pageGroup) {
    switch (pageGroup) {
      case 'home_feed':
      case 'reels':
      case 'notifications':
        return const Duration(minutes: 5);
      case 'search_explore':
      case 'wallet':
      case 'store':
        return const Duration(minutes: 10);
      case 'ads':
      case 'promote':
      case 'vendor_public':
      case 'advertiser':
        return const Duration(minutes: 10);
      case 'saved_items':
      case 'follow_requests':
      case 'privacy':
      case 'coins_history':
      case 'redemption_requests':
        return const Duration(minutes: 15);
      default:
        return const Duration(minutes: 10);
    }
  }

  void _evictOldest() {
    if (_cache.isEmpty) return;
    _cache.remove(_cache.keys.first);
  }

  LinkedHashMap<String, CacheEntry> get debugCache => _cache;
}
