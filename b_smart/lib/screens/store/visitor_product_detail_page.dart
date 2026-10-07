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
import 'store_profile_page.dart';
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
    return formatStoreMoney(_displayPriceValue);
  }

  double get _displayPriceValue {
    if (_variants.isNotEmpty) {
      for (final v in _variants) {
        final matchesColor =
            _selectedColor == null || v['color'] == _selectedColor;
        final matchesSize = _selectedSize == null || v['size'] == _selectedSize;
        if (matchesColor && matchesSize) {
          final parsed = double.tryParse(v['price'] ?? '');
          if (parsed != null && parsed > 0) return parsed;
        }
      }
    }
    return _item.price;
  }

  /// Compare-at price, only from real data: an explicit MRP on the listing,
  /// or the highest variant price when it sits above the selected one.
  double? get _mrp {
    final raw = _item.raw;
    for (final key in const [
      'mrp',
      'MRP',
      'original_price',
      'compare_at_price',
      'comparePrice',
      'list_price',
      'regular_price',
    ]) {
      final value = raw[key];
      final parsed = value is num
          ? value.toDouble()
          : double.tryParse(value?.toString() ?? '');
      if (parsed != null && parsed > _displayPriceValue) return parsed;
    }
    var maxVariant = 0.0;
    for (final v in _variants) {
      final parsed = double.tryParse(v['price'] ?? '');
      if (parsed != null && parsed > maxVariant) maxVariant = parsed;
    }
    if (maxVariant > _displayPriceValue) return maxVariant;
    return null;
  }

  int? get _discountPct {
    final mrp = _mrp;
    if (mrp == null || mrp <= 0) return null;
    final pct = ((mrp - _displayPriceValue) / mrp * 100).round();
    return pct > 0 ? pct : null;
  }

  /// Every usable image on the listing (gallery keys + cover fallback).
  List<String> get _galleryImages {
    final out = <String>[];
    void add(String? url) {
      final trimmed = (url ?? '').trim();
      if (trimmed.isEmpty || out.contains(trimmed)) return;
      out.add(UrlHelper.absoluteUrl(trimmed));
    }

    final raw = _item.raw;
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
      final value = raw[key];
      if (value is! List) continue;
      for (final entry in value) {
        if (entry is String) {
          add(entry);
        } else if (entry is Map) {
          final map = entry.map((k, v) => MapEntry(k.toString(), v));
          for (final rk in const [
            'fileUrl',
            'file_url',
            'secure_url',
            'download_url',
            'url',
            'src',
            'image_url',
            'imageUrl',
            'image',
            'path',
          ]) {
            final candidate = map[rk]?.toString() ?? '';
            if (candidate.trim().isNotEmpty) {
              add(candidate);
              break;
            }
          }
        }
      }
    }
    add(_item.imageUrl);
    return out;
  }

  static String? _rawText(Map<String, dynamic> raw, List<String> keys) {
    for (final key in keys) {
      final value = raw[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static List<String> _rawStringList(
      Map<String, dynamic> raw, List<String> keys) {
    for (final key in keys) {
      final value = raw[key];
      if (value is List) {
        final out = value
            .map((e) => e?.toString().trim() ?? '')
            .where((e) => e.isNotEmpty)
            .toList();
        if (out.isNotEmpty) return out;
      } else if (value is String) {
        final out = value
            .split(RegExp(r'[\n•\-]+'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        if (out.isNotEmpty) return out;
      }
    }
    return const [];
  }

  double? get _ratingValue => double.tryParse(_item.rating.trim());

  int get _reviewsCount {
    final digits = _item.reviews.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits) ?? 0;
  }

  List<String> get _highlights => _rawStringList(_item.raw, const [
        'highlights',
        'key_features',
        'features',
        'keyFeatures',
      ]);

  String? get _dimensions => _rawText(_item.raw, const [
        'dimensions',
        'dimension',
        'size_info',
      ]);

  String? get _warranty => _rawText(_item.raw, const [
        'warranty',
      ]);

  String get _returnPolicy =>
      _rawText(_item.raw, const [
        'return_policy',
        'returnPolicy',
        'returns',
        'return_policy_text',
      ]) ??
      '7 Days Replacement';

  String get _dispatchLabel {
    final raw = _item.duration.trim();
    return raw.isEmpty ? '2-3 days' : raw;
  }

  /// Same-category items first, then the rest — never the item itself.
  List<StoreMockCatalogItem> get _similarItems {
    final pool =
        StoreMockState.catalog.where((e) => e.id != _item.id).toList();
    int score(StoreMockCatalogItem e) {
      var s = 0;
      if (e.category.trim().toLowerCase() ==
          _item.category.trim().toLowerCase()) {
        s += 2;
      }
      if (e.type == _item.type) s += 1;
      return s;
    }

    pool.sort((a, b) => score(b).compareTo(score(a)));
    return pool.take(8).toList();
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

  void _openStore() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            StoreProfilePage(ownerUserId: widget.ownerUserId),
      ),
    );
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
    final stockLabel = StoreMockState.instance.stockLabelFor(
      _item,
      variant: _selectedVariant,
    );
    final stockQuantity = StoreMockState.instance.stockQuantityFor(
      _item,
      variant: _selectedVariant,
    );
    final hasOwner = (widget.ownerUserId?.trim().isNotEmpty == true);

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
                padding: const EdgeInsets.fromLTRB(0, 12, 0, 108),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _ProductTopBar(onCart: _openCart),
                  ),
                  const SizedBox(height: 12),
                  _ProductGallery(
                    images: _galleryImages,
                    productId: _item.id,
                    discountPct: _discountPct,
                  ),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _TitlePriceCard(
                      category: product.category,
                      title: product.title,
                      ratingValue: _ratingValue,
                      ratingLabel: product.rating,
                      reviewsCount: _reviewsCount,
                      priceLabel: _displayPrice,
                      mrpLabel:
                          _mrp == null ? null : formatStoreMoney(_mrp!),
                      discountPct: _discountPct,
                      stockLabel: stockLabel,
                      isOutOfStock: isOutOfStock,
                      lowStock: !isOutOfStock &&
                          stockQuantity != null &&
                          stockQuantity <= 5,
                      stockQuantity: stockQuantity,
                      onRatingTap: _openReviews,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _PurchaseCard(
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
                      quantity: _quantity,
                      onMinus: isOutOfStock || _quantity <= 1
                          ? null
                          : () => _setQuantity(_quantity - 1),
                      onPlus: isOutOfStock || _quantity >= maxQuantity
                          ? null
                          : () => _setQuantity(_quantity + 1),
                      quantityNote: isOutOfStock
                          ? 'This option is currently unavailable.'
                          : stockQuantity == null
                              ? 'Quantity is checked again before checkout.'
                              : 'You can add up to $maxQuantity ${maxQuantity == 1 ? 'unit' : 'units'} for this option.',
                      quantityNoteError: isOutOfStock,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _AssuranceCard(
                      dispatchLabel: _dispatchLabel,
                      returnLabel: _returnPolicy,
                    ),
                  ),
                  if (_highlights.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _HighlightsCard(highlights: _highlights),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _DetailsAccordion(
                      description: product.description,
                      category: product.category,
                      productId: _item.id,
                      dimensions: _dimensions,
                      warranty: _warranty,
                      returnPolicy: _returnPolicy,
                      dispatchLabel: _dispatchLabel,
                    ),
                  ),
                  if (hasOwner) ...[
                    const SizedBox(height: 10),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      child: FutureBuilder<_ProductOwner?>(
                        future: _ownerFuture,
                        builder: (context, snapshot) {
                          return _SellerCard(
                            owner: snapshot.data,
                            loading: snapshot.connectionState !=
                                ConnectionState.done,
                            onViewStore: _openStore,
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _ReviewsSummary(
                      ratingValue: _ratingValue,
                      ratingLabel: product.rating,
                      reviewsCount: _reviewsCount,
                      onTap: _openReviews,
                    ),
                  ),
                  if (_similarItems.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _SimilarCarousel(
                      items: _similarItems,
                      onTap: (item) => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => VisitorProductDetailPage(
                            product:
                                VisitorProductDetailData(item: item),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
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

class _ProductGallery extends StatefulWidget {
  final List<String> images;
  final String productId;
  final int? discountPct;

  const _ProductGallery({
    required this.images,
    required this.productId,
    required this.discountPct,
  });

  @override
  State<_ProductGallery> createState() => _ProductGalleryState();
}

class _ProductGalleryState extends State<_ProductGallery> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    return SizedBox(
      height: 330,
      width: double.infinity,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: images.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => StoreItemImage(
              imageUrl: images[i],
              icon: LucideIcons.package,
              width: double.infinity,
              height: 330,
              debugLabel: 'store-product-detail',
            ),
          ),
          if (widget.discountPct != null)
            Positioned(
              top: 14,
              left: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF388E3C),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${widget.discountPct}% OFF',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          Positioned(
            top: 12,
            right: 16,
            child: WishlistHeartButton(
              productId: widget.productId,
              size: 42,
              iconSize: 21,
            ),
          ),
          if (images.length > 1)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.38),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < images.length; i++) ...[
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: _index == i ? 18 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: _index == i
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        if (i != images.length - 1)
                          const SizedBox(width: 5),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TitlePriceCard extends StatelessWidget {
  final String category;
  final String title;
  final double? ratingValue;
  final String ratingLabel;
  final int reviewsCount;
  final String priceLabel;
  final String? mrpLabel;
  final int? discountPct;
  final String stockLabel;
  final bool isOutOfStock;
  final bool lowStock;
  final int? stockQuantity;
  final VoidCallback onRatingTap;

  const _TitlePriceCard({
    required this.category,
    required this.title,
    required this.ratingValue,
    required this.ratingLabel,
    required this.reviewsCount,
    required this.priceLabel,
    required this.mrpLabel,
    required this.discountPct,
    required this.stockLabel,
    required this.isOutOfStock,
    required this.lowStock,
    required this.stockQuantity,
    required this.onRatingTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: storeSoftCardDecoration(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            category.toUpperCase(),
            style: const TextStyle(
              color: BStoreColors.accentPurple,
              fontSize: 11.5,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              color: BStoreColors.textPrimary,
              fontSize: 19,
              height: 1.2,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: onRatingTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (ratingValue != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF388E3C),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            ratingValue!.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Icon(LucideIcons.star,
                              color: Colors.white, size: 12),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F2F6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        ratingLabel.isEmpty ? 'New' : ratingLabel,
                        style: const TextStyle(
                          color: BStoreColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      reviewsCount > 0
                          ? '$reviewsCount rating${reviewsCount == 1 ? '' : 's'}'
                          : 'No ratings yet',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: BStoreColors.textSoft,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(LucideIcons.chevronRight,
                      color: BStoreColors.textSoft, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                priceLabel,
                style: const TextStyle(
                  color: BStoreColors.textPrimary,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (mrpLabel != null) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    mrpLabel!,
                    style: const TextStyle(
                      color: BStoreColors.textSoft,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ),
              ],
              if (discountPct != null) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '$discountPct% off',
                    style: const TextStyle(
                      color: Color(0xFF388E3C),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            'Inclusive of all taxes',
            style: TextStyle(
              color: BStoreColors.textSoft,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                isOutOfStock
                    ? LucideIcons.circleX
                    : lowStock
                        ? LucideIcons.flame
                        : LucideIcons.circleCheck,
                size: 16,
                color: isOutOfStock || lowStock
                    ? const Color(0xFFB3261E)
                    : const Color(0xFF388E3C),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  isOutOfStock
                      ? 'Out of stock'
                      : lowStock
                          ? 'Only $stockQuantity left in stock — order soon'
                          : stockLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isOutOfStock || lowStock
                        ? const Color(0xFFB3261E)
                        : const Color(0xFF388E3C),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PurchaseCard extends StatelessWidget {
  final List<String> colors;
  final List<String> sizes;
  final String? selectedColor;
  final String? selectedSize;
  final ValueChanged<String> onColorSelected;
  final ValueChanged<String> onSizeSelected;
  final int quantity;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  final String quantityNote;
  final bool quantityNoteError;

  const _PurchaseCard({
    required this.colors,
    required this.sizes,
    required this.selectedColor,
    required this.selectedSize,
    required this.onColorSelected,
    required this.onSizeSelected,
    required this.quantity,
    required this.onMinus,
    required this.onPlus,
    required this.quantityNote,
    required this.quantityNoteError,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: storeSoftCardDecoration(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (colors.isNotEmpty || sizes.isNotEmpty) ...[
            _VariantSelector(
              colors: colors,
              sizes: sizes,
              selectedColor: selectedColor,
              selectedSize: selectedSize,
              onColorSelected: onColorSelected,
              onSizeSelected: onSizeSelected,
            ),
            const SizedBox(height: 14),
          ],
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
                quantity: quantity,
                onMinus: onMinus,
                onPlus: onPlus,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            quantityNote,
            style: TextStyle(
              color: quantityNoteError
                  ? const Color(0xFFB3261E)
                  : BStoreColors.textSoft,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AssuranceCard extends StatelessWidget {
  final String dispatchLabel;
  final String returnLabel;

  const _AssuranceCard({
    required this.dispatchLabel,
    required this.returnLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: storeSoftCardDecoration(radius: 16),
      child: Column(
        children: [
          _AssuranceRow(
            icon: LucideIcons.truck,
            title: 'Fast delivery',
            subtitle: 'Arrives in $dispatchLabel',
          ),
          const SizedBox(height: 14),
          _AssuranceRow(
            icon: LucideIcons.rotateCcw,
            title: 'Easy replacement',
            subtitle: returnLabel,
          ),
          const SizedBox(height: 14),
          const _AssuranceRow(
            icon: LucideIcons.shieldCheck,
            title: 'Secure checkout',
            subtitle: 'Buyer protection on every order',
          ),
        ],
      ),
    );
  }
}

class _AssuranceRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _AssuranceRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
            color: BStoreColors.primarySoft,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: BStoreColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: BStoreColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: BStoreColors.textSoft,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HighlightsCard extends StatelessWidget {
  final List<String> highlights;

  const _HighlightsCard({required this.highlights});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: storeSoftCardDecoration(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Highlights',
            style: TextStyle(
              color: BStoreColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < highlights.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(LucideIcons.circleCheck,
                      color: BStoreColors.primary, size: 15),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    highlights[i],
                    style: const TextStyle(
                      color: BStoreColors.textSecondary,
                      fontSize: 13.5,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            if (i != highlights.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _DetailsAccordion extends StatelessWidget {
  final String description;
  final String category;
  final String productId;
  final String? dimensions;
  final String? warranty;
  final String returnPolicy;
  final String dispatchLabel;

  const _DetailsAccordion({
    required this.description,
    required this.category,
    required this.productId,
    required this.dimensions,
    required this.warranty,
    required this.returnPolicy,
    required this.dispatchLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: storeSoftCardDecoration(radius: 16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _SpecTile(
            title: 'Product details',
            initiallyExpanded: true,
            children: [
              if (description.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    description.trim(),
                    style: const TextStyle(
                      color: BStoreColors.textSecondary,
                      fontSize: 13.5,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              _SpecRow(label: 'Category', value: category),
              _SpecRow(
                label: 'Product ID',
                value: productId.length > 14
                    ? '${productId.substring(0, 14)}…'
                    : productId,
              ),
              if (dimensions != null)
                _SpecRow(label: 'Dimensions', value: dimensions!),
              if (warranty != null)
                _SpecRow(label: 'Warranty', value: warranty!),
            ],
          ),
          _SpecTile(
            title: 'Delivery & returns',
            children: [
              _SpecRow(label: 'Dispatch', subtitle: 'Arrives in $dispatchLabel'),
              _SpecRow(label: 'Returns', subtitle: returnPolicy),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpecTile extends StatelessWidget {
  final String title;
  final bool initiallyExpanded;
  final List<Widget> children;

  const _SpecTile({
    required this.title,
    this.initiallyExpanded = false,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      initiallyExpanded: initiallyExpanded,
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      shape: const Border(),
      collapsedShape: const Border(),
      title: Text(
        title,
        style: const TextStyle(
          color: BStoreColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w900,
        ),
      ),
      children: children,
    );
  }
}

class _SpecRow extends StatelessWidget {
  final String label;
  final String? value;
  final String? subtitle;

  const _SpecRow({required this.label, this.value, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: BStoreColors.textSoft,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value ?? subtitle ?? '',
              style: TextStyle(
                color: value != null
                    ? BStoreColors.textPrimary
                    : BStoreColors.textSecondary,
                fontSize: 13,
                fontWeight:
                    value != null ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SellerCard extends StatelessWidget {
  final _ProductOwner? owner;
  final bool loading;
  final VoidCallback onViewStore;

  const _SellerCard({
    required this.owner,
    required this.loading,
    required this.onViewStore,
  });

  @override
  Widget build(BuildContext context) {
    final ownerName = owner?.displayName.trim().isNotEmpty == true
        ? owner!.displayName.trim()
        : (loading ? 'Loading store...' : 'Store owner');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: storeSoftCardDecoration(radius: 16),
      child: Row(
        children: [
          ClipOval(
            child: Container(
              width: 52,
              height: 52,
              color: BStoreColors.cardWarm,
              alignment: Alignment.center,
              child: owner?.avatarUrl.trim().isNotEmpty == true
                  ? SafeNetworkImage(
                      url: owner!.avatarUrl,
                      headers: owner!.avatarHeaders,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                    )
                  : Text(
                      ownerName.characters.first.toUpperCase(),
                      style: const TextStyle(
                        color: BStoreColors.textPrimary,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
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
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                const Row(
                  children: [
                    Icon(LucideIcons.badgeCheck,
                        color: BStoreColors.primary, size: 13),
                    SizedBox(width: 4),
                    Text(
                      'Verified seller',
                      style: TextStyle(
                        color: BStoreColors.accentPurple,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 38,
            child: FilledButton(
              onPressed: loading ? null : onViewStore,
              style: BStoreButtons.filled(radius: 10),
              child: const Text(
                'View Store',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewsSummary extends StatelessWidget {
  final double? ratingValue;
  final String ratingLabel;
  final int reviewsCount;
  final VoidCallback onTap;

  const _ReviewsSummary({
    required this.ratingValue,
    required this.ratingLabel,
    required this.reviewsCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: storeSoftCardDecoration(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ratings & Reviews',
            style: TextStyle(
              color: BStoreColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                ratingValue != null
                    ? ratingValue!.toStringAsFixed(1)
                    : (ratingLabel.isEmpty ? 'New' : ratingLabel),
                style: const TextStyle(
                  color: BStoreColors.textPrimary,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StarsRow(value: ratingValue ?? 0, size: 15),
                    const SizedBox(height: 4),
                    Text(
                      reviewsCount > 0
                          ? '$reviewsCount verified rating${reviewsCount == 1 ? '' : 's'}'
                          : 'No reviews yet',
                      style: const TextStyle(
                        color: BStoreColors.textSoft,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: OutlinedButton(
              onPressed: onTap,
              style: BStoreButtons.outlined(radius: 10),
              child: const Text(
                'See all reviews',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StarsRow extends StatelessWidget {
  final double value;
  final double size;

  const _StarsRow({required this.value, this.size = 13});

  @override
  Widget build(BuildContext context) {
    final full = value.round().clamp(0, 5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++)
          Padding(
            padding: EdgeInsets.only(right: i == 4 ? 0 : 2),
            child: Icon(
              LucideIcons.star,
              size: size,
              color: i < full
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFFDADDE3),
            ),
          ),
      ],
    );
  }
}

class _SimilarCarousel extends StatelessWidget {
  final List<StoreMockCatalogItem> items;
  final ValueChanged<StoreMockCatalogItem> onTap;

  const _SimilarCarousel({required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Similar Products',
            style: TextStyle(
              color: BStoreColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 212,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) =>
                _SimilarCard(item: items[i], onTap: () => onTap(items[i])),
          ),
        ),
      ],
    );
  }
}

class _SimilarCard extends StatelessWidget {
  final StoreMockCatalogItem item;
  final VoidCallback onTap;

  const _SimilarCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final rating = double.tryParse(item.rating.trim());
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 152,
        decoration: storeSoftCardDecoration(radius: 14),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StoreItemImage(
              imageUrl: item.imageUrl,
              icon: item.icon,
              width: double.infinity,
              height: 118,
              debugLabel: 'store-product-similar',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: BStoreColors.textPrimary,
                      fontSize: 12.5,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.priceLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: BStoreColors.textPrimary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (rating != null)
                    Row(
                      children: [
                        _StarsRow(value: rating, size: 11),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            item.reviews,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: BStoreColors.textSoft,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
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
