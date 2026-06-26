import 'package:shared_preferences/shared_preferences.dart';

import '../utils/current_user.dart';

/// Tiny persistence layer for scroll/playback memory.
///
/// This keeps the user's last known feed offset and reels index available
/// across route rebuilds or app restarts without changing UI behavior.
class UiSurfaceMemoryService {
  UiSurfaceMemoryService._();

  static final UiSurfaceMemoryService instance = UiSurfaceMemoryService._();

  static const String _feedScrollOffsetSuffix = 'feed_scroll_offset';
  static const String _reelsIndexSuffix = 'reels_index';

  String? _cachedScopeId;

  void clearCache() {
    _cachedScopeId = null;
  }

  Future<String?> _scopeId() async {
    final cached = _cachedScopeId;
    if (cached != null && cached.isNotEmpty) return cached;
    final uid = (await CurrentUser.id)?.trim();
    if (uid == null || uid.isEmpty) return null;
    _cachedScopeId = uid;
    return uid;
  }

  String _key(String scopeId, String suffix) => 'ui_surface_${scopeId}_$suffix';

  Future<SharedPreferences?> _prefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  Future<void> saveFeedScrollOffset(double offset) async {
    if (offset.isNaN || offset.isInfinite) return;
    final scopeId = await _scopeId();
    if (scopeId == null) return;
    final prefs = await _prefs();
    if (prefs == null) return;
    try {
      await prefs.setDouble(
        _key(scopeId, _feedScrollOffsetSuffix),
        offset < 0 ? 0 : offset,
      );
    } catch (_) {}
  }

  Future<double?> loadFeedScrollOffset() async {
    final scopeId = await _scopeId();
    if (scopeId == null) return null;
    final prefs = await _prefs();
    if (prefs == null) return null;
    try {
      final value = prefs.getDouble(_key(scopeId, _feedScrollOffsetSuffix));
      if (value == null || value.isNaN || value.isInfinite || value < 0) {
        return null;
      }
      return value;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveReelsIndex(int index) async {
    if (index < 0) return;
    final scopeId = await _scopeId();
    if (scopeId == null) return;
    final prefs = await _prefs();
    if (prefs == null) return;
    try {
      await prefs.setInt(_key(scopeId, _reelsIndexSuffix), index);
    } catch (_) {}
  }

  Future<int?> loadReelsIndex() async {
    final scopeId = await _scopeId();
    if (scopeId == null) return null;
    final prefs = await _prefs();
    if (prefs == null) return null;
    try {
      final value = prefs.getInt(_key(scopeId, _reelsIndexSuffix));
      if (value == null || value < 0) return null;
      return value;
    } catch (_) {
      return null;
    }
  }
}
