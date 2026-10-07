import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/phase2_store_api.dart';
import '../../services/page_cache_service.dart';
import '../../utils/current_user.dart';
import '../../utils/url_helper.dart';
import 'shared/store_money.dart';

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

class StoreCheckoutException implements Exception {
  final String message;

  const StoreCheckoutException(this.message);

  @override
  String toString() => message;
}

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

  String get priceLabel => formatStoreMoney(price);

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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'category': category,
      'description': description,
      'imageUrl': imageUrl,
      'iconCodePoint': icon.codePoint,
      'price': price,
      'duration': duration,
      'rating': rating,
      'reviews': reviews,
      'raw': raw,
    };
  }

  factory StoreMockCatalogItem.fromJson(Map<String, dynamic> json) {
    return StoreMockCatalogItem(
      id: json['id'] as String,
      type: StoreMockItemType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => StoreMockItemType.product,
      ),
      title: json['title'] as String,
      category: json['category'] as String,
      description: json['description'] as String,
      imageUrl: json['imageUrl'] as String? ?? '',
      icon: StoreMockState._iconForCategory(json['category'] as String? ?? ''),
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      duration: json['duration'] as String? ?? '',
      rating: json['rating'] as String? ?? '',
      reviews: json['reviews'] as String? ?? '',
      raw: Map<String, dynamic>.from(json['raw'] as Map? ?? {}),
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

  Map<String, dynamic> toJson() {
    return {
      'item': item.toJson(),
      'quantity': quantity,
      'schedule': schedule,
      'variant': variant,
    };
  }

  factory StoreMockCartLine.fromJson(Map<String, dynamic> json) {
    return StoreMockCartLine(
      item: StoreMockCatalogItem.fromJson(json['item'] as Map<String, dynamic>),
      quantity: json['quantity'] as int? ?? 1,
      schedule: json['schedule'] as String?,
      variant: Map<String, dynamic>.from(json['variant'] as Map? ?? {}),
    );
  }
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
  final PageCacheService _pageCache = PageCacheService();

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
  DateTime? _catalogLoadedAt;
  DateTime? _cartLoadedAt;
  Object? _lastError;
  Object? _lastCartSyncError;
  Future<void> _cartSync = Future<void>.value();

  bool get catalogLoading => _catalogLoading;
  bool get cartLoading => _cartLoading;
  Object? get lastError => _lastError;
  String? get lastErrorMessage => _lastError?.toString();

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

  int maxQuantityFor(
    StoreMockCatalogItem item, {
    Map<String, dynamic>? variant,
  }) {
    if (item.type != StoreMockItemType.product) return 99;
    return (stockQuantityFor(item, variant: variant) ?? 99).clamp(0, 99);
  }

  int? stockQuantityFor(
    StoreMockCatalogItem item, {
    Map<String, dynamic>? variant,
  }) {
    if (item.type != StoreMockItemType.product) return null;
    final variantLimit = _stockLimitFrom(_cleanVariant(variant));
    if (variantLimit != null) return variantLimit;
    final itemLimit = _stockLimitFrom(item.raw);
    if (itemLimit != null) return itemLimit;
    final variants = variantsOf(item);
    if (variants.isEmpty) return null;
    var total = 0;
    var sawStock = false;
    for (final option in variants) {
      final stock = int.tryParse(option['stock'] ?? '');
      if (stock == null) continue;
      sawStock = true;
      total += stock.clamp(0, 1 << 30).toInt();
    }
    return sawStock ? total : null;
  }

  String stockLabelFor(
    StoreMockCatalogItem item, {
    Map<String, dynamic>? variant,
  }) {
    if (item.type != StoreMockItemType.product) return '';
    final stock = stockQuantityFor(item, variant: variant);
    if (stock == null) return 'Available';
    if (stock <= 0) return 'Out of stock';
    if (stock <= 5) return 'Only $stock left';
    return '$stock in stock';
  }

  bool isAtStockLimit(
    StoreMockCatalogItem item, {
    Map<String, dynamic>? variant,
  }) {
    final quantity = quantityForVariant(item, variant);
    return quantity >= maxQuantityFor(item, variant: variant);
  }

  static int? _stockLimitFrom(Map<String, dynamic> source) {
    for (final key in const [
      'stock_quantity',
      'stockQuantity',
      'stock',
      'quantity',
      'available_quantity',
      'availableQuantity',
      'inventory',
    ]) {
      final value = source[key];
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value.trim());
        if (parsed != null) return parsed;
      }
    }
    return null;
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
    // Variants carry their own price per the Phase 2 spec
    // (`variants: [{color, size, stock_quantity, price}]`). Dropping it made
    // a priced variant silently fall back to the product price, so the cart
    // and checkout totals were wrong.
    final price = variant['price'];
    if (price is num && price > 0) {
      cleaned['price'] = price.toDouble();
    } else if (price is String) {
      final parsed = double.tryParse(price.trim());
      if (parsed != null && parsed > 0) cleaned['price'] = parsed;
    }
    final stock = variant['stock_quantity'];
    if (stock is num) cleaned['stock_quantity'] = stock.toInt();
    return cleaned;
  }

  static Map<String, dynamic> _cartVariantPayload(
    Map<String, dynamic>? variant,
  ) {
    if (variant == null || variant.isEmpty) return const {};
    final payload = <String, dynamic>{};
    for (final key in const ['color', 'size']) {
      final value = variant[key]?.toString().trim();
      if (value != null && value.isNotEmpty) payload[key] = value;
    }
    return payload;
  }

  void addToCart(
    StoreMockCatalogItem item, {
    int quantity = 1,
    String? schedule,
    Map<String, dynamic>? variant,
  }) {
    final cleanVariant = _cleanVariant(variant);
    final maxQuantity = maxQuantityFor(item, variant: cleanVariant);
    if (maxQuantity <= 0) return;
    final key = _variantKey(cleanVariant);
    final index = _cartLines.indexWhere(
      (line) => line.item.id == item.id && line.variantKey == key,
    );
    var syncQuantity = 0;
    if (index == -1) {
      final targetQuantity = quantity.clamp(1, maxQuantity);
      _cartLines.add(
        StoreMockCartLine(
          item: item,
          quantity: targetQuantity,
          schedule: schedule,
          variant: cleanVariant,
        ),
      );
      syncQuantity = targetQuantity;
    } else {
      final current = _cartLines[index];
      final targetQuantity =
          (current.quantity + quantity).clamp(1, maxQuantity);
      if (targetQuantity == current.quantity &&
          (schedule == null || schedule == current.schedule)) {
        return;
      }
      _cartLines[index] = current.copyWith(
        quantity: targetQuantity,
        schedule: schedule ?? current.schedule,
      );
      syncQuantity = targetQuantity - current.quantity;
    }
    notifyListeners();
    if (item.type == StoreMockItemType.product && syncQuantity > 0) {
      final cartVariant = _cartVariantPayload(cleanVariant);
      _queueCartSync(
        () => _api.addCartItem(
          productId: item.id,
          quantity: syncQuantity,
          variant: cartVariant,
        ),
      );
    }
  }

  void setCartQuantity(
    StoreMockCatalogItem item,
    int quantity, {
    String? schedule,
    Map<String, dynamic>? variant,
  }) {
    final cleanVariant = _cleanVariant(variant);
    final maxQuantity = maxQuantityFor(item, variant: cleanVariant);
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

    if (maxQuantity <= 0) return;
    final targetQuantity = quantity.clamp(1, maxQuantity);
    if (index == -1) {
      _cartLines.add(
        StoreMockCartLine(
          item: item,
          quantity: targetQuantity,
          schedule: schedule,
          variant: cleanVariant,
        ),
      );
    } else {
      if (_cartLines[index].quantity == targetQuantity &&
          (schedule == null || schedule == _cartLines[index].schedule)) {
        return;
      }
      _cartLines[index] = _cartLines[index].copyWith(
        quantity: targetQuantity,
        schedule: schedule ?? _cartLines[index].schedule,
      );
    }
    notifyListeners();
    if (item.type == StoreMockItemType.product) {
      final cartVariant = _cartVariantPayload(cleanVariant);
      _queueCartSync(
        () => _api.updateCartItem(
          productId: item.id,
          quantity: targetQuantity,
          variant: cartVariant,
        ),
      );
    }
  }

  void updateQuantity(String itemId, int quantity,
      {Map<String, dynamic>? variant}) {
    final cleanVariant = _cleanVariant(variant);
    final key = _variantKey(cleanVariant);
    final index = _cartLines.indexWhere(
      (line) => line.item.id == itemId && line.variantKey == key,
    );
    if (index == -1) return;
    final shouldRemove = quantity <= 0;
    if (quantity <= 0) {
      _cartLines.removeAt(index);
    } else {
      final maxQuantity = maxQuantityFor(
        _cartLines[index].item,
        variant: _cartLines[index].variant,
      );
      if (maxQuantity <= 0) return;
      final targetQuantity = quantity.clamp(1, maxQuantity);
      if (_cartLines[index].quantity == targetQuantity) return;
      _cartLines[index] = _cartLines[index].copyWith(
        quantity: targetQuantity,
      );
      quantity = targetQuantity;
    }
    notifyListeners();
    if (shouldRemove) {
      _queueCartSync(() => _api.removeCartItem(itemId));
    } else {
      final cartVariant = _cartVariantPayload(cleanVariant);
      _queueCartSync(
        () => _api.updateCartItem(
          productId: itemId,
          quantity: quantity.clamp(1, 99),
          variant: cartVariant,
        ),
      );
    }
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
    _queueCartSync(() => _api.removeCartItem(itemId));
  }

  String money(double amount) => formatStoreMoney(amount, decimals: 2);

  bool _isFresh(DateTime? loadedAt, Duration maxAge) {
    if (loadedAt == null) return false;
    return DateTime.now().difference(loadedAt) < maxAge;
  }

  Future<void> ensureMarketplace({
    String? query,
    String? category,
    Duration maxAge = const Duration(seconds: 45),
  }) async {
    final userId = await CurrentUser.id;
    final cacheParams = <String, dynamic>{
      if (query != null && query.isNotEmpty) 'query': query,
      if (category != null && category.isNotEmpty) 'category': category,
    };
    final cached = await _pageCache.get('store', userId ?? '', cacheParams);
    if (!_catalogLoading &&
        _isFresh(_catalogLoadedAt, maxAge) &&
        (query == null || query.isEmpty) &&
        (category == null || category.isEmpty)) {
      return Future.value();
    }
    if (!_catalogLoading && cached != null) {
      try {
        final decoded = jsonDecode(cached) as List;
        final items = decoded
            .map((e) =>
                StoreMockCatalogItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _catalog = items;
        _catalogLoadedAt = DateTime.now();
        notifyListeners();
        return;
      } on Exception catch (_) {
        _pageCache.invalidate('store', userId ?? '');
      }
    }
    return refreshMarketplace(query: query, category: category);
  }

  Future<void> ensureCart({
    Duration maxAge = const Duration(seconds: 45),
  }) {
    if (_cartLoading || _isFresh(_cartLoadedAt, maxAge)) {
      return Future.value();
    }
    return refreshCart();
  }

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
      _catalogLoadedAt = DateTime.now();
      _lastError = null;
      try {
        final userId = await CurrentUser.id;
        final cacheParams = <String, dynamic>{
          if (query != null && query.isNotEmpty) 'query': query,
          if (category != null && category.isNotEmpty) 'category': category,
        };
        await _pageCache.set(
          'store',
          userId ?? '',
          cacheParams,
          jsonEncode(_catalog.map((e) => e.toJson()).toList()),
        );
      } on Exception catch (_) {}
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
      final items = cartLinesFromApi(data);
      if (items != null) {
        _cartLines
          ..clear()
          ..addAll(items);
      }
      _cartLoadedAt = DateTime.now();
    } catch (e) {
      _lastError = e;
    } finally {
      _cartLoading = false;
      notifyListeners();
    }
  }

  Future<List<StoreMockCartLine>> prepareProductCheckout() async {
    await ensureCartSynced();
    try {
      final data = await _api.getCart();
      final items = cartLinesFromApi(data) ?? const <StoreMockCartLine>[];
      _cartLines
        ..clear()
        ..addAll(items);
      _cartLoadedAt = DateTime.now();
      _lastError = null;
      notifyListeners();
    } catch (e) {
      _lastError = e;
      notifyListeners();
      throw const StoreCheckoutException(
        'Could not refresh your cart. Please try again.',
      );
    }

    final productLines = _cartLines
        .where((line) => line.item.type == StoreMockItemType.product)
        .toList(growable: false);
    if (productLines.isEmpty) {
      if (_cartLines.isNotEmpty) {
        throw const StoreCheckoutException(
          'Services are booked directly, not via product checkout.',
        );
      }
      throw const StoreCheckoutException(
        'Your cart is empty. Please add a product again before checkout.',
      );
    }
    return productLines;
  }

  Future<Map<String, dynamic>> checkoutWithWallet({
    required Map<String, String> shippingAddress,
    bool cartPrepared = false,
  }) async {
    if (!cartPrepared) await prepareProductCheckout();
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
    bool cartPrepared = false,
  }) async {
    if (!cartPrepared) await prepareProductCheckout();
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
    final res = await _api.updateOrderStatus(orderId: orderId, status: status);
    unawaited(refreshSellerOrders());
    return res;
  }

  // ── Service bookings (direct booking, no cart per spec) ──
  Future<Map<String, dynamic>> createBooking(Map<String, dynamic> body) async {
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
  static double amountOf(Map<String, dynamic> m) => _number(
      m, const ['total_amount', 'amount', 'total', 'price', 'paid_amount']);

  void _queueCartSync(Future<dynamic> Function() operation) {
    _cartSync = _cartSync.then((_) async {
      try {
        await operation();
        _lastCartSyncError = null;
      } catch (e) {
        _lastCartSyncError = e;
        try {
          final data = await _api.getCart();
          final items = cartLinesFromApi(data);
          if (items != null) {
            _cartLines
              ..clear()
              ..addAll(items);
            _cartLoadedAt = DateTime.now();
          }
        } catch (_) {
          // Keep the optimistic cart visible if the server cart cannot be
          // refreshed; checkout will still stop with the sync error.
        }
        notifyListeners();
      }
    });
    unawaited(_cartSync);
  }

  Future<void> ensureCartSynced() async {
    await _cartSync;
    final error = _lastCartSyncError;
    if (error != null) {
      throw const StoreCheckoutException(
        'Cart sync failed. Please try adding the product again.',
      );
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
      imageUrl: firstImageUrl(json),
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
      imageUrl: firstImageUrl(json),
      icon: _iconForCategory(category),
      price: _number(json, const ['price', 'selling_price', 'amount']),
      duration: _text(json, const ['duration'], fallback: '1 hour'),
      rating: _text(json, const ['rating'], fallback: 'New'),
      reviews: _text(json, const ['reviews', 'review_count'], fallback: '0'),
      raw: json,
    );
  }

  /// Public for testing: parses a `GET /cart` response into cart lines.
  static List<StoreMockCartLine>? cartLinesFromApi(Map<String, dynamic> data) {
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
  static List<Map<String, String>> variantsOf(StoreMockCatalogItem item) {
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
        'stock':
            (map['stock_quantity'] ?? map['stock'])?.toString().trim() ?? '',
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

  /// Resolves the first displayable image URL from an API item.
  ///
  /// Public because the seller manage screens parse the same payload and must
  /// not re-implement the key order: the influencer upload endpoints return
  /// `{fileName, fileUrl}`, so `fileUrl` has to win over the bare `fileName`,
  /// which is a filename and not a URL.
  static String firstImageUrl(Map<String, dynamic> json) {
    String resolve(dynamic value) {
      final raw = value?.toString().trim() ?? '';
      if (raw.isEmpty || raw == 'null') return '';
      return UrlHelper.normalizeUrl(raw);
    }

    String fromMap(Map<dynamic, dynamic> source) {
      final map = source.map((key, value) => MapEntry(key.toString(), value));
      for (final key in const [
        'fileUrl',
        'file_url',
        'secure_url',
        'downloadUrl',
        'download_url',
        'url',
        'image_url',
        'imageUrl',
        'cover_image',
        'coverImage',
        'thumbnail',
        'thumbnail_url',
        'thumbnailUrl',
        'src',
        'path',
        'fileName',
        'filename',
        'name',
      ]) {
        final resolved = resolve(map[key]);
        if (resolved.isNotEmpty) return resolved;
      }
      for (final key in const ['image', 'cover', 'photo', 'asset', 'file']) {
        final value = map[key];
        if (value is Map) {
          final resolved = fromMap(value);
          if (resolved.isNotEmpty) return resolved;
        } else {
          final resolved = resolve(value);
          if (resolved.isNotEmpty) return resolved;
        }
      }
      return '';
    }

    String fromList(dynamic value) {
      if (value is! List) return '';
      for (final entry in value) {
        final resolved = entry is Map ? fromMap(entry) : resolve(entry);
        if (resolved.isNotEmpty) return resolved;
      }
      return '';
    }

    // The influencer upload endpoints return `{fileName, fileUrl}`, so
    // `fileUrl` must be tried before the bare `fileName` (which is not a URL).
    for (final key in const [
      'images',
      'image_urls',
      'imageUrls',
      'media',
      'photos',
      'gallery',
      'attachments',
      'files',
    ]) {
      final resolved = fromList(json[key]);
      if (resolved.isNotEmpty) return resolved;
    }
    // Single-image fallbacks.
    for (final key in const [
      'fileUrl',
      'file_url',
      'secure_url',
      'downloadUrl',
      'download_url',
      'image_url',
      'imageUrl',
      'image',
      'cover',
      'cover_photo',
      'coverPhoto',
      'cover_image',
      'coverImage',
      'thumbnail',
      'thumbnail_url',
      'thumbnailUrl',
      'url',
      'src',
      'path',
      'fileName',
      'filename',
    ]) {
      final value = json[key];
      if (value is Map) {
        final resolved = fromMap(value);
        if (resolved.isNotEmpty) return resolved;
      } else {
        final resolved = resolve(value);
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
