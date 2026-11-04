import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../store_models.dart';
import '../store_wishlist.dart';
import '../visitor_product_detail_page.dart';
import '../visitor_service_detail_page.dart';
import 'store_money.dart';
import 'store_shared_widgets.dart';

/// A compact, image-first marketplace tile with familiar shopping controls.
class MarketplaceListingCard extends StatelessWidget {
  static const double imageHeight = 242;
  static const double gridHeight = 356;

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
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => VisitorServiceDetailPage(
          ownerUserId: ownerUserId,
          item: item,
        ),
      ));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => VisitorProductDetailPage(
        ownerUserId: ownerUserId,
        product: VisitorProductDetailData(item: item),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openDetail(context),
      borderRadius: BorderRadius.circular(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: imageHeight,
            width: double.infinity,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F7F8),
                      border: Border.all(
                        color: const Color(0xFFBEC4CC),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: StoreItemImage(
                      imageUrl: item.imageUrl,
                      icon: item.icon,
                      width: double.infinity,
                      height: imageHeight,
                      fit: BoxFit.cover,
                      debugLabel: 'marketplace-listing-card',
                    ),
                  ),
                ),
                if (!_isService)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: WishlistHeartButton(
                      productId: item.id,
                      size: 27,
                      iconSize: 15,
                    ),
                  ),
                Positioned(
                  right: 8,
                  bottom: -12,
                  child: SizedBox(
                    height: 38,
                    child: _isService
                        ? _BookButton(onTap: () => _openDetail(context))
                        : _CartAction(item: item),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF101828),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              _isService
                  ? (item.duration.trim().isEmpty
                      ? item.category
                      : '${item.category} · ${item.duration}')
                  : item.category,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF667085),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              _isService
                  ? 'From ${formatCompactStoreMoney(item.price)}'
                  : formatCompactStoreMoney(item.price),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF101828),
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BookButton({required this.onTap});

  @override
  Widget build(BuildContext context) => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF078D92),
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFF078D92)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: Size.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
        child: const Text('Book',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900)),
      );
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
          return OutlinedButton.icon(
            onPressed: maxQuantity <= 0
                ? null
                : () => StoreMockState.instance.addToCart(item),
            icon: const Icon(LucideIcons.shoppingBag, size: 14),
            label: const Text('Add'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF078D92),
              backgroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFF078D92)),
              padding: const EdgeInsets.symmetric(horizontal: 11),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9)),
              textStyle:
                  const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
            ),
          );
        }
        return Container(
          width: 104,
          decoration: BoxDecoration(
            color: const Color(0xFF078D92),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            children: [
              _QuantityControl(
                icon: LucideIcons.minus,
                onTap: () => StoreMockState.instance
                    .updateQuantity(item.id, quantity - 1),
              ),
              Expanded(
                child: Text('$quantity',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900)),
              ),
              _QuantityControl(
                icon: LucideIcons.plus,
                disabled: quantity >= maxQuantity,
                onTap: quantity >= maxQuantity
                    ? null
                    : () => StoreMockState.instance
                        .updateQuantity(item.id, quantity + 1),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QuantityControl extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool disabled;
  const _QuantityControl(
      {required this.icon, required this.onTap, this.disabled = false});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 31,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Center(
            child: Icon(icon,
                color: disabled ? Colors.white54 : Colors.white, size: 15),
          ),
        ),
      );
}
