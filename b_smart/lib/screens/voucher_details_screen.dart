import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

class VoucherDetailsScreen extends StatelessWidget {
  const VoucherDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final data =
        args is Map ? Map<String, dynamic>.from(args) : <String, dynamic>{};

    final brandName = (data['brandName'] as String?) ?? 'Flipkart Gift Card';
    final amountLabel = (data['amountLabel'] as String?) ?? '₹1,000';
    final assetPath = (data['assetPath'] as String?) ??
        'assets/giftcards/flipkartgiftcard.avif';
    final voucherCode =
        (data['voucherCode'] as String?) ?? 'FLIP-8742-2211-ABCD';
    final pin = (data['pin'] as String?) ?? '4589';
    final expiryLabel = (data['expiryLabel'] as String?) ?? '31 Dec 2026';
    final redeemSteps = (data['redeemSteps'] as List?)
            ?.map((item) => item.toString())
            .toList() ??
        <String>[
          'Visit flipkart.com',
          'Add products to cart and go to payment',
          'Choose gift card / voucher option',
          'Enter the voucher code and PIN to pay',
        ];
    final actionLabel = (data['actionLabel'] as String?) ?? 'Go to Flipkart';
    final actionUrl =
        (data['actionUrl'] as String?) ?? 'https://www.flipkart.com/';

    return Scaffold(
      backgroundColor: Colors.white,
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
                    'Voucher Details',
                    style: GoogleFonts.montserrat(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF111111),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Center(
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 420),
                height: 170,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: const Color(0xFFF3F4F6),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Image.asset(assetPath, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              brandName,
              style: GoogleFonts.montserrat(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF111111),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              amountLabel,
              style: GoogleFonts.montserrat(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF111111),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                children: [
                  _InfoRow(
                    label: 'Voucher Code',
                    value: voucherCode,
                    actionLabel: 'Copy',
                    onAction: () => _copy(context, voucherCode),
                  ),
                  const Divider(height: 1),
                  _InfoRow(
                    label: 'PIN',
                    value: pin,
                    actionLabel: 'Copy',
                    onAction: () => _copy(context, pin),
                  ),
                  const Divider(height: 1),
                  _InfoRow(
                    label: 'Expiry Date',
                    value: expiryLabel,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How to Redeem',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF111111),
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final step in redeemSteps) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '•',
                            style: GoogleFonts.montserrat(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF111111),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              step,
                              style: GoogleFonts.montserrat(
                                fontSize: 13,
                                height: 1.35,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF111111),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () async {
                  final uri = Uri.tryParse(actionUrl);
                  if (uri == null) return;
                  final ok = await launchUrl(
                    uri,
                    mode: LaunchMode.externalApplication,
                  );
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not open link')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF97316),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  actionLabel,
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copy(BuildContext context, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _InfoRow({
    required this.label,
    required this.value,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final hasAction = actionLabel != null && onAction != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF4B5563),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.left,
              style: GoogleFonts.montserrat(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF111111),
              ),
            ),
          ),
          if (hasAction)
            InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.copy,
                        size: 15, color: Color(0xFF6B7280)),
                    const SizedBox(width: 6),
                    Text(
                      actionLabel!,
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF4B5563),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            const SizedBox(width: 12),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF111111)),
        ),
      ),
    );
  }
}
