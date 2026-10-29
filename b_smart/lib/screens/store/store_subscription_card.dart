import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/phase2_store_api.dart';
import '../../services/razorpay_checkout_service.dart';
import 'store_theme.dart';

/// React-parity subscription management for an influencer's own store.
/// Matches the web app: clean white card with teal accent, no dark gradient.
class StoreSubscriptionCard extends StatefulWidget {
  const StoreSubscriptionCard({super.key});
  @override
  State<StoreSubscriptionCard> createState() => _StoreSubscriptionCardState();
}

class _StoreSubscriptionCardState extends State<StoreSubscriptionCard> {
  final _api = Phase2StoreApi();
  final _razorpay = RazorpayCheckoutService();
  Map<String, dynamic>? _subscription;
  bool _loading = true;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _razorpay.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      _subscription = await _api.myAccountSubscription();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _upgrade() async {
    setState(() => _working = true);
    try {
      final response = await _api.upgradeAccountSubscription();
      final data = response['razorpay'] as Map?;
      final key = data?['key_id']?.toString() ?? '';
      final id = data?['subscription_id']?.toString() ?? '';
      if (key.isEmpty || id.isEmpty) {
        throw StateError('Subscription details unavailable.');
      }
      _razorpay.openSubscription(
          keyId: key,
          subscriptionId: id,
          description: 'Upgrade store subscription',
          onSuccess: (_) async {
            await _load();
            if (mounted) setState(() => _working = false);
          },
          onFailure: (e) {
            if (mounted) setState(() => _working = false);
          });
    } catch (e) {
      if (mounted) {
        setState(() => _working = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _activate({required bool startTrial}) async {
    setState(() => _working = true);
    try {
      final response = await _api.createAccountSubscription(
        startTrial: startTrial,
      );
      final data = response['razorpay'] as Map?;
      final key = data?['key_id']?.toString() ?? '';
      final id = data?['subscription_id']?.toString() ?? '';
      if (key.isEmpty || id.isEmpty) {
        throw StateError('Subscription details unavailable.');
      }
      _razorpay.openSubscription(
        keyId: key,
        subscriptionId: id,
        description: startTrial
            ? '7-day trial — ₹99/month after trial'
            : '₹99/month store subscription',
        onSuccess: (_) async {
          await _load();
          if (mounted) setState(() => _working = false);
        },
        onFailure: (_) {
          if (mounted) setState(() => _working = false);
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _working = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not activate plan: $e')));
    }
  }

  Future<void> _cancel() async {
    final id = _subscription?['_id']?.toString() ??
        _subscription?['id']?.toString() ??
        '';
    if (id.isEmpty) return;
    await _api.cancelAccountSubscription(id);
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox(height: 8);
    if (_subscription == null) {
      return Container(
        decoration: BStoreDecorations.card(radius: BStoreRadii.cardLarge),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(LucideIcons.sparkles, color: BStoreColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Marketplace Seller Plan',
                style: BStoreTypography.screenTitle.copyWith(fontSize: 16),
              ),
            ]),
            const SizedBox(height: 8),
            Text(
              'List products and services, receive bookings, and manage your store.',
              style: BStoreTypography.body.copyWith(fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            Text(
              '₹99 / month',
              style: BStoreTypography.screenTitle.copyWith(fontSize: 24),
            ),
            const SizedBox(height: 4),
            Text(
              '7-day free trial available · Cancel anytime',
              style: BStoreTypography.label.copyWith(fontSize: 11.5),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _working ? null : () => _activate(startTrial: true),
                  style: BStoreButtons.outlined(
                    foreground: BStoreColors.primary,
                    border: BStoreColors.primary,
                  ),
                  child: Text(_working ? 'Opening…' : 'Start free trial'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _working ? null : () => _activate(startTrial: false),
                  style: BStoreButtons.filled(
                    background: const Color(0xFFFFD166),
                    foreground: BStoreColors.textPrimary,
                  ),
                  child: const Text('Subscribe now'),
                ),
              ),
            ]),
          ],
        ),
      );
    }
    final status = _subscription!['status']?.toString() ?? 'created';
    final trial = status == 'trialing';
    return Container(
      decoration: BStoreDecorations.card(radius: BStoreRadii.cardLarge),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            trial
                ? 'Free trial active'
                : status == 'past_due'
                    ? 'Payment needs attention'
                    : 'Store subscription active',
            style: BStoreTypography.sectionTitle.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            trial
                ? '₹99/month after your trial. You can upgrade now or cancel anytime.'
                : '₹99/month · status: $status',
            style: BStoreTypography.body.copyWith(fontSize: 12.5),
          ),
          if (trial) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: _working ? null : _upgrade,
              child: Text(_working ? 'Opening checkout…' : 'Upgrade now',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
          TextButton(
            onPressed: _working ? null : _cancel,
            child: const Text(
              'Cancel subscription',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}