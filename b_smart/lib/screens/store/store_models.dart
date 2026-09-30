import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/phase2_store_api.dart';
import '../../utils/url_helper.dart';

class StoreCategory {
  final String label;
  final IconData icon;

  const StoreCategory(this.label, this.icon);
}

class StoreProduct {
  final String title;
  final String subtitle;
  final Color color;
  final String imageAsset;

  const StoreProduct(this.title, this.subtitle, this.color, this.imageAsset);
}

enum StoreMockItemType { product, service }

enum StoreMockOrderStatus { newOrder, processing, shipped, completed }

class StoreMockCatalogItem {
  final String id;
  final StoreMockItemType type;
  final String title;
  final String category;
  final String description;
  final String imageUrl;
  final IconData icon;
  final double price;
  final String duration;
  final String rating;
  final String reviews;
  final Map<String, dynamic> raw;

  const StoreMockCatalogItem({
    required this.id,
    required this.type,
    required this.title,
    required this.category,
    required this.description,
    this.imageUrl = '',
    required this.icon,
    required this.price,
    required this.duration,
    required this.rating,
    required this.reviews,
    this.raw = const {},
  });

  String get priceLabel {
    final whole = price == price.roundToDouble();
    return '₹${whole ? price.toStringAsFixed(0) : price.toStringAsFixed(2)}';
  }

  StoreMockCatalogItem copyWith({
    String? id,
    String? title,
    String? category,
    String? description,
    String? imageUrl,
    double? price,
    String? duration,
    String? rating,
    String? reviews,
    Map<String, dynamic>? raw,
  }) {
    return StoreMockCatalogItem(
      id: id ?? this.id,
      type: type,
      title: title ?? this.title,
      category: category ?? this.category,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      icon: icon,
      price: price ?? this.price,
      duration: duration ?? this.duration,
      rating: rating ?? this.rating,
      reviews: reviews ?? this.reviews,
      raw: raw ?? this.raw,
    );
  }
}

class StoreMockCartLine {
  final StoreMockCatalogItem item;
  final int quantity;
  final String? schedule;
  final Map<String, dynamic> variant;

  const StoreMockCartLine({
    required this.item,
    required this.quantity,
    this.schedule,
    this.variant = const {},
  });

  StoreMockCartLine copyWith({
    int? quantity,
    String? schedule,
    Map<String, dynamic>? variant,
  }) {
    return StoreMockCartLine(
      item: item,
      quantity: quantity ?? this.quantity,
      schedule: schedule ?? this.schedule,
      variant: variant ?? this.variant,
    );
  }

  /// Stable key identifying a variant choice (color/size), '' when none.
  String get variantKey {
    final color = variant['color']?.toString().trim() ?? '';
    final size = variant['size']?.toString().trim() ?? '';
    if (color.isEmpty && size.isEmpty) return '';
    return '$color|$size';
  }

  String get variantLabel {
    final parts = [
      variant['color']?.toString().trim() ?? '',
      variant['size']?.toString().trim() ?? '',
    ].where((e) => e.isNotEmpty).toList();
    return parts.join(' · ');
  }

  /// Variant-specific price wins when the backend provides one.
  double get unitPrice {
    final raw = variant['price'];
    if (raw is num && raw > 0) return raw.toDouble();
    if (raw is String) {
      final parsed = double.tryParse(raw);
      if (parsed != null && parsed > 0) return parsed;
    }
    return item.price;
  }

  double get total => unitPrice * quantity;
}

class StoreMockOrder {
  final String id;
  final String customerName;
  final Color avatarColor;
  final StoreMockOrderStatus status;
  final List<StoreMockCartLine> lines;
  final double paidAmount;
  final double bCoinsSavings;
  final String address;

  const StoreMockOrder({
    required this.id,
    required this.customerName,
    required this.avatarColor,
    required this.status,
    required this.lines,
    required this.paidAmount,
    required this.bCoinsSavings,
    required this.address,
  });

  String get customerInitials {
    final parts = customerName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'BS';
    final first = parts.first.characters.first.toUpperCase();
    if (parts.length == 1) return first;
    return '$first${parts.last.characters.first.toUpperCase()}';
  }

