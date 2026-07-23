import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/api_exceptions.dart';
import '../api/gift_cards_api.dart';

class RedemptionRequestsScreen extends StatefulWidget {
  const RedemptionRequestsScreen({super.key});

  @override
  State<RedemptionRequestsScreen> createState() =>
      _RedemptionRequestsScreenState();
}

class _RedemptionRequestsScreenState extends State<RedemptionRequestsScreen> {
  final GiftCardsApi _giftCardsApi = GiftCardsApi();
  String _filter = 'All';
  bool _loading = true;
  String? _errorMessage;
  int _requestId = 0;
  List<_RedemptionRequest> _requests = <_RedemptionRequest>[];

  static const List<String> _filters = <String>[
    'All',
    'Pending',
    'Processing',
    'Completed',
    'Cancelled',
  ];

  static const List<_RedemptionRequest> _fallbackRequests =
      <_RedemptionRequest>[
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

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    final currentRequest = ++_requestId;
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    try {
      final orders = await _giftCardsApi.getMyGiftCardOrders(
        status: _filter,
      );
      final requests = orders
          .map((raw) => _RedemptionRequest.fromApi(raw))
          .toList(growable: false);

      if (!mounted || currentRequest != _requestId) return;
      setState(() {
        _requests = requests;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || currentRequest != _requestId) return;
      setState(() {
        _requests = _fallbackRequests;
        _loading = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted || currentRequest != _requestId) return;
      setState(() {
        _requests = _fallbackRequests;
        _loading = false;
        _errorMessage = 'Could not load redemption history.';
      });
    }
  }

  List<_RedemptionRequest> get _visibleRequests {
    if (_filter == 'All') return _requests;
    return _requests.where((request) => request.status == _filter).toList();
  }

  void _handleRequestTap(_RedemptionRequest request) {
    if (request.status == 'Pending') {
      _showActionSheet(
        title: 'Cancel this gift card',
        subtitle:
            'Slide to confirm cancellation. This will keep the order in your history.',
        actionLabel: 'Cancel Gift Card',
        accentColor: const Color(0xFFF97316),
        icon: LucideIcons.circleX,
        onConfirm: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('${request.name} cancellation is ready to connect.'),
              backgroundColor: const Color(0xFFF97316),
            ),
          );
        },
      );
      return;
    }

