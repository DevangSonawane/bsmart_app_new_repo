import 'api_client.dart';

/// REST API wrapper for the wishlist endpoints.
///
///   GET    /wishlist               – logged-in user's wishlist
///                                    (full product data, newest-added first)
///   DELETE /wishlist               – clear the entire wishlist
///   POST   /wishlist/items         – { product_id } (no-op if already there)
///   DELETE /wishlist/items/:id     – remove one product
class WishlistApi {
  WishlistApi({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<Map<String, dynamic>>> getWishlist() async {
    final data = await _client.get('/wishlist');
    return _asList(data);
  }

  /// Adds a product; returns the updated wishlist when the backend sends
  /// one, otherwise refetches. A 404 surfaces as NotFoundException
  /// ("Product not found") via ApiClient.
  Future<List<Map<String, dynamic>>> addItem(String productId) async {
    final data = await _client.post(
      '/wishlist/items',
      body: {'product_id': productId},
    );
    final list = _asListOrNull(data);
    if (list != null) return list;
    return getWishlist();
  }

  Future<List<Map<String, dynamic>>> removeItem(String productId) async {
    final data = await _client.delete(
      '/wishlist/items/${Uri.encodeComponent(productId)}',
    );
    final list = _asListOrNull(data);
    if (list != null) return list;
    return getWishlist();
  }

  Future<void> clear() async {
    await _client.delete('/wishlist');
  }

  /// Returns null when the payload carries no list (e.g. `{success: true}`),
  /// so callers can fall back to a refetch.
  static List<Map<String, dynamic>>? _asListOrNull(dynamic data) {
    if (data == null) return null;
    if (data is List) {
      return data.whereType<Map>().map(_stringMap).toList();
    }
    if (data is Map) {
      final map = _stringMap(data);
      for (final key in const [
        'wishlist',
        'items',
        'products',
        'data',
        'results',
      ]) {
        final value = map[key];
        if (value is List) {
          return value.whereType<Map>().map(_stringMap).toList();
        }
        if (value is Map) {
          final nested = _stringMap(value);
          for (final nestedKey in const [
            'wishlist',
            'items',
            'products',
            'results',
          ]) {
            final nestedValue = nested[nestedKey];
            if (nestedValue is List) {
              return nestedValue.whereType<Map>().map(_stringMap).toList();
            }
          }
        }
      }
      // `{success: true}` style — no list present.
      return null;
    }
    return null;
  }

  static List<Map<String, dynamic>> _asList(dynamic data) {
    return _asListOrNull(data) ?? const [];
  }

  static Map<String, dynamic> _stringMap(Map source) {
    return source.map((key, value) => MapEntry(key.toString(), value));
  }
}
