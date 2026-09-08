import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../services/wallet_service.dart';
import 'shared/store_shared_widgets.dart';
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
    this.orderTotal = 39.99,
    this.initialCoins = 0,
    this.checkoutMode = false,
  });

  @override
  State<StoreBCoinsPage> createState() => _StoreBCoinsPageState();
}

class _StoreBCoinsPageState extends State<StoreBCoinsPage> {
  static const double _coinValue = 0.01;
  static const int _coinStep = 50;
  static const int _defaultApplyCoins = 500;

  late final Future<int> _balanceFuture;
  int _coinsToApply = 0;
  bool _hasInitializedCoins = false;

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

  String _money(double amount) => '\$${amount.toStringAsFixed(2)}';

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
                        const SizedBox(height: 16),
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
                          onMinus: isLoading || selected <= 0
                              ? null
                              : () => _setCoins(selected - _coinStep, balance),
                          onPlus: isLoading || selected >= maxCoins
                              ? null
                              : () => _setCoins(selected + _coinStep, balance),
                          onSliderChanged: isLoading || maxCoins <= 0
                              ? null
                              : (value) => _setCoins(value.round(), balance),
                          onUseMaximum: isLoading || maxCoins <= 0
                              ? null
                              : () => _setCoins(maxCoins, balance),
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
      height: 80,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(LucideIcons.arrowLeft, size: 27),
              color: BStoreColors.textPrimary,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 42, height: 42),
            ),
          ),
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StoreBsmartWordmark(),
              SizedBox(height: 14),
              Text(
                'Use bCoins',
                style: TextStyle(
                  color: BStoreColors.textPrimary,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  height: 1.12,
                ),
              ),
            ],
          ),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BStoreDecorations.card(radius: 14),
      child: Row(
        children: [
          const _BCoinsLogo(size: 66),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Available balance',
                  style: TextStyle(
                    color: BStoreColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                isLoading
                    ? const LinearProgressIndicator(minHeight: 3)
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text.rich(
                          TextSpan(
                            text: coinsText(balance),
                            children: const [
                              TextSpan(
                                text: ' bCoins',
                                style: TextStyle(fontSize: 18),
                              ),
                            ],
                          ),
                          style: const TextStyle(
                            color: BStoreColors.textPrimary,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                const SizedBox(height: 4),
                Text(
                  '= $value value',
                  style: const TextStyle(
                    color: BStoreColors.textSecondary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
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
  final String Function(int amount) coinsText;

  const _ApplyCard({
    required this.coins,
    required this.maxCoins,
    required this.value,
    required this.onMinus,
    required this.onPlus,
    required this.onSliderChanged,
    required this.onUseMaximum,
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
          const SizedBox(height: 10),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: BStoreColors.primary,
              inactiveTrackColor: BStoreColors.border,
              thumbColor: Colors.white,
              overlayColor: BStoreColors.primary.withValues(alpha: 0.12),
              trackHeight: 5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
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
  final String Function(int amount) coinsText;

  const _RemainingBalanceCard({
    required this.remainingBalance,
    required this.coinsText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BStoreDecorations.card(radius: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: BStoreColors.primary, width: 2),
            ),
            child: const Icon(
              LucideIcons.walletCards,
              color: BStoreColors.textPrimary,
              size: 21,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Remaining balance',
                  style: TextStyle(
                    color: BStoreColors.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${coinsText(remainingBalance)} bCoins',
                  style: const TextStyle(
                    color: BStoreColors.textSecondary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(LucideIcons.chevronRight, size: 21),
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
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: FilledButton(
          onPressed: enabled ? onPressed : null,
          style: BStoreButtons.filled(radius: 10),
          child: Text('Apply ${coinsText(coins)} bCoins'),
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

class _BCoinsLogo extends StatelessWidget {
  final double size;

  const _BCoinsLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: BStoreColors.primary, width: 3),
      ),
      alignment: Alignment.center,
      child: Text(
        'b',
        style: TextStyle(
          color: BStoreColors.primary,
          fontSize: size * 0.58,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
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
