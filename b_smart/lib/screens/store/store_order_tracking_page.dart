import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/phase2_store_api.dart';
import '../../utils/url_helper.dart';
import 'shared/store_shared_widgets.dart';
import 'store_models.dart';
import 'store_theme.dart';

class StoreOrderTrackingListPage extends StatefulWidget {
  const StoreOrderTrackingListPage({super.key});

  @override
  State<StoreOrderTrackingListPage> createState() =>
      _StoreOrderTrackingListState();
}

class _StoreOrderTrackingListState extends State<StoreOrderTrackingListPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      StoreMockState.instance.refreshBuyerOrders();
      StoreMockState.instance.refreshBuyerBookings();
    });
  }

  Future<void> _retry() async {
    await Future.wait([
      StoreMockState.instance.refreshBuyerOrders(),
      StoreMockState.instance.refreshBuyerBookings(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: BStoreTheme.data(context),
      child: Scaffold(
        backgroundColor: BStoreColors.background,
        body: SafeArea(
          bottom: false,
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              14,
              8,
              14,
              MediaQuery.of(context).padding.bottom + 24,
            ),
            children: [
              const _StorePageHeader(title: 'Tracking Order'),
              const SizedBox(height: 12),
              AnimatedBuilder(
                animation: StoreMockState.instance,
                builder: (context, _) {
                  final visibleOrders = [
                    ...StoreMockState.instance.buyerOrders
                        .map(TrackingOrder.fromApiOrder),
                    ...StoreMockState.instance.buyerBookings
                        .map(TrackingOrder.fromApiBooking),
                  ];
                  final loading =
                      StoreMockState.instance.ordersLoading ||
                          StoreMockState.instance.bookingsLoading;
                  final error = !loading && visibleOrders.isEmpty
                      ? StoreMockState.instance.lastError
                      : null;
                  return Column(
                    children: [
                      if (loading) const LinearProgressIndicator(),
                      for (final order in visibleOrders) ...[
                        TrackingOrderCard(order: order),
                        const SizedBox(height: 10),
                      ],
                      if (visibleOrders.isEmpty && !loading)
                        Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: error == null
                              ? const StoreEmptyState(
                                  icon: LucideIcons.packageSearch,
                                  title: 'No orders yet',
                                  body:
                                      'Your product orders and service bookings will appear here.',
                                )
                              : StoreEmptyState(
                                  icon: LucideIcons.cloudOff,
                                  title: "Couldn't load orders",
                                  body: '$error',
                                ),
                        ),
                      if (error != null && !loading)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: OutlinedButton.icon(
                            onPressed: _retry,
                            icon: const Icon(
                                LucideIcons.refreshCw,
                                size: 16),
                            label: const Text('Retry'),
                          ),
                        ),
                    ],
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

class StoreOrderTrackingDetailPage extends StatefulWidget {
  final TrackingOrder order;

  /// Seller mode: shows an advance-status button instead of Cancel.
  final String? sellerAdvanceLabel;
  final Future<void> Function()? onSellerAdvance;

  const StoreOrderTrackingDetailPage({
    super.key,
    required this.order,
    this.sellerAdvanceLabel,
    this.onSellerAdvance,
  });

  @override
  State<StoreOrderTrackingDetailPage> createState() =>
      _StoreOrderTrackingDetailState();
}

class _StoreOrderTrackingDetailState
    extends State<StoreOrderTrackingDetailPage> {
  late TrackingOrder _order;
  bool _refreshing = false;
  final _scrollController = ScrollController();
  final _timelineKey = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTimeline() {
    final context = _timelineKey.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _refreshStatus();
  }

  /// Refetches the latest order/booking status by id (Phase 2 md:
  /// GET /api/orders/:id, GET /api/service-bookings/:id).
  Future<void> _refreshStatus() async {
    if (!_order.live || _refreshing) return;
    setState(() => _refreshing = true);
    try {
      final data = _order.isService
          ? await Phase2StoreApi().getServiceBooking(_order.id)
          : await Phase2StoreApi().getOrder(_order.id);
      if (!mounted || data.isEmpty) return;
      final status = StoreMockState.statusOf(data);
      if (status.isEmpty) return;
      setState(() {
        _order = TrackingOrder(
          id: _order.id,
          title: _order.title,
          status: status,
          eta: _order.isService
              ? (data['booking_date']?.toString() ?? _order.eta)
              : _order.eta,
          imageUrl: _order.imageUrl,
          currentStep: _order.isService
              ? TrackingOrder.stepForBookingStatus(status)
              : TrackingOrder.stepForOrderStatus(status),
          isService: _order.isService,
          live: true,
          rawStatus: status,
        );
      });
    } catch (_) {
      // Keep list data on failure.
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  bool get _cancellable =>
      _order.live &&
      ['pending', 'confirmed', 'processing'].contains(_order.rawStatus);

  Future<void> _cancel(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Cancel?'),
        content: Text(_order.isService
            ? 'Cancel booking #${_order.id}? Refund issued if already paid.'
            : 'Cancel order #${_order.id}? Items restocked, refund issued.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(d).pop(false),
              child: const Text('Keep')),
          FilledButton(
              onPressed: () => Navigator.of(d).pop(true),
              child: const Text('Cancel')),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    try {
      if (_order.isService) {
        await StoreMockState.instance.cancelBuyerBooking(_order.id);
      } else {
        await StoreMockState.instance.cancelBuyerOrder(_order.id);
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cancelled with refund where paid.')),
      );
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cancel failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: BStoreTheme.data(context),
      child: Scaffold(
        backgroundColor: BStoreColors.background,
        body: SafeArea(
          bottom: false,
          child: ListView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              14,
              8,
              14,
              MediaQuery.of(context).padding.bottom + 24,
            ),
            children: [
              _StorePageHeader(
                title: 'Order Details',
                refreshing: _refreshing,
                onRefresh: () => _refreshStatus(),
              ),
              const SizedBox(height: 10),
              _ArrivalCard(order: _order),
              const SizedBox(height: 10),
              _OrderInfoCard(order: _order),
              const SizedBox(height: 10),
              Container(
                key: _timelineKey,
                child: _TimelineCard(order: _order),
              ),
              if (_order.lines.isNotEmpty) ...[
                const SizedBox(height: 10),
                _DetailItemsCard(order: _order),
              ],
              if (_order.address.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                _DetailAddressCard(address: _order.address),
              ],
              const SizedBox(height: 10),
              _StatusNoteCard(order: _order),
              if (widget.sellerAdvanceLabel != null &&
                  widget.onSellerAdvance != null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: () => widget.onSellerAdvance!(),
                    style: FilledButton.styleFrom(
                      backgroundColor: BStoreColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      widget.sellerAdvanceLabel!,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ] else if (_cancellable) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: _scrollToTimeline,
                            icon: const Icon(LucideIcons.truck, size: 19),
                            label: const Text('Track Order'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: BStoreColors.primary,
                              side: const BorderSide(
                                  color: BStoreColors.primary),
                              textStyle: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w900,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            onPressed: () => _cancel(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              textStyle: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w900,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(_order.isService
                                ? 'Cancel booking'
                                : 'Cancel order'),
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
      ),
    );
  }
}

class TrackingLine {
  final String title;
  final String imageUrl;
  final int quantity;
  final double price;

  const TrackingLine({
    required this.title,
    required this.imageUrl,
    required this.quantity,
    required this.price,
  });
}

class TrackingOrder {
  final String id;
  final String title;
  final String status;
  final String eta;
  final String imageUrl;
  final int currentStep;
  final bool isService;
  final bool live;
  final String rawStatus;
  final List<TrackingLine> lines;
  final double amount;
  final String address;

  const TrackingOrder({
    required this.id,
    required this.title,
    required this.status,
    required this.eta,
    required this.imageUrl,
    required this.currentStep,
    required this.isService,
    this.live = false,
    this.rawStatus = '',
    this.lines = const [],
    this.amount = 0,
    this.address = '',
  });

  static int stepForOrderStatus(String s) => _stepForOrderStatus(s);

  static int stepForBookingStatus(String s) => _stepForBookingStatus(s);

  /// Human-readable status, never raw snake_case.
  static String prettyStatus(String s) {
    final cleaned = s.trim().replaceAll('_', ' ');
    if (cleaned.isEmpty) return 'Confirmed';
    return cleaned
        .split(RegExp(r'\s+'))
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  /// Pill color per state (Flipkart-style: green delivered, amber waiting).
  static Color colorForStatus(String s) {
    final v = s.trim().toLowerCase();
    if (v.contains('cancel') ||
        v.contains('fail') ||
        v.contains('refund') ||
        v.contains('reject')) {
      return const Color(0xFFB3261E);
    }
    if (v.contains('deliver') || v.contains('complet')) {
      return const Color(0xFF388E3C);
    }
    if (v.contains('ship') || v.contains('progress') || v.contains('assign')) {
      return const Color(0xFF1D4ED8);
    }
    if (v.contains('pend') ||
        v.contains('confirm') ||
        v.contains('process') ||
        v.contains('schedul')) {
      return const Color(0xFFB7791F);
    }
    return BStoreColors.primary;
  }

  /// Secondary meta line: never the raw 'Live order' placeholder.
  String get metaLine {
    final idPart = '#$id';
    if (isService && eta.trim().isNotEmpty && eta.trim() != 'Scheduled') {
      return '$idPart  \u2022  $eta';
    }
    return idPart;
  }

  static int _stepForOrderStatus(String s) {
    return switch (s) {
      'processing' => 1,
      'shipped' => 2,
      'delivered' || 'completed' => 3,
      _ => 0,
    };
  }

  static int _stepForBookingStatus(String s) {
    return switch (s) {
      'in_progress' => 2,
      'completed' => 3,
      'confirmed' => 1,
      _ => 0,
    };
  }

  factory TrackingOrder.fromApiOrder(Map<String, dynamic> m) {
    final id = StoreMockState.orderIdOf(m);
    final status = StoreMockState.statusOf(m);
    final items = m['items'];
    String title = 'Store order';
    String imageUrl = '';
    final lines = <TrackingLine>[];
    if (items is List && items.isNotEmpty) {
      for (final entry in items.whereType<Map>()) {
        final fm = entry.map((k, v) => MapEntry(k.toString(), v));
        final prod = fm['product'] ??
            fm['product_details'] ??
            fm['item'] ??
            fm['listing'];
        final pm = prod is Map
            ? prod.map((k, v) => MapEntry(k.toString(), v))
            : fm;
        final lineTitle =
            (pm['name'] ?? pm['title'] ?? 'Item').toString();
        final qty = (fm['quantity'] is num)
            ? (fm['quantity'] as num).toInt()
            : int.tryParse('${fm['quantity'] ?? 1}') ?? 1;
        lines.add(TrackingLine(
          title: lineTitle,
          imageUrl: _imageOf(pm),
          quantity: qty.clamp(1, 99),
          price: StoreMockState.amountOf(pm),
        ));
      }
      title = lines.first.title;
      if (lines.length > 1) title = '$title + ${lines.length - 1} more';
      imageUrl = lines.first.imageUrl;
    }
    return TrackingOrder(
      id: id.isEmpty ? 'order' : id,
      title: title,
      status: status.isEmpty ? 'Order confirmed' : status,
      eta: 'Live order',
      imageUrl: imageUrl,
      currentStep: _stepForOrderStatus(status),
      isService: false,
      live: true,
      rawStatus: status,
      lines: lines,
      amount: StoreMockState.amountOf(m),
      address: _addressOf(m),
    );
  }

  /// Builds a tracking view from a store order (cart checkout,
  /// manager list, success page) so every entry point lands on the
  /// tracking page of THAT particular order.
  factory TrackingOrder.fromStoreOrder(StoreMockOrder order) {
    final lines = order.lines;
    final title = lines.isEmpty
        ? 'Order'
        : lines.length == 1
            ? lines.first.item.title
            : '${lines.first.item.title} + ${lines.length - 1} more';
    final raw = switch (order.status) {
      StoreMockOrderStatus.newOrder => 'pending',
      StoreMockOrderStatus.processing => 'processing',
      StoreMockOrderStatus.shipped => 'shipped',
      StoreMockOrderStatus.completed => 'delivered',
    };
    final step = switch (order.status) {
      StoreMockOrderStatus.newOrder => 0,
      StoreMockOrderStatus.processing => 1,
      StoreMockOrderStatus.shipped => 2,
      StoreMockOrderStatus.completed => 3,
    };
    return TrackingOrder(
      id: order.id,
      title: title,
      status: raw,
      eta: 'Live order',
      imageUrl: lines.isEmpty ? '' : lines.first.item.imageUrl,
      currentStep: step,
      isService: false,
      live: true,
      rawStatus: raw,
      lines: [
        for (final line in lines)
          TrackingLine(
            title: line.item.title,
            imageUrl: line.item.imageUrl,
            quantity: line.quantity,
            price: line.item.price,
          ),
      ],
      amount: order.paidAmount,
      address: order.address,
    );
  }

  static String _addressOf(Map<String, dynamic> m) {
    final ship = m['shipping_address'] ?? m['customer_address'];
    if (ship is Map) {
      final parts = [
        ship['name'],
        ship['address_line1'] ?? ship['address'],
        [
          ship['city'],
          ship['state'],
          ship['pincode'] ?? ship['zip']
        ]
            .where((e) =>
                e?.toString().trim().isNotEmpty ?? false)
            .join(', '),
      ]
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
      return parts.join('\n');
    }
    return '';
  }

  factory TrackingOrder.fromApiBooking(Map<String, dynamic> m) {
    final id = StoreMockState.bookingIdOf(m);
    final status = StoreMockState.statusOf(m);
    final svc = m['service'];
    final sm = svc is Map
        ? svc.map((k, v) => MapEntry(k.toString(), v))
        : m;
    final bookingTitle =
        (sm['name'] ?? sm['title'] ?? 'Service booking').toString();
    return TrackingOrder(
      id: id.isEmpty ? 'booking' : id,
      title: bookingTitle,
      status: status.isEmpty ? 'Request confirmed' : status,
      eta: (m['booking_date'] ?? 'Scheduled').toString(),
      imageUrl: _imageOf(sm),
      currentStep: _stepForBookingStatus(status),
      isService: true,
      live: true,
      rawStatus: status,
      lines: [
        TrackingLine(
          title: bookingTitle,
          imageUrl: _imageOf(sm),
          quantity: 1,
          price: StoreMockState.amountOf(sm),
        ),
      ],
      amount: StoreMockState.amountOf(m),
      address: _addressOf(m),
    );
  }

  static String _imageOf(Map<String, dynamic> json) {
    String resolve(dynamic value) {
      if (value is Map) {
        final map = value.map((k, v) => MapEntry(k.toString(), v));
        for (final key in [
          'fileUrl',
          'file_url',
          'secure_url',
          'download_url',
          'url',
          'src',
          'image_url',
          'imageUrl',
          'image',
          'cover',
          'thumbnail',
          'path',
          'fileName',
          'filename',
        ]) {
          final candidate = map[key]?.toString().trim() ?? '';
          if (candidate.isNotEmpty) {
            return UrlHelper.absoluteUrl(candidate);
          }
        }
        return '';
      }
      final text = value?.toString().trim() ?? '';
      return text.isEmpty ? '' : UrlHelper.absoluteUrl(text);
    }

    for (final key in [
      'images',
      'image_urls',
      'imageUrls',
      'media',
      'photos',
      'gallery',
    ]) {
      final value = json[key];
      if (value is List) {
        for (final entry in value) {
          final resolved = resolve(entry);
          if (resolved.isNotEmpty) return resolved;
        }
      }
    }
    for (final key in [
      'image_url',
      'imageUrl',
      'image',
      'cover',
      'thumbnail',
      'url',
      'src',
      'path',
    ]) {
      final resolved = resolve(json[key]);
      if (resolved.isNotEmpty) return resolved;
    }
    return '';
  }
}

/// Compact Flipkart-style bar: back + left-aligned title, no wordmark.
class _StorePageHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onRefresh;
  final bool refreshing;

  const _StorePageHeader({
    required this.title,
    this.onRefresh,
    this.refreshing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(LucideIcons.arrowLeft, size: 25),
            color: BStoreColors.textPrimary,
            padding: EdgeInsets.zero,
            constraints:
                const BoxConstraints.tightFor(width: 40, height: 40),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: BStoreColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (onRefresh != null)
            IconButton(
              onPressed: refreshing ? null : onRefresh,
              icon: refreshing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : const Icon(LucideIcons.refreshCw, size: 20),
              color: BStoreColors.textPrimary,
              tooltip: 'Refresh status',
            ),
        ],
      ),
    );
  }
}

class TrackingOrderCard extends StatelessWidget {
  final TrackingOrder order;

  const TrackingOrderCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => StoreOrderTrackingDetailPage(order: order),
          ),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BStoreDecorations.card(radius: 14),
        child: Row(
          children: [
            StoreItemImage(
              imageUrl: order.imageUrl,
              icon: order.isService
                  ? LucideIcons.briefcaseBusiness
                  : LucideIcons.package,
              width: 52,
              height: 52,
              borderRadius: 10,
              debugLabel: 'store-tracking-order',
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: BStoreColors.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: TrackingOrder.colorForStatus(
                                  order.rawStatus)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          TrackingOrder.prettyStatus(
                              order.rawStatus.isEmpty
                                  ? order.status
                                  : order.rawStatus),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: TrackingOrder.colorForStatus(
                                order.rawStatus),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    order.metaLine,
                    maxLines: 1,
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
            const SizedBox(width: 8),
            const Icon(
              LucideIcons.chevronRight,
              color: BStoreColors.textPrimary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

/// Status hero: item thumb + colored status pill + title + order meta.
class _ArrivalCard extends StatelessWidget {
  final TrackingOrder order;

  const _ArrivalCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final statusColor =
        TrackingOrder.colorForStatus(order.rawStatus);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BStoreDecorations.card(radius: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StoreItemImage(
            imageUrl: order.imageUrl,
            icon: order.isService
                ? LucideIcons.briefcaseBusiness
                : LucideIcons.package,
            width: 64,
            height: 64,
            borderRadius: 12,
            debugLabel: 'store-tracking-hero',
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    TrackingOrder.prettyStatus(
                        order.rawStatus.isEmpty
                            ? order.status
                            : order.rawStatus),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  order.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: BStoreColors.textPrimary,
                    fontSize: 16,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  order.metaLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: BStoreColors.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
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

/// Real order facts only: ID (tap to copy), type, schedule.
class _OrderInfoCard extends StatelessWidget {
  final TrackingOrder order;

  const _OrderInfoCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BStoreDecorations.card(radius: 16),
      child: Column(
        children: [
          _InfoRow(
            icon: LucideIcons.receiptText,
            label: 'Order ID',
            value: '#${order.id}',
            actionIcon: LucideIcons.copy,
            onAction: () {
              Clipboard.setData(ClipboardData(text: order.id));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Order ID copied')),
              );
            },
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: order.isService
                ? LucideIcons.briefcaseBusiness
                : LucideIcons.package,
            label: 'Order type',
            value: order.isService ? 'Service booking' : 'Product order',
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: LucideIcons.calendarDays,
            label: order.isService ? 'Scheduled' : 'Delivery',
            value: order.isService
                ? (order.eta.trim().isEmpty ? 'To be scheduled' : order.eta)
                : (order.eta.trim().isEmpty || order.eta.trim() == 'Live order'
                    ? 'Tracking live'
                    : order.eta),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.actionIcon,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            color: BStoreColors.primarySoft,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: BStoreColors.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  color: BStoreColors.textMuted,
                  fontSize: 10,
                  letterSpacing: 0.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: BStoreColors.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        if (actionIcon != null)
          IconButton(
            onPressed: onAction,
            icon: Icon(actionIcon, size: 18),
            color: BStoreColors.primary,
            tooltip: 'Copy',
          ),
      ],
    );
  }
}

class _TimelineCard extends StatelessWidget {
  final TrackingOrder order;

  const _TimelineCard({required this.order});

  static const _steps = [
    'Order confirmed',
    'Packed',
    'Out for delivery',
    'Delivered',
  ];

  static const _serviceSteps = [
    'Request confirmed',
    'Provider assigned',
    'Service scheduled',
    'Completed',
  ];

  @override
  Widget build(BuildContext context) {
    final steps = order.isService ? _serviceSteps : _steps;
    // Honest labels only: the backend exposes no per-step timestamps,
    // so finished steps say Done instead of invented clock times.
    final liveLabel = TrackingOrder.prettyStatus(
        order.rawStatus.isEmpty ? order.status : order.rawStatus);
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
      decoration: BStoreDecorations.card(radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              text: 'Order ',
              children: [
                TextSpan(
                  text: '#${order.id}',
                  style: const TextStyle(color: BStoreColors.accentPurple),
                ),
              ],
            ),
            style: const TextStyle(
              color: BStoreColors.textPrimary,
              fontSize: 15.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 13),
          for (var i = 0; i < steps.length; i++)
            _TimelineStep(
              title: steps[i],
              time: i < order.currentStep
                  ? 'Done'
                  : i == order.currentStep
                      ? liveLabel
                      : 'Pending',
              isComplete: i < order.currentStep,
              isCurrent: i == order.currentStep,
              showLine: i != steps.length - 1,
            ),
        ],
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  final String title;
  final String time;
  final bool isComplete;
  final bool isCurrent;
  final bool showLine;

  const _TimelineStep({
    required this.title,
    required this.time,
    required this.isComplete,
    required this.isCurrent,
    required this.showLine,
  });

  @override
  Widget build(BuildContext context) {
    final active = isComplete || isCurrent;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 21,
                  height: 21,
                  decoration: BoxDecoration(
                    color: isComplete ? BStoreColors.primary : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: active ? BStoreColors.primary : Colors.black12,
                      width: isCurrent ? 4 : 2,
                    ),
                  ),
                  child: isComplete
                      ? const Icon(
                          LucideIcons.check,
                          color: Colors.white,
                          size: 13,
                        )
                      : null,
                ),
                if (showLine)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: active ? BStoreColors.primary : Colors.black12,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: BStoreColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    time,
                    style: const TextStyle(
                      color: BStoreColors.textSecondary,
                      fontSize: 11.8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Items in this order with quantities and line totals.
class _DetailItemsCard extends StatelessWidget {
  final TrackingOrder order;

  const _DetailItemsCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final money = StoreMockState.instance.money;
    var computed = 0.0;
    for (final line in order.lines) {
      computed += line.price * line.quantity;
    }
    final total = order.amount > 0 ? order.amount : computed;
    var count = 0;
    for (final line in order.lines) {
      count += line.quantity;
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: BStoreDecorations.card(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$count item${count == 1 ? '' : 's'} in this order',
            style: const TextStyle(
              color: BStoreColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          for (final line in order.lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StoreItemImage(
                    imageUrl: line.imageUrl,
                    icon: order.isService
                        ? LucideIcons.briefcaseBusiness
                        : LucideIcons.package,
                    width: 56,
                    height: 56,
                    borderRadius: 10,
                    debugLabel: 'store-tracking-line',
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          line.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: BStoreColors.textPrimary,
                            fontSize: 13.5,
                            height: 1.25,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F2F6),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Qty: ${line.quantity}',
                            style: const TextStyle(
                              color: BStoreColors.textPrimary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    money(line.price * line.quantity),
                    style: const TextStyle(
                      color: BStoreColors.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          if (total > 0) ...[
            const Divider(height: 1, color: Color(0xFFE9ECEF)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Order total',
                      style: TextStyle(
                        color: BStoreColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    money(total),
                    style: const TextStyle(
                      color: BStoreColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailAddressCard extends StatelessWidget {
  final String address;

  const _DetailAddressCard({required this.address});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BStoreDecorations.card(radius: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: BStoreColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.mapPin,
                color: BStoreColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DELIVERY ADDRESS',
                  style: TextStyle(
                    color: BStoreColors.textMuted,
                    fontSize: 10,
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  address,
                  style: const TextStyle(
                    color: BStoreColors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
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

/// Honest status note: the backend exposes no courier assignment, so we
/// show payment/fulfilment state instead of inventing a courier.
class _StatusNoteCard extends StatelessWidget {
  final TrackingOrder order;

  const _StatusNoteCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final note = order.isService
        ? 'The provider confirms each step. You will be notified on every update.'
        : 'The seller advances each step. Stock and refunds are handled automatically on cancel.';
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
      decoration: BStoreDecorations.card(radius: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            LucideIcons.info,
            color: BStoreColors.primary,
            size: 20,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order #${order.id}',
                  style: const TextStyle(
                    color: BStoreColors.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  note,
                  style: const TextStyle(
                    color: BStoreColors.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
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

