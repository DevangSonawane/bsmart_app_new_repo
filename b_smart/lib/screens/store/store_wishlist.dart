import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/wishlist_api.dart';
import '../../utils/app_error_handler.dart';
import 'store_models.dart';
import 'store_wishlist_screen.dart';

/// Server-backed product wishlist (GET /wishlist et al).
///
/// Singleton ChangeNotifier mirroring [StoreMockState]: full product data,
/// newest-added first. The API is product-only, so only product ids are
/// tracked here.
class WishlistState extends ChangeNotifier {
  WishlistState._();

  static final WishlistState instance = WishlistState._();

  final WishlistApi _api = WishlistApi();

  List<StoreMockCatalogItem> _items = [];
  bool _loading = false;
  bool _loadedOnce = false;
  Object? _lastError;
  final Set<String> _mutatingIds = {};
  bool _clearing = false;

  List<StoreMockCatalogItem> get items => List.unmodifiable(_items);
  int get count => _items.length;
  bool get loading => _loading;
  Object? get lastError => _lastError;
  bool get clearing => _clearing;

  /// User-facing text for [lastError]. Never renders a raw exception
  /// (e.g. "ApiException(404): Not found").
  String? get lastErrorMessage {
    final error = _lastError;
    if (error == null) return null;
    return AppErrorHandler.userMessage(
      error,
      fallback: 'Could not update your wishlist. Please try again.',
    );
  }

  double get totalValue => _items.fold(0.0, (sum, item) => sum + item.price);

  bool isSaved(String productId) => _items.any((item) => item.id == productId);

  bool isMutating(String productId) => _mutatingIds.contains(productId);

  /// Loads once (idempotent) — safe to call from widget initStates.
  Future<void> ensureLoaded() {
    if (_loadedOnce || _loading) return Future.value();
    return refresh();
  }

  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    _lastError = null;
    notifyListeners();
    try {
      final raw = await _api.getWishlist();
      _items = raw
          .map(StoreMockState.productFromApi)
          .where((item) => item.id.trim().isNotEmpty)
          .toList();
      _loadedOnce = true;
      _lastError = null;
    } catch (e) {
      _lastError = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> add(String productId) async {
    if (isSaved(productId) || _mutatingIds.contains(productId)) return;
    _mutatingIds.add(productId);
    _lastError = null;
    notifyListeners();
    try {
      final raw = await _api.addItem(productId);
      _items = raw
          .map(StoreMockState.productFromApi)
          .where((item) => item.id.trim().isNotEmpty)
          .toList();
      _loadedOnce = true;
    } catch (e) {
      _lastError = e;
      rethrow;
    } finally {
      _mutatingIds.remove(productId);
      notifyListeners();
    }
  }

  Future<void> remove(String productId) async {
    if (_mutatingIds.contains(productId)) return;
    _mutatingIds.add(productId);
    _lastError = null;
    notifyListeners();
    try {
      final raw = await _api.removeItem(productId);
      _items = raw
          .map(StoreMockState.productFromApi)
          .where((item) => item.id.trim().isNotEmpty)
          .toList();
    } catch (e) {
      _lastError = e;
      rethrow;
    } finally {
      _mutatingIds.remove(productId);
      notifyListeners();
    }
  }

  Future<void> toggle(String productId) {
    return isSaved(productId) ? remove(productId) : add(productId);
  }

  Future<void> clear() async {
    if (_clearing || _items.isEmpty) return;
    _clearing = true;
    _lastError = null;
    notifyListeners();
    try {
      await _api.clear();
      _items = [];
    } catch (e) {
      _lastError = e;
      rethrow;
    } finally {
      _clearing = false;
      notifyListeners();
    }
  }
}

/// Round white heart button used on product cards and the detail page.
///
/// Fills teal-red when the product is wishlisted; shows a spinner while the
/// wishlist API call is in flight and a snackbar on failure.
class WishlistHeartButton extends StatefulWidget {
  final String productId;
  final double size;
  final double iconSize;

  const WishlistHeartButton({
    super.key,
    required this.productId,
    this.size = 34,
    this.iconSize = 18,
  });

  @override
  State<WishlistHeartButton> createState() => _WishlistHeartButtonState();
}

class _WishlistHeartButtonState extends State<WishlistHeartButton> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(WishlistState.instance.ensureLoaded());
    });
  }

  Future<void> _toggle() async {
    try {
      await WishlistState.instance.toggle(widget.productId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppErrorHandler.userMessage(
              e,
              fallback: 'Could not update your wishlist. Please try again.',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: WishlistState.instance,
      builder: (context, _) {
        final state = WishlistState.instance;
        final saved = state.isSaved(widget.productId);
        final busy = state.isMutating(widget.productId);
        return GestureDetector(
          onTap: busy ? null : _toggle,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 9,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: busy
                ? const Padding(
                    padding: EdgeInsets.all(9),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    // Filled material heart when saved (lucide has no
                    // filled variant), outline lucide heart otherwise.
                    saved ? Icons.favorite : LucideIcons.heart,
                    color: saved
                        ? const Color(0xFF078D92)
                        : const Color(0xFF060D35),
                    size: widget.iconSize,
                  ),
          ),
        );
      },
    );
  }
}

/// Opens the wishlist screen (BStore themed).
void openWishlist(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const StoreWishlistScreen()),
  );
}
