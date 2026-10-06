import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/api_client.dart';
import '../../api/phase2_store_api.dart';
import '../../services/supabase_service.dart';
import '../../utils/url_helper.dart';
import '../../widgets/safe_network_image.dart';
import 'shared/store_shared_widgets.dart';
import 'shared/store_money.dart';
import 'store_models.dart';
import 'store_theme.dart';
import 'store_wishlist.dart';
import 'visitor_product_reviews_page.dart';
import 'visitor_store_cart_page.dart';

class VisitorProductDetailData {
  final StoreMockCatalogItem item;

  const VisitorProductDetailData({
    required this.item,
  });

  String get imageUrl => item.imageUrl;
  String get title => item.title;
  String get price => item.priceLabel;
  String get rating => item.rating;
  String get reviews => item.reviews;
  String get category => item.category;
  String get description => item.description;
}

class VisitorProductDetailPage extends StatefulWidget {
  final VisitorProductDetailData product;
  final String? ownerUserId;

  const VisitorProductDetailPage({
    super.key,
    required this.product,
    this.ownerUserId,
  });

  @override
  State<VisitorProductDetailPage> createState() =>
      _VisitorProductDetailPageState();
}

class _VisitorProductDetailPageState extends State<VisitorProductDetailPage> {
  late Future<_ProductOwner?> _ownerFuture;
  late StoreMockCatalogItem _item;
  int _quantity = 1;
  String? _selectedColor;
  String? _selectedSize;

  static final _serverIdPattern = RegExp(r'^[0-9a-fA-F]{24}$');

  List<Map<String, String>> get _variants => StoreMockState.variantsOf(_item);

  Set<String> get _colors => StoreMockState.colorsOf(_item);

  Set<String> get _sizes => StoreMockState.sizesOf(_item);

  Map<String, dynamic> get _selectedVariant {
    final variant = <String, dynamic>{
      if (_selectedColor != null) 'color': _selectedColor,
      if (_selectedSize != null) 'size': _selectedSize,
    };
    for (final option in _variants) {
      final matchesColor =
          _selectedColor == null || option['color'] == _selectedColor;
      final matchesSize =
          _selectedSize == null || option['size'] == _selectedSize;
      if (!matchesColor || !matchesSize) continue;
      final price = double.tryParse(option['price'] ?? '');
      final stock = int.tryParse(option['stock'] ?? '');
      if (price != null && price > 0) variant['price'] = price;
      if (stock != null) variant['stock_quantity'] = stock;
      break;
    }
    return variant;
  }

  int get _maxQuantity =>
      StoreMockState.instance.maxQuantityFor(_item, variant: _selectedVariant);

  bool get _isOutOfStock => _maxQuantity <= 0;

  String get _displayPrice {
    if (_variants.isNotEmpty) {
      for (final v in _variants) {
        final matchesColor =
            _selectedColor == null || v['color'] == _selectedColor;
        final matchesSize = _selectedSize == null || v['size'] == _selectedSize;
        if (matchesColor && matchesSize) {
          final parsed = double.tryParse(v['price'] ?? '');
          if (parsed != null && parsed > 0) {
            return formatStoreMoney(parsed);
          }
        }
      }
    }
    return _item.priceLabel;
  }

  @override
  void initState() {
    super.initState();
    _item = widget.product.item;
    _ownerFuture = _loadOwner();
    _selectDefaultVariant();
    _quantity = StoreMockState.instance
        .quantityForVariant(_item, _selectedVariant)
        .clamp(1, _maxQuantity <= 0 ? 1 : _maxQuantity);
    if (StoreMockState.instance.quantityFor(_item.id) == 0) {
      _quantity = 1;
    }
    StoreMockState.instance.addListener(_syncQuantityFromCart);
    _refreshDetail();
  }

  @override
  void dispose() {
    StoreMockState.instance.removeListener(_syncQuantityFromCart);
    super.dispose();
  }

  void _selectDefaultVariant() {
    final colors = StoreMockState.colorsOf(_item);
    final sizes = StoreMockState.sizesOf(_item);
    if (colors.isNotEmpty) _selectedColor = colors.first;
    if (sizes.isNotEmpty) _selectedSize = sizes.first;
  }

