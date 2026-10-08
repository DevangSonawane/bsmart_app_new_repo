import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../services/wallet_service.dart';
import 'shared/store_money.dart';
import 'store_theme.dart';

class StoreBCoinsResult {
  final int coinsApplied;
  final double savings;
  final double newTotal;
  final int remainingBalance;

  const StoreBCoinsResult({
    required this.coinsApplied,
    required this.savings,
    required this.newTotal,
    required this.remainingBalance,
  });
}

class StoreBCoinsPage extends StatefulWidget {
  final double orderTotal;
  final int initialCoins;
  final bool checkoutMode;

  const StoreBCoinsPage({
    super.key,
    this.orderTotal = 0,
    this.initialCoins = 0,
    this.checkoutMode = false,
  });

  @override
  State<StoreBCoinsPage> createState() => _StoreBCoinsPageState();
}

class _StoreBCoinsPageState extends State<StoreBCoinsPage> {
  static const double _coinValue = 1.0; // Phase 2 md: 1 coin = Rs.1
  static const int _coinStep = 10;
  static const int _defaultApplyCoins = 500;

  late final Future<int> _balanceFuture;
  int _coinsToApply = 0;
  bool _hasInitializedCoins = false;
  double? _activeFraction;

  @override
  void initState() {
    super.initState();
    _coinsToApply = widget.initialCoins;
    _balanceFuture = WalletService().getCoinBalance();
  }

  int _maxCoins(int balance) {
    final totalLimit = (widget.orderTotal / _coinValue).floor();
    return math.max(0, math.min(balance, totalLimit));
  }

  double _savingsFor(int coins) => coins * _coinValue;

  String _money(double amount) => formatStoreMoney(amount, decimals: 2);

