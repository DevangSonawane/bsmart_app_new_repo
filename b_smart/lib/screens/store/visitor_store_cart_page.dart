import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/api_client.dart';
import '../../services/supabase_service.dart';
import '../../utils/url_helper.dart';
import '../../widgets/safe_network_image.dart';
import 'shared/store_shared_widgets.dart';
import 'store_bcoins_page.dart';
import 'store_models.dart';
import 'store_theme.dart';
import 'visitor_product_payment_page.dart';

class VisitorStoreCartPage extends StatefulWidget {
  final String? ownerUserId;
  final bool showBackButton;
  final bool showContinueShopping;
  final void Function(BuildContext context)? onBack;
  final void Function(BuildContext context)? onContinueShopping;

  const VisitorStoreCartPage({
    super.key,
    this.ownerUserId,
    this.showBackButton = false,
    this.showContinueShopping = false,
    this.onBack,
    this.onContinueShopping,
  });

  @override
  State<VisitorStoreCartPage> createState() => _VisitorStoreCartPageState();
}

class _VisitorStoreCartPageState extends State<VisitorStoreCartPage> {
  late Future<_CartOwner?> _ownerFuture;
  StoreBCoinsResult? _bCoinsResult;
  double _lastSubtotal = 0;

  @override
  void initState() {
    super.initState();
    _ownerFuture = _loadOwner();
    _lastSubtotal = StoreMockState.instance.subtotal;
    StoreMockState.instance.addListener(_handleCartChanged);
  }

  @override
  void dispose() {
    StoreMockState.instance.removeListener(_handleCartChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant VisitorStoreCartPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerUserId != widget.ownerUserId) {
      _ownerFuture = _loadOwner();
    }
  }

