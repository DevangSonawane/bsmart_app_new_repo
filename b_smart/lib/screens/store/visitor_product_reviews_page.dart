import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'shared/store_shared_widgets.dart';
import 'store_theme.dart';
import 'visitor_product_detail_page.dart';
import 'visitor_store_cart_page.dart';

class VisitorProductReviewsPage extends StatefulWidget {
  final VisitorProductDetailData product;
  final String? ownerUserId;

  const VisitorProductReviewsPage({
    super.key,
    required this.product,
    this.ownerUserId,
  });

  @override
  State<VisitorProductReviewsPage> createState() =>
      _VisitorProductReviewsPageState();
}

class _VisitorProductReviewsPageState extends State<VisitorProductReviewsPage> {
  bool _withPhotosOnly = false;

  static const List<_ProductReview> _reviews = [
    _ProductReview(
      name: 'Emily Carter',
      rating: 5,
      verified: true,
      body:
          'The kit works well and feels durable. I love the reusable packaging.',
      avatarColor: Color(0xFFEBD8C9),
      photoAssets: [
        'assets/bSmart_Store/mockimages/vegetables.jpg',
        'assets/bSmart_Store/mockimages/vegetables_clean_test.jpg',
        'assets/bSmart_Store/mockimages/vegetables_cutout_preview.png',
      ],
    ),
    _ProductReview(
      name: 'Daniel Kim',
      rating: 4,
      verified: true,
      body: 'Good-quality essentials and fast delivery.',
      avatarColor: Color(0xFFD9EBED),
      photoAssets: [],
    ),
    _ProductReview(
      name: 'Priya Shah',
      rating: 5,
      verified: true,
      body: 'Exactly as described. The packaging looked premium too.',
      avatarColor: Color(0xFFECE4F8),
      photoAssets: [
        'assets/bSmart_Store/mockimages/clothes.jpg',
        'assets/bSmart_Store/mockimages/electronics.jpg',
      ],
    ),
  ];

  void _openCart() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VisitorStoreCartScreen(ownerUserId: widget.ownerUserId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleReviews = _withPhotosOnly
        ? _reviews.where((review) => review.photoAssets.isNotEmpty).toList()
        : _reviews;

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
                padding: EdgeInsets.fromLTRB(
                  14,
                  8,
                  14,
                  MediaQuery.of(context).padding.bottom + 90,
                ),
                children: [
                  _ReviewsHeader(onCart: _openCart),
                  const SizedBox(height: 10),
                  _ReviewsSummaryCard(
                    rating: widget.product.rating,
                    reviews: widget.product.reviews,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _FilterPill(
                        label: 'All reviews',
                        selected: !_withPhotosOnly,
                        onTap: () => setState(() => _withPhotosOnly = false),
                      ),
                      const SizedBox(width: 8),
                      _FilterPill(
                        label: 'With photos',
                        icon: LucideIcons.camera,
                        selected: _withPhotosOnly,
                        onTap: () => setState(() => _withPhotosOnly = true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final review in visibleReviews) ...[
                    _ReviewCard(review: review),
                    const SizedBox(height: 10),
                  ],
                  TextButton.icon(
                    onPressed: () => setState(() => _withPhotosOnly = false),
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(LucideIcons.chevronRight, size: 19),
                    label: const Text('View all reviews'),
                    style: TextButton.styleFrom(
                      foregroundColor: BStoreColors.accentPurple,
                      textStyle: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _ReviewsBottomBar(
                  price: widget.product.price,
                  onAddToCart: _openCart,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductReview {
  final String name;
  final int rating;
  final bool verified;
  final String body;
  final Color avatarColor;
  final List<String> photoAssets;

  const _ProductReview({
    required this.name,
    required this.rating,
    required this.verified,
    required this.body,
    required this.avatarColor,
    required this.photoAssets,
  });
}

class _ReviewsHeader extends StatelessWidget {
  final VoidCallback onCart;

  const _ReviewsHeader({required this.onCart});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(LucideIcons.arrowLeft, size: 24),
              color: BStoreColors.textPrimary,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            ),
          ),
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StoreBsmartWordmark(),
              SizedBox(height: 12),
              Text(
                'Reviews',
                style: TextStyle(
                  color: BStoreColors.textPrimary,
                  fontSize: 18.5,
                  height: 1.12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              onPressed: onCart,
              icon: Badge.count(
                count: 2,
                backgroundColor: BStoreColors.primary,
                child: const Icon(LucideIcons.shoppingCart, size: 23),
              ),
              color: BStoreColors.textPrimary,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 42, height: 42),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewsSummaryCard extends StatelessWidget {
  final String rating;
  final String reviews;

  const _ReviewsSummaryCard({
    required this.rating,
    required this.reviews,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BStoreDecorations.card(radius: 14),
      child: Row(
        children: [
          Text(
            rating,
            style: const TextStyle(
              color: BStoreColors.textPrimary,
              fontSize: 36,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 14),
          const _Stars(rating: 5, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$reviews reviews',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: BStoreColors.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? BStoreColors.primary : BStoreColors.textPrimary;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? BStoreColors.primary : BStoreColors.border,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: color, size: 17),
                const SizedBox(width: 7),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final _ProductReview review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BStoreDecorations.card(radius: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ReviewerAvatar(review: review),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  review.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: BStoreColors.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _Stars(rating: review.rating, size: 15.5),
                    const SizedBox(width: 8),
                    if (review.verified)
                      const Flexible(
                        child: Text(
                          '✓ Verified',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: BStoreColors.primary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  review.body,
                  style: const TextStyle(
                    color: BStoreColors.textPrimary,
                    fontSize: 12.6,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (review.photoAssets.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (var i = 0; i < review.photoAssets.length; i++) ...[
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: AspectRatio(
                              aspectRatio: 1.08,
                              child: Image.asset(
                                review.photoAssets[i],
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        if (i != review.photoAssets.length - 1)
                          const SizedBox(width: 7),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewerAvatar extends StatelessWidget {
  final _ProductReview review;

  const _ReviewerAvatar({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: review.avatarColor,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        review.name.characters.first,
        style: const TextStyle(
          color: BStoreColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  final int rating;
  final double size;

  const _Stars({
    required this.rating,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++)
          Padding(
            padding: EdgeInsets.only(right: i == 4 ? 0 : size * .12),
            child: Icon(
              LucideIcons.star,
              color:
                  i < rating ? BStoreColors.primary : const Color(0xFFDADDE3),
              size: size,
            ),
          ),
      ],
    );
  }
}

class _ReviewsBottomBar extends StatelessWidget {
  final String price;
  final VoidCallback onAddToCart;

  const _ReviewsBottomBar({
    required this.price,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        14,
        10,
        14,
        MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BStoreDecorations.topPanel(),
      child: Row(
        children: [
          Expanded(
            child: Text(
              price,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: BStoreColors.primary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Container(width: 1, height: 36, color: BStoreColors.divider),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 46,
              child: FilledButton.icon(
                onPressed: onAddToCart,
                icon: const Icon(LucideIcons.shoppingCart, size: 20),
                label: const Text('Add to Cart'),
                style: BStoreButtons.filled(radius: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