  void _onVariantChanged() {
    final qty = StoreMockState.instance.quantityForVariant(
      _item,
      _selectedVariant,
    );
    final maxQuantity = _maxQuantity;
    setState(() {
      _quantity = maxQuantity <= 0 ? 1 : (qty > 0 ? qty : 1);
    });
  }

  /// Refetches the product by id so detail is never stale.
  /// Seed/offline items keep the passed-in data on any failure.
  Future<void> _refreshDetail() async {
    final id = _item.id.trim();
    if (!_serverIdPattern.hasMatch(id)) return;
    try {
      final data = await Phase2StoreApi().getProduct(id);
      if (!mounted || data.isEmpty) return;
      final fresh = StoreMockState.productFromApi(data);
      setState(() {
        _item = fresh;
        if (_selectedColor != null &&
            !StoreMockState.colorsOf(fresh).contains(_selectedColor)) {
          _selectedColor = null;
        }
        if (_selectedSize != null &&
            !StoreMockState.sizesOf(fresh).contains(_selectedSize)) {
          _selectedSize = null;
        }
        if (_selectedColor == null || _selectedSize == null) {
          _selectDefaultVariant();
        }
        final maxQuantity = _maxQuantity;
        _quantity = maxQuantity <= 0 ? 1 : _quantity.clamp(1, maxQuantity);
      });
    } catch (_) {
      // Keep the listed data; browse/Search already show server content.
    }
  }

  void _syncQuantityFromCart() {
    final cartQuantity = StoreMockState.instance.quantityForVariant(
      _item,
      _selectedVariant,
    );
    final maxQuantity = _maxQuantity;
    final nextQuantity =
        maxQuantity <= 0 ? 1 : (cartQuantity > 0 ? cartQuantity : 1);
    if (!mounted || nextQuantity == _quantity) return;
    setState(() => _quantity = nextQuantity);
  }

  Future<_ProductOwner?> _loadOwner() async {
    final ownerId = widget.ownerUserId?.trim();
    if (ownerId == null || ownerId.isEmpty) return null;

    final user = await SupabaseService().getUserById(ownerId);
    if (user == null) return null;

    final name = _firstString(user, const [
      'full_name',
      'fullName',
      'displayName',
      'name',
      'username',
    ]);
    final avatarUrl = UrlHelper.absoluteUrl(
      _firstString(user, const [
            'avatar_url',
            'avatarUrl',
            'profile_picture',
            'profilePicture',
            'profile_image',
            'profileImage',
            'photoUrl',
            'avatar',
          ]) ??
          '',
    );

    Map<String, String>? avatarHeaders;
    if (avatarUrl.isNotEmpty && UrlHelper.shouldAttachAuthHeader(avatarUrl)) {
      final token = await ApiClient().getToken();
      if (token != null && token.isNotEmpty) {
        avatarHeaders = {'Authorization': 'Bearer $token'};
      }
    }

    return _ProductOwner(
      displayName: name ?? 'Store owner',
      avatarUrl: avatarUrl,
      avatarHeaders: avatarHeaders,
    );
  }

