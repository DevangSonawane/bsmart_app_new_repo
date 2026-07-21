import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../services/wallet_service.dart';

class RedeemGiftCardsScreen extends StatefulWidget {
  const RedeemGiftCardsScreen({super.key});

  @override
  State<RedeemGiftCardsScreen> createState() => _RedeemGiftCardsScreenState();
}

class _RedeemGiftCardsScreenState extends State<RedeemGiftCardsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _category = 'All';

  static const List<String> _categories = <String>[
    'All',
    'Shopping',
    'Food',
    'Entertainment',
    'Travel',
  ];

  static const List<_GiftCard> _giftCards = <_GiftCard>[
    _GiftCard(
      name: 'Amazon Pay Gift Card',
      assetPath: 'assets/giftcards/amazongiftcard.webp',
      category: 'Shopping',
      startsFrom: 5000,
      isPopular: true,
      description:
          'Use Amazon Pay Gift Card for shopping on Amazon.in across millions of products.',
    ),
    _GiftCard(
      name: 'Flipkart Gift Card',
      assetPath: 'assets/giftcards/flipkartgiftcard.avif',
      category: 'Shopping',
      startsFrom: 5000,
      isPopular: true,
      description:
          'Redeem this card for fashion, electronics, and everyday essentials on Flipkart.',
    ),
    _GiftCard(
      name: 'Myntra Gift Card',
      assetPath: 'assets/giftcards/myntra.jpeg',
      category: 'Shopping',
      startsFrom: 5000,
      isPopular: true,
      description:
          'Unlock fashion rewards for apparel, footwear, and lifestyle shopping.',
    ),
    _GiftCard(
      name: 'Zomato Gift Card',
      assetPath: 'assets/giftcards/zomatogiftcard.avif',
      category: 'Food',
      startsFrom: 4000,
      isPopular: true,
      description:
          'Enjoy food orders, dining, and quick delivery with Zomato credits.',
    ),
    _GiftCard(
      name: 'Uber Gift Card',
      assetPath: 'assets/giftcards/ubergiftcard.png',
      category: 'Travel',
      startsFrom: 5000,
      isPopular: false,
      description:
          'Use Uber credits for rides, airport trips, and everyday travel.',
    ),
    _GiftCard(
      name: 'AJIO Gift Card',
      assetPath: 'assets/giftcards/ajiogiftcard.jpg',
      category: 'Shopping',
      startsFrom: 5000,
      isPopular: false,
      description: 'Shop clothing, accessories, and style finds across AJIO.',
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_GiftCard> get _filteredCards {
    return _giftCards.where((card) {
      final matchesCategory = _category == 'All' || card.category == _category;
      final matchesQuery = _query.isEmpty ||
          card.name.toLowerCase().contains(_query.toLowerCase()) ||
          card.category.toLowerCase().contains(_query.toLowerCase());
      return matchesCategory && matchesQuery;
    }).toList();
  }

  List<_GiftCard> get _popularCards =>
      _filteredCards.where((card) => card.isPopular).toList();

  List<_GiftCard> get _allCards =>
      _filteredCards.where((card) => !card.isPopular).toList();

  void _showCardDetails(_GiftCard card) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _GiftCardDetailScreen(card: card),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg =
        isDark ? const Color(0xFF0B0B0B) : const Color(0xFFF8F8FB);
    final titleColor = isDark ? Colors.white : const Color(0xFF111111);
    final subColor = isDark
        ? Colors.white.withValues(alpha: 0.62)
        : Colors.black.withValues(alpha: 0.58);
    final surface =
        isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white;
    final border = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.06);
    final chipIdleBg =
        isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white;
    final chipIdleText = isDark
        ? Colors.white.withValues(alpha: 0.72)
        : Colors.black.withValues(alpha: 0.68);

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          color: const Color(0xFFF97316),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Row(
                children: [
                  _HeaderButton(
                    icon: LucideIcons.arrowLeft,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Redeem',
                      style: GoogleFonts.montserrat(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: titleColor,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  _HeaderButton(
                    icon: LucideIcons.rotateCw,
                    onTap: () {
                      setState(() {
                        _query = '';
                        _category = 'All';
                        _searchController.clear();
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: border),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value.trim()),
                  decoration: InputDecoration(
                    hintText: 'Search gift cards...',
                    hintStyle: GoogleFonts.montserrat(
                      color: subColor,
                      fontWeight: FontWeight.w500,
                    ),
                    prefixIcon:
                        Icon(LucideIcons.search, color: subColor, size: 18),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final label = _categories[index];
                    final isSelected = label == _category;
                    return ChoiceChip(
                      label: Text(label),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _category = label),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      labelStyle: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: isSelected ? Colors.white : chipIdleText,
                      ),
                      selectedColor: const Color(0xFFF97316),
                      backgroundColor: chipIdleBg,
                      side: BorderSide(
                          color: isSelected ? Colors.transparent : border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      showCheckmark: false,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    );
                  },
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Popular Gift Cards',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 14),
              _GiftCardGrid(
                cards: _popularCards,
                onTap: _showCardDetails,
                emptyText: 'No popular gift cards match your search.',
              ),
              const SizedBox(height: 28),
              Text(
                'All Gift Cards',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 14),
              _GiftCardGrid(
                cards: _allCards,
                onTap: _showCardDetails,
                emptyText: 'No more gift cards match your search.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GiftCardGrid extends StatelessWidget {
  final List<_GiftCard> cards;
  final ValueChanged<_GiftCard> onTap;
  final String emptyText;

  const _GiftCardGrid({
    required this.cards,
    required this.onTap,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final muted = isDark
          ? Colors.white.withValues(alpha: 0.4)
          : Colors.black.withValues(alpha: 0.42);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Text(
          emptyText,
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w600,
            color: muted,
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.79,
      ),
      itemBuilder: (context, index) {
        return _GiftCardTile(
          card: cards[index],
          onTap: () => onTap(cards[index]),
        );
      },
    );
  }
}

class _GiftCardTile extends StatelessWidget {
  final _GiftCard card;
  final VoidCallback onTap;

  const _GiftCardTile({
    required this.card,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);
    final bg = isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF111111);
    final subColor = isDark
        ? Colors.white.withValues(alpha: 0.52)
        : Colors.black.withValues(alpha: 0.52);
    const accent = Color(0xFFF97316);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 58,
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  child: Container(
                    width: double.infinity,
                    color: _bannerBackground(card.name),
                    child: card.assetPath.isNotEmpty
                        ? Image.asset(
                            card.assetPath,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (_, __, ___) =>
                                _fallbackBanner(card, titleColor),
                          )
                        : _fallbackBanner(card, titleColor),
                  ),
                ),
              ),
              Expanded(
                flex: 42,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Starts from',
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: subColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${card.startsFrom.toStringAsFixed(0)} bCoins',
                        style: GoogleFonts.montserrat(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallbackBanner(_GiftCard card, Color titleColor) {
    return Center(
      child: Text(
        card.shortName,
        style: GoogleFonts.montserrat(
          fontSize: 28,
          fontWeight: FontWeight.w900,
          color: titleColor,
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  Color _bannerBackground(String name) {
    switch (name) {
      case 'Amazon Pay Gift Card':
        return const Color(0xFF232F3E);
      case 'Flipkart Gift Card':
        return const Color(0xFF2874F0);
      case 'Myntra Gift Card':
        return const Color(0xFFFFFFFF);
      case 'Zomato Gift Card':
        return const Color(0xFFEF4444);
      case 'Uber Gift Card':
        return const Color(0xFF000000);
      case 'AJIO Gift Card':
        return const Color(0xFF2F3C4E);
      default:
        return const Color(0xFFF3F4F6);
    }
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
    final border = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.05);
    final iconColor = isDark ? Colors.white : const Color(0xFF111111);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
      ),
    );
  }
}

class _GiftCardDetailScreen extends StatefulWidget {
  final _GiftCard card;

  const _GiftCardDetailScreen({required this.card});

  @override
  State<_GiftCardDetailScreen> createState() => _GiftCardDetailScreenState();
}

class _GiftCardDetailScreenState extends State<_GiftCardDetailScreen> {
  final WalletService _walletService = WalletService();
  int _availableBalance = 0;
  bool _isLoadingBalance = true;
  int _selectedValueIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    try {
      final balance = await _walletService.getCoinBalance();
      if (!mounted) return;
      setState(() {
        _availableBalance = balance;
        _isLoadingBalance = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingBalance = false;
      });
    }
  }

  Future<void> _redeemNow() async {
    final selected = widget.card.values[_selectedValueIndex];
    if (_availableBalance < selected.coins) {
      await _showInsufficientCoinsDialog(
        requiredCoins: selected.coins,
        availableCoins: _availableBalance,
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => _GiftCardRedemptionSuccessScreen(
          card: widget.card,
          selectedValue: selected,
          deductedCoins: selected.coins,
          newBalance: _availableBalance - selected.coins,
        ),
      ),
    );
  }

  Future<void> _showInsufficientCoinsDialog({
    required int requiredCoins,
    required int availableCoins,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF141414) : Colors.white;
    final border = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
    final titleColor = isDark ? Colors.white : const Color(0xFF111111);
    final subColor = isDark
        ? Colors.white.withValues(alpha: 0.68)
        : Colors.black.withValues(alpha: 0.62);
    final mutedBg =
        isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF8F8FB);

    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: border),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 30,
                  offset: Offset(0, 18),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x11FF6B00),
                  ),
                  child: const Icon(
                    Icons.warning_amber_outlined,
                    size: 32,
                    color: Color(0xFFF97316),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Insufficient Coins',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: mutedBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: border),
                  ),
                  child: Column(
                    children: [
                      _DialogAmountRow(
                        label: 'Required',
                        value: '${_formatCoins(requiredCoins)} bCoins',
                      ),
                      const SizedBox(height: 16),
                      _DialogAmountRow(
                        label: 'Available',
                        value: '${_formatCoins(availableCoins)} bCoins',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Please earn more coins to redeem this gift card.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                    color: subColor,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF97316),
                      side: const BorderSide(
                          color: Color(0xFFF97316), width: 1.4),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Close',
                      style: GoogleFonts.montserrat(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg =
        isDark ? const Color(0xFF0B0B0B) : const Color(0xFFF8F8FB);
    final titleColor = isDark ? Colors.white : const Color(0xFF111111);
    final subColor = isDark
        ? Colors.white.withValues(alpha: 0.6)
        : Colors.black.withValues(alpha: 0.58);
    final cardSurface =
        isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white;
    final border = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.06);
    final mutedBorder = isDark
        ? Colors.white.withValues(alpha: 0.09)
        : Colors.black.withValues(alpha: 0.08);
    const selectedBg = Color(0xFFF97316);

    final selected = widget.card.values[_selectedValueIndex];
    final canRedeem = !_isLoadingBalance && _availableBalance >= selected.coins;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Row(
              children: [
                _HeaderButton(
                  icon: LucideIcons.arrowLeft,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Gift Card Details',
                    style: GoogleFonts.montserrat(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: titleColor,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardSurface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
                    blurRadius: 24,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: AspectRatio(
                aspectRatio: 1.9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: widget.card.assetPath.isNotEmpty
                      ? Image.asset(
                          widget.card.assetPath,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _GiftCardBannerFallback(card: widget.card),
                        )
                      : _GiftCardBannerFallback(card: widget.card),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              widget.card.name,
              style: GoogleFonts.montserrat(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.card.description,
              style: GoogleFonts.montserrat(
                fontSize: 13,
                height: 1.5,
                fontWeight: FontWeight.w500,
                color: subColor,
              ),
            ),
            const SizedBox(height: 26),
            Text(
              'Gift Card Value',
              style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.card.values.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.08,
              ),
              itemBuilder: (context, index) {
                final value = widget.card.values[index];
                final isSelected = index == _selectedValueIndex;
                return _ValueTile(
                  value: value,
                  isSelected: isSelected,
                  onTap: () => setState(() => _selectedValueIndex = index),
                );
              },
            ),
            const SizedBox(height: 18),
            _SummaryRow(
              label: 'You Pay',
              value: _isLoadingBalance
                  ? 'Loading...'
                  : '${_formatCoins(selected.coins)} bCoins',
              borderColor: mutedBorder,
              backgroundColor: cardSurface,
              titleColor: titleColor,
              valueColor: titleColor,
            ),
            const SizedBox(height: 12),
            _SummaryRow(
              label: 'Your Available Balance',
              value: _isLoadingBalance
                  ? 'Loading...'
                  : '${_formatCoins(_availableBalance)} bCoins',
              borderColor: mutedBorder,
              backgroundColor: cardSurface,
              titleColor: titleColor,
              valueColor:
                  canRedeem ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoadingBalance ? null : _redeemNow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: selectedBg,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      const Color(0xFFF97316).withValues(alpha: 0.35),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(
                  'Redeem Now',
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCoins(int n) {
    final str = n.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      final indexFromEnd = str.length - i;
      buffer.write(str[i]);
      if (indexFromEnd > 1 && indexFromEnd % 3 == 1) {
        buffer.write(',');
      }
    }
    return buffer.toString();
  }
}

class _GiftCardRedemptionSuccessScreen extends StatelessWidget {
  final _GiftCard card;
  final _GiftCardValue selectedValue;
  final int deductedCoins;
  final int newBalance;

  const _GiftCardRedemptionSuccessScreen({
    required this.card,
    required this.selectedValue,
    required this.deductedCoins,
    required this.newBalance,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFFF8F8F8) : Colors.white;
    const titleColor = Color(0xFF111111);
    final subColor = Colors.black.withValues(alpha: 0.62);
    const cardSurface = Colors.white;
    final border = Colors.black.withValues(alpha: 0.08);

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            children: [
              Row(
                children: [
                  _HeaderButton(
                    icon: LucideIcons.arrowLeft,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 240,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ..._confettiDots(),
                    Container(
                      width: 92,
                      height: 92,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF22C55E),
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 54,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Redemption Successful!',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'You have successfully redeemed',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: subColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${card.name} (${selectedValue.rupeesValueLabel})',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardSurface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _SuccessMetric(
                        label: 'Deducted',
                        value: '${_formatCoins(deductedCoins)} bCoins',
                        valueColor: const Color(0xFF111111),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 56,
                      color: border,
                    ),
                    Expanded(
                      child: _SuccessMetric(
                        label: 'New Balance',
                        value: '${_signedCoins(newBalance)} bCoins',
                        valueColor: newBalance >= 0
                            ? const Color(0xFF111111)
                            : const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Your gift card voucher will be delivered\nwithin 2 hours via',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  height: 1.55,
                  fontWeight: FontWeight.w500,
                  color: subColor,
                ),
              ),
              const SizedBox(height: 22),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _DeliveryChannel(
                    icon: LucideIcons.bell,
                    label: 'Notification',
                  ),
                  _DeliveryChannel(
                    icon: LucideIcons.mail,
                    label: 'Email',
                  ),
                  _DeliveryChannel(
                    icon: LucideIcons.messageCircle,
                    label: 'In-App Message',
                  ),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/wallet');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF97316),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(
                    'View Redemption History',
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const RedeemGiftCardsScreen(),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFF97316),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                child: Text(
                  'Back to Redeem',
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _confettiDots() {
    const placements = <_ConfettiDot>[
      _ConfettiDot(top: 26, left: 28, color: Color(0xFFE11D48)),
      _ConfettiDot(top: 38, left: 88, color: Color(0xFFF59E0B)),
      _ConfettiDot(top: 18, left: 160, color: Color(0xFFEC4899)),
      _ConfettiDot(top: 72, left: 18, color: Color(0xFF8B5CF6)),
      _ConfettiDot(top: 86, left: 58, color: Color(0xFF22C55E)),
      _ConfettiDot(top: 84, left: 130, color: Color(0xFFF97316)),
      _ConfettiDot(top: 116, left: 38, color: Color(0xFF0EA5E9)),
      _ConfettiDot(top: 124, left: 102, color: Color(0xFF14B8A6)),
      _ConfettiDot(top: 118, left: 178, color: Color(0xFFEF4444)),
      _ConfettiDot(top: 52, left: 210, color: Color(0xFFA855F7)),
    ];

    return placements
        .map(
          (dot) => Positioned(
            top: dot.top,
            left: dot.left,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: dot.color,
                shape: BoxShape.circle,
              ),
            ),
          ),
        )
        .toList();
  }

  String _formatCoins(int n) {
    final abs = n.abs();
    final str = abs.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      final indexFromEnd = str.length - i;
      buffer.write(str[i]);
      if (indexFromEnd > 1 && indexFromEnd % 3 == 1) {
        buffer.write(',');
      }
    }
    return buffer.toString();
  }

  String _signedCoins(int n) =>
      n >= 0 ? _formatCoins(n) : '-${_formatCoins(n)}';
}

class _GiftCardBannerFallback extends StatelessWidget {
  final _GiftCard card;

  const _GiftCardBannerFallback({required this.card});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: _bannerBackground(card.name),
      alignment: Alignment.center,
      child: Text(
        card.shortName,
        style: GoogleFonts.montserrat(
          fontSize: 32,
          fontWeight: FontWeight.w900,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
    );
  }

  Color _bannerBackground(String name) {
    switch (name) {
      case 'Amazon Pay Gift Card':
        return const Color(0xFF232F3E);
      case 'Flipkart Gift Card':
        return const Color(0xFF2874F0);
      case 'Myntra Gift Card':
        return const Color(0xFFFFFFFF);
      case 'Zomato Gift Card':
        return const Color(0xFFEF4444);
      case 'Uber Gift Card':
        return const Color(0xFF000000);
      case 'AJIO Gift Card':
        return const Color(0xFF2F3C4E);
      default:
        return const Color(0xFFF3F4F6);
    }
  }
}

class _DialogAmountRow extends StatelessWidget {
  final String label;
  final String value;

  const _DialogAmountRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF111111);
    final valueColor = isDark ? Colors.white : const Color(0xFF111111);
    const coinColor = Color(0xFFF59E0B);

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: titleColor,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.circle, size: 12, color: coinColor),
            const SizedBox(width: 8),
            Text(
              value,
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: valueColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SuccessMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _SuccessMetric({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.montserrat(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black.withValues(alpha: 0.52),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          value,
          textAlign: TextAlign.center,
          style: GoogleFonts.montserrat(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class _DeliveryChannel extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DeliveryChannel({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 30, color: const Color(0xFF111111)),
        const SizedBox(height: 10),
        Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF111111),
          ),
        ),
      ],
    );
  }
}

class _ConfettiDot {
  final double top;
  final double left;
  final Color color;

  const _ConfettiDot({
    required this.top,
    required this.left,
    required this.color,
  });
}

class _ValueTile extends StatelessWidget {
  final _GiftCardValue value;
  final bool isSelected;
  final VoidCallback onTap;

  const _ValueTile({
    required this.value,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isSelected
        ? Colors.transparent
        : (isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.08));
    final bg = isSelected
        ? const Color(0xFFF97316)
        : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white);
    final titleColor = isSelected
        ? Colors.white
        : (isDark ? Colors.white : const Color(0xFF111111));
    final subColor = isSelected
        ? Colors.white.withValues(alpha: 0.86)
        : (isDark
            ? Colors.white.withValues(alpha: 0.58)
            : Colors.black.withValues(alpha: 0.56));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value.rupeesValueLabel,
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${_formatCoins(value.coins)} bCoins',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: subColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCoins(int n) {
    final str = n.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      final indexFromEnd = str.length - i;
      buffer.write(str[i]);
      if (indexFromEnd > 1 && indexFromEnd % 3 == 1) {
        buffer.write(',');
      }
    }
    return buffer.toString();
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color borderColor;
  final Color backgroundColor;
  final Color titleColor;
  final Color valueColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.borderColor,
    required this.backgroundColor,
    required this.titleColor,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: titleColor,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _GiftCard {
  final String name;
  final String assetPath;
  final String category;
  final double startsFrom;
  final bool isPopular;
  final String description;
  final List<_GiftCardValue> values;

  const _GiftCard({
    required this.name,
    required this.assetPath,
    required this.category,
    required this.startsFrom,
    required this.isPopular,
    required this.description,
  }) : values = _standardValues;

  String get shortName {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'GC';
    if (parts.length == 1) {
      final raw = parts.first;
      return raw.length >= 2
          ? raw.substring(0, 2).toUpperCase()
          : raw.toUpperCase();
    }
    return parts.first.substring(0, 1).toUpperCase();
  }
}

class _GiftCardValue {
  final int rupees;
  final int coins;

  const _GiftCardValue({
    required this.rupees,
    required this.coins,
  });

  String get rupeesValueLabel => '₹$rupees';
}

const List<_GiftCardValue> _standardValues = <_GiftCardValue>[
  _GiftCardValue(rupees: 100, coins: 5000),
  _GiftCardValue(rupees: 250, coins: 12500),
  _GiftCardValue(rupees: 500, coins: 25000),
  _GiftCardValue(rupees: 1000, coins: 50000),
  _GiftCardValue(rupees: 2000, coins: 100000),
];
