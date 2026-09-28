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
    return _asMap(await _cachedGet('/cart'));
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
    required Map<String, dynamic> shippingAddress,
  }) async {
    return _asMap(await _post('/orders/checkout', body: {
      'payment_method': paymentMethod,
      'shipping_address': shippingAddress,
    }));
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
    return _asMap(await _post('/service-bookings', body: body));
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
