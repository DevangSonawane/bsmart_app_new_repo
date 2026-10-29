import 'package:flutter/material.dart';
import '../../services/razorpay_checkout_service.dart';
import 'service_cart_state.dart';
import 'store_models.dart';

class ServiceCartPage extends StatefulWidget {
  const ServiceCartPage({super.key});
  @override
  State<ServiceCartPage> createState() => _ServiceCartPageState();
}

class _ServiceCartPageState extends State<ServiceCartPage> {
  int _coins = 0;
  bool _paying = false;
  final _razorpay = RazorpayCheckoutService();
  @override
  void dispose() {
    _razorpay.dispose();
    super.dispose();
  }

  Future<void> _checkout() async {
    final cart = ServiceCartState.instance;
    if (cart.lines.isEmpty) return;
    setState(() => _paying = true);
    try {
      final response = await StoreMockState.instance.createBookingOrder(
          cart.lines.map((e) => e.payload).toList(), _coins);
      final order = response['order'] as Map? ?? response;
      final id = (order['_id'] ?? order['id']).toString();
      final rp = RazorpayCheckoutService.razorpayOf(response,
          fallbackTotal: cart.total.toDouble());
      if (rp == null) {
        cart.clear();
        if (mounted) Navigator.pop(context);
        return;
      }
      _razorpay.open(
          keyId: rp.keyId,
          orderId: rp.orderId,
          amountPaise: rp.amountPaise,
          onSuccess: (p) async {
            await StoreMockState.instance.verifyBookingPayment(
                bookingId: id,
                razorpayOrderId: p.orderId,
                razorpayPaymentId: p.paymentId,
                razorpaySignature: p.signature);
            cart.clear();
            if (mounted) Navigator.pop(context);
          },
          onFailure: (_) {
            if (mounted) setState(() => _paying = false);
          });
    } catch (e) {
      if (mounted) {
        setState(() => _paying = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Service cart')),
      body: AnimatedBuilder(
          animation: ServiceCartState.instance,
          builder: (_, __) {
            final c = ServiceCartState.instance;
            return Column(children: [
              Expanded(
                  child: c.lines.isEmpty
                      ? const Center(child: Text('Your service cart is empty.'))
                      : ListView(children: [
                          for (final line in c.lines)
                            ListTile(
                                title: Text(line.title),
                                subtitle: Text('₹${line.total}'),
                                trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => c.remove(line)))
                        ])),
              Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    Text('Total ₹${c.total}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18)),
                    Slider(
                        value: _coins.clamp(0, c.total).toDouble(),
                        max: c.total.toDouble().clamp(1, double.infinity),
                        onChanged: (v) => setState(() => _coins = v.round())),
                    FilledButton(
                        onPressed: _paying ? null : _checkout,
                        child: Text(_paying ? 'Processing…' : 'Checkout'))
                  ]))
            ]);
          }));
}
