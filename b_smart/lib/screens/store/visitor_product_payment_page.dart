import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/api_exceptions.dart';
import '../../services/razorpay_checkout_service.dart';
import '../../services/wallet_service.dart';
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
                    const SizedBox(height: 14),
                    AnimatedBuilder(
                      animation: StoreAddressBook.instance,
                      builder: (context, _) => Column(
                        children: [
                          _AmountDueCard(
                            amount: widget.amount,
                            bCoinsSavings: widget.bCoinsSavings,
                          ),
                          const SizedBox(height: 18),
                          const _SectionLabel('Pay with'),
                          const SizedBox(height: 9),
                          _PaymentMethodCard(
                            selected: _selectedMethod == 'wallet',
                            brandAsset: 'assets/store/payment/wallet.svg',
                            title: 'Wallet / bCoins',
                            subtitle: '1 coin = ₹1 · deducted instantly',
                            onTap: () =>
                                setState(() => _selectedMethod = 'wallet'),
                          ),
                          const SizedBox(height: 10),
                          _PaymentMethodCard(
                            selected: _selectedMethod == 'razorpay',
                            brandAsset: 'assets/store/payment/razorpay.svg',
                            title: 'Razorpay',
                            subtitle: 'UPI · cards · netbanking',
                            onTap: () =>
                                setState(() => _selectedMethod = 'razorpay'),
                          ),
                          const SizedBox(height: 18),
                          const _SectionLabel('Deliver to'),
                          const SizedBox(height: 9),
                          _DeliveryAddressCard(
                            address: _address,
                            onChange: _pickAddress,
                          ),
                          const SizedBox(height: 10),
                          _BillingAddressCard(
                            value: _useDeliveryAddress,
                            onChanged: (value) {
                              setState(() => _useDeliveryAddress = value);
                            },
                          ),
                          const SizedBox(height: 14),
                          const _SecurePaymentNote(),
                        ],
                      ),
                    ),
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
              'Checkout',
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

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: BStoreColors.textSoft,
        fontSize: 11,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _AmountDueCard extends StatelessWidget {
  final String amount;
  final double bCoinsSavings;

  const _AmountDueCard({
    required this.amount,
    this.bCoinsSavings = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B1030), Color(0xFF1B2560)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B1030).withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -48,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF078D92).withValues(alpha: 0.45),
                    const Color(0xFF078D92).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AMOUNT PAYABLE',
                  style: TextStyle(
                    color: Color(0xFF9AA3C7),
                    fontSize: 10.5,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    amount,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      height: 1.0,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (bCoinsSavings > 0) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF139B54).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: const Color(0xFF139B54).withValues(alpha: 0.45),
                      ),
                    ),
                    child: const Text(
                      'bCoins applied to this order',
                      style: TextStyle(
                        color: Color(0xFF5EEAD4),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
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

class _PaymentMethodCard extends StatelessWidget {
  final bool selected;
  final String brandAsset;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _PaymentMethodCard({
    required this.selected,
    required this.brandAsset,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? BStoreColors.primary : BStoreColors.borderSoft,
            width: selected ? 1.8 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: BStoreColors.primary.withValues(alpha: 0.14),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            _RadioDot(selected: selected),
            const SizedBox(width: 11),
            Container(
              width: 58,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF6F7F9),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: BStoreColors.borderSoft),
              ),
              child: SvgPicture.asset(
                brandAsset,
                width: 48,
                height: 30,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 11),
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
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
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
    final hasAddress = address != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasAddress
              ? BStoreColors.borderSoft
              : const Color(0xFFE87822).withValues(alpha: 0.55),
          width: hasAddress ? 1 : 1.4,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: hasAddress
                  ? const Color(0xFFE9F8E6)
                  : const Color(0xFFFFF1E3),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              LucideIcons.mapPin,
              color: hasAddress
                  ? const Color(0xFF139B54)
                  : const Color(0xFFE87822),
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasAddress
                      ? 'Deliver to ${address.name}'
                      : 'No delivery address',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: BStoreColors.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  hasAddress
                      ? address.summaryLine
                      : 'Add an address to continue',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: BStoreColors.textSecondary,
                    fontSize: 11.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            height: 38,
            child: FilledButton(
              onPressed: onChange,
              style: FilledButton.styleFrom(
                backgroundColor:
                    hasAddress ? const Color(0xFFF1F4F8) : BStoreColors.primary,
                foregroundColor:
                    hasAddress ? BStoreColors.textPrimary : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
                textStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              child: Text(hasAddress ? 'Change' : 'Add'),
            ),
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
      padding: const EdgeInsets.fromLTRB(12, 9, 6, 9),
      decoration: storeSoftCardDecoration(radius: 16),
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
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0A9BA0), Color(0xFF078D92)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: BStoreColors.primary.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                LucideIcons.shieldCheck,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF0B1030),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0B1030).withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                LucideIcons.lockKeyhole,
                color: Color(0xFF5EEAD4),
                size: 24,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          '100% Secure Payments',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: BStoreColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'All transactions are encrypted with 256-bit SSL security. Your card and UPI details are never stored on our servers.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: BStoreColors.textSecondary,
            fontSize: 12,
            height: 1.5,
            fontWeight: FontWeight.w600,
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
    final serverMap =
        serverOrder is Map ? Map<String, dynamic>.from(serverOrder) : response;
    final serverId =
        (serverMap['id'] ?? serverMap['_id'] ?? serverMap['order_id'])
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

  String? _validateShippingAddress(Map<String, String> address) {
    const labels = {
      'name': 'name',
      'phone': 'phone number',
      'address_line1': 'address',
      'city': 'city',
      'state': 'state',
      'pincode': 'pincode',
    };
    for (final entry in labels.entries) {
      if ((address[entry.key] ?? '').trim().isEmpty) {
        return 'Please add your ${entry.value} before checkout.';
      }
    }
    return null;
  }

  Future<String?> _validateWalletBalance() async {
    if (widget.paymentMethod != 'wallet') return null;
    final balance = await WalletService().getCoinBalance();
    final payable = _amountValue(widget.amount).ceil();
    if (balance >= payable) return null;
    return 'Insufficient bCoins. You have $balance bCoins, but this order needs $payable. Please choose Razorpay or add bCoins.';
  }

  String _checkoutErrorMessage(Object error) {
    if (error is StoreCheckoutException) return error.message;
    if (error is ApiException) {
      final message = error.message.trim();
      if (error.statusCode == 400 &&
          widget.paymentMethod == 'razorpay' &&
          _amountValue(widget.amount) > 1000000) {
        return 'This order total is very high (${widget.amount}) and the payment gateway rejected it. Please reduce quantity or split the order.';
      }
      if (message.isNotEmpty && message.toLowerCase() != 'bad request') {
        return message;
      }
      if (error.statusCode == 400) {
        return 'Checkout was rejected. Please check cart items, delivery address, and payment method.';
      }
      return message.isEmpty ? 'Checkout failed.' : message;
    }
    return error.toString();
  }

  Future<void> _payWithRazorpay(
    List<StoreMockCartLine> productLines,
    Map<String, String> address,
  ) async {
    // Creates the backend order first (stays pending until verified).
    final response = await StoreMockState.instance.checkoutWithRazorpay(
      shippingAddress: address,
      cartPrepared: true,
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
    final ready = !_submitting && widget.enabled;
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: BStoreColors.borderSoft),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.amount,
                    style: const TextStyle(
                      color: BStoreColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.bCoinsSavings > 0
                      ? 'incl. bCoins savings'
                      : 'Total payable',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: BStoreColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: !ready
                  ? null
                  : () async {
                      if (StoreMockState.instance.cartLines.isEmpty) {
                        Navigator.of(context).maybePop();
                        return;
                      }
                      final address = widget.shippingAddress;
                      final addressError = _validateShippingAddress(address);
                      if (addressError != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(addressError)),
                        );
                        return;
                      }
                      setState(() => _submitting = true);
                      try {
                        final walletError = await _validateWalletBalance();
                        if (walletError != null) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(walletError)),
                          );
                          return;
                        }
                        // Services have no cart per spec: only products go through
                        // POST /api/orders/checkout. This also refreshes the
                        // server cart so optimistic local items cannot drift into
                        // a backend "cart is empty" checkout error.
                        final productLines = await StoreMockState.instance
                            .prepareProductCheckout();
                        if (widget.paymentMethod == 'razorpay') {
                          await _payWithRazorpay(productLines, address);
                          return;
                        }
                        final response =
                            await StoreMockState.instance.checkoutWithWallet(
                          shippingAddress: address,
                          cartPrepared: true,
                        );
                        if (!context.mounted) return;
                        _goSuccess(
                          _orderFrom(response, productLines),
                          'Wallet',
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(_checkoutErrorMessage(e))),
                        );
                      } finally {
                        if (mounted) setState(() => _submitting = false);
                      }
                    },
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Icon(LucideIcons.lockKeyhole, size: 17),
              label: Text(
                _submitting
                    ? 'Paying…'
                    : widget.enabled
                        ? 'Pay Now'
                        : 'Add Address',
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: BStoreColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFD5DEE4),
                padding: const EdgeInsets.symmetric(horizontal: 26),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
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
              const SizedBox(height: 16),
              _SuccessHero(order: order, amount: amount),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: storeSoftCardDecoration(radius: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'RECEIPT',
                      style: TextStyle(
                        color: BStoreColors.textSoft,
                        fontSize: 11,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _SuccessRow(label: 'Amount paid', value: amount),
                    const SizedBox(height: 10),
                    _SuccessRow(
                        label: 'Payment method', value: paymentMethodLabel),
                    const SizedBox(height: 10),
                    _SuccessRow(
                      label: _hasService(order) ? 'Fulfillment' : 'Delivery',
                      value: _hasService(order) ? 'Scheduled' : 'Processing',
                    ),
                    const Divider(height: 20, color: BStoreColors.border),
                    Text(
                      _hasService(order)
                          ? 'We will notify you when the provider accepts the service request.'
                          : 'We will notify you when the seller starts delivery.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: BStoreColors.textSecondary,
                        fontSize: 12.5,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    StoreMockState.instance.refreshBuyerOrders();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => StoreOrderTrackingDetailPage(
                          order: TrackingOrder.fromStoreOrder(order),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(LucideIcons.truck, size: 19),
                  label: const Text(
                    'Track Order',
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
              const SizedBox(height: 10),
              SizedBox(
                height: 50,
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).popUntil(
                    (route) => route.isFirst,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: BStoreColors.textPrimary,
                    side: const BorderSide(color: BStoreColors.borderSoft),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Continue shopping',
                    style:
                        TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900),
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
    return Row(
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
            icon: const Icon(Icons.close_rounded, size: 22),
            color: BStoreColors.textPrimary,
            padding: EdgeInsets.zero,
          ),
        ),
        const Spacer(),
      ],
    );
  }
}

class _SuccessHero extends StatelessWidget {
  final StoreMockOrder order;
  final String amount;

  const _SuccessHero({required this.order, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B4F52), Color(0xFF0B1030)],
          stops: [0.0, 1.0],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF078D92).withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            left: -52,
            top: -60,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF34D399).withValues(alpha: 0.4),
                    const Color(0xFF34D399).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: -40,
            bottom: -56,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.14),
                  width: 1.5,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.5, end: 1.0),
                  duration: const Duration(milliseconds: 550),
                  curve: Curves.elasticOut,
                  builder: (context, scale, child) => Transform.scale(
                    scale: scale,
                    child: child,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color:
                                const Color(0xFF34D399).withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                      ),
                      Container(
                        width: 66,
                        height: 66,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF34D399), Color(0xFF078D92)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF34D399)
                                  .withValues(alpha: 0.5),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Center(
                  child: Text(
                    'Order confirmed',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    amount,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF5EEAD4),
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: order.id));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Order ID copied to clipboard'),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            'ID ${order.id.toUpperCase()}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          LucideIcons.copy,
                          color: Colors.white.withValues(alpha: 0.7),
                          size: 13,
                        ),
                      ],
                    ),
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