  String _coins(int amount) {
    final text = amount.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final remaining = text.length - i;
      buffer.write(text[i]);
      if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
    }
    return buffer.toString();
  }

  void _setCoins(int value, int balance) {
    final maxCoins = _maxCoins(balance);
    final normalized = value.clamp(0, maxCoins).toInt();
    final stepped = normalized >= maxCoins
        ? maxCoins
        : ((normalized / _coinStep).round() * _coinStep)
            .clamp(0, maxCoins)
            .toInt();
    setState(() => _coinsToApply = stepped);
  }

  void _initializeCoinsIfNeeded(int maxCoins) {
    if (_hasInitializedCoins || maxCoins <= 0) return;
    _hasInitializedCoins = true;
    final preferred = widget.initialCoins > 0
        ? widget.initialCoins
        : math.min(_defaultApplyCoins, maxCoins);
    _coinsToApply = preferred.clamp(0, maxCoins).toInt();
  }

  void _apply(int balance) {
    final savings = _savingsFor(_coinsToApply);
    final result = StoreBCoinsResult(
      coinsApplied: _coinsToApply,
      savings: savings,
      newTotal: math.max(0, widget.orderTotal - savings),
      remainingBalance: math.max(0, balance - _coinsToApply),
    );

    if (widget.checkoutMode) {
      Navigator.of(context).pop(result);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_coins(_coinsToApply)} bCoins ready for checkout'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: BStoreTheme.data(context),
      child: Scaffold(
        backgroundColor: BStoreColors.background,
        body: SafeArea(
          bottom: false,
          child: FutureBuilder<int>(
            future: _balanceFuture,
            builder: (context, snapshot) {
              final balance = snapshot.data ?? 0;
              final isLoading =
                  snapshot.connectionState != ConnectionState.done;
              final maxCoins = _maxCoins(balance);
              if (!isLoading) _initializeCoinsIfNeeded(maxCoins);
              final selected = _coinsToApply.clamp(0, maxCoins).toInt();
              if (selected != _coinsToApply && !isLoading) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _coinsToApply = selected);
                });
              }

              return Column(
                children: [
                  Expanded(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        14,
                        8,
                        14,
                        MediaQuery.of(context).padding.bottom + 74,
                      ),
                      children: [
                        const _BCoinsHeader(),
                        const SizedBox(height: 14),
                        _BalanceCard(
                          balance: balance,
                          isLoading: isLoading,
                          value: _money(_savingsFor(balance)),
                          coinsText: _coins,
                        ),
                        const SizedBox(height: 12),
                        _ApplyCard(
                          coins: selected,
                          maxCoins: maxCoins,
                          value: _money(_savingsFor(selected)),
                          activeFraction: _activeFraction,
                          onMinus: isLoading || selected <= 0
                              ? null
                              : () {
                                  _activeFraction = null;
                                  _setCoins(
                                      selected - _coinStep, balance);
                                },
                          onPlus: isLoading || selected >= maxCoins
                              ? null
                              : () {
                                  _activeFraction = null;
                                  _setCoins(
                                      selected + _coinStep, balance);
                                },
                          onSliderChanged: isLoading || maxCoins <= 0
                              ? null
                              : (value) {
                                  _activeFraction = null;
                                  _setCoins(value.round(), balance);
                                },
                          onUseMaximum: isLoading || maxCoins <= 0
                              ? null
                              : () {
                                  _activeFraction = null;
                                  _setCoins(maxCoins, balance);
                                },
                          onFraction: isLoading || maxCoins <= 0
                              ? null
                              : (fraction) {
                                  _activeFraction = fraction;
                                  _setCoins(
                                      (maxCoins * fraction).round(),
                                      balance);
                                },
                          coinsText: _coins,
                        ),
                        const SizedBox(height: 12),
                        _OrderTotalCard(
                          orderTotal: _money(widget.orderTotal),
                          savings: '-${_money(_savingsFor(selected))}',
                          newTotal: _money(
                            math.max(
                                0, widget.orderTotal - _savingsFor(selected)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _RemainingBalanceCard(
                          remainingBalance: math.max(0, balance - selected),
                          balance: balance,
                          coinsText: _coins,
                        ),
                        const SizedBox(height: 10),
                        const _InfoCard(),
                      ],
                    ),
                  ),
                  _ApplyButton(
                    coins: selected,
                    enabled: !isLoading && selected > 0,
                    onPressed: () => _apply(balance),
                    coinsText: _coins,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BCoinsHeader extends StatelessWidget {
  const _BCoinsHeader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BStoreColors.borderSoft),
            ),
            child: IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(LucideIcons.arrowLeft, size: 22),
              color: BStoreColors.textPrimary,
              padding: EdgeInsets.zero,
            ),
          ),
          const Expanded(
            child: Text(
              'Use bCoins',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: BStoreColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final int balance;
  final bool isLoading;
  final String value;
  final String Function(int amount) coinsText;

  const _BalanceCard({
    required this.balance,
    required this.isLoading,
    required this.value,
    required this.coinsText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF141021), Color(0xFF2A1B4E), Color(0xFF4A2E0A)],
          stops: [0.0, 0.6, 1.0],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF5B301).withValues(alpha: 0.25),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -46,
            top: -52,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFF5B301).withValues(alpha: 0.35),
                    const Color(0xFFF5B301).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 70,
            top: 22,
            child: Transform.rotate(
              angle: 0.35,
              child: const Icon(
                LucideIcons.coins,
                color: Color(0xFFF5B301),
                size: 56,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: const Text(
                          'WALLET BALANCE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      isLoading
                          ? const SizedBox(
                              height: 38,
                              width: 38,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                    Color(0xFFF5B301)),
                              ),
                            )
                          : FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text.rich(
                                TextSpan(
                                  text: coinsText(balance),
                                  children: const [
                                    TextSpan(
                                      text: ' b',
                                      style: TextStyle(
                                        fontSize: 22,
                                        color: Color(0xFFF5B301),
                                      ),
                                    ),
                                  ],
                                ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 38,
                                  height: 1.0,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                      const SizedBox(height: 6),
                      Text(
                        '= $value value  ·  1 coin = ₹1',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
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

class _ApplyCard extends StatelessWidget {
  final int coins;
  final int maxCoins;
  final String value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  final ValueChanged<double>? onSliderChanged;
  final VoidCallback? onUseMaximum;
  final ValueChanged<double>? onFraction;
  final double? activeFraction;
  final String Function(int amount) coinsText;

  const _ApplyCard({
    required this.coins,
    required this.maxCoins,
    required this.value,
    required this.onMinus,
    required this.onPlus,
    required this.onSliderChanged,
    required this.onUseMaximum,
    required this.onFraction,
    required this.activeFraction,
    required this.coinsText,
  });

  @override
  Widget build(BuildContext context) {
    final sliderMax = math.max(1, maxCoins).toDouble();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BStoreDecorations.card(radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Apply bCoins',
            style: TextStyle(
              color: BStoreColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _StepperButton(icon: LucideIcons.minus, onPressed: onMinus),
              Expanded(
                child: Column(
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        coinsText(coins),
                        style: const TextStyle(
                          color: BStoreColors.textPrimary,
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '= $value value',
                      style: const TextStyle(
                        color: BStoreColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _StepperButton(icon: LucideIcons.plus, onPressed: onPlus),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final entry in const [
                ('25%', 0.25),
                ('50%', 0.5),
                ('75%', 0.75),
                ('MAX', 1.0),
              ])
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        right: entry.$1 == 'MAX' ? 0 : 8),
                    child: Builder(
                      builder: (context) {
                        final isActive =
                            activeFraction == entry.$2;
                        return OutlinedButton(
                          onPressed: maxCoins <= 0
                              ? null
                              : () => onFraction?.call(entry.$2),
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                                BStoreColors.textPrimary,
                            backgroundColor: isActive
                                ? const Color(0xFFFFF3D1)
                                : Colors.white,
                            side: BorderSide(
                              color: isActive
                                  ? const Color(0xFFF5B301)
                                  : BStoreColors.borderSoft,
                              width: isActive ? 1.6 : 1,
                            ),
                            overlayColor:
                                const Color(0xFFF5B301)
                                    .withValues(alpha: 0.15),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                                vertical: 10),
                            textStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          child: Text(entry.$1),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (maxCoins <= 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF4EEFF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'No bCoins available right now. Earn bCoins from rewards and come back to apply them here.',
                style: TextStyle(
                  color: Color(0xFF684AC8),
                  fontSize: 12.5,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFFF5B301),
                inactiveTrackColor: const Color(0xFFF0E3BE),
                thumbColor: const Color(0xFFE87822),
                overlayColor: const Color(0xFFF5B301)
                    .withValues(alpha: 0.18),
                trackHeight: 6,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 11),
              ),
              child: Slider(
                min: 0,
                max: sliderMax,
                value: coins.clamp(0, maxCoins).toDouble(),
                onChanged: onSliderChanged,
              ),
            ),
          Center(
            child: TextButton(
              onPressed: onUseMaximum,
              child: const Text(
                'Use maximum',
                style: TextStyle(
                  color: BStoreColors.accentPurple,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderTotalCard extends StatelessWidget {
  final String orderTotal;
  final String savings;
  final String newTotal;

  const _OrderTotalCard({
    required this.orderTotal,
    required this.savings,
    required this.newTotal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BStoreDecorations.card(radius: 14),
      child: Column(
        children: [
          _SummaryRow(label: 'Order total', value: orderTotal),
          const SizedBox(height: 9),
          _SummaryRow(
            label: 'bCoins savings',
            value: savings,
            valueColor: BStoreColors.primary,
          ),
          const Divider(height: 18, color: BStoreColors.divider),
          _SummaryRow(
            label: 'New total',
            value: newTotal,
            labelWeight: FontWeight.w900,
            valueColor: BStoreColors.primary,
            valueSize: 20,
          ),
        ],
      ),
    );
  }
}

class _RemainingBalanceCard extends StatelessWidget {
  final int remainingBalance;
  final int balance;
  final String Function(int amount) coinsText;

  const _RemainingBalanceCard({
    required this.remainingBalance,
    required this.balance,
    required this.coinsText,
  });

  @override
  Widget build(BuildContext context) {
    final usedFraction = balance <= 0
        ? 0.0
        : ((balance - remainingBalance) / balance).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BStoreDecorations.card(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFF5B301), Color(0xFFE87822)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.walletCards,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Remaining balance',
                      style: TextStyle(
                        color: BStoreColors.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${coinsText(remainingBalance)} of ${coinsText(balance)} bCoins',
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
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  Expanded(
                    flex: ((1 - usedFraction) * 1000).round(),
                    child: Container(color: const Color(0xFFF5B301)),
                  ),
                  Expanded(
                    flex: (usedFraction * 1000).round() + 1,
                    child: Container(color: const Color(0xFFF0E3BE)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            usedFraction <= 0
                ? 'Nothing applied yet'
                : '${(usedFraction * 100).round()}% of balance in use',
            style: const TextStyle(
              color: BStoreColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BStoreDecorations.card(radius: 12).copyWith(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Row(
        children: [
          Icon(
            LucideIcons.info,
            color: BStoreColors.textSecondary,
            size: 21,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'bCoins are applied as a discount at checkout.',
              style: TextStyle(
                color: BStoreColors.textSecondary,
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ApplyButton extends StatelessWidget {
  final int coins;
  final bool enabled;
  final VoidCallback onPressed;
  final String Function(int amount) coinsText;

  const _ApplyButton({
    required this.coins,
    required this.enabled,
    required this.onPressed,
    required this.coinsText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        18,
        10,
        18,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BStoreDecorations.topPanel(),
      child: Opacity(
        opacity: enabled ? 1.0 : 0.55,
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF5B301), Color(0xFFE87822)],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF5B301).withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: FilledButton(
            onPressed: enabled ? onPressed : null,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.transparent,
              disabledForegroundColor: Colors.white,
              shadowColor: Colors.transparent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              'Apply ${coinsText(coins)} bCoins',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _StepperButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        fixedSize: const Size(50, 44),
        minimumSize: Size.zero,
        padding: EdgeInsets.zero,
        foregroundColor: BStoreColors.textPrimary,
        side: const BorderSide(color: BStoreColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Icon(icon, size: 24),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final FontWeight labelWeight;
  final double valueSize;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.labelWeight = FontWeight.w600,
    this.valueSize = 17,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: BStoreColors.textPrimary,
              fontSize: 13.5,
              fontWeight: labelWeight,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? BStoreColors.textPrimary,
            fontSize: valueSize,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
