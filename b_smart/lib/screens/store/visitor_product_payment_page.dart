import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../services/razorpay_checkout_service.dart';
import 'shared/store_shared_widgets.dart';
import 'store_address_book.dart';
import 'store_models.dart';
import 'store_order_tracking_page.dart';
import 'store_saved_address_page.dart';
import 'store_theme.dart';

class VisitorProductPaymentPage extends StatefulWidget {
  final String amount;
  final double bCoinsSavings;

  const VisitorProductPaymentPage({
    super.key,
    required this.amount,
    this.bCoinsSavings = 0,
  });

  @override
  State<VisitorProductPaymentPage> createState() =>
      _VisitorProductPaymentPageState();
}

class _VisitorProductPaymentPageState extends State<VisitorProductPaymentPage> {
  String _selectedMethod = 'wallet';
  bool _useDeliveryAddress = true;

  @override
  void initState() {
    super.initState();
    StoreAddressBook.instance.ensureLoaded();
  }

  ShipAddress? get _address => StoreAddressBook.instance.selected;

  Future<void> _pickAddress() async {
    final picked = await Navigator.of(context).push<ShipAddress>(
      MaterialPageRoute<ShipAddress>(
        builder: (_) => const StoreSavedAddressPage(selectMode: true),
      ),
    );
    if (picked == null || !mounted) return;
    StoreAddressBook.instance.select(picked.id);
    setState(() {});
  }

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
                      selected: _selectedMethod == 'wallet',
                      icon: const Icon(LucideIcons.wallet, size: 28),
                      title: 'Wallet / bCoins',
                      subtitle: '1 coin = ₹1 · deducted instantly',
                      trailing: _selectedMethod == 'wallet'
                          ? const _SelectedPill()
                          : null,
                      onTap: () => setState(() => _selectedMethod = 'wallet'),
                    ),
                    const SizedBox(height: 8),
                    _PaymentMethodCard(
                      selected: _selectedMethod == 'razorpay',
                      icon: const Icon(LucideIcons.creditCard, size: 28),
                      title: 'Razorpay',
                      subtitle: 'UPI · cards · netbanking',
                      trailing: _selectedMethod == 'razorpay'
                          ? const _SelectedPill()
                          : null,
                      onTap: () =>
                          setState(() => _selectedMethod = 'razorpay'),
                    ),
                    const SizedBox(height: 10),
                    AnimatedBuilder(
                      animation: StoreAddressBook.instance,
                      builder: (context, _) => _DeliveryAddressCard(
                        address: _address,
                        onChange: _pickAddress,
                      ),
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
              AnimatedBuilder(
                animation: StoreAddressBook.instance,
                builder: (context, _) {
                  final address = _address;
                  return _PayButton(
                    amount: widget.amount,
                    bCoinsSavings: widget.bCoinsSavings,
                    paymentMethod: _selectedMethod,
                    shippingAddress: address?.toShippingJson() ?? const {},
                    addressLabel: address == null
                        ? 'Add a delivery address'
                        : '${address.name}\n${address.summaryLine}\nIndia',
                    enabled: address != null,
                  );
                },
              ),
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
                'Checkout',
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
            'Total due',
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

class _DeliveryAddressCard extends StatelessWidget {
  final ShipAddress? address;
  final VoidCallback onChange;

  const _DeliveryAddressCard({
    required this.address,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final address = this.address;
    return Container(
      constraints: const BoxConstraints(minHeight: 54),
      padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
      decoration: storeSoftCardDecoration(radius: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: BStoreColors.surfaceTint,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.mapPin,
              color: BStoreColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  address == null
                      ? 'No delivery address'
                      : '${address.label} · ${address.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: BStoreColors.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  address == null
                      ? 'Add an address to continue'
                      : address.summaryLine,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: BStoreColors.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onChange,
            child: const Text('Change'),
          ),
        ],
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

class _PayButton extends StatefulWidget {
  final String amount;
  final double bCoinsSavings;
  final String paymentMethod;
  final Map<String, String> shippingAddress;
  final String addressLabel;
  final bool enabled;

  const _PayButton({
    required this.amount,
    required this.bCoinsSavings,
    this.paymentMethod = 'wallet',
    required this.shippingAddress,
    required this.addressLabel,
    this.enabled = true,
  });

  @override
  State<_PayButton> createState() => _PayButtonState();
}

class _PayButtonState extends State<_PayButton> {
  bool _submitting = false;
  final RazorpayCheckoutService _razorpay = RazorpayCheckoutService();

  @override
  void dispose() {
    _razorpay.dispose();
    super.dispose();
  }

  StoreMockOrder _orderFrom(
    Map<String, dynamic> response,
    List<StoreMockCartLine> productLines,
  ) {
    final serverOrder = response['order'];
    final serverMap = serverOrder is Map
        ? Map<String, dynamic>.from(serverOrder)
        : response;
    final serverId = (serverMap['id'] ??
            serverMap['_id'] ??
            serverMap['order_id'])
        ?.toString();
    return StoreMockOrder(
      id: (serverId == null || serverId.isEmpty)
          ? 'BS${DateTime.now().millisecondsSinceEpoch}'
          : serverId,
      customerName: 'You',
      avatarColor: const Color(0xFFE5F5F3),
      status: StoreMockOrderStatus.newOrder,
      lines: productLines,
      paidAmount: _amountValue(widget.amount),
      bCoinsSavings: widget.bCoinsSavings,
      address: widget.addressLabel,
    );
  }

  void _goSuccess(StoreMockOrder order, String methodLabel) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => VisitorProductPurchaseSuccessPage(
          amount: widget.amount,
          order: order,
          paymentMethodLabel: methodLabel,
        ),
      ),
    );
  }

  Future<void> _payWithRazorpay(
    List<StoreMockCartLine> productLines,
    Map<String, String> address,
  ) async {
    // Creates the backend order first (stays pending until verified).
    final response = await StoreMockState.instance.checkoutWithRazorpay(
      shippingAddress: address,
    );
    if (!mounted) return;
    final order = _orderFrom(response, productLines);
    final razorpay = RazorpayCheckoutService.razorpayOf(
      response,
      fallbackTotal: _amountValue(widget.amount),
    );
    if (razorpay == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Razorpay checkout is unavailable — the server did not return a '
            'Razorpay order. Pay with wallet, or ask the backend team to '
            'verify RAZORPAY_KEY_ID / RAZORPAY_SECRET are set.',
          ),
        ),
      );
      if (mounted) setState(() => _submitting = false);
      return;
    }
    _razorpay.open(
      keyId: razorpay.keyId,
      orderId: razorpay.orderId,
      amountPaise: razorpay.amountPaise,
      description: 'B-Smart order ${order.id}',
      onSuccess: (success) async {
        try {
          await StoreMockState.instance.verifyOrderPayment(
            orderId: order.id,
            razorpayOrderId: success.orderId,
            razorpayPaymentId: success.paymentId,
            razorpaySignature: success.signature,
          );
          if (!mounted) return;
          _goSuccess(order, 'Razorpay');
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Payment verification failed: $e')),
          );
        } finally {
          if (mounted) setState(() => _submitting = false);
        }
      },
      onFailure: (failure) {
        if (!mounted) return;
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              failure.dismissed
                  ? 'Payment cancelled. Order ${order.id} is pending — retry from tracking.'
                  : 'Razorpay: ${failure.message} Order ${order.id} stays pending.',
            ),
            duration: const Duration(seconds: 6),
          ),
        );
      },
    );
  }

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
          onPressed: (_submitting || !widget.enabled)
              ? null
              : () async {
                  if (StoreMockState.instance.cartLines.isEmpty) {
                    Navigator.of(context).maybePop();
                    return;
                  }
                  final lines = List<StoreMockCartLine>.from(
                    StoreMockState.instance.cartLines,
                  );
                  // Services have no cart per spec: only products go through
                  // POST /api/orders/checkout.
                  final productLines = lines
                      .where((l) => l.item.type == StoreMockItemType.product)
                      .toList();
                  if (productLines.isEmpty) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Services are booked directly, not via product checkout.'),
                      ),
                    );
                    return;
                  }
                  setState(() => _submitting = true);
                  try {
                    final address = widget.shippingAddress;
                    if (widget.paymentMethod == 'razorpay') {
                      await _payWithRazorpay(productLines, address);
                      return;
                    }
                    final response =
                        await StoreMockState.instance.checkoutWithWallet(
                      shippingAddress: address,
                    );
                    if (!context.mounted) return;
                    _goSuccess(
                      _orderFrom(response, productLines),
                      'Wallet',
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Checkout failed: $e')),
                    );
                  } finally {
                    if (mounted) setState(() => _submitting = false);
                  }
                },
          icon: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(LucideIcons.lockKeyhole, size: 18),
          label: Text(
            _submitting
                ? 'Confirming...'
                : widget.enabled
                    ? 'Confirm and pay ${widget.amount}'
                    : 'Add a delivery address to continue',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
          style: BStoreButtons.filled(radius: 9),
        ),
      ),
    );
  }

  static double _amountValue(String amount) {
    return double.tryParse(amount.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
  }
}