  int get itemCount => lines.fold(0, (sum, line) => sum + line.quantity);
}

class StoreMockState extends ChangeNotifier {
  StoreMockState._();

  static final StoreMockState instance = StoreMockState._();
  static List<StoreMockCatalogItem> get catalog => instance._catalog;

  final List<StoreMockCartLine> _cartLines = [];

  final Phase2StoreApi _api = Phase2StoreApi();

  // ── Live Phase-2 lists (replaces mock orders/bookings in UI) ──
  List<Map<String, dynamic>> buyerOrders = const [];
  List<Map<String, dynamic>> sellerOrders = const [];
  List<Map<String, dynamic>> buyerBookings = const [];
  List<Map<String, dynamic>> sellerBookings = const [];
  bool ordersLoading = false;
  bool bookingsLoading = false;
  List<StoreMockCatalogItem> _catalog = [];
  bool _catalogLoading = false;
  bool _cartLoading = false;
  Object? _lastError;

  bool get catalogLoading => _catalogLoading;
  bool get cartLoading => _cartLoading;
  Object? get lastError => _lastError;

  List<StoreMockCatalogItem> get products =>
      _catalog.where((item) => item.type == StoreMockItemType.product).toList();

  List<StoreMockCatalogItem> get services =>
      _catalog.where((item) => item.type == StoreMockItemType.service).toList();

  List<StoreMockCartLine> get cartLines => List.unmodifiable(_cartLines);

  int get cartCount => _cartLines.fold(0, (sum, line) => sum + line.quantity);

  double get subtotal => _cartLines.fold(0.0, (sum, line) => sum + line.total);

  int quantityFor(String id) {
    return _cartLines
        .where((line) => line.item.id == id)
        .fold(0, (sum, line) => sum + line.quantity);
  }

  int quantityForVariant(
    StoreMockCatalogItem item,
    Map<String, dynamic>? variant,
  ) {
    final key = _variantKey(variant);
    final index = _cartLines.indexWhere(
      (line) => line.item.id == item.id && line.variantKey == key,
    );
    return index == -1 ? 0 : _cartLines[index].quantity;
  }

  static String _variantKey(Map<String, dynamic>? variant) {
    if (variant == null || variant.isEmpty) return '';
    final color = variant['color']?.toString().trim() ?? '';
    final size = variant['size']?.toString().trim() ?? '';
    if (color.isEmpty && size.isEmpty) return '';
    return '$color|$size';
  }

  static Map<String, dynamic> _cleanVariant(Map<String, dynamic>? variant) {
    if (variant == null || variant.isEmpty) return const {};
    final cleaned = <String, dynamic>{};
    for (final key in ['color', 'size']) {
      final value = variant[key]?.toString().trim();
      if (value != null && value.isNotEmpty) cleaned[key] = value;
    }
    return cleaned;
  }

  void addToCart(
    StoreMockCatalogItem item, {
    int quantity = 1,
    String? schedule,
    Map<String, dynamic>? variant,
  }) {
    final cleanVariant = _cleanVariant(variant);
    final key = _variantKey(cleanVariant);
    final index = _cartLines.indexWhere(
      (line) => line.item.id == item.id && line.variantKey == key,
    );
    if (index == -1) {
      _cartLines.add(
        StoreMockCartLine(
          item: item,
          quantity: quantity.clamp(1, 99),
          schedule: schedule,
          variant: cleanVariant,
        ),
      );
    } else {
      final current = _cartLines[index];
      _cartLines[index] = current.copyWith(
        quantity: (current.quantity + quantity).clamp(1, 99),
        schedule: schedule ?? current.schedule,
      );
    }
    notifyListeners();
    if (item.type == StoreMockItemType.product) {
      unawaited(_syncAddCartItem(
          item.id, quantity.clamp(1, 99),
          variant: cleanVariant));
    }
  }

