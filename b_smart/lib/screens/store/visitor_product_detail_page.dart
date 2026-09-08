import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/api_client.dart';
import '../../services/supabase_service.dart';
import '../../utils/url_helper.dart';
import '../../widgets/safe_network_image.dart';
import 'shared/store_shared_widgets.dart';
import 'store_theme.dart';
import 'visitor_store_cart_page.dart';

class VisitorProductDetailData {
  final String imageAsset;
  final String title;
  final String price;
  final String rating;
  final String reviews;
  final String category;
  final String description;

  const VisitorProductDetailData({
    required this.imageAsset,
    required this.title,
    required this.price,
    required this.rating,
    required this.reviews,
    this.category = 'Home & Living',
    this.description =
        'A complete set of reusable, plant-friendly cleaning essentials for a naturally fresh home.',
  });
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
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _ownerFuture = _loadOwner();
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
      displayName: name ?? 'Alex Morgan',
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

  @override
  Widget build(BuildContext context) {
    final product = widget.product;

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
                  _ProductImageCard(imageAsset: product.imageAsset),
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
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.price,
                          style: const TextStyle(
                            color: BStoreColors.primary,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const _StockBadge(),
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
                        onMinus: _quantity <= 1
                            ? null
                            : () => setState(() => _quantity--),
                        onPlus: () => setState(() => _quantity++),
                      ),
                    ],
                  ),
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
                  onAddToCart: _openCart,
                  onBuyNow: _openCart,
                ),
              ),
            ],
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
            child: IconButton(
              onPressed: onCart,
              icon: Badge.count(
                count: 2,
                backgroundColor: BStoreColors.primary,
                child: const Icon(LucideIcons.shoppingCart, size: 26),
              ),
              color: BStoreColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductImageCard extends StatelessWidget {
  final String imageAsset;

  const _ProductImageCard({required this.imageAsset});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Image.asset(
            imageAsset,
            width: double.infinity,
            height: 250,
            fit: BoxFit.cover,
            cacheWidth: 820,
          ),
          Positioned(
            top: 14,
            right: 14,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                LucideIcons.heart,
                color: BStoreColors.textPrimary,
                size: 21,
              ),
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

  const _RatingLine({required this.rating, required this.reviews});

  @override
  Widget build(BuildContext context) {
    return Row(
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
    );
  }
}

class _StockBadge extends StatelessWidget {
  const _StockBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFE5F5F3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: BStoreColors.primary,
            child: Icon(LucideIcons.check, color: Colors.white, size: 14),
          ),
          SizedBox(width: 8),
          Text(
            'In stock',
            style: TextStyle(
              color: BStoreColors.primary,
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
        : (loading ? 'Loading store...' : 'Alex Morgan');

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
  final VoidCallback onPlus;

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
            color: BStoreColors.textPrimary,
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
  final VoidCallback onAddToCart;
  final VoidCallback onBuyNow;

  const _ProductBottomActions({
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
                onPressed: onAddToCart,
                icon: const Icon(LucideIcons.shoppingCart, size: 18),
                label: const Text('Add to Cart'),
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
                onPressed: onBuyNow,
                style: BStoreButtons.filled(radius: 12),
                child: const Text(
                  'Buy Now',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
