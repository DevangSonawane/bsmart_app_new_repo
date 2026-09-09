import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'shared/store_shared_widgets.dart';
import 'store_models.dart';

class SelfStoreOrdersPage extends StatefulWidget {
  const SelfStoreOrdersPage({super.key});

  @override
  State<SelfStoreOrdersPage> createState() => _SelfStoreOrdersPageState();
}

enum _OrderManagerPage { list, details, fulfill }

typedef _SelfOrderStatus = StoreMockOrderStatus;
typedef _SelfOrder = StoreMockOrder;
typedef _SelfOrderProduct = StoreMockCartLine;

class _SelfStoreOrdersPageState extends State<SelfStoreOrdersPage> {
  _OrderManagerPage _page = _OrderManagerPage.list;
  _SelfOrderStatus _selectedStatus = StoreMockOrderStatus.newOrder;
  _SelfOrder _selectedOrder = StoreMockState.instance.orders.first;

  @override
  Widget build(BuildContext context) {
    return switch (_page) {
      _OrderManagerPage.list => _buildListPage(),
      _OrderManagerPage.details => _buildDetailsPage(),
      _OrderManagerPage.fulfill => _buildFulfillPage(),
    };
  }

  Widget _buildListPage() {
    final filteredOrders = StoreMockState.instance.orders
        .where((order) => order.status == _selectedStatus)
        .toList();
    return SliverList.list(
      children: [
        const _OrdersTopBar(showBack: false, title: 'Orders'),
        _OrderStatusTabs(
          selectedStatus: _selectedStatus,
          onSelected: (status) => setState(() => _selectedStatus = status),
        ),
        const SizedBox(height: 8),
        for (final order in filteredOrders)
          _OrderSummaryCard(
            order: order,
            onViewOrder: () => setState(() {
              _selectedOrder = order;
              _page = _OrderManagerPage.details;
            }),
          ),
        if (filteredOrders.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 24, 18, 0),
            child: StoreEmptyState(
              icon: LucideIcons.shoppingBag,
              title: 'No orders here',
              body: 'Orders for this status will appear here.',
            ),
          ),
      ],
    );
  }

  Widget _buildDetailsPage() {
    return SliverList.list(
      children: [
        _OrdersTopBar(
          showBack: true,
          title: 'Order details',
          subtitle: 'Order #${_selectedOrder.id}',
          onBack: () => setState(() => _page = _OrderManagerPage.list),
        ),
        _OrderDetailsCard(order: _selectedOrder),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
          child: _TealActionButton(
            label: 'Start processing',
            onTap: () => setState(() => _page = _OrderManagerPage.fulfill),
          ),
        ),
      ],
    );
  }

  Widget _buildFulfillPage() {
    return SliverList.list(
      children: [
        _OrdersTopBar(
          showBack: true,
          title: 'Fulfill order',
          subtitle: 'Order #${_selectedOrder.id}',
          onBack: () => setState(() => _page = _OrderManagerPage.details),
        ),
        const _FulfillOrderCard(),
        const _NotifyCustomerCard(),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
          child: _TealActionButton(
            label: 'Mark as shipped',
            onTap: () => setState(() => _page = _OrderManagerPage.list),
          ),
        ),
      ],
    );
  }
}

class _OrdersTopBar extends StatelessWidget {
  final bool showBack;
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;

  const _OrdersTopBar({
    required this.showBack,
    required this.title,
    this.subtitle,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        MediaQuery.of(context).padding.top + 14,
        18,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 34,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: showBack
                      ? IconButton(
                          onPressed: onBack,
                          icon: const Icon(LucideIcons.arrowLeft, size: 20),
                          tooltip: 'Back',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 34,
                            height: 34,
                          ),
                        )
                      : const StoreBsmartWordmark(),
                ),
                if (showBack) const StoreBsmartWordmark(),
                if (!showBack)
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.search,
                          color: Color(0xFF060D35),
                          size: 20,
                        ),
                        SizedBox(width: 18),
                        Icon(
                          LucideIcons.bell,
                          color: Color(0xFF060D35),
                          size: 20,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF060D35),
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 5),
            StoreOrderNumberText(text: subtitle!),
          ],
        ],
      ),
    );
  }
}

