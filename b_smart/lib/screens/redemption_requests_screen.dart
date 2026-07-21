import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class RedemptionRequestsScreen extends StatefulWidget {
  const RedemptionRequestsScreen({super.key});

  @override
  State<RedemptionRequestsScreen> createState() =>
      _RedemptionRequestsScreenState();
}

class _RedemptionRequestsScreenState extends State<RedemptionRequestsScreen> {
  String _filter = 'All';

  static const List<String> _filters = <String>[
    'All',
    'Pending',
    'Completed',
    'Cancelled',
  ];

  static const List<_RedemptionRequest> _requests = <_RedemptionRequest>[
    _RedemptionRequest(
      name: 'Amazon Gift Card',
      amountLabel: '₹500',
      dateLabel: '21 Jul 2024, 02:53 PM',
      status: 'Pending',
      assetPath: 'assets/giftcards/amazongiftcard.webp',
    ),
    _RedemptionRequest(
      name: 'Flipkart Gift Card',
      amountLabel: '₹1,000',
      dateLabel: '20 Jul 2024, 11:20 AM',
      status: 'Completed',
      assetPath: 'assets/giftcards/flipkartgiftcard.avif',
      voucherCode: 'FLIP-8742-2211-ABCD',
      pin: '4589',
      expiryLabel: '31 Dec 2026',
      redeemSteps: <String>[
        'Visit flipkart.com',
        'Add products to cart and go to payment',
        'Choose gift card / voucher option',
        'Enter the voucher code and PIN to pay',
      ],
      actionLabel: 'Go to Flipkart',
      actionUrl: 'https://www.flipkart.com/',
    ),
    _RedemptionRequest(
      name: 'Myntra Gift Card',
      amountLabel: '₹500',
      dateLabel: '18 Jul 2024, 09:15 AM',
      status: 'Cancelled',
      assetPath: 'assets/giftcards/myntra.jpeg',
    ),
    _RedemptionRequest(
      name: 'Zomato Gift Card',
      amountLabel: '₹100',
      dateLabel: '16 Jul 2024, 08:45 PM',
      status: 'Pending',
      assetPath: 'assets/giftcards/zomatogiftcard.avif',
    ),
  ];

  List<_RedemptionRequest> get _visibleRequests {
    if (_filter == 'All') return _requests;
    return _requests.where((request) => request.status == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFFF9F9F9) : Colors.white;
    const titleColor = Color(0xFF111111);
    final subColor = Colors.black.withValues(alpha: 0.56);
    const chipBg = Colors.white;
    final border = Colors.black.withValues(alpha: 0.08);

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _HeaderButton(
                    icon: LucideIcons.arrowLeft,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'My Redemption Requests',
                      style: GoogleFonts.montserrat(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: titleColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _filters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final label = _filters[index];
                    final selected = label == _filter;
                    return ChoiceChip(
                      label: Text(label),
                      selected: selected,
                      onSelected: (_) => setState(() => _filter = label),
                      selectedColor: const Color(0xFFF97316),
                      backgroundColor: chipBg,
                      showCheckmark: false,
                      labelStyle: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: selected ? Colors.white : subColor,
                      ),
                      side: BorderSide(
                        color: selected ? Colors.transparent : border,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (_visibleRequests.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(LucideIcons.receiptText,
                        size: 30, color: subColor.withValues(alpha: 0.45)),
                    const SizedBox(height: 8),
                    Text(
                      'No requests found',
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: subColor,
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: [
                  for (final request in _visibleRequests) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: _RequestCard(request: request),
                    ),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final _RedemptionRequest request;

  const _RequestCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface =
        isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white;
    final shadow = isDark
        ? Colors.black.withValues(alpha: 0.24)
        : Colors.black.withValues(alpha: 0.06);
    final border = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
    const titleColor = Color(0xFF111111);
    final subColor = Colors.black.withValues(alpha: 0.55);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: shadow,
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            height: 72,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: const Color(0xFFF3F4F6),
            ),
            child: Image.asset(
              request.assetPath,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(LucideIcons.image, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 72,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    request.amountLabel,
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: titleColor,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    request.dateLabel,
                    style: GoogleFonts.montserrat(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: subColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _StatusPill(status: request.status),
              if (request.status == 'Completed') ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pushNamed(
                    '/wallet/voucher-details',
                    arguments: {
                      'brandName': request.name,
                      'amountLabel': request.amountLabel,
                      'assetPath': request.assetPath,
                      'voucherCode':
                          request.voucherCode ?? 'FLIP-8742-2211-ABCD',
                      'pin': request.pin ?? '4589',
                      'expiryLabel': request.expiryLabel ?? '31 Dec 2026',
                      'redeemSteps': request.redeemSteps ??
                          <String>[
                            'Visit flipkart.com',
                            'Add products to cart and go to payment',
                            'Choose gift card / voucher option',
                            'Enter the voucher code and PIN to pay',
                          ],
                      'actionLabel': request.actionLabel ?? 'Go to Flipkart',
                      'actionUrl':
                          request.actionUrl ?? 'https://www.flipkart.com/',
                    },
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF3B82F6),
                    side:
                        const BorderSide(color: Color(0xFF93C5FD), width: 1.2),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'View Voucher',
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    late final Color bg;
    late final Color fg;

    switch (status) {
      case 'Completed':
        bg = const Color(0x1A22C55E);
        fg = const Color(0xFF16A34A);
        break;
      case 'Cancelled':
        bg = const Color(0x1A6B7280);
        fg = const Color(0xFF4B5563);
        break;
      default:
        bg = const Color(0x1AF59E0B);
        fg = const Color(0xFFEA580C);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status,
        style: GoogleFonts.montserrat(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
    final border = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.05);
    final iconColor = isDark ? Colors.white : const Color(0xFF111111);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
      ),
    );
  }
}

class _RedemptionRequest {
  final String name;
  final String amountLabel;
  final String dateLabel;
  final String status;
  final String assetPath;
  final String? voucherCode;
  final String? pin;
  final String? expiryLabel;
  final List<String>? redeemSteps;
  final String? actionLabel;
  final String? actionUrl;

  const _RedemptionRequest({
    required this.name,
    required this.amountLabel,
    required this.dateLabel,
    required this.status,
    required this.assetPath,
    this.voucherCode,
    this.pin,
    this.expiryLabel,
    this.redeemSteps,
    this.actionLabel,
    this.actionUrl,
  });
}