    if (request.status == 'Cancelled') {
      _showActionSheet(
        title: 'Delete this gift card',
        subtitle:
            'Slide to confirm deletion. This will remove the cancelled order from the list.',
        actionLabel: 'Delete Gift Card',
        accentColor: const Color(0xFFEF4444),
        icon: LucideIcons.trash2,
        onConfirm: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('${request.name} delete action is ready to connect.'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        },
      );
    }
  }

  void _showActionSheet({
    required String title,
    required String subtitle,
    required String actionLabel,
    required Color accentColor,
    required IconData icon,
    required VoidCallback onConfirm,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (sheetContext) {
        return _RequestActionSheet(
          title: title,
          subtitle: subtitle,
          actionLabel: actionLabel,
          accentColor: accentColor,
          icon: icon,
          onConfirm: onConfirm,
        );
      },
    );
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
        child: RefreshIndicator(
          onRefresh: _loadRequests,
          color: const Color(0xFFF97316),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                        onSelected: (_) {
                          if (_filter == label) return;
                          setState(() => _filter = label);
                          _loadRequests();
                        },
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
              if (_loading && _requests.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 52),
                  child: Center(
                    child: Column(
                      children: [
                        const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Color(0xFFF97316),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Loading redemption history...',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: subColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_visibleRequests.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(LucideIcons.receiptText,
                          size: 30, color: subColor.withValues(alpha: 0.45)),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage != null
                            ? 'Showing saved requests'
                            : 'No requests found',
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
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF7F1D1D),
                            ),
                          ),
                        ),
                      ),
                    if (_errorMessage != null) const SizedBox(height: 14),
                    for (final request in _visibleRequests) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: _RequestCard(
                          request: request,
                          onTap: request.status == 'Pending' ||
                                  request.status == 'Cancelled'
                              ? () => _handleRequestTap(request)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final _RedemptionRequest request;
  final VoidCallback? onTap;

  const _RequestCard({
    required this.request,
    this.onTap,
  });

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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
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
                child: request.imageUrl != null && request.imageUrl!.isNotEmpty
                    ? Image.network(
                        request.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _fallbackImage(),
                      )
                    : Image.asset(
                        request.assetPath,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _fallbackImage(),
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
                      if ((request.vendor ?? '').trim().isNotEmpty) ...[
                        Text(
                          request.vendor!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: subColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                      ],
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
                          'actionLabel':
                              request.actionLabel ?? 'Go to Flipkart',
                          'actionUrl':
                              request.actionUrl ?? 'https://www.flipkart.com/',
                        },
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF3B82F6),
                        side: const BorderSide(
                            color: Color(0xFF93C5FD), width: 1.2),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
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
        ),
      ),
    );
  }

  Widget _fallbackImage() {
    return const Center(
      child: Icon(LucideIcons.image, color: Colors.grey),
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
      case 'Processing':
        bg = const Color(0x1A3B82F6);
        fg = const Color(0xFF2563EB);
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

class _RequestActionSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final String actionLabel;
  final Color accentColor;
  final IconData icon;
  final VoidCallback onConfirm;

  const _RequestActionSheet({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.accentColor,
    required this.icon,
    required this.onConfirm,
  });

  @override
  State<_RequestActionSheet> createState() => _RequestActionSheetState();
}

class _RequestActionSheetState extends State<_RequestActionSheet> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF121212) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF111111);
    final subColor = isDark
        ? Colors.white.withValues(alpha: 0.66)
        : Colors.black.withValues(alpha: 0.58);

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Container(
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.16)
                      : Colors.black.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: widget.accentColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.icon,
                  size: 32,
                  color: widget.accentColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                  color: subColor,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Tap to confirm ${widget.actionLabel.toLowerCase()}',
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: subColor,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _confirmAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    widget.actionLabel,
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: subColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmAction() {
    Navigator.of(context).pop();
    widget.onConfirm();
  }
}

class _RedemptionRequest {
  final String? id;
  final String name;
  final String? vendor;
  final String amountLabel;
  final String dateLabel;
  final String status;
  final String assetPath;
  final String? imageUrl;
  final String? giftCardId;
  final String? voucherCode;
  final String? pin;
  final String? expiryLabel;
  final List<String>? redeemSteps;
  final String? actionLabel;
  final String? actionUrl;

  const _RedemptionRequest({
    this.id,
    required this.name,
    this.vendor,
    required this.amountLabel,
    required this.dateLabel,
    required this.status,
    required this.assetPath,
    this.imageUrl,
    this.giftCardId,
    this.voucherCode,
    this.pin,
    this.expiryLabel,
    this.redeemSteps,
    this.actionLabel,
    this.actionUrl,
  });

