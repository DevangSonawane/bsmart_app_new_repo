class StoryCache {
  static final Map<String, Map<String, dynamic>> _byMediaUrl = {};
  static final Map<String, Map<String, dynamic>> _byItemId = {};

  static void put(String mediaUrl, Map<String, dynamic> payload) {
    if (mediaUrl.isEmpty) return;
    _byMediaUrl[mediaUrl] = payload;
  }

  static Map<String, dynamic>? get(String mediaUrl) {
    if (mediaUrl.isEmpty) return null;
    return _byMediaUrl[mediaUrl];
  }

  static void putById(String itemId, Map<String, dynamic> payload) {
    if (itemId.isEmpty) return;
    _byItemId[itemId] = payload;
  }

  static Map<String, dynamic>? getById(String itemId) {
    if (itemId.isEmpty) return null;
    return _byItemId[itemId];
  }
}
