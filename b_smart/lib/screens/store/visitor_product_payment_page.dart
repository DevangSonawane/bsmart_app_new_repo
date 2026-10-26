import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _useDeliveryAddress = true;
  int _coinBalance = 0;
  int _coinsToUse = 0;
  bool _loadingBalance = true;

  @override
  void initState() {
    super.initState();
    StoreAddressBook.instance.ensureLoaded();
    _loadCoinBalance();
  }

  Future<void> _loadCoinBalance() async {
    try {
      final balance = await WalletService().getCoinBalance();
      if (mounted) setState(() => _coinBalance = balance);
    } finally {
      if (mounted) setState(() => _loadingBalance = false);
    }
  }

  int get _orderTotal => _amountValue(widget.amount);

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
                          const _SectionLabel('Split payment'),
                          const SizedBox(height: 9),
                          _PaymentSplitSlider(
                            total: _orderTotal,
                            availableCoins: _coinBalance,
                            coinsToUse: _coinsToUse,
                            loading: _loadingBalance,
                            onChanged: (value) =>
                                setState(() => _coinsToUse = value),
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
                    coinsToUse: _coinsToUse,
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

int _amountValue(String amount) =>
    double.tryParse(amount.replaceAll(RegExp(r'[^0-9.]'), ''))?.ceil() ?? 0;

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

class _PaymentSplitSlider extends StatelessWidget {
  final int total;
  final int availableCoins;
  final int coinsToUse;
  final bool loading;
  final ValueChanged<int> onChanged;

  const _PaymentSplitSlider({
    required this.total,
    required this.availableCoins,
    required this.coinsToUse,
    required this.loading,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final maximum = availableCoins.clamp(0, total);
    final applied = coinsToUse.clamp(0, maximum);
    final razorpay = total - applied;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFF4FAF9)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD8EBE8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Split your payment',
                        style: TextStyle(
                          color: BStoreColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        )),
                    SizedBox(height: 2),
                    Text('Use bCoins first, then pay the rest online',
                        style: TextStyle(
                          color: BStoreColors.textSecondary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        )),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F4F1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(LucideIcons.coins,
                      size: 14, color: BStoreColors.primary),
                  const SizedBox(width: 5),
                  Text(loading ? '…' : '$availableCoins',
                      style: const TextStyle(
                          color: BStoreColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w900)),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(children: [
            const Text('bCoins to use',
                style: TextStyle(
                    color: BStoreColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800)),
            const Spacer(),
            Text('$applied / $maximum',
                style: const TextStyle(
                    color: BStoreColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 2),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 7,
              activeTrackColor: BStoreColors.primary,
              inactiveTrackColor: const Color(0xFFDCE9E7),
              thumbColor: BStoreColors.primary,
              overlayColor: BStoreColors.primary.withValues(alpha: 0.12),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
            ),
            child: Slider(
              value: applied.toDouble(),
              min: 0,
              max: maximum == 0 ? 1 : maximum.toDouble(),
              divisions: maximum == 0 ? null : maximum,
              onChanged: loading || maximum == 0
                  ? null
                  : (value) => onChanged(value.round()),
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            _SplitAmount(
                label: 'bCoins',
                value: '₹$applied',
                color: const Color(0xFFE1F5F1),
                valueColor: BStoreColors.primary),
            const SizedBox(width: 10),
            _SplitAmount(
                label: 'Pay via Razorpay',
                value: '₹$razorpay',
                color: const Color(0xFFF0F2F6),
                valueColor: BStoreColors.textPrimary),
          ]),
          const SizedBox(height: 12),
          const Text(
            'bCoins are applied first and are charged only after payment is confirmed.',
            style: TextStyle(
              color: BStoreColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SplitAmount extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color valueColor;

  const _SplitAmount({
    required this.label,
    required this.value,
    required this.color,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(13)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: BStoreColors.textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(value,
                style: TextStyle(
                    color: valueColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w900)),
          ]),
        ),
      );
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
  final int coinsToUse;
  final Map<String, String> shippingAddress;
  final String addressLabel;
  final bool enabled;

  const _PayButton({
    required this.amount,
    required this.bCoinsSavings,
    required this.coinsToUse,
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
      paidAmount: _amountValue(widget.amount).toDouble(),
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

  Future<String?> _validateCoinBalance() async {
    final balance = await WalletService().getCoinBalance();
    if (balance >= widget.coinsToUse) return null;
    return 'Your bCoin balance changed. You have $balance bCoins but selected ${widget.coinsToUse}. Adjust the slider and try again.';
  }

  String _checkoutErrorMessage(Object error) {
    if (error is StoreCheckoutException) return error.message;
    if (error is ApiException) {
      final message = error.message.trim();
      if (error.statusCode == 400 &&
          widget.coinsToUse < _amountValue(widget.amount) &&
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
    int coinsToUse,
  ) async {
    // Creates the backend order first (stays pending until verified).
    final response = await StoreMockState.instance.checkoutWithCoins(
      shippingAddress: address,
      coinsToUse: coinsToUse,
      cartPrepared: true,
    );
    if (!mounted) return;
    final order = _orderFrom(response, productLines);
    final razorpay = RazorpayCheckoutService.razorpayOf(
      response,
      fallbackTotal: _amountValue(widget.amount).toDouble(),
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
          _goSuccess(order, coinsToUse == 0 ? 'Razorpay' : 'bCoins + Razorpay');
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
                        final walletError = await _validateCoinBalance();
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
                        final total = _amountValue(widget.amount);
                        final coinsToUse = widget.coinsToUse.clamp(0, total);
                        if (coinsToUse < total) {
                          await _payWithRazorpay(
                            productLines,
                            address,
                            coinsToUse,
                          );
                          return;
                        }
                        final response =
                            await StoreMockState.instance.checkoutWithCoins(
                          shippingAddress: address,
                          coinsToUse: coinsToUse,
                          cartPrepared: true,
                        );
                        if (!context.mounted) return;
                        StoreMockState.instance.completeCoinsOnlyCheckout();
                        _goSuccess(
                          _orderFrom(response, productLines),
                          'bCoins',
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
