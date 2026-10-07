import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../store_models.dart';
import '../store_wishlist.dart';
import '../visitor_product_detail_page.dart';
import '../visitor_service_detail_page.dart';
import 'store_money.dart';
import 'store_shared_widgets.dart';

/// Futuristic listing card shared by the marketplace + storefront grids.
///
/// One card, one price, one skeleton for products AND services so every
/// tile aligns perfectly:
///   image (124) → title (fixed 2-line box) → price + rating row →
///   status line (stock / duration, fixed height) → CTA (fixed 34).
/// Dark navy shell, image melting into the card, single mint price.
class MarketplaceListingCard extends StatelessWidget {
  static const double imageHeight = 124;

  /// Grid aspect denominator tuned to the fixed skeleton height (~269).
  static const double gridHeight = 276;

  final StoreMockCatalogItem item;
  final String? ownerUserId;

  const MarketplaceListingCard({
    super.key,
    required this.item,
    required this.ownerUserId,
  });

  bool get _isService => item.type == StoreMockItemType.service;

  void _openDetail(BuildContext context) {
    if (_isService) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => VisitorServiceDetailPage(
            ownerUserId: ownerUserId,
            item: item,
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VisitorProductDetailPage(
          ownerUserId: ownerUserId,
          product: VisitorProductDetailData(item: item),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openDetail(context),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0C1430),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.09),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0C1430).withValues(alpha: 0.28),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                StoreItemImage(
                  imageUrl: item.imageUrl,
                  icon: item.icon,
                  width: double.infinity,
                  height: imageHeight,
                  debugLabel: 'marketplace-listing-card',
                ),
                // Melt the photo into the navy shell.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 46,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF0C1430).withValues(alpha: 0.0),
                          const Color(0xFF0C1430),
                        ],
                      ),
                    ),
                  ),
                ),
                if (item.category.trim().isNotEmpty)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Text(
                        item.category.trim().toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                if (!_isService)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: WishlistHeartButton(productId: item.id),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(11, 9, 11, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 37,
                    child: Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        height: 1.35,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _isService
                              ? 'From ${formatCompactStoreMoney(item.price)}'
                              : formatCompactStoreMoney(item.price),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF5EEAD4),
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(LucideIcons.star,
                          color: Color(0xFFF59E0B), size: 12),
                      const SizedBox(width: 3),
                      Text(
                        item.rating,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        ' (${item.reviews})',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  SizedBox(
                    height: 15,
                    child: _StatusLine(item: item, isService: _isService),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 34,
                    width: double.infinity,
                    child: _isService
                        ? _BookButton(
                            onTap: () => _openDetail(context),
                          )
                        : _CartAction(item: item),
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

/// Single status line: stock dot for products, duration for services.
class _StatusLine extends StatelessWidget {
  final StoreMockCatalogItem item;
  final bool isService;

  const _StatusLine({required this.item, required this.isService});

  @override
  Widget build(BuildContext context) {
    if (isService) {
      final duration = item.duration.trim();
      if (duration.isEmpty) return const SizedBox.shrink();
      return Row(
        children: [
          const Icon(LucideIcons.clock3,
              color: Color(0xFF5EEAD4), size: 12),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              duration,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }
    final label = StoreMockState.instance.stockLabelFor(item);
    if (label.isEmpty) return const SizedBox.shrink();
    final qty = StoreMockState.instance.stockQuantityFor(item);
    final color = qty == null
        ? const Color(0xFF34D399)
        : qty <= 0
            ? const Color(0xFFF87171)
            : qty <= 5
                ? const Color(0xFFFBBF24)
                : const Color(0xFF34D399);
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _BookButton extends StatelessWidget {
  final VoidCallback onTap;

  const _BookButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF078D92),
        foregroundColor: Colors.white,
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Book',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
          ),
          SizedBox(width: 5),
          Icon(LucideIcons.arrowRight, size: 15),
        ],
      ),
    );
  }
}

class _CartAction extends StatelessWidget {
  final StoreMockCatalogItem item;

  const _CartAction({required this.item});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: StoreMockState.instance,
      builder: (context, _) {
        final quantity = StoreMockState.instance.quantityFor(item.id);
        final maxQuantity = StoreMockState.instance.maxQuantityFor(item);
        if (quantity == 0) {
          return OutlinedButton(
            onPressed: maxQuantity <= 0
                ? null
                : () => StoreMockState.instance.addToCart(item),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF5EEAD4),
              side: const BorderSide(color: Color(0xFF5EEAD4)),
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.shoppingCart, size: 14),
                SizedBox(width: 6),
                Text(
                  'Add',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          );
        }
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF078D92),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => StoreMockState.instance.updateQuantity(
                    item.id,
                    quantity - 1,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  child: const Center(
                    child:
                        Icon(LucideIcons.minus, color: Colors.white, size: 15),
                  ),
                ),
              ),
              SizedBox(
                width: 30,
                child: Text(
                  '$quantity',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: quantity >= maxQuantity
                      ? null
                      : () => StoreMockState.instance.updateQuantity(
                            item.id,
                            quantity + 1,
                          ),
                  borderRadius: BorderRadius.circular(10),
                  child: Center(
                    child: Icon(
                      LucideIcons.plus,
                      color: quantity >= maxQuantity
                          ? Colors.white54
                          : Colors.white,
                      size: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