class VisitorProductPurchaseSuccessPage extends StatelessWidget {
  final String amount;
  final StoreMockOrder order;
  final String paymentMethodLabel;

  const VisitorProductPurchaseSuccessPage({
    super.key,
    required this.amount,
    required this.order,
    this.paymentMethodLabel = 'Wallet',
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
                'Order confirmed',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: BStoreColors.textPrimary,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Order #${order.id}',
                textAlign: TextAlign.center,
                style: const TextStyle(
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
                    _SuccessRow(
                        label: 'Payment method',
                        value: paymentMethodLabel),
                    const SizedBox(height: 10),
                    _SuccessRow(
                      label: _hasService(order) ? 'Fulfillment' : 'Delivery',
                      value: _hasService(order) ? 'Scheduled' : 'Processing',
                    ),
                    const Divider(height: 24, color: BStoreColors.border),
                    Text(
                      _hasService(order)
                          ? 'Your order has been confirmed successfully. We will notify you when the provider accepts the service request.'
                          : 'Your order has been placed successfully. We will notify you when the seller starts delivery.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
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
                  onPressed: () {
                    StoreMockState.instance.refreshBuyerOrders();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            const StoreOrderTrackingListPage(),
                      ),
                    );
                  },
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

  bool _hasService(StoreMockOrder order) {
    return order.lines
        .any((line) => line.item.type == StoreMockItemType.service);
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