  void setCartQuantity(
    StoreMockCatalogItem item,
    int quantity, {
    String? schedule,
    Map<String, dynamic>? variant,
  }) {
    final cleanVariant = _cleanVariant(variant);
    final key = _variantKey(cleanVariant);
    final index = _cartLines.indexWhere(
      (line) => line.item.id == item.id && line.variantKey == key,
    );
    if (quantity <= 0) {
      if (index != -1) {
        _cartLines.removeAt(index);
        notifyListeners();
      }
      return;
    }

    if (index == -1) {
      _cartLines.add(
        StoreMockCartLine(
          item: item,
          quantity: quantity.clamp(1, 99),
          schedule: schedule,
          variant: cleanVariant,
        ),
      );
    } else {
      _cartLines[index] = _cartLines[index].copyWith(
        quantity: quantity.clamp(1, 99),
        schedule: schedule ?? _cartLines[index].schedule,
      );
    }
    notifyListeners();
    if (item.type == StoreMockItemType.product) {
      unawaited(_syncUpdateCartItem(item.id, quantity.clamp(0, 99),
          variant: cleanVariant));
    }
  }

  void updateQuantity(String itemId, int quantity,
      {Map<String, dynamic>? variant}) {
    final key = _variantKey(_cleanVariant(variant));
    final index = _cartLines.indexWhere(
      (line) => line.item.id == itemId && line.variantKey == key,
    );
    if (index == -1) return;
    if (quantity <= 0) {
      _cartLines.removeAt(index);
    } else {
      _cartLines[index] = _cartLines[index].copyWith(
        quantity: quantity.clamp(1, 99),
      );
    }
    notifyListeners();
    unawaited(_syncUpdateCartItem(itemId, quantity.clamp(0, 99),
        variant: _cleanVariant(variant)));
  }

  void removeFromCart(String itemId, {Map<String, dynamic>? variant}) {
    if (variant == null) {
      _cartLines.removeWhere((line) => line.item.id == itemId);
    } else {
      final key = _variantKey(_cleanVariant(variant));
      _cartLines.removeWhere(
        (line) => line.item.id == itemId && line.variantKey == key,
      );
    }
    notifyListeners();
    unawaited(_syncRemoveCartItem(itemId));
  }

  String money(double amount) => '₹${amount.toStringAsFixed(2)}';