  factory _RedemptionRequest.fromApi(Map<String, dynamic> json) {
    final giftCard = _asMap(json['gift_card']) ??
        _asMap(json['giftCard']) ??
        _asMap(json['card']) ??
        _asMap(json['gift_card_details']) ??
        _asMap(json['giftCardDetails']);
    final source = giftCard ?? json;
    final media = _asMap(json['media']) ?? _asMap(source['media']);
    final name = _pickString(json, const [
          'title',
          'name',
          'brand_name',
          'brandName',
          'gift_card_name',
          'giftCardName',
        ]) ??
        'Gift Card';
    final vendor = _pickString(json, const [
          'vendor',
          'merchant',
          'brand',
        ]) ??
        _pickString(source, const ['vendor', 'merchant', 'brand']);
    final amountLabel = _resolveAmountLabel(json, source);
    final status = _formatStatus(
      _pickString(json, const ['status', 'state', 'order_status']) ?? 'pending',
    );
    final dateLabel = _formatDateLabel(
      _pickString(json, const [
            'created_at',
            'createdAt',
            'ordered_at',
            'orderedAt',
            'updated_at',
            'updatedAt',
            'createdAt',
            'updatedAt',
          ]) ??
          '',
    );
    final imageUrl = _mediaUrl(media) ??
        _mediaUrl(json['media']) ??
        _pickString(json, const ['image_url', 'imageUrl']);
    final assetPath = _assetPathForName(name, vendor: vendor);
    final giftCardId = _pickString(json, const [
      'gift_card_id',
      'giftCardId',
      'giftcard_id',
      'giftcardId',
    ]);
    final completedDetails = status == 'Completed'
        ? _completedVoucherDetails(json, source, name, assetPath)
        : const <String, dynamic>{};

    return _RedemptionRequest(
      id: _pickString(json, const ['id', '_id', 'order_id', 'orderId']),
      name: name,
      vendor: vendor,
      amountLabel: amountLabel,
      dateLabel: dateLabel,
      status: status,
      assetPath: assetPath,
      imageUrl: imageUrl,
      giftCardId: giftCardId,
      voucherCode: completedDetails['voucherCode'] as String?,
      pin: completedDetails['pin'] as String?,
      expiryLabel: completedDetails['expiryLabel'] as String?,
      redeemSteps: completedDetails['redeemSteps'] as List<String>?,
      actionLabel: completedDetails['actionLabel'] as String?,
      actionUrl: completedDetails['actionUrl'] as String?,
    );
  }
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

String? _pickString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return null;
}

double? _pickDouble(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is num) return value.toDouble();
    if (value is String) {
      final cleaned = value.replaceAll(RegExp(r'[^0-9.]'), '');
      final parsed = double.tryParse(cleaned);
      if (parsed != null) return parsed;
    }
  }
  return null;
}

String? _mediaUrl(dynamic media) {
  final map = _asMap(media);
  if (map == null) return null;
  return _pickString(map, const ['url', 'image_url', 'imageUrl']);
}

List<String>? _parseStringList(dynamic value) {
  if (value is! List) return null;
  final items = value
      .map((item) => item?.toString().trim())
      .whereType<String>()
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
  return items;
}

String _formatStatus(String raw) {
  final normalized = raw.trim().toLowerCase();
  switch (normalized) {
    case 'pending':
      return 'Pending';
    case 'processing':
      return 'Processing';
    case 'completed':
      return 'Completed';
    case 'cancelled':
    case 'canceled':
      return 'Cancelled';
    default:
      if (normalized.isEmpty) return 'Pending';
      return normalized[0].toUpperCase() + normalized.substring(1);
  }
}

String _resolveAmountLabel(
  Map<String, dynamic> order,
  Map<String, dynamic> source,
) {
  final coins = _pickDouble(order, const [
        'bcoins',
        'coins',
        'coin_amount',
        'coinAmount',
      ]) ??
      _pickDouble(source, const [
        'bcoins',
        'coins',
        'coin_amount',
        'coinAmount',
      ]);
  if (coins != null && coins > 0) {
    return '${_formatCoins(coins.round())} bCoins';
  }

  final rupees = _pickDouble(source, const [
    'amount',
    'value',
    'denomination',
    'price',
    'rupees',
  ]);
  if (rupees != null && rupees > 0) {
    return '₹${_formatCoins(rupees.round())}';
  }

  return 'Gift Card';
}

