import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/api_client.dart';
import '../../services/supabase_service.dart';
import '../../utils/url_helper.dart';
import '../../widgets/safe_network_image.dart';
import 'shared/store_shared_widgets.dart';
import 'shared/store_money.dart';
import 'store_bcoins_page.dart';
import 'store_models.dart';
import 'store_wishlist.dart';
import 'store_theme.dart';
import 'visitor_product_payment_page.dart';

class VisitorStoreCartPage extends StatefulWidget {
  final String? ownerUserId;
  final bool showBackButton;
  final bool showContinueShopping;
  final bool showHeader;
  final void Function(BuildContext context)? onBack;
  final void Function(BuildContext context)? onContinueShopping;

  const VisitorStoreCartPage({
    super.key,
    this.ownerUserId,
    this.showBackButton = false,
    this.showContinueShopping = false,
    this.showHeader = true,
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
  final Set<String> _selectedKeys = {};
  final Set<String> _knownKeys = {};

  static String _lineKey(StoreMockCartLine line) =>
      '${line.item.id}|${line.variantLabel}|${line.schedule}';

  @override
  void initState() {
    super.initState();
    _ownerFuture = _loadOwner();
    _lastSubtotal = StoreMockState.instance.subtotal;
    _syncSelection();
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

  List<StoreMockCartLine> get _selectedLines => StoreMockState.instance
      .cartLines
      .where((line) => _selectedKeys.contains(_lineKey(line)))
      .toList();

  double get _selectedSubtotal =>
      _selectedLines.fold(0.0, (sum, line) => sum + line.total);

  int get _selectedQty =>
      _selectedLines.fold(0, (sum, line) => sum + line.quantity);

  double get _total => (_selectedSubtotal - (_bCoinsResult?.savings ?? 0))
      .clamp(0, _selectedSubtotal)
      .toDouble();

  String _money(double amount) => formatStoreMoney(amount, decimals: 2);

  void _syncSelection({bool selectNew = true}) {
    final current = {
      for (final line in StoreMockState.instance.cartLines) _lineKey(line)
    };
    if (selectNew) _selectedKeys.addAll(current.difference(_knownKeys));
    _knownKeys
      ..clear()
      ..addAll(current);
    _selectedKeys.retainAll(current);
  }

  void _handleCartChanged() {
    final before = _selectedKeys.toSet();
    _syncSelection();
    final subtotal = StoreMockState.instance.subtotal;
    final shouldResetBCoins =
        _bCoinsResult != null && subtotal != _lastSubtotal;
    _lastSubtotal = subtotal;
    if (!mounted) return;
    final selectionChanged = before.length != _selectedKeys.length ||
        !_selectedKeys.containsAll(before);
    if (!shouldResetBCoins && !selectionChanged) return;
    setState(() {
      if (shouldResetBCoins) _bCoinsResult = null;
    });
  }

  void _toggleLine(String key) {
    setState(() {
      if (!_selectedKeys.remove(key)) _selectedKeys.add(key);
    });
  }

  void _toggleSelectAll() {
    final current = {
      for (final line in StoreMockState.instance.cartLines) _lineKey(line)
    };
    setState(() {
      if (_selectedKeys.containsAll(current) && current.isNotEmpty) {
        _selectedKeys.clear();
      } else {
        _selectedKeys.addAll(current);
      }
    });
  }

  Future<void> _removeSelected() async {
    final lines = _selectedLines;
    if (lines.isEmpty) return;
    try {
      for (final line in lines) {
        StoreMockState.instance.removeFromCart(
          line.item.id,
          variant: line.variant,
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Remove failed: $e')),
      );
    }
  }

  Future<void> _openBCoins() async {
    final result = await Navigator.of(context).push<StoreBCoinsResult>(
      MaterialPageRoute<StoreBCoinsResult>(
        builder: (_) => StoreBCoinsPage(
          orderTotal: _selectedSubtotal,
          initialCoins: _bCoinsResult?.coinsApplied ?? 0,
          checkoutMode: true,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _lastSubtotal = StoreMockState.instance.subtotal;
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
          final allKeys = {
            for (final line in cartLines) _lineKey(line)
          };
          final allSelected =
              allKeys.isNotEmpty && _selectedKeys.containsAll(allKeys);
          final topInset = widget.showHeader
              ? 0.0
              : MediaQuery.of(context).padding.top + 12;
          return Column(
            children: [
              if (!widget.showHeader) SizedBox(height: topInset),
              if (widget.showHeader)
                _CartHeader(
                  showBackButton: widget.showBackButton,
                  onBack: widget.onBack,
                ),
              if (widget.showHeader)
                FutureBuilder<_CartOwner?>(
                  future: _ownerFuture,
                  builder: (context, snapshot) {
                    return _CartStoreCard(
                      owner: snapshot.data,
                      isLoading:
                          snapshot.connectionState != ConnectionState.done,
                    );
                  },
                ),
              if (cartLines.isNotEmpty)
                _SelectionCard(
                  selectedQty: _selectedQty,
                  totalQty: StoreMockState.instance.cartCount,
                  allSelected: allSelected,
                  canRemove: _selectedLines.isNotEmpty,
                  onToggleAll: _toggleSelectAll,
                  onRemoveSelected: _removeSelected,
                ),
              if (cartLines.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 48, 24, 0),
                  child: _EmptyCart(
                    onShopNow: () {
                      final onContinueShopping =
                          widget.onContinueShopping;
                      if (widget.showContinueShopping) {
                        if (onContinueShopping != null) {
                          onContinueShopping(context);
                        } else {
                          Navigator.of(context).maybePop();
                        }
                      } else {
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          '/home',
                          (route) => route.isFirst,
                        );
                      }
                    },
                  ),
                )
              else ...[
                for (final line in cartLines)
                  _CartItemCard(
                    line: line,
                    selected: _selectedKeys.contains(_lineKey(line)),
                    onToggleSelect: () => _toggleLine(_lineKey(line)),
                  ),
                _DeliveryCard(
                  hasProducts: hasProducts,
                  hasServices: hasServices,
                ),
                _BCoinsCard(
                  appliedCoins: _bCoinsResult?.coinsApplied ?? 0,
                  savings: _bCoinsResult?.savings ?? 0,
                  onTap: _openBCoins,
                  onRemove: _bCoinsResult == null
                      ? null
                      : () => setState(() => _bCoinsResult = null),
                ),
                _CartTotalsCard(
                  itemLabel: _selectedQty == 1
                      ? 'Subtotal (1 item)'
                      : 'Subtotal ($_selectedQty items)',
                  subtotal: _money(_selectedSubtotal),
                  savings: _bCoinsResult?.savings ?? 0,
                  total: _money(_total),
                ),
                if (hasServices)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Text(
                      'Services are booked directly with a date/time slot — only products go through checkout.',
                      style: TextStyle(
                        color: BStoreColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                _CheckoutButton(
                  amount: _money(_total),
                  bCoinsSavings: _bCoinsResult?.savings ?? 0,
                  enabled: _selectedLines.isNotEmpty,
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
        backgroundColor: BStoreColors.backgroundAlt,
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

class _EmptyCart extends StatelessWidget {
  final VoidCallback onShopNow;

  const _EmptyCart({required this.onShopNow});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 172,
              height: 172,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    BStoreColors.primary.withValues(alpha: 0.16),
                    BStoreColors.primary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
            Container(
              width: 124,
              height: 124,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0A9BA0), Color(0xFF078D92)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: BStoreColors.primary
                        .withValues(alpha: 0.35),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: const Icon(
                LucideIcons.shoppingCart,
                color: Colors.white,
                size: 56,
              ),
            ),
            Positioned(
              right: 8,
              top: 22,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF5B301), Color(0xFFE87822)],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: const Center(
                  child: Text(
                    'b',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Your cart is feeling light',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: BStoreColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Looks like you haven’t added anything yet.\nDiscover products and services you’ll love.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: BStoreColors.textSecondary,
            fontSize: 13,
            height: 1.45,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            onPressed: onShopNow,
            icon: const Icon(LucideIcons.store, size: 19),
            label: const Text(
              'Start shopping',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: BStoreColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF0D489)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'b',
                style: TextStyle(
                  color: Color(0xFFE87822),
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Tip: apply bCoins at checkout and save on every order',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: BStoreColors.textPrimary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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
  final int selectedQty;
  final int totalQty;
  final bool allSelected;
  final bool canRemove;
  final VoidCallback onToggleAll;
  final VoidCallback onRemoveSelected;

  const _SelectionCard({
    required this.selectedQty,
    required this.totalQty,
    required this.allSelected,
    required this.canRemove,
    required this.onToggleAll,
    required this.onRemoveSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: storeSoftCardDecoration(radius: 14),
        child: Row(
          children: [
            _CheckedBox(
              size: 24,
              checked: allSelected,
              onTap: onToggleAll,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$selectedQty of $totalQty selected',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: BStoreColors.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (canRemove)
              TextButton(
                onPressed: onRemoveSelected,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFE5484D),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                  textStyle: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                child: const Text('REMOVE'),
              ),
            TextButton(
              onPressed: onToggleAll,
              style: TextButton.styleFrom(
                foregroundColor: BStoreColors.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                textStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              child: Text(allSelected ? 'DESELECT ALL' : 'SELECT ALL'),
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
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
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
  final bool selected;
  final VoidCallback onToggleSelect;

  const _CartItemCard({
    required this.line,
    required this.selected,
    required this.onToggleSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isProduct = line.item.type == StoreMockItemType.product;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Opacity(
        opacity: selected ? 1.0 : 0.62,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: storeSoftCardDecoration(radius: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  StoreItemImage(
                    imageUrl: line.item.imageUrl,
                    icon: line.item.icon,
                    width: 104,
                    height: 118,
                    borderRadius: 10,
                    debugLabel: 'store-cart-item',
                  ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: _CheckedBox(
                      size: 22,
                      checked: selected,
                      onTap: onToggleSelect,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isProduct
                          ? 'Product'
                          : 'Service${line.schedule == null ? '' : ' • ${line.schedule}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: BStoreColors.textSecondary,
                        fontSize: 10.5,
                        letterSpacing: 0.4,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            line.item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: BStoreColors.textPrimary,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              height: 1.25,
                            ),
                          ),
                        ),
                        if (isProduct) ...[
                          const SizedBox(width: 4),
                          _WishlistHeart(productId: line.item.id),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${StoreMockState.instance.money(line.unitPrice)}'
                      '${line.quantity > 1 ? ' x ${line.quantity}' : ''}'
                      '${line.variantLabel.isEmpty ? '' : ' · ${line.variantLabel}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: BStoreColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: StoreMockState.instance.stockLabelFor(
                              line.item,
                              variant: line.variant,
                            ),
                            style: const TextStyle(
                              color: BStoreColors.textSoft,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const TextSpan(
                            text: '  •  Free delivery',
                            style: TextStyle(
                              color: Color(0xFF139B54),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _QuantityStepper(
                          quantity: line.quantity,
                          maxQuantity:
                              StoreMockState.instance.maxQuantityFor(
                            line.item,
                            variant: line.variant,
                          ),
                          onMinus: () =>
                              StoreMockState.instance.updateQuantity(
                            line.item.id,
                            line.quantity - 1,
                            variant: line.variant,
                          ),
                          onPlus: () =>
                              StoreMockState.instance.updateQuantity(
                            line.item.id,
                            line.quantity + 1,
                            variant: line.variant,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          StoreMockState.instance.money(line.total),
                          style: const TextStyle(
                            color: BStoreColors.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox.square(
                          dimension: 30,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () =>
                                StoreMockState.instance.removeFromCart(
                              line.item.id,
                              variant: line.variant,
                            ),
                            child: const Icon(
                              LucideIcons.trash2,
                              size: 18,
                              color: BStoreColors.textSoft,
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
      ),
    );
  }
}

class _WishlistHeart extends StatelessWidget {
  final String productId;

  const _WishlistHeart({required this.productId});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: WishlistState.instance,
      builder: (context, _) {
        final saved = WishlistState.instance.isSaved(productId);
        final mutating =
            WishlistState.instance.isMutating(productId);
        return InkWell(
          onTap: mutating
              ? null
              : () => WishlistState.instance.toggle(productId),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Icon(
              LucideIcons.heart,
              color: saved
                  ? const Color(0xFFE5484D)
                  : BStoreColors.textSoft,
              size: 19,
            ),
          ),
        );
      },
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  final int quantity;
  final int maxQuantity;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _QuantityStepper({
    required this.quantity,
    required this.maxQuantity,
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
            onTap: quantity >= maxQuantity ? null : onPlus,
            child: Icon(
              LucideIcons.plus,
              color: quantity >= maxQuantity
                  ? BStoreColors.textMuted
                  : BStoreColors.primary,
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
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: storeSoftCardDecoration(radius: 14),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          hasServices && hasProducts
                              ? 'Delivery & service'
                              : hasServices
                                  ? 'Service booking'
                                  : 'Delivery',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: BStoreColors.textPrimary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (!hasServices)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE9F8E6),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'FREE',
                            style: TextStyle(
                              color: Color(0xFF139B54),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasServices && hasProducts
                        ? 'Products ship, services stay scheduled'
                        : hasServices
                            ? 'Provider will confirm your selected slot'
                            : 'Arrives in 2-3 days',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: BStoreColors.textSecondary,
                      fontSize: 12,
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
  final VoidCallback? onRemove;

  const _BCoinsCard({
    required this.appliedCoins,
    required this.savings,
    required this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final hasApplied = appliedCoins > 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E7),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFF0D489),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFF5B301), Color(0xFFE87822)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'b',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
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
                    Text(
                      hasApplied
                          ? '$appliedCoins bCoins applied'
                          : 'Apply bCoins discount',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: BStoreColors.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasApplied
                          ? 'You save ${formatStoreMoney(savings, decimals: 2)} on this order'
                          : 'Use your wallet coins at checkout',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF139B54),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasApplied && onRemove != null)
                InkWell(
                  onTap: onRemove,
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.close_rounded,
                      color: BStoreColors.textSoft,
                      size: 18,
                    ),
                  ),
                )
              else
                const Icon(
                  LucideIcons.ticketPercent,
                  color: Color(0xFFE87822),
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartTotalsCard extends StatelessWidget {
  final String itemLabel;
  final String subtotal;
  final double savings;
  final String total;

  const _CartTotalsCard({
    required this.itemLabel,
    required this.subtotal,
    required this.savings,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final hasSavings = savings > 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: storeSoftCardDecoration(radius: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PRICE DETAILS',
              style: TextStyle(
                color: BStoreColors.textSoft,
                fontSize: 11,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            _TotalRow(label: 'Price ($itemLabel)', value: subtotal),
            const SizedBox(height: 10),
            const _TotalRow(
              label: 'Delivery charges',
              value: 'FREE',
              valueColor: Color(0xFF139B54),
            ),
            if (hasSavings) ...[
              const SizedBox(height: 10),
              _TotalRow(
                label: 'bCoins discount',
                value: '− ${formatStoreMoney(savings, decimals: 2)}',
                valueColor: const Color(0xFF139B54),
              ),
            ],
            const Divider(height: 20, color: BStoreColors.divider),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Total amount',
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
                    color: BStoreColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            if (hasSavings) ...[
              const SizedBox(height: 4),
              Text(
                'You save ${formatStoreMoney(savings, decimals: 2)} on this order',
                style: const TextStyle(
                  color: Color(0xFF139B54),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
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
  final bool enabled;

  const _CheckoutButton({
    required this.amount,
    required this.bCoinsSavings,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: SizedBox(
        height: 52,
        width: double.infinity,
        child: FilledButton(
          onPressed: enabled
              ? () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => VisitorProductPaymentPage(
                        amount: amount,
                        bCoinsSavings: bCoinsSavings,
                      ),
                    ),
                  );
                }
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: BStoreColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFFD5DEE4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              enabled ? 'Place Order • $amount' : 'Select items to continue',
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
            ),
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
  final bool checked;
  final VoidCallback? onTap;

  const _CheckedBox({
    required this.size,
    this.checked = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: checked ? BStoreColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(7),
          border: checked
              ? null
              : Border.all(color: const Color(0xFFC3C9D4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: checked
            ? Icon(LucideIcons.check,
                color: Colors.white, size: size * 0.6)
            : null,
      ),
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