class _OrderStatusTabs extends StatelessWidget {
  final _SelfOrderStatus selectedStatus;
  final ValueChanged<_SelfOrderStatus> onSelected;

  const _OrderStatusTabs({
    required this.selectedStatus,
    required this.onSelected,
  });

  static const _tabs = [
    (StoreMockOrderStatus.newOrder, 'New'),
    (StoreMockOrderStatus.processing, 'Processing'),
    (StoreMockOrderStatus.shipped, 'Shipped'),
    (StoreMockOrderStatus.completed, 'Completed'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
      child: Row(
        children: [
          for (final tab in _tabs)
            Expanded(
              child: _OrderStatusTab(
                label: tab.$2,
                selected: selectedStatus == tab.$1,
                onTap: () => onSelected(tab.$1),
              ),
            ),
        ],
      ),
    );
  }
}

class _OrderStatusTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _OrderStatusTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: selected ? null : onTap,
      child: SizedBox(
        height: 34,
        child: Column(
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected
                    ? const Color(0xFF078D92)
                    : const Color(0xFF060D35),
                fontSize: 11,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
            const Spacer(),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: 2,
              width: selected ? 42 : 0,
              decoration: BoxDecoration(
                color: const Color(0xFF078D92),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  final _SelfOrder order;
  final VoidCallback onViewOrder;

  const _OrderSummaryCard({
    required this.order,
    required this.onViewOrder,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: storeSoftCardDecoration(radius: 14),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CustomerAvatar(order: order, size: 58),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StoreOrderNumberText(text: 'Order #${order.id}'),
                      const SizedBox(height: 5),
                      Text(
                        order.customerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF060D35),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${order.itemCount} ${order.itemCount == 1 ? 'item' : 'items'}',
                        style: const TextStyle(
                          color: Color(0xFF29304D),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
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
                    const _PaidPill(),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 58,
              child: Row(
                children: [
                  const SizedBox(width: 72),
                  for (final line in order.lines.take(3)) ...[
                    StoreProductThumb(asset: line.item.imageAsset, size: 58),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onViewOrder,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF078D92),
                side: const BorderSide(color: Color(0xFFD5DEE4)),
                fixedSize: const Size.fromHeight(38),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'View order',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(width: 80),
                  Icon(LucideIcons.chevronRight, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderDetailsCard extends StatelessWidget {
  final _SelfOrder order;

  const _OrderDetailsCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
      child: Container(
        decoration: storeSoftCardDecoration(radius: 14),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  _CustomerAvatar(order: order, size: 58),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.customerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF060D35),
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          '${order.itemCount} ${order.itemCount == 1 ? 'item' : 'items'}',
                          style: const TextStyle(
                            color: Color(0xFF29304D),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        StoreMockState.instance.money(order.paidAmount),
                        style: const TextStyle(
                          color: Color(0xFF060D35),
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 9),
                      const _PaidPill(),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE9ECEF)),
            for (final line in order.lines) _OrderProductRow(product: line),
            const Divider(height: 1, color: Color(0xFFE9ECEF)),
            _InfoRow(
              icon: LucideIcons.mapPin,
              label: 'Delivery address',
              value: order.address,
            ),
            const Divider(height: 1, color: Color(0xFFE9ECEF)),
            _MoneyRow(
              icon: LucideIcons.creditCard,
              label: 'Payment received',
              value: StoreMockState.instance.money(order.paidAmount),
            ),
            const Divider(height: 1, color: Color(0xFFE9ECEF)),
            _MoneyRow(
              icon: LucideIcons.badgePercent,
              label: 'bCoins discount',
              value: '-${StoreMockState.instance.money(order.bCoinsSavings)}',
              valueColor: const Color(0xFF684AC8),
            ),
            const Divider(height: 1, color: Color(0xFFE9ECEF)),
            _MoneyRow(
              icon: LucideIcons.circleDollarSign,
              label: 'Your earnings',
              value: StoreMockState.instance
                  .money(order.paidAmount - order.bCoinsSavings),
              valueColor: const Color(0xFF078D92),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderProductRow extends StatelessWidget {
  final _SelfOrderProduct product;

  const _OrderProductRow({required this.product});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          StoreProductThumb(asset: product.item.imageAsset, size: 74),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              product.item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF060D35),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                StoreMockState.instance.money(product.item.price),
                style: const TextStyle(
                  color: Color(0xFF060D35),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Qty: ${product.quantity}',
                style: const TextStyle(
                  color: Color(0xFF29304D),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
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

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF060D35), size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF060D35),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF29304D),
                fontSize: 11,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _MoneyRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: valueColor ?? const Color(0xFF060D35), size: 18),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: valueColor ?? const Color(0xFF060D35),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? const Color(0xFF060D35),
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _FulfillOrderCard extends StatelessWidget {
  const _FulfillOrderCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
      child: Container(
        decoration: storeSoftCardDecoration(radius: 14),
        child: const Column(
          children: [
            _FulfillStepRow(
              step: '',
              title: 'Confirm items',
              subtitle: '2 of 2 items confirmed',
              complete: true,
              expanded: false,
            ),
            Divider(height: 1, color: Color(0xFFE9ECEF)),
            _FulfillStepRow(
              step: '',
              title: 'Pack order',
              subtitle: 'Order packed and ready',
              complete: true,
              expanded: false,
            ),
            Divider(height: 1, color: Color(0xFFE9ECEF)),
            _FulfillStepRow(
              step: '3',
              title: 'Courier',
              subtitle: '',
              complete: false,
              expanded: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _FulfillStepRow extends StatelessWidget {
  final String step;
  final String title;
  final String subtitle;
  final bool complete;
  final bool expanded;

  const _FulfillStepRow({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.complete,
    required this.expanded,
  });

  @override
  Widget build(BuildContext context) {
    final color = complete ? const Color(0xFF078D92) : const Color(0xFF0A9296);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: complete
                ? const Icon(LucideIcons.check, color: Colors.white, size: 19)
                : Text(
                    step,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF060D35),
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (!expanded)
                      const Icon(
                        LucideIcons.chevronDown,
                        color: Color(0xFF060D35),
                        size: 18,
                      ),
                  ],
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF29304D),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (expanded) ...[
                  const SizedBox(height: 18),
                  const _FulfillField(
                    label: 'Courier',
                    value: 'Select courier',
                    hasChevron: true,
                  ),
                  const SizedBox(height: 14),
                  const _FulfillField(
                    label: 'Tracking number',
                    value: 'Enter tracking number',
                    hasChevron: false,
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

class _FulfillField extends StatelessWidget {
  final String label;
  final String value;
  final bool hasChevron;

  const _FulfillField({
    required this.label,
    required this.value,
    required this.hasChevron,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF060D35),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 7),
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: const Color(0xFFD1D9E0)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF29304D),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (hasChevron)
                const Icon(
                  LucideIcons.chevronDown,
                  color: Color(0xFF29304D),
                  size: 18,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NotifyCustomerCard extends StatelessWidget {
  const _NotifyCustomerCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: storeSoftCardDecoration(radius: 14),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: Color(0xFFF0F1F3),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Text(
                '4',
                style: TextStyle(
                  color: Color(0xFF29304D),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notify customer',
                    style: TextStyle(
                      color: Color(0xFF060D35),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Send shipping confirmation',
                    style: TextStyle(
                      color: Color(0xFF29304D),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: true,
              activeThumbColor: const Color(0xFF078D92),
              onChanged: (_) {},
            ),
          ],
        ),
      ),
    );
  }
}

class _TealActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TealActionButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF078D92),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _PaidPill extends StatelessWidget {
  const _PaidPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFE9F8E6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'Paid',
        style: TextStyle(
          color: Color(0xFF047C58),
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _CustomerAvatar extends StatelessWidget {
  final _SelfOrder order;
  final double size;

  const _CustomerAvatar({
    required this.order,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: order.avatarColor,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        order.customerInitials,
        style: const TextStyle(
          color: Color(0xFF060D35),
          fontSize: 15,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
