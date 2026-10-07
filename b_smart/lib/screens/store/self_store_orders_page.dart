import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../utils/url_helper.dart';
import 'shared/store_shared_widgets.dart';
import 'store_models.dart';
import 'store_order_tracking_page.dart';
import 'store_theme.dart';

class SelfStoreOrdersPage extends StatefulWidget {
  final bool showHeader;

  const SelfStoreOrdersPage({
    super.key,
    this.showHeader = true,
  });

  @override
  State<SelfStoreOrdersPage> createState() => _SelfStoreOrdersPageState();
}


enum _OrderMode { buy, sell }

typedef _SelfOrder = StoreMockOrder;

class _SelfStoreOrdersPageState extends State<SelfStoreOrdersPage> {
  _OrderMode _orderMode = _OrderMode.buy;
  final Set<String> _advancingIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      StoreMockState.instance.refreshBuyerOrders();
      StoreMockState.instance.refreshSellerOrders();
    });
  }

  List<_SelfOrder> get _liveOrders =>
      StoreMockState.instance.sellerOrders.map(_mockFromApi).toList();

  List<_SelfOrder> get _buyerOrders =>
      StoreMockState.instance.buyerOrders.map(_mockFromApi).toList();

  static _SelfOrder _mockFromApi(Map<String, dynamic> m) {
    final id = StoreMockState.orderIdOf(m).isEmpty
        ? 'order'
        : StoreMockState.orderIdOf(m);
    final statusStr = StoreMockState.statusOf(m);
    final status = switch (statusStr) {
      'processing' => StoreMockOrderStatus.processing,
      'shipped' => StoreMockOrderStatus.shipped,
      'delivered' || 'completed' => StoreMockOrderStatus.completed,
      _ => StoreMockOrderStatus.newOrder,
    };
    final ship = m['shipping_address'];
    final customer = ship is Map
        ? (ship['name']?.toString() ?? 'Customer')
        : (m['buyer_name']?.toString() ?? 'Customer');
    final address = ship is Map
        ? [
            ship['name'],
            ship['address_line1'],
            '${ship['city'] ?? ''}, ${ship['state'] ?? ''} ${ship['pincode'] ?? ''}'
          ].where((e) => (e?.toString().trim().isNotEmpty ?? false)).join('\n')
        : '';
    final amount = StoreMockState.amountOf(m);
    final rawItems = m['items'];
    final lines = <StoreMockCartLine>[];
    if (rawItems is List) {
      for (final r in rawItems.whereType<Map>()) {
        final map = r.map((k, v) => MapEntry(k.toString(), v));
        final prod = map['product'] ??
            map['product_details'] ??
            map['productDetail'] ??
            map['item'] ??
            map['listing'];
        final pm =
            prod is Map ? prod.map((k, v) => MapEntry(k.toString(), v)) : map;
        final title = (pm['name'] ?? pm['title'] ?? 'Item').toString();
        final price = StoreMockState.amountOf(pm);
        final qty = (map['quantity'] is num)
            ? (map['quantity'] as num).toInt()
            : int.tryParse('${map['quantity'] ?? 1}') ?? 1;
        lines.add(StoreMockCartLine(
          item: StoreMockCatalogItem(
            id: (pm['id'] ?? pm['_id'] ?? title).toString(),
            type: StoreMockItemType.product,
            title: title,
            category: (pm['category'] ?? 'Product').toString(),
            description: '',
            imageUrl: _orderImageOf(pm, fallback: map),
            icon: LucideIcons.package,
            price: price,
            duration: '2-3 days',
            rating: 'New',
            reviews: '0',
            raw: Map<String, dynamic>.from(pm),
          ),
          quantity: qty.clamp(1, 99),
        ));
      }
    }
    return StoreMockOrder(
      id: id,
      customerName: customer,
      avatarColor: const Color(0xFFEAD8CC),
      status: status,
      lines: lines,
      paidAmount: amount,
      bCoinsSavings: 0,
      address: address.isEmpty ? customer : address,
    );
  }

  static String _orderImageOf(
    Map<String, dynamic> pm, {
    Map<String, dynamic>? fallback,
  }) {
    final primary = StoreMockState.firstImageUrl(pm);
    if (primary.isNotEmpty) return primary;

    final source = fallback;
    if (source == null) return '';
    for (final key in const [
      'product_image',
      'productImage',
      'item_image',
      'itemImage',
      'image_url',
      'imageUrl',
      'thumbnail',
      'cover_image',
      'coverImage',
    ]) {
      final value = source[key]?.toString().trim();
      if (value != null && value.isNotEmpty && value != 'null') {
        return UrlHelper.absoluteUrl(value);
      }
    }
    return StoreMockState.firstImageUrl(source);
  }

  @override
  Widget build(BuildContext context) {
    return _buildListPage();
  }

  /// One detail page for every order: the tracking detail. Buyer taps open
  /// it directly; seller taps add an advance-status action on top.
  void _openOrder(StoreMockOrder order) {
    final canAdvance = _orderMode == _OrderMode.sell &&
        order.status != StoreMockOrderStatus.completed;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StoreOrderTrackingDetailPage(
          order: TrackingOrder.fromStoreOrder(order),
          sellerAdvanceLabel:
              canAdvance ? _advanceLabelFor(order.status) : null,
          onSellerAdvance: canAdvance
              ? () => _advanceSellerOrder(order.id, order.status)
              : null,
        ),
      ),
    );
  }

  static String _advanceLabelFor(StoreMockOrderStatus status) {
    return switch (status) {
      StoreMockOrderStatus.newOrder => 'Start processing',
      StoreMockOrderStatus.processing => 'Mark as shipped',
      StoreMockOrderStatus.shipped => 'Mark as delivered',
      StoreMockOrderStatus.completed => 'Mark as delivered',
    };
  }

  Future<void> _advanceSellerOrder(
      String orderId, StoreMockOrderStatus status) async {
    if (_advancingIds.contains(orderId)) return;
    final next = switch (status) {
      StoreMockOrderStatus.newOrder => 'processing',
      StoreMockOrderStatus.processing => 'shipped',
      StoreMockOrderStatus.shipped => 'delivered',
      StoreMockOrderStatus.completed => 'delivered',
    };
    setState(() => _advancingIds.add(orderId));
    try {
      await StoreMockState.instance.advanceOrderStatus(orderId, next);
      await StoreMockState.instance.refreshSellerOrders();
      if (!mounted) return;
      Navigator.of(context).maybePop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order status updated.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status update failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _advancingIds.remove(orderId));
    }
  }

  Widget _buildListPage() {
    return AnimatedBuilder(
      animation: StoreMockState.instance,
      builder: (context, _) {
        final liveOrders =
            _orderMode == _OrderMode.sell ? _liveOrders : _buyerOrders;
        final loading = StoreMockState.instance.ordersLoading;
        final error = !loading && liveOrders.isEmpty
            ? StoreMockState.instance.lastError
            : null;
        return SliverList.list(
          children: [
            if (widget.showHeader)
              const _OrdersTopBar(title: 'Orders'),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
              child: Container(
                height: 40,
                decoration: storeSoftCardDecoration(radius: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: _OrderModeTab(
                        label: 'Buy',
                        selected: _orderMode == _OrderMode.buy,
                        onTap: () =>
                            setState(() => _orderMode = _OrderMode.buy),
                      ),
                    ),
                    Expanded(
                      child: _OrderModeTab(
                        label: 'Sell',
                        selected: _orderMode == _OrderMode.sell,
                        onTap: () =>
                            setState(() => _orderMode = _OrderMode.sell),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (loading)
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 16, 18, 0),
                child: LinearProgressIndicator(),
              ),
            const SizedBox(height: 8),
            for (final order in liveOrders)
              _OrderSummaryCard(
                order: order,
                isSeller: _orderMode == _OrderMode.sell,
                onViewOrder: () => _openOrder(order),
              ),
            if (liveOrders.isEmpty && !loading)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 24, 18, 0),
                child: StoreEmptyState(
                  icon: _orderMode == _OrderMode.buy
                      ? LucideIcons.shoppingBag
                      : LucideIcons.store,
                  title: 'No orders here',
                  body: _orderMode == _OrderMode.buy
                      ? 'Orders you place will appear here.'
                      : 'Orders for this status will appear here.',
                ),
              ),
            if (error != null && !loading)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                child: OutlinedButton.icon(
                  onPressed: () {
                    if (_orderMode == _OrderMode.buy) {
                      StoreMockState.instance.refreshBuyerOrders();
                    } else {
                      StoreMockState.instance.refreshSellerOrders();
                    }
                  },
                  icon: const Icon(LucideIcons.refreshCw, size: 16),
                  label: const Text('Retry'),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Plain status label for simple users (no ids, no jargon).
String _plainStatusLabel(StoreMockOrderStatus status) {
  return switch (status) {
    StoreMockOrderStatus.newOrder => 'New',
    StoreMockOrderStatus.processing => 'Processing',
    StoreMockOrderStatus.shipped => 'Shipped',
    StoreMockOrderStatus.completed => 'Delivered',
  };
}

class _OrdersTopBar extends StatelessWidget {
  final String title;

  const _OrdersTopBar({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        26,
        MediaQuery.of(context).padding.top + 6,
        18,
        0,
      ),
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFF060D35),
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _OrderModeTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _OrderModeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : BStoreColors.textSecondary;
    final bg = selected ? BStoreColors.primary : Colors.transparent;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  final StoreMockOrder order;
  final bool isSeller;
  final VoidCallback onViewOrder;

  const _OrderSummaryCard({
    required this.order,
    this.isSeller = false,
    required this.onViewOrder,
  });

  String get _title {
    if (order.lines.isEmpty) return 'Order';
    final first = order.lines.first.item.title;
    if (order.lines.length == 1) return first;
    return '$first + ${order.lines.length - 1} more';
  }

  String get _subtitle {
    final count =
        '${order.itemCount} ${order.itemCount == 1 ? 'item' : 'items'}';
    if (isSeller && order.customerName.trim().isNotEmpty) {
      return '${order.customerName} • $count';
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final firstLine = order.lines.isEmpty ? null : order.lines.first;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
      child: InkWell(
        onTap: onViewOrder,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: storeSoftCardDecoration(radius: 14),
          child: Row(
            children: [
              StoreProductThumb(
                imageUrl: firstLine?.item.imageUrl ?? '',
                icon: firstLine?.item.icon ?? LucideIcons.package,
                size: 56,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF060D35),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF596174),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _StatusPill(status: order.status),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    StoreMockState.instance.money(order.paidAmount),
                    style: const TextStyle(
                      color: Color(0xFF060D35),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Icon(
                    LucideIcons.chevronRight,
                    color: Color(0xFF596174),
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final StoreMockOrderStatus status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
            StoreMockOrderStatus.newOrder => (
                const Color(0xFFE9F6F5),
                const Color(0xFF078D92)
              ),
            StoreMockOrderStatus.processing => (
                const Color(0xFFFFF3E6),
                const Color(0xFFB26A00)
              ),
            StoreMockOrderStatus.shipped => (
                const Color(0xFFEAF3FF),
                const Color(0xFF2442B5)
              ),
            StoreMockOrderStatus.completed => (
                const Color(0xFFE9F8E6),
                const Color(0xFF047C58)
              ),
          };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _plainStatusLabel(status),
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Status hero: big pill + headline + item count.