  /// Loads the live marketplace. On success the catalog reflects the
  /// server exactly (possibly empty); on failure the previous content
  /// stays and [lastError] is set for retry UI.
  Future<void> refreshMarketplace({String? query, String? category}) async {
    if (_catalogLoading) return;
    _catalogLoading = true;
    _lastError = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _api.listProducts(query: query, category: category),
        _api.listServices(query: query, category: category),
      ]);
      final products = results[0].map(_productFromApi);
      final services = results[1].map(_serviceFromApi);
      _catalog = <StoreMockCatalogItem>[...products, ...services]
          .where((item) => item.id.trim().isNotEmpty)
          .toList();
      _lastError = null;
    } catch (e) {
      _lastError = e;
    } finally {
      _catalogLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshCart() async {
    if (_cartLoading) return;
    _cartLoading = true;
    _lastError = null;
    notifyListeners();
    try {
      final data = await _api.getCart();
      final items = _cartItemsFromApi(data);
      if (items != null) {
        _cartLines
          ..clear()
          ..addAll(items);
      }
    } catch (e) {
      _lastError = e;
    } finally {
      _cartLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> checkoutWithWallet({
    required Map<String, String> shippingAddress,
  }) async {
    final response = await _api.checkoutOrder(
      paymentMethod: 'wallet',
      shippingAddress: shippingAddress,
    );
    _cartLines.clear();
    notifyListeners();
    unawaited(refreshBuyerOrders());
    return response;
  }

  /// Razorpay branch: creates a backend Razorpay order (order stays pending).
  /// Caller must open Razorpay Checkout with `response['razorpay']`
  /// then call [verifyOrderPayment].
  Future<Map<String, dynamic>> checkoutWithRazorpay({
    required Map<String, String> shippingAddress,
  }) async {
    final response = await _api.checkoutOrder(
      paymentMethod: 'razorpay',
      shippingAddress: shippingAddress,
    );
    notifyListeners();
    return response;
  }

  Future<Map<String, dynamic>> verifyOrderPayment({
    required String orderId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    final response = await _api.verifyOrderPayment(
      orderId: orderId,
      razorpayOrderId: razorpayOrderId,
      razorpayPaymentId: razorpayPaymentId,
      razorpaySignature: razorpaySignature,
    );
    _cartLines.clear();
    notifyListeners();
    unawaited(refreshBuyerOrders());
    return response;
  }

  Future<void> clearCartLive() async {
    try {
      await _api.clearCart();
    } finally {
      _cartLines.clear();
      notifyListeners();
    }
  }

  Future<void> refreshBuyerOrders() async {
    if (ordersLoading) return;
    ordersLoading = true;
    notifyListeners();
    try {
      buyerOrders = await _api.myOrders();
      _lastError = null;
    } catch (e) {
      _lastError = e;
    } finally {
      ordersLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshSellerOrders() async {
    if (ordersLoading) return;
    ordersLoading = true;
    notifyListeners();
    try {
      sellerOrders = await _api.sellerOrders();
      _lastError = null;
    } catch (e) {
      _lastError = e;
    } finally {
      ordersLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> cancelBuyerOrder(String orderId) async {
    final res = await _api.cancelOrder(orderId);
    unawaited(refreshBuyerOrders());
    return res;
  }

  Future<Map<String, dynamic>> advanceOrderStatus(
      String orderId, String status) async {
    final res =
        await _api.updateOrderStatus(orderId: orderId, status: status);
    unawaited(refreshSellerOrders());
    return res;
  }

  // ── Service bookings (direct booking, no cart per spec) ──
  Future<Map<String, dynamic>> createBooking(
      Map<String, dynamic> body) async {
    final res = await _api.createServiceBooking(body: body);
    unawaited(refreshBuyerBookings());
    return res;
  }

  Future<Map<String, dynamic>> verifyBookingPayment({
    required String bookingId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    final res = await _api.verifyServiceBookingPayment(
      bookingId: bookingId,
      razorpayOrderId: razorpayOrderId,
      razorpayPaymentId: razorpayPaymentId,
      razorpaySignature: razorpaySignature,
    );
    unawaited(refreshBuyerBookings());
    return res;
  }

  Future<void> refreshBuyerBookings() async {
    if (bookingsLoading) return;
    bookingsLoading = true;
    notifyListeners();
    try {
      buyerBookings = await _api.myServiceBookings();
      _lastError = null;
    } catch (e) {
      _lastError = e;
    } finally {
      bookingsLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshSellerBookings() async {
    if (bookingsLoading) return;
    bookingsLoading = true;
    notifyListeners();
    try {
      sellerBookings = await _api.sellerServiceBookings();
      _lastError = null;
    } catch (e) {
      _lastError = e;
    } finally {
      bookingsLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> cancelBuyerBooking(String bookingId) async {
    final res = await _api.cancelServiceBooking(bookingId);
    unawaited(refreshBuyerBookings());
    return res;
  }

  Future<Map<String, dynamic>> advanceBookingStatus(
      String bookingId, String status) async {
    final res = await _api.updateServiceBookingStatus(
        bookingId: bookingId, status: status);
    unawaited(refreshSellerBookings());
    return res;
  }

  // ── Shared helpers for order/booking UIs ──
  static String orderIdOf(Map<String, dynamic> m) =>
      _text(m, const ['id', '_id', 'order_id']);
  static String bookingIdOf(Map<String, dynamic> m) =>
      _text(m, const ['id', '_id', 'booking_id']);
  static String statusOf(Map<String, dynamic> m) =>
      _text(m, const ['status', 'order_status', 'booking_status'],
          fallback: 'pending')
          .toLowerCase();
  static double amountOf(Map<String, dynamic> m) =>
      _number(m, const ['total_amount', 'amount', 'total', 'price', 'paid_amount']);

  Future<void> _syncAddCartItem(String productId, int quantity,
      {Map<String, dynamic>? variant}) async {
    try {
      await _api.addCartItem(
          productId: productId, quantity: quantity, variant: variant);
      await refreshCart();
    } catch (e) {
      _lastError = e;
      notifyListeners();
    }
  }

  Future<void> _syncUpdateCartItem(String productId, int quantity,
      {Map<String, dynamic>? variant}) async {
    try {
      await _api.updateCartItem(
          productId: productId, quantity: quantity, variant: variant);
      await refreshCart();
    } catch (e) {
      _lastError = e;
      notifyListeners();
    }
  }

  Future<void> _syncRemoveCartItem(String productId) async {
    try {
      await _api.removeCartItem(productId);
      await refreshCart();
    } catch (e) {
      _lastError = e;
      notifyListeners();
    }
  }

  static StoreMockCatalogItem _productFromApi(Map<String, dynamic> json) {
    final id = _id(json);
    final category = _text(json, const ['category'], fallback: 'Product');
    return StoreMockCatalogItem(
      id: id,
      type: StoreMockItemType.product,
      title: _text(json, const ['name', 'title'], fallback: 'Product'),
      category: category,
      description: _text(
        json,
        const ['short_description', 'description', 'subtitle'],
      ),
      imageUrl: _firstImage(json),
      icon: _iconForCategory(category),
      price: _number(json, const [
        'selling_price',
        'sale_price',
        'discounted_price',
        'price',
        'amount',
        'mrp',
      ]),
      duration: _text(json, const ['dispatch_time'], fallback: '2-3 days'),
      rating: _text(json, const ['rating'], fallback: 'New'),
      reviews: _text(json, const ['reviews', 'review_count'], fallback: '0'),
      raw: json,
    );
  }

  static StoreMockCatalogItem _serviceFromApi(Map<String, dynamic> json) {
    final category = _text(json, const ['category'], fallback: 'Service');
    return StoreMockCatalogItem(
      id: _id(json),
      type: StoreMockItemType.service,
      title: _text(json, const ['name', 'title'], fallback: 'Service'),
      category: category,
      description: _text(
        json,
        const ['short_description', 'description', 'subtitle'],
      ),
      imageUrl: _firstImage(json),
      icon: _iconForCategory(category),
      price: _number(json, const ['price', 'selling_price', 'amount']),
      duration: _text(json, const ['duration'], fallback: '1 hour'),
      rating: _text(json, const ['rating'], fallback: 'New'),
      reviews: _text(json, const ['reviews', 'review_count'], fallback: '0'),
      raw: json,
    );
  }

  List<StoreMockCartLine>? _cartItemsFromApi(Map<String, dynamic> data) {
    final rawItems = _cartItemList(data);
    if (rawItems == null) return null;
    return rawItems.whereType<Map>().map((raw) {
      final map = raw.map((key, value) => MapEntry(key.toString(), value));
      // Some responses nest the product, others inline it on the cart line.
      final nested = map['product'] ?? map['item'] ?? map['product_details'];
      final productJson = (nested is Map)
          ? nested.map((key, value) => MapEntry(key.toString(), value))
          : map;
      var product = _productFromApi(productJson);
      // A cart line often carries its own live price alongside a partial
      // product object; prefer whichever actually resolved to a value.
      if (product.price <= 0) {
        final linePrice = _number(map, const [
          'unit_price',
          'line_price',
          'unitPrice',
          'linePrice',
          'selling_price',
          'price',
          'final_price',
          'total_price',
          'amount',
          'mrp',
        ]);
        if (linePrice > 0) product = product.copyWith(price: linePrice);
      }
      final variantJson = map['variant'];
      final variant = variantJson is Map
          ? _cleanVariant(
              variantJson.map((key, value) => MapEntry(key.toString(), value)))
          : const <String, dynamic>{};
      return StoreMockCartLine(
        item: product,
        quantity: _number(map, const ['quantity', 'qty']).round().clamp(1, 99),
        variant: variant,
      );
    }).toList();
  }

  /// Locates the cart line array across the response shapes the API may use.
  static List<dynamic>? _cartItemList(Map<String, dynamic> data) {
    for (final key in const [
      'items',
      'cart_items',
      'cartItems',
      'products',
      'lines',
      'data',
      'cart',
    ]) {
      final value = data[key];
      if (value is List) return value;
      if (value is Map) {
        final nested = value.map((k, v) => MapEntry(k.toString(), v));
        for (final nestedKey in const [
          'items',
          'cart_items',
          'cartItems',
          'products',
          'lines',
        ]) {
          final nestedValue = nested[nestedKey];
          if (nestedValue is List) return nestedValue;
        }
      }
    }
    return null;
  }

  /// Public parsing helpers so search/detail screens can reuse the same
  /// product/service mapping as the marketplace.
  static StoreMockCatalogItem productFromApi(Map<String, dynamic> json) =>
      _productFromApi(json);

  static StoreMockCatalogItem serviceFromApi(Map<String, dynamic> json) =>
      _serviceFromApi(json);

  /// Variant options from a product payload, each with
  /// `color`, `size`, `price`, `stock` strings (may be empty).
  static List<Map<String, String>> variantsOf(
      StoreMockCatalogItem item) {
    final raw = item.raw['variants'];
    if (raw is! List) return const [];
    final out = <Map<String, String>>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final map = entry.map((key, value) => MapEntry(key.toString(), value));
      final color = map['color']?.toString().trim() ?? '';
      final size = map['size']?.toString().trim() ?? '';
      if (color.isEmpty && size.isEmpty) continue;
      out.add({
        'color': color,
        'size': size,
        'price': map['price']?.toString().trim() ?? '',
        'stock': (map['stock_quantity'] ?? map['stock'])
                ?.toString()
                .trim() ??
            '',
      });
    }
    return out;
  }

  static Set<String> colorsOf(StoreMockCatalogItem item) => variantsOf(item)
      .map((v) => v['color'] ?? '')
      .where((e) => e.isNotEmpty)
      .toSet();

  static Set<String> sizesOf(StoreMockCatalogItem item) => variantsOf(item)
      .map((v) => v['size'] ?? '')
      .where((e) => e.isNotEmpty)
      .toSet();

  static String _id(Map<String, dynamic> json) {
    return _text(json, const ['id', '_id', 'product_id', 'service_id']);
  }

  static String _text(
    Map<String, dynamic> json,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = json[key];
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty && text != 'null') return text;
    }
    return fallback;
  }

  static double _number(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return 0;
  }

  static String _firstImage(Map<String, dynamic> json) {
    // The influencer upload endpoints return `{fileName, fileUrl}`, so
    // `fileUrl` must be tried before the bare `fileName` (which is not a URL).
    for (final key in const ['images', 'image_urls', 'media']) {
      final images = json[key];
      if (images is! List || images.isEmpty) continue;
      final first = images.first;
      if (first is Map) {
        final value = _text(
          first.map((key, value) => MapEntry(key.toString(), value)),
          const [
            'fileUrl',
            'file_url',
            'url',
            'image_url',
            'imageUrl',
            'src',
            'path',
            'fileName',
            'filename',
          ],
        );
        final resolved = UrlHelper.absoluteUrl(value);
        if (resolved.isNotEmpty) return resolved;
      }
      if (first is String) {
        final resolved = UrlHelper.absoluteUrl(first);
        if (resolved.isNotEmpty) return resolved;
      }
    }
    // Single-image fallbacks.
    for (final key in const [
      'fileUrl',
      'file_url',
      'image_url',
      'imageUrl',
      'image',
      'thumbnail',
      'url',
    ]) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        final resolved = UrlHelper.absoluteUrl(value);
        if (resolved.isNotEmpty) return resolved;
      }
    }
    return '';
  }

  static IconData _iconForCategory(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('service') || lower.contains('consult')) {
      return LucideIcons.briefcaseBusiness;
    }
    if (lower.contains('home')) return LucideIcons.house;
    if (lower.contains('well')) return LucideIcons.sparkles;
    if (lower.contains('elect') || lower.contains('mobile')) {
      return LucideIcons.smartphone;
    }
    return LucideIcons.package;
  }
}