  static String? _firstString(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  void _openCart() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VisitorStoreCartScreen(ownerUserId: widget.ownerUserId),
      ),
    );
  }

  void _addToCart({required bool openCart}) {
    if (_isOutOfStock) return;
    StoreMockState.instance.setCartQuantity(
      _item,
      _quantity.clamp(1, _maxQuantity),
      variant: _selectedVariant,
    );
    if (openCart) {
      _openCart();
      return;
    }
  }

  void _setQuantity(int quantity) {
    final maxQuantity = _maxQuantity;
    if (maxQuantity <= 0) {
      setState(() => _quantity = 1);
      return;
    }
    final nextQuantity = quantity.clamp(1, maxQuantity);
    setState(() => _quantity = nextQuantity);
    if (StoreMockState.instance.quantityForVariant(
          _item,
          _selectedVariant,
        ) >
        0) {
      StoreMockState.instance.setCartQuantity(
        _item,
        nextQuantity,
        variant: _selectedVariant,
      );
    }
  }

  void _openReviews() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VisitorProductReviewsPage(
          product: VisitorProductDetailData(item: _item),
          ownerUserId: widget.ownerUserId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = VisitorProductDetailData(item: _item);
    final maxQuantity = _maxQuantity;
    final isOutOfStock = maxQuantity <= 0;

    return Theme(
      data: BStoreTheme.data(context),
      child: Scaffold(
        backgroundColor: BStoreColors.background,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 108),
                children: [
                  _ProductTopBar(onCart: _openCart),
                  const SizedBox(height: 16),
                  _ProductImageCard(
                    imageUrl: product.imageUrl,
                    productId: _item.id,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    product.category,
                    style: const TextStyle(
                      color: BStoreColors.accentPurple,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    product.title,
                    style: const TextStyle(
                      color: BStoreColors.textPrimary,
                      fontSize: 24,
                      height: 1.08,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 9),
                  _RatingLine(
                    rating: product.rating,
                    reviews: product.reviews,
                    onTap: _openReviews,
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _displayPrice,
                          style: const TextStyle(
                            color: BStoreColors.primary,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      _StockBadge(stock: _maxQuantity),
                    ],
                  ),
                  const SizedBox(height: 11),
                  Text(
                    product.description,
                    style: const TextStyle(
                      color: BStoreColors.textSecondary,
                      fontSize: 13.5,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _IncludedTile(),
                  const SizedBox(height: 10),
                  FutureBuilder<_ProductOwner?>(
                    future: _ownerFuture,
                    builder: (context, snapshot) {
                      return _SellerCard(
                        owner: snapshot.data,
                        loading:
                            snapshot.connectionState != ConnectionState.done,
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Quantity',
                          style: TextStyle(
                            color: BStoreColors.textPrimary,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      _QuantityControl(
                        quantity: _quantity,
                        onMinus: isOutOfStock || _quantity <= 1
                            ? null
                            : () => _setQuantity(_quantity - 1),
                        onPlus: isOutOfStock || _quantity >= maxQuantity
                            ? null
                            : () => _setQuantity(_quantity + 1),
                      ),
                    ],
                  ),
                  if (_variants.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _VariantSelector(
                      colors: _colors.toList(),
                      sizes: _sizes.toList(),
                      selectedColor: _selectedColor,
                      selectedSize: _selectedSize,
                      onColorSelected: (color) {
                        setState(() => _selectedColor = color);
                        _onVariantChanged();
                      },
                      onSizeSelected: (size) {
                        setState(() => _selectedSize = size);
                        _onVariantChanged();
                      },
                    ),
                  ],
                  const SizedBox(height: 10),
                  const Divider(color: BStoreColors.divider),
                  const SizedBox(height: 8),
                  const _DeliveryRow(),
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _ProductBottomActions(
                  enabled: !isOutOfStock,
                  onAddToCart: () => _addToCart(openCart: false),
                  onBuyNow: () => _addToCart(openCart: true),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VariantSelector extends StatelessWidget {
  final List<String> colors;
  final List<String> sizes;
  final String? selectedColor;
  final String? selectedSize;
  final ValueChanged<String> onColorSelected;
  final ValueChanged<String> onSizeSelected;

  const _VariantSelector({
    required this.colors,
    required this.sizes,
    required this.selectedColor,
    required this.selectedSize,
    required this.onColorSelected,
    required this.onSizeSelected,
  });

  static Color? _parseColor(String value) {
    var hex = value.trim().replaceFirst('#', '');
    if (hex.length == 3) {
      hex = hex.split('').map((c) => '$c$c').join();
    }
    if (hex.length == 6) {
      final parsed = int.tryParse(hex, radix: 16);
      if (parsed != null) return Color(0xFF000000 | parsed);
    }
    if (hex.length == 8) {
      final parsed = int.tryParse(hex, radix: 16);
      if (parsed != null) return Color(parsed);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (colors.isNotEmpty) ...[
          Text(
            'Color${selectedColor == null ? '' : ': $selectedColor'}',
            style: const TextStyle(
              color: BStoreColors.textPrimary,
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final color in colors)
                _ColorChip(
                  label: color,
                  swatch: _parseColor(color),
                  selected: selectedColor == color,
                  onTap: () => onColorSelected(color),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (sizes.isNotEmpty) ...[
          Text(
            'Size${selectedSize == null ? '' : ': $selectedSize'}',
            style: const TextStyle(
              color: BStoreColors.textPrimary,
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final size in sizes)
                _SizeChip(
                  label: size,
                  selected: selectedSize == size,
                  onTap: () => onSizeSelected(size),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ColorChip extends StatelessWidget {
  final String label;
  final Color? swatch;
  final bool selected;
  final VoidCallback onTap;

  const _ColorChip({
    required this.label,
    required this.swatch,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final circle = swatch ?? BStoreColors.textSecondary;
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: circle,
            border: Border.all(
              color: selected ? BStoreColors.primary : BStoreColors.divider,
              width: selected ? 3 : 1.5,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: BStoreColors.primary.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: selected
              ? const Icon(LucideIcons.check, color: Colors.white, size: 18)
              : null,
        ),
      ),
    );
  }
}

class _SizeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SizeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? BStoreColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: selected ? BStoreColors.primary : BStoreColors.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : BStoreColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ProductOwner {
  final String displayName;
  final String avatarUrl;
  final Map<String, String>? avatarHeaders;

  const _ProductOwner({
    required this.displayName,
    required this.avatarUrl,
    required this.avatarHeaders,
  });
}

class _ProductTopBar extends StatelessWidget {
  final VoidCallback onCart;

  const _ProductTopBar({required this.onCart});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(LucideIcons.arrowLeft, size: 25),
              color: BStoreColors.textPrimary,
            ),
          ),
          const Center(child: StoreBsmartWordmark()),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: StoreMockState.instance,
                  builder: (context, _) => IconButton(
                    onPressed: onCart,
                    icon: Badge.count(
                      count: StoreMockState.instance.cartCount,
                      backgroundColor: BStoreColors.primary,
                      child: const Icon(LucideIcons.shoppingCart, size: 26),
                    ),
                    color: BStoreColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductImageCard extends StatelessWidget {
  final String imageUrl;
  final String productId;

  const _ProductImageCard({
    required this.imageUrl,
    required this.productId,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          StoreItemImage(
            imageUrl: imageUrl,
            icon: LucideIcons.package,
            width: double.infinity,
            height: 250,
            debugLabel: 'store-product-detail',
          ),
          Positioned(
            top: 14,
            right: 14,
            child: WishlistHeartButton(
              productId: productId,
              size: 42,
              iconSize: 21,
            ),
          ),
          Positioned(
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.76),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: BStoreColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  for (var i = 0; i < 2; i++) ...[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFDADDE3),
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (i == 0) const SizedBox(width: 10),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingLine extends StatelessWidget {
  final String rating;
  final String reviews;
  final VoidCallback? onTap;

  const _RatingLine({
    required this.rating,
    required this.reviews,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.star, color: BStoreColors.primary, size: 18),
            const SizedBox(width: 8),
            Text(
              rating,
              style: const TextStyle(
                color: BStoreColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 14),
            Container(width: 1, height: 20, color: const Color(0xFFD2D7E0)),
            const SizedBox(width: 14),
            Text(
              '$reviews reviews',
              style: const TextStyle(
                color: BStoreColors.textSoft,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StockBadge extends StatelessWidget {
  final int? stock;

  const _StockBadge({required this.stock});

  @override
  Widget build(BuildContext context) {
    final inStock = (stock ?? 1) > 0;
    final label = stock == null
        ? 'In stock'
        : !inStock
            ? 'Out of stock'
            : stock! <= 5
                ? 'Only $stock left'
                : 'In stock';
    final color = !inStock ? const Color(0xFFB3261E) : BStoreColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: inStock ? const Color(0xFFE5F5F3) : const Color(0xFFFDECEA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: color,
            child: Icon(
              inStock ? LucideIcons.check : LucideIcons.x,
              color: Colors.white,
              size: 14,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _IncludedTile extends StatelessWidget {
  const _IncludedTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: storeSoftCardDecoration(radius: 12),
      child: const Row(
        children: [
          Icon(LucideIcons.package, color: BStoreColors.primary, size: 22),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              "What's included",
              style: TextStyle(
                color: BStoreColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Icon(LucideIcons.chevronDown,
              color: BStoreColors.textPrimary, size: 22),
        ],
      ),
    );
  }
}

class _SellerCard extends StatelessWidget {
  final _ProductOwner? owner;
  final bool loading;

  const _SellerCard({required this.owner, required this.loading});

  @override
  Widget build(BuildContext context) {
    final ownerName = owner?.displayName.trim().isNotEmpty == true
        ? owner!.displayName.trim()
        : (loading ? 'Loading store...' : 'Store owner');

    return Container(
      height: 86,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: storeSoftCardDecoration(radius: 13),
      child: Row(
        children: [
          ClipOval(
            child: Container(
              width: 58,
              height: 58,
              color: BStoreColors.cardWarm,
              alignment: Alignment.center,
              child: owner?.avatarUrl.trim().isNotEmpty == true
                  ? SafeNetworkImage(
                      url: owner!.avatarUrl,
                      headers: owner!.avatarHeaders,
                      width: 58,
                      height: 58,
                      fit: BoxFit.cover,
                    )
                  : Text(
                      ownerName.characters.first.toUpperCase(),
                      style: const TextStyle(
                        color: BStoreColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sold by',
                  style: TextStyle(
                    color: BStoreColors.textSoft,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  ownerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: BStoreColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 1),
                const Text(
                  'Personal Store',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: BStoreColors.accentPurple,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(LucideIcons.messageCircle, size: 16),
            label: const Text('Message'),
            style: OutlinedButton.styleFrom(
              foregroundColor: BStoreColors.textPrimary,
              side: const BorderSide(color: BStoreColors.divider),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuantityControl extends StatelessWidget {
  final int quantity;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  const _QuantityControl({
    required this.quantity,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 126,
      height: 44,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFD5DEE4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            onPressed: onMinus,
            icon: const Icon(LucideIcons.minus),
            color: BStoreColors.primary,
          ),
          Text(
            '$quantity',
            style: const TextStyle(
              color: BStoreColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          IconButton(
            onPressed: onPlus,
            icon: const Icon(LucideIcons.plus),
            color:
                onPlus == null ? BStoreColors.textMuted : BStoreColors.primary,
          ),
        ],
      ),
    );
  }
}

class _DeliveryRow extends StatelessWidget {
  const _DeliveryRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(LucideIcons.truck, color: BStoreColors.primary, size: 28),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Delivery',
                style: TextStyle(
                  color: BStoreColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Arrives in 2-3 days',
                style: TextStyle(
                  color: BStoreColors.textSoft,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Icon(LucideIcons.chevronRight,
            color: BStoreColors.textPrimary, size: 24),
      ],
    );
  }
}

class _ProductBottomActions extends StatelessWidget {
  final bool enabled;
  final VoidCallback onAddToCart;
  final VoidCallback onBuyNow;

  const _ProductBottomActions({
    required this.enabled,
    required this.onAddToCart,
    required this.onBuyNow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BStoreDecorations.topPanel(),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 46,
              child: OutlinedButton.icon(
                onPressed: enabled ? onAddToCart : null,
                icon: const Icon(LucideIcons.shoppingCart, size: 18),
                label: Text(enabled ? 'Add to Cart' : 'Out of Stock'),
                style: BStoreButtons.outlined(
                  foreground: BStoreColors.primary,
                  border: BStoreColors.primary,
                  radius: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 46,
              child: FilledButton(
                onPressed: enabled ? onBuyNow : null,
                style: BStoreButtons.filled(radius: 12),
                child: Text(
                  enabled ? 'Buy Now' : 'Unavailable',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
