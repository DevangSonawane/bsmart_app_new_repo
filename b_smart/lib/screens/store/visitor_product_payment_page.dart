import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'shared/store_shared_widgets.dart';
import 'store_theme.dart';

class VisitorProductPaymentPage extends StatefulWidget {
  final String amount;

  const VisitorProductPaymentPage({
    super.key,
    required this.amount,
  });

  @override
  State<VisitorProductPaymentPage> createState() =>
      _VisitorProductPaymentPageState();
}

class _VisitorProductPaymentPageState extends State<VisitorProductPaymentPage> {
  String _selectedMethod = 'visa';
  bool _useDeliveryAddress = true;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: BStoreTheme.data(context),
      child: Scaffold(
        backgroundColor: BStoreColors.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    16,
                    12,
                    16,
                    MediaQuery.of(context).padding.bottom + 86,
                  ),
                  children: [
                    const _PaymentHeader(),
                    const SizedBox(height: 18),
                    _AmountDueCard(amount: widget.amount),
                    const SizedBox(height: 18),
                    const Text(
                      'Choose payment method',
                      style: TextStyle(
                        color: BStoreColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 9),
                    _PaymentMethodCard(
                      selected: _selectedMethod == 'visa',
                      icon: const _VisaMark(),
                      title: 'Visa .... 4821',
                      subtitle: 'Expires 08/29',
                      trailing: const _SelectedPill(),
                      onTap: () => setState(() => _selectedMethod = 'visa'),
                    ),
                    const SizedBox(height: 8),
                    _PaymentMethodCard(
                      selected: _selectedMethod == 'card',
                      icon: const Icon(LucideIcons.creditCard, size: 28),
                      title: 'Add new card',
                      onTap: () => setState(() => _selectedMethod = 'card'),
                    ),
                    const SizedBox(height: 8),
                    _PaymentMethodCard(
                      selected: _selectedMethod == 'wallet',
                      icon: const Icon(LucideIcons.wallet, size: 28),
                      title: 'Digital wallet',
                      onTap: () => setState(() => _selectedMethod = 'wallet'),
                    ),
                    const SizedBox(height: 8),
                    _PaymentMethodCard(
                      selected: _selectedMethod == 'bcoins',
                      icon: const _BCoinsMark(),
                      title: 'Pay with bCoins',
                      onTap: () => setState(() => _selectedMethod = 'bcoins'),
                    ),
                    const SizedBox(height: 10),
                    _BillingAddressCard(
                      value: _useDeliveryAddress,
                      onChanged: (value) {
                        setState(() => _useDeliveryAddress = value);
                      },
                    ),
                    const SizedBox(height: 13),
                    const _SecurePaymentNote(),
                  ],
                ),
              ),
              _PayButton(amount: widget.amount),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentHeader extends StatelessWidget {
  const _PaymentHeader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 70,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(LucideIcons.chevronLeft, size: 28),
              color: BStoreColors.textPrimary,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 34, height: 34),
            ),
          ),
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StoreBsmartWordmark(),
              SizedBox(height: 14),
              Text(
                'Payment',
                style: TextStyle(
                  color: BStoreColors.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AmountDueCard extends StatelessWidget {
  final String amount;

  const _AmountDueCard({required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 13),
      decoration: storeSoftCardDecoration(radius: 12),
      child: Column(
        children: [
          const Text(
            'Amount due',
            style: TextStyle(
              color: Color(0xFF4B546D),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              amount,
              style: const TextStyle(
                color: BStoreColors.primary,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  final bool selected;
  final Widget icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  const _PaymentMethodCard({
    required this.selected,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        constraints: const BoxConstraints(minHeight: 54),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: storeSoftCardDecoration(radius: 12),
        child: Row(
          children: [
            _RadioDot(selected: selected),
            const SizedBox(width: 9),
            _IconTile(child: icon),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: BStoreColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF566079),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ??
                const Icon(
                  LucideIcons.chevronRight,
                  color: BStoreColors.textPrimary,
                  size: 21,
                ),
          ],
        ),
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  final bool selected;

  const _RadioDot({required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 18,
      height: 18,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? BStoreColors.primary : const Color(0xFF4B546D),
          width: selected ? 2.2 : 1.5,
        ),
      ),
      child: selected
          ? const DecoratedBox(
              decoration: BoxDecoration(
                color: BStoreColors.primary,
                shape: BoxShape.circle,
              ),
            )
          : null,
    );
  }
}

class _IconTile extends StatelessWidget {
  final Widget child;

  const _IconTile({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8EBEF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _VisaMark extends StatelessWidget {
  const _VisaMark();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'VISA',
      style: TextStyle(
        color: BStoreColors.visaBlue,
        fontSize: 15,
        fontWeight: FontWeight.w900,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}

class _BCoinsMark extends StatelessWidget {
  const _BCoinsMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: BStoreColors.accentPurple, width: 1.4),
      ),
      child: const Center(
        child: Text(
          'b',
          style: TextStyle(
            color: BStoreColors.accentPurple,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _SelectedPill extends StatelessWidget {
  const _SelectedPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: BStoreColors.primary,
        borderRadius: BorderRadius.circular(7),
      ),
      child: const Text(
        'Selected',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _BillingAddressCard extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _BillingAddressCard({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 54),
      padding: const EdgeInsets.fromLTRB(10, 7, 4, 7),
      decoration: storeSoftCardDecoration(radius: 12),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: BStoreColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.check, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Use delivery address\nas billing address',
              style: TextStyle(
                color: BStoreColors.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                height: 1.35,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: BStoreColors.primary,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFE2E6EA),
          ),
        ],
      ),
    );
  }
}

class _SecurePaymentNote extends StatelessWidget {
  const _SecurePaymentNote();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(LucideIcons.shieldCheck, color: BStoreColors.primary, size: 28),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Secure payment',
                style: TextStyle(
                  color: BStoreColors.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Your payment information is encrypted and processed securely.',
                style: TextStyle(
                  color: BStoreColors.textSecondary,
                  fontSize: 11.5,
                  height: 1.35,
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

class _PayButton extends StatelessWidget {
  final String amount;

  const _PayButton({required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 8,
      ),
      color: BStoreColors.background,
      child: SizedBox(
        height: 46,
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => VisitorProductPurchaseSuccessPage(
                  amount: amount,
                ),
              ),
            );
          },
          icon: const Icon(LucideIcons.lockKeyhole, size: 18),
          label: Text(
            'Pay $amount',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
          style: BStoreButtons.filled(radius: 9),
        ),
      ),
    );
  }
}

class VisitorProductPurchaseSuccessPage extends StatelessWidget {
  final String amount;

  const VisitorProductPurchaseSuccessPage({
    super.key,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: BStoreTheme.data(context),
      child: Scaffold(
        backgroundColor: BStoreColors.background,
        body: SafeArea(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
            children: [
              const _SuccessHeader(),
              const SizedBox(height: 48),
              Center(
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: const BoxDecoration(
                    color: BStoreColors.surfaceTint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.circleCheck,
                    color: BStoreColors.primary,
                    size: 42,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Product purchased',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: BStoreColors.textPrimary,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Order #BS2048',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: BStoreColors.accentPurple,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: storeSoftCardDecoration(radius: 12),
                child: Column(
                  children: [
                    _SuccessRow(label: 'Amount paid', value: amount),
                    const SizedBox(height: 10),
                    const _SuccessRow(
                        label: 'Payment method', value: 'Visa 4821'),
                    const SizedBox(height: 10),
                    const _SuccessRow(label: 'Delivery', value: 'Processing'),
                    const Divider(height: 24, color: BStoreColors.border),
                    const Text(
                      'Your order has been placed successfully. We will notify you when the seller starts delivery.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: BStoreColors.textSecondary,
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 46,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).popUntil(
                    (route) => route.isFirst,
                  ),
                  style: BStoreButtons.filled(),
                  child: const Text(
                    'Continue shopping',
                    style:
                        TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 46,
                child: OutlinedButton(
                  onPressed: () {},
                  style: BStoreButtons.outlined(),
                  child: const Text(
                    'View order',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
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

class _SuccessHeader extends StatelessWidget {
  const _SuccessHeader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(LucideIcons.chevronLeft, size: 28),
              color: BStoreColors.textPrimary,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 34, height: 34),
            ),
          ),
          const StoreBsmartWordmark(),
        ],
      ),
    );
  }
}

class _SuccessRow extends StatelessWidget {
  final String label;
  final String value;

  const _SuccessRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: BStoreColors.textMuted,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: BStoreColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
