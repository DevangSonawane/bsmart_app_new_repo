import '../models/store_profile.dart';
import 'api_client.dart';

class Phase2StoreApi {
  Phase2StoreApi({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  /// Short-lived in-memory GET cache so tab switches feel instant.
  /// Mutations clear it; entries expire after [_cacheTtl] regardless.
  static final Map<String, _CacheEntry> _getCache = {};
  static const Duration _cacheTtl = Duration(seconds: 30);

  Future<dynamic> _cachedGet(
    String path, {
    Map<String, String>? queryParams,
  }) async {
    final params = queryParams;
    String key = path;
    if (params != null && params.isNotEmpty) {
      final entries = params.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      key = '$path?${entries.map((e) => '${e.key}=${e.value}').join('&')}';
    }
    final hit = _getCache[key];
    if (hit != null &&
        DateTime.now().difference(hit.at) < _cacheTtl) {
      return hit.data;
    }
    final data = await _client.get(path, queryParams: queryParams);
    _getCache[key] = _CacheEntry(data, DateTime.now());
    return data;
  }

  static void _bustCache() => _getCache.clear();

  Future<dynamic> _post(String path, {Map<String, dynamic>? body}) async {
    try {
      return await _client.post(path, body: body);
    } finally {
      _bustCache();
    }
  }

  Future<dynamic> _patch(String path, {Map<String, dynamic>? body}) async {
    try {
      return await _client.patch(path, body: body);
    } finally {
      _bustCache();
    }
  }

  Future<dynamic> _delete(String path) async {
    try {
      return await _client.delete(path);
    } finally {
      _bustCache();
    }
  }

  Future<List<Map<String, dynamic>>> listProducts({
    String? query,
    String? category,
  }) async {
    final data = await _cachedGet(
      '/influencer-products',
      queryParams: _cleanQuery({'q': query, 'category': category}),
    );
    return _asList(data);
  }

  Future<List<Map<String, dynamic>>> listServices({
    String? query,
    String? category,
  }) async {
    final data = await _cachedGet(
      '/influencer-services',
      queryParams: _cleanQuery({'q': query, 'category': category}),
    );
    return _asList(data);
  }

  Future<List<Map<String, dynamic>>> myProducts() async {
    return _asList(await _cachedGet('/influencer-products/my'));
  }

  Future<List<Map<String, dynamic>>> myServices() async {
    return _asList(await _cachedGet('/influencer-services/my'));
  }

  Future<Map<String, dynamic>> getProduct(String id) async {
    return _asMap(await _cachedGet('/influencer-products/$id'));
  }

  Future<Map<String, dynamic>> getService(String id) async {
    return _asMap(await _cachedGet('/influencer-services/$id'));
  }

  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> body) async {
    return _asMap(await _post('/influencer-products', body: body));
  }

  Future<Map<String, dynamic>> updateProduct(
    String id,
    Map<String, dynamic> body,
  ) async {
    return _asMap(await _patch('/influencer-products/$id', body: body));
  }

  Future<void> deleteProduct(String id) async {
    await _delete('/influencer-products/$id');
  }

  Future<Map<String, dynamic>> createService(Map<String, dynamic> body) async {
    return _asMap(await _post('/influencer-services', body: body));
  }

  Future<Map<String, dynamic>> updateService(
    String id,
    Map<String, dynamic> body,
  ) async {
    return _asMap(await _patch('/influencer-services/$id', body: body));
  }

  Future<void> deleteService(String id) async {
    await _delete('/influencer-services/$id');
  }

  Future<Map<String, dynamic>> getCart() async {
    // Returned un-unwrapped on purpose: the cart line array can live under
    // `data`, `cart` or the root, and the caller walks all of them.
    final data = await _cachedGet('/cart');
    if (data is Map<String, dynamic>) return data;
    return <String, dynamic>{'items': data};
  }

  Future<Map<String, dynamic>> addCartItem({
    required String productId,
    int quantity = 1,
    Map<String, dynamic>? variant,
  }) async {
    return _asMap(await _post('/cart/items', body: {
      'product_id': productId,
      'quantity': quantity,
      if (variant != null && variant.isNotEmpty) 'variant': variant,
    }));
  }

  Future<Map<String, dynamic>> updateCartItem({
    required String productId,
    required int quantity,
    Map<String, dynamic>? variant,
  }) async {
    return _asMap(await _patch('/cart/items/$productId', body: {
      'quantity': quantity,
      if (variant != null && variant.isNotEmpty) 'variant': variant,
    }));
  }

  Future<void> removeCartItem(String productId) async {
    await _delete('/cart/items/$productId');
  }

  Future<void> clearCart() async {
    await _delete('/cart');
  }

  Future<Map<String, dynamic>> checkoutOrder({
    required String paymentMethod,
    required Map<String, String> shippingAddress,
  }) async {
    // Returned raw, not through _asMap: the Razorpay branch returns
    // `{order: {...}, razorpay: {order_id, amount, key_id}}` and _asMap
    // would unwrap `order`, discarding the sibling `razorpay` payload.
    final data = await _post('/orders/checkout', body: {
      'payment_method': paymentMethod,
      'shipping_address': shippingAddress,
    });
    return _rawMap(data);
  }

  /// Returns the response object as-is, unwrapping only a `data` envelope
  /// (never a named sibling like `order` / `razorpay`).
  static Map<String, dynamic> _rawMap(dynamic data) {
    if (data is! Map) return <String, dynamic>{};
    final map = data.map((key, value) => MapEntry(key.toString(), value));
    final nested = map['data'];
    if (nested is Map) {
      return nested.map((key, value) => MapEntry(key.toString(), value));
    }
    return map;
  }

  Future<Map<String, dynamic>> verifyOrderPayment({
    required String orderId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    return _asMap(await _post('/orders/$orderId/verify-payment', body: {
      'razorpay_order_id': razorpayOrderId,
      'razorpay_payment_id': razorpayPaymentId,
      'razorpay_signature': razorpaySignature,
    }));
  }

  Future<List<Map<String, dynamic>>> myOrders() async {
    return _asList(await _cachedGet('/orders'));
  }

  Future<Map<String, dynamic>> getOrder(String orderId) async {
    return _asMap(await _cachedGet('/orders/$orderId'));
  }

  Future<Map<String, dynamic>> cancelOrder(String orderId) async {
    return _asMap(await _patch('/orders/$orderId/cancel'));
  }

  Future<List<Map<String, dynamic>>> sellerOrders() async {
    return _asList(await _cachedGet('/orders/seller/mine'));
  }

  Future<Map<String, dynamic>> updateOrderStatus({
    required String orderId,
    required String status,
  }) async {
    return _asMap(await _patch('/orders/$orderId/status', body: {
      'status': status,
    }));
  }

  Future<Map<String, dynamic>> createServiceBooking({
    required Map<String, dynamic> body,
  }) async {
    // Raw for the same reason as checkoutOrder: the Razorpay branch returns a
    // sibling `razorpay` payload that _asMap would discard.
    return _rawMap(await _post('/service-bookings', body: body));
  }

  Future<List<Map<String, dynamic>>> myServiceBookings() async {
    return _asList(await _cachedGet('/service-bookings'));
  }

  Future<Map<String, dynamic>> getServiceBooking(String bookingId) async {
    return _asMap(await _cachedGet('/service-bookings/$bookingId'));
  }

  Future<Map<String, dynamic>> cancelServiceBooking(String bookingId) async {
    return _asMap(await _patch('/service-bookings/$bookingId/cancel'));
  }

  Future<Map<String, dynamic>> verifyServiceBookingPayment({
    required String bookingId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    return _asMap(
        await _post('/service-bookings/$bookingId/verify-payment', body: {
      'razorpay_order_id': razorpayOrderId,
      'razorpay_payment_id': razorpayPaymentId,
      'razorpay_signature': razorpaySignature,
    }));
  }

  Future<List<Map<String, dynamic>>> sellerServiceBookings() async {
    return _asList(await _cachedGet('/service-bookings/seller/mine'));
  }

  Future<Map<String, dynamic>> updateServiceBookingStatus({
    required String bookingId,
    required String status,
  }) async {
    return _asMap(await _patch('/service-bookings/$bookingId/status',
        body: {'status': status}));
  }

  Future<Map<String, dynamic>> switchUserRole({
    required String userId,
    required Map<String, dynamic> body,
  }) async {
    return _asMap(await _patch('/users/$userId/role', body: body));
  }

  /// Storefront profile for a seller. Public / optional auth.
  ///
  /// The response is `{ "store": { ... } }`.
  Future<StoreProfile> getStoreProfile(String userId) async {
    final data = await _client.get('/users/$userId/store-profile');
    return StoreProfile.fromApiJson(_storeOf(data));
  }

  /// Updates the signed-in seller's own storefront profile.
  ///
  /// Only the fields present in [body] are updated, so callers should send
  /// just what changed.
  Future<StoreProfile> updateStoreProfile({
    required Map<String, dynamic> body,
  }) async {
    if (body.isEmpty) {
      throw ArgumentError('Nothing to update on the store profile.');
    }
    final data = await _client.patch('/users/me/store-profile', body: body);
    final store = _storeOf(data);
    // Some deployments return an ack without the profile; fall back to
    // merging the patch we just sent so the UI stays in sync.
    if (store.isEmpty) return StoreProfile.fromApiJson(body);
    return StoreProfile.fromApiJson(store);
  }

  /// Unwraps `{store: {...}}`, tolerating a bare or `data`-wrapped object.
  static Map<String, dynamic> _storeOf(dynamic data) {
    if (data is! Map) return const {};
    final map = data.map((k, v) => MapEntry(k.toString(), v));
    final store = map['store'];
    if (store is Map) {
      return store.map((k, v) => MapEntry(k.toString(), v));
    }
    final data_ = map['data'];
    if (data_ is Map) {
      final nested = data_.map((k, v) => MapEntry(k.toString(), v));
      final nestedStore = nested['store'];
      if (nestedStore is Map) {
        return nestedStore.map((k, v) => MapEntry(k.toString(), v));
      }
      return nested;
    }
    return map;
  }

  static Map<String, String>? _cleanQuery(Map<String, String?> source) {
    final query = <String, String>{};
    source.forEach((key, value) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) query[key] = trimmed;
    });
    return query.isEmpty ? null : query;
  }

  static Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      final nested = _firstMap(data, const [
        'data',
        'item',
        'product',
        'service',
        'cart',
        'order',
        'booking'
      ]);
      return nested ?? data;
    }
    return <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _asList(dynamic data) {
    if (data is List) return data.whereType<Map>().map(_stringMap).toList();
    if (data is Map) {
      for (final key in const [
        'data',
        'items',
        'products',
        'services',
        'orders',
        'bookings',
        'cart',
      ]) {
        final value = data[key];
        if (value is List) {
          return value.whereType<Map>().map(_stringMap).toList();
        }
        if (value is Map && value['items'] is List) {
          return (value['items'] as List)
              .whereType<Map>()
              .map(_stringMap)
              .toList();
        }
      }
    }
    return const [];
  }

  static Map<String, dynamic>? _firstMap(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];
      if (value is Map) return _stringMap(value);
    }
    return null;
  }

  static Map<String, dynamic> _stringMap(Map source) {
    return source.map((key, value) => MapEntry(key.toString(), value));
  }
}

class _CacheEntry {
  final dynamic data;
  final DateTime at;

  const _CacheEntry(this.data, this.at);
}
