class PromoteLikeCache {
  static final Map<String, Map<String, dynamic>> _byId = {};

  PromoteLikeCache._();

  static void clear() {
    _byId.clear();
  }

  static void putById(String itemId, Map<String, dynamic> payload) {
    final id = itemId.trim();
    if (id.isEmpty) return;
    _byId[id] = Map<String, dynamic>.from(payload);
  }

  static Map<String, dynamic>? getById(String itemId) {
    final id = itemId.trim();
    if (id.isEmpty) return null;
    return _byId[id];
  }
}
