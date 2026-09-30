import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:razorpay_flutter/razorpay_flutter.dart';

/// Result of a successful Razorpay Checkout payment.
class RazorpayCheckoutSuccess {
  final String paymentId;
  final String orderId;
  final String signature;

  const RazorpayCheckoutSuccess({
    required this.paymentId,
    required this.orderId,
    required this.signature,
  });
}

/// Failure / dismissal from Razorpay Checkout.
class RazorpayCheckoutFailure {
  final String message;
  final bool dismissed;

  const RazorpayCheckoutFailure(this.message, {this.dismissed = false});
}

/// Thin wrapper around the Razorpay native Checkout SDK.
///
/// Backend contract (Phase 2 md): `POST /api/orders/checkout` (or
/// `POST /api/service-bookings`) with `payment_method: razorpay` returns
/// `razorpay: { order_id, amount, key_id }`. Open that order here, then call
/// the matching `verify-payment` endpoint with the success payload.
class RazorpayCheckoutService {
  Razorpay? _razorpay;
  void Function(RazorpayCheckoutSuccess)? _onSuccess;
  void Function(RazorpayCheckoutFailure)? _onFailure;

  bool get isAvailable => !kIsWeb;

  /// Opens Razorpay Checkout for a backend-created order.
  ///
  /// [amountPaise] must match the backend Razorpay order amount (paise).
  void open({
    required String keyId,
    required String orderId,
    required int amountPaise,
    String currency = 'INR',
    String name = 'B-Smart Store',
    String? description,
    String? contact,
    String? email,
    required void Function(RazorpayCheckoutSuccess) onSuccess,
    required void Function(RazorpayCheckoutFailure) onFailure,
  }) {
    dispose();
    _onSuccess = onSuccess;
    _onFailure = onFailure;
    if (!isAvailable) {
      onFailure(const RazorpayCheckoutFailure(
        'Razorpay Checkout is only available on Android/iOS.',
      ));
      return;
    }
    try {
      _razorpay = Razorpay();
      _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleSuccess);
      _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handleError);
      _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleWallet);
      _razorpay!.open({
        'key': keyId,
        'order_id': orderId,
        'amount': amountPaise,
        'currency': currency,
        'name': name,
        if (description != null && description.isNotEmpty)
          'description': description,
        'prefill': {
          if (contact != null && contact.isNotEmpty) 'contact': contact,
          if (email != null && email.isNotEmpty) 'email': email,
        },
      });
    } catch (e) {
      onFailure(RazorpayCheckoutFailure('Could not open Razorpay: $e'));
    }
  }

  void _handleSuccess(PaymentSuccessResponse response) {
    final paymentId = response.paymentId ?? '';
    final orderId = response.orderId ?? '';
    final signature = response.signature ?? '';
    if (paymentId.isEmpty || orderId.isEmpty || signature.isEmpty) {
      _onFailure?.call(const RazorpayCheckoutFailure(
        'Razorpay returned an incomplete success payload.',
      ));
      return;
    }
    _onSuccess?.call(RazorpayCheckoutSuccess(
      paymentId: paymentId,
      orderId: orderId,
      signature: signature,
    ));
  }

  void _handleError(PaymentFailureResponse response) {
    final code = response.code ?? -1;
    // Code 0 from the SDK generally means the user dismissed/cancelled.
    _onFailure?.call(RazorpayCheckoutFailure(
      response.message?.trim().isNotEmpty == true
          ? response.message!.trim()
          : 'Razorpay payment failed.',
      dismissed: code == 0,
    ));
  }

  void _handleWallet(ExternalWalletResponse response) {
    _onFailure?.call(RazorpayCheckoutFailure(
      'External wallet ${response.walletName ?? ''} selected. '
      'Complete the payment to confirm the order.',
    ));
  }

  /// Local test override, supplied at run time — never committed:
  /// `flutter run --dart-define=RAZORPAY_KEY_ID=rzp_test_...`
  /// Used only when the backend response omits `key_id`. The backend
  /// response always wins. The SECRET always stays server-side.
  static const String _envKeyId = String.fromEnvironment(
    'RAZORPAY_KEY_ID',
    defaultValue: '',
  );

  /// Extracts `{keyId, orderId, amountPaise}` from a checkout/create response.
  ///
  /// Returns null when neither the backend nor the local override provides
  /// a key.
  static ({String keyId, String orderId, int amountPaise})? razorpayOf(
    Map<String, dynamic> response, {
    required double fallbackTotal,
  }) {
    // The razorpay block can be a sibling of `order`, nested under `data`,
    // or flattened onto the response root.
    final map = response.map((key, value) => MapEntry(key.toString(), value));
    final data = map['data'];
    final scope = data is Map
        ? data.map((key, value) => MapEntry(key.toString(), value))
        : map;
    Map<String, dynamic>? block;
    for (final source in [map, scope]) {
      final raw = source['razorpay'];
      if (raw is Map) {
        block = raw.map((key, value) => MapEntry(key.toString(), value));
        break;
      }
    }

    var keyId = block?['key_id']?.toString().trim() ?? '';
    if (keyId.isEmpty) keyId = scope['key_id']?.toString().trim() ?? '';
    if (keyId.isEmpty) keyId = _envKeyId.trim();

    var orderId = block?['order_id']?.toString().trim() ?? '';
    if (orderId.isEmpty) {
      orderId = scope['razorpay_order_id']?.toString().trim() ?? '';
    }
    if (keyId.isEmpty || orderId.isEmpty) return null;

    var amountPaise = (fallbackTotal * 100).round();
    final rawAmount = block?['amount'] ?? block?['amount_paise'];
    if (rawAmount is num && rawAmount > 0) {
      amountPaise = rawAmount.toInt();
    } else if (rawAmount is String) {
      final parsed = int.tryParse(rawAmount);
      if (parsed != null && parsed > 0) amountPaise = parsed;
    }
    return (keyId: keyId, orderId: orderId, amountPaise: amountPaise);
  }

  void dispose() {
    try {
      _razorpay?.clear();
    } catch (_) {}
    _razorpay = null;
    _onSuccess = null;
    _onFailure = null;
  }
}