Map<String, dynamic> _completedVoucherDetails(
  Map<String, dynamic> order,
  Map<String, dynamic> source,
  String name,
  String assetPath,
) {
  final voucherCode = _pickString(order, const [
    'voucher_code',
    'voucherCode',
    'code',
  ]);
  final pin = _pickString(order, const ['pin', 'voucher_pin', 'voucherPin']);
  final expiryLabel = _pickString(order, const [
    'expiry_label',
    'expiryLabel',
    'expiry_date',
    'expiryDate',
    'expires_at',
    'expiresAt',
  ]);
  final redeemSteps = _parseStringList(order['redeem_steps']) ??
      _parseStringList(order['redeemSteps']) ??
      _parseStringList(source['redeem_steps']) ??
      _parseStringList(source['redeemSteps']);
  final actionUrl = _pickString(source, const [
    'action_url',
    'actionUrl',
    'redeem_url',
    'redeemUrl',
    'url',
  ]);
  final actionLabel = _pickString(source, const [
        'action_label',
        'actionLabel',
      ]) ??
      'View Voucher';

  return <String, dynamic>{
    'voucherCode': voucherCode,
    'pin': pin,
    'expiryLabel': expiryLabel,
    'redeemSteps': redeemSteps ??
        <String>[
          'Open the merchant app or website',
          'Add your products and proceed to checkout',
          'Choose voucher or gift card payment',
          'Enter the voucher code and PIN to pay',
        ],
    'actionLabel': actionLabel,
    'actionUrl': actionUrl ?? _defaultActionUrlForGiftCard(name),
    'assetPath': assetPath,
  };
}

String _formatDateLabel(String raw) {
  if (raw.trim().isEmpty) return 'Just now';
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  final local = parsed.toLocal();
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final amPm = local.hour >= 12 ? 'PM' : 'AM';
  return '${local.day} ${months[local.month - 1]} ${local.year}, '
      '${hour.toString().padLeft(2, '0')}:$minute $amPm';
}

String _assetPathForName(String name, {String? vendor}) {
  final key = '${name.trim()} ${vendor ?? ''}'.trim().toLowerCase();
  switch (key) {
    case 'amazon gift card':
    case 'amazon pay gift card':
    case 'amazon':
    case 'amazon amazon':
      return 'assets/giftcards/amazongiftcard.webp';
    case 'flipkart gift card':
    case 'flipkart':
    case 'flipkart flipkart':
      return 'assets/giftcards/flipkartgiftcard.avif';
    case 'myntra gift card':
    case 'myntra':
    case 'myntra myntra':
      return 'assets/giftcards/myntra.jpeg';
    case 'zomato gift card':
    case 'zomato':
    case 'zomato zomato':
      return 'assets/giftcards/zomatogiftcard.avif';
    case 'uber gift card':
    case 'uber':
    case 'uber uber':
      return 'assets/giftcards/ubergiftcard.png';
    case 'ajio gift card':
    case 'ajio':
    case 'ajio ajio':
      return 'assets/giftcards/ajiogiftcard.jpg';
    default:
      return '';
  }
}

String _defaultActionUrlForGiftCard(String name) {
  switch (name.trim().toLowerCase()) {
    case 'amazon gift card':
    case 'amazon pay gift card':
    case 'amazon':
      return 'https://www.amazon.in/';
    case 'flipkart gift card':
    case 'flipkart':
      return 'https://www.flipkart.com/';
    case 'myntra gift card':
    case 'myntra':
      return 'https://www.myntra.com/';
    case 'zomato gift card':
    case 'zomato':
      return 'https://www.zomato.com/';
    case 'uber gift card':
    case 'uber':
      return 'https://www.uber.com/';
    case 'ajio gift card':
    case 'ajio':
      return 'https://www.ajio.com/';
    default:
      return 'https://www.google.com/';
  }
}

String _formatCoins(int n) {
  final abs = n.abs();
  final str = abs.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < str.length; i++) {
    final indexFromEnd = str.length - i;
    buffer.write(str[i]);
    if (indexFromEnd > 1 && indexFromEnd % 3 == 1) {
      buffer.write(',');
    }
  }
  return buffer.toString();
}