  Future<_CartOwner?> _loadOwner() async {
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

    return _CartOwner(
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

  double get _total => (_subtotal - (_bCoinsResult?.savings ?? 0))
      .clamp(0, _subtotal)
      .toDouble();

  double get _subtotal => StoreMockState.instance.subtotal;

  String _money(double amount) => '\$${amount.toStringAsFixed(2)}';

  void _handleCartChanged() {
    final subtotal = StoreMockState.instance.subtotal;
    final shouldResetBCoins =
        _bCoinsResult != null && subtotal != _lastSubtotal;
    _lastSubtotal = subtotal;
    if (!mounted || !shouldResetBCoins) return;
    setState(() => _bCoinsResult = null);
  }

  Future<void> _openBCoins() async {
    final result = await Navigator.of(context).push<StoreBCoinsResult>(
      MaterialPageRoute<StoreBCoinsResult>(
        builder: (_) => StoreBCoinsPage(
          orderTotal: _subtotal,
          initialCoins: _bCoinsResult?.coinsApplied ?? 0,
          checkoutMode: true,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _lastSubtotal = _subtotal;
      _bCoinsResult = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: AnimatedBuilder(
        animation: StoreMockState.instance,
        builder: (context, _) {
          final cartLines = StoreMockState.instance.cartLines;
          final hasProducts = cartLines.any(
            (line) => line.item.type == StoreMockItemType.product,
          );
          final hasServices = cartLines.any(
            (line) => line.item.type == StoreMockItemType.service,
          );
          return Column(
            children: [
              _CartHeader(
                showBackButton: widget.showBackButton,
                onBack: widget.onBack,
              ),
              if (cartLines.isNotEmpty)
                _SelectionCard(itemCount: StoreMockState.instance.cartCount),
              FutureBuilder<_CartOwner?>(
                future: _ownerFuture,
                builder: (context, snapshot) {
                  return _CartStoreCard(
                    owner: snapshot.data,
                    isLoading: snapshot.connectionState != ConnectionState.done,
                  );
                },
              ),
              if (cartLines.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(10, 18, 10, 0),
                  child: StoreEmptyState(
                    icon: LucideIcons.shoppingCart,
                    title: 'Your cart is empty',
                    body: 'Products and services you add will appear here.',
                  ),
                )
              else ...[
                for (final line in cartLines) _CartItemCard(line: line),
                _DeliveryCard(
                  hasProducts: hasProducts,
                  hasServices: hasServices,
                ),
                _BCoinsCard(
                  appliedCoins: _bCoinsResult?.coinsApplied ?? 0,
                  savings: _bCoinsResult?.savings ?? 0,
                  onTap: _openBCoins,
                ),
                _CartTotalsCard(
                  subtotal: _money(_subtotal),
                  savings: _bCoinsResult?.savings ?? 0,
                  total: _money(_total),
                ),
                _CheckoutButton(
                  amount: _money(_total),
                  bCoinsSavings: _bCoinsResult?.savings ?? 0,
                ),
                if (widget.showContinueShopping)
                  _ContinueShoppingButton(
                    onPressed: () {
                      final onContinueShopping = widget.onContinueShopping;
                      if (onContinueShopping != null) {
                        onContinueShopping(context);
                      } else {
                        Navigator.of(context).maybePop();
                      }
                    },
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class VisitorStoreCartScreen extends StatelessWidget {
  final String? ownerUserId;
  final bool showContinueShopping;
  final void Function(BuildContext context)? onBack;
  final void Function(BuildContext context)? onContinueShopping;

  const VisitorStoreCartScreen({
    super.key,
    this.ownerUserId,
    this.showContinueShopping = false,
    this.onBack,
    this.onContinueShopping,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: BStoreTheme.data(context),
      child: Scaffold(
        backgroundColor: BStoreColors.background,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            VisitorStoreCartPage(
              ownerUserId: ownerUserId,
              showBackButton: true,
              showContinueShopping: showContinueShopping,
              onBack: onBack,
              onContinueShopping: onContinueShopping,
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 22)),
          ],
        ),
      ),
    );
  }
}

class _CartOwner {
  final String displayName;
  final String avatarUrl;
  final Map<String, String>? avatarHeaders;

  const _CartOwner({
    required this.displayName,
    required this.avatarUrl,
    required this.avatarHeaders,
  });
}

class _CartHeader extends StatelessWidget {
  final bool showBackButton;
  final void Function(BuildContext context)? onBack;

  const _CartHeader({
    required this.showBackButton,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + 8,
        16,
        0,
      ),
      child: Column(
        children: [
          SizedBox(
            height: 34,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (showBackButton)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () {
                        final onBack = this.onBack;
                        if (onBack != null) {
                          onBack(context);
                        } else {
                          Navigator.of(context).maybePop();
                        }
                      },
                      icon: const Icon(
                        LucideIcons.chevronLeft,
                        color: BStoreColors.textPrimary,
                        size: 28,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 34,
                        height: 34,
                      ),
                    ),
                  ),
                const Center(child: StoreBsmartWordmark()),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'My Cart',
            style: TextStyle(
              color: BStoreColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectionCard extends StatelessWidget {
  final int itemCount;

  const _SelectionCard({required this.itemCount});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 16, 10, 0),
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: storeSoftCardDecoration(radius: 12),
        child: Row(
          children: [
            const _CheckedBox(size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$itemCount selected ${itemCount == 1 ? 'item' : 'items'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: BStoreColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                foregroundColor: BStoreColors.primary,
                padding: EdgeInsets.zero,
                minimumSize: const Size(66, 32),
              ),
              child: const Text(
                'Select all',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartStoreCard extends StatelessWidget {
  final _CartOwner? owner;
  final bool isLoading;

  const _CartStoreCard({
    required this.owner,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final ownerName = owner?.displayName.trim().isNotEmpty == true
        ? owner!.displayName.trim()
        : (isLoading ? 'Loading store...' : 'Store owner');
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 0),
      child: Container(
        height: 66,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: storeSoftCardDecoration(radius: 12),
        child: Row(
          children: [
            _OwnerAvatar(
              name: ownerName,
              avatarUrl: owner?.avatarUrl ?? '',
              avatarHeaders: owner?.avatarHeaders,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "$ownerName's Personal Store",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: BStoreColors.textPrimary,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Personal Store',
                    style: TextStyle(
                      color: BStoreColors.accentPurple,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                    ),
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

class _OwnerAvatar extends StatelessWidget {
  final String name;
  final String avatarUrl;
  final Map<String, String>? avatarHeaders;

  const _OwnerAvatar({
    required this.name,
    required this.avatarUrl,
    required this.avatarHeaders,
  });

  @override
  Widget build(BuildContext context) {
    const size = 44.0;
    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: BStoreColors.cardWarm,
        alignment: Alignment.center,
        child: avatarUrl.trim().isEmpty
            ? _Initial(name: name, fontSize: 15)
            : SafeNetworkImage(
                url: avatarUrl,
                headers: avatarHeaders,
                width: size,
                height: size,
                fit: BoxFit.cover,
                debugLabel: 'visitor-cart-owner-avatar',
                errorWidget: _Initial(name: name, fontSize: 15),
              ),
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final StoreMockCartLine line;

  const _CartItemCard({
    required this.line,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 0),
      child: Container(
        height: 126,
        padding: const EdgeInsets.all(10),
        decoration: storeSoftCardDecoration(radius: 12),
        child: Row(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image.asset(
                    line.item.imageAsset,
                    width: 116,
                    height: 106,
                    fit: BoxFit.cover,
                    cacheWidth: 360,
                  ),
                ),
                const Positioned(
                  top: 0,
                  left: 0,
                  child: _CheckedBox(size: 22),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.item.type == StoreMockItemType.service
                        ? 'Service${line.schedule == null ? '' : ' • ${line.schedule}'}'
                        : 'Product',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: BStoreColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          line.item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: BStoreColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            height: 1.15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        LucideIcons.heart,
                        color: BStoreColors.textPrimary,
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${StoreMockState.instance.money(line.item.price)}'
                    '${line.quantity > 1 ? ' x ${line.quantity}' : ''}',
                    style: const TextStyle(
                      color: BStoreColors.primary,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      _QuantityStepper(
                        quantity: line.quantity,
                        onMinus: () => StoreMockState.instance.updateQuantity(
                          line.item.id,
                          line.quantity - 1,
                        ),
                        onPlus: () => StoreMockState.instance.updateQuantity(
                          line.item.id,
                          line.quantity + 1,
                        ),
                      ),
                      const Spacer(),
                      SizedBox.square(
                        dimension: 30,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => StoreMockState.instance
                              .removeFromCart(line.item.id),
                          child: const Icon(
                            LucideIcons.trash2,
                            size: 19,
                            color: BStoreColors.textPrimary,
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

class _QuantityStepper extends StatelessWidget {
  final int quantity;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _QuantityStepper({
    required this.quantity,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 32,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFD5DEE4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          InkWell(
            onTap: onMinus,
            child: const Icon(
              LucideIcons.minus,
              color: BStoreColors.primary,
              size: 15,
            ),
          ),
          Text(
            '$quantity',
            style: const TextStyle(
              color: BStoreColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          InkWell(
            onTap: onPlus,
            child: const Icon(
              LucideIcons.plus,
              color: BStoreColors.primary,
              size: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  final bool hasProducts;
  final bool hasServices;

  const _DeliveryCard({
    required this.hasProducts,
    required this.hasServices,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 0),
      child: Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: storeSoftCardDecoration(radius: 12),
        child: Row(
          children: [
            _SoftIconBubble(
              icon: hasServices && !hasProducts
                  ? LucideIcons.calendarCheck
                  : LucideIcons.truck,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasServices && hasProducts
                        ? 'Delivery & service'
                        : hasServices
                            ? 'Service booking'
                            : 'Delivery',
                    style: const TextStyle(
                      color: BStoreColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasServices && hasProducts
                        ? 'Products ship, services stay scheduled'
                        : hasServices
                            ? 'Provider will confirm your selected slot'
                            : 'Arrives in 2-3 days',
                    style: const TextStyle(
                      color: BStoreColors.textSecondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
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

class _BCoinsCard extends StatelessWidget {
  final int appliedCoins;
  final double savings;
  final VoidCallback onTap;

  const _BCoinsCard({
    required this.appliedCoins,
    required this.savings,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasApplied = appliedCoins > 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: storeSoftCardDecoration(radius: 12),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 19,
                backgroundColor: BStoreColors.primary,
                child: Text(
                  'b',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: hasApplied ? 'Applied ' : 'Apply ',
                    children: [
                      TextSpan(
                        text: hasApplied
                            ? '$appliedCoins bCoins'
                            : 'bCoins discount',
                        style: const TextStyle(color: BStoreColors.primary),
                      ),
                      if (hasApplied)
                        TextSpan(
                          text: ' (-\$${savings.toStringAsFixed(2)})',
                        ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: BStoreColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Icon(
                LucideIcons.chevronRight,
                color: BStoreColors.textPrimary,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartTotalsCard extends StatelessWidget {
  final String subtotal;
  final double savings;
  final String total;

  const _CartTotalsCard({
    required this.subtotal,
    required this.savings,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final hasSavings = savings > 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: storeSoftCardDecoration(radius: 12),
        child: Column(
          children: [
            _TotalRow(label: 'Subtotal', value: subtotal),
            const SizedBox(height: 10),
            const _TotalRow(
              label: 'Delivery',
              value: 'Free',
              valueColor: BStoreColors.primary,
            ),
            if (hasSavings) ...[
              const SizedBox(height: 10),
              _TotalRow(
                label: 'bCoins savings',
                value: '-\$${savings.toStringAsFixed(2)}',
                valueColor: BStoreColors.primary,
              ),
            ],
            const Divider(height: 20, color: BStoreColors.divider),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Total',
                    style: TextStyle(
                      color: BStoreColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  total,
                  style: const TextStyle(
                    color: BStoreColors.primary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _TotalRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: BStoreColors.textSecondary,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? BStoreColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _CheckoutButton extends StatelessWidget {
  final String amount;
  final double bCoinsSavings;

  const _CheckoutButton({
    required this.amount,
    required this.bCoinsSavings,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 0),
      child: SizedBox(
        height: 46,
        child: FilledButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => VisitorProductPaymentPage(
                  amount: amount,
                  bCoinsSavings: bCoinsSavings,
                ),
              ),
            );
          },
          style: FilledButton.styleFrom(
            backgroundColor: BStoreColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text(
            'Proceed to Checkout',
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }
}

class _ContinueShoppingButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _ContinueShoppingButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      child: SizedBox(
        height: 44,
        width: double.infinity,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: BStoreColors.primary,
            side: const BorderSide(color: BStoreColors.primary, width: 1.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text(
            'Continue shopping',
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }
}

class _CheckedBox extends StatelessWidget {
  final double size;

  const _CheckedBox({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: BStoreColors.primary,
        borderRadius: BorderRadius.circular(7),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(LucideIcons.check, color: Colors.white, size: size * 0.6),
    );
  }
}

class _SoftIconBubble extends StatelessWidget {
  final IconData icon;

  const _SoftIconBubble({required this.icon});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 19,
      backgroundColor: const Color(0xFFE5F5F3),
      child: Icon(icon, color: BStoreColors.textPrimary, size: 19),
    );
  }
}

class _Initial extends StatelessWidget {
  final String name;
  final double fontSize;

  const _Initial({required this.name, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial =
        trimmed.isEmpty ? 'S' : trimmed.characters.first.toUpperCase();
    return Text(
      initial,
      style: TextStyle(
        color: BStoreColors.textPrimary,
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}
