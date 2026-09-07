import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'shared/store_shared_widgets.dart';

class SelfStoreServicePage extends StatefulWidget {
  const SelfStoreServicePage({super.key});

  @override
  State<SelfStoreServicePage> createState() => _SelfStoreServicePageState();
}

enum _ServiceRequestStatus { newRequest, confirmed, completed }

class _ServiceRequest {
  final String title;
  final String customerName;
  final String customerInitials;
  final Color avatarColor;
  final String price;
  final String date;
  final String time;
  final String location;
  final String note;
  final String earnings;
  final _ServiceRequestStatus status;

  const _ServiceRequest({
    required this.title,
    required this.customerName,
    required this.customerInitials,
    required this.avatarColor,
    required this.price,
    required this.date,
    required this.time,
    required this.location,
    required this.note,
    required this.earnings,
    required this.status,
  });
}

class _SelfStoreServicePageState extends State<SelfStoreServicePage> {
  _ServiceRequestStatus _selectedStatus = _ServiceRequestStatus.newRequest;
  _ServiceRequest? _selectedRequest;

  static const _requests = [
    _ServiceRequest(
      title: 'Home Cleaning',
      customerName: 'Emily Carter',
      customerInitials: 'EC',
      avatarColor: Color(0xFFEAD8CC),
      price: r'$40',
      date: 'Sep 8',
      time: '10:00 AM',
      location: 'At customer location',
      note: 'Please focus on the kitchen and living room.',
      earnings: r'$36.00',
      status: _ServiceRequestStatus.newRequest,
    ),
    _ServiceRequest(
      title: 'Business Consulting',
      customerName: 'Daniel Kim',
      customerInitials: 'DK',
      avatarColor: Color(0xFFD9E8F2),
      price: r'$60',
      date: 'Sep 9',
      time: '2:00 PM',
      location: 'At customer location',
      note: 'I need help reviewing a launch plan and pricing model.',
      earnings: r'$54.00',
      status: _ServiceRequestStatus.newRequest,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final selectedRequest = _selectedRequest;
    if (selectedRequest != null) {
      return _RequestDetailsPage(
        request: selectedRequest,
        onBack: () => setState(() => _selectedRequest = null),
      );
    }

    return _buildRequestsList();
  }

  Widget _buildRequestsList() {
    final filtered = _requests
        .where((request) => request.status == _selectedStatus)
        .toList();

    return SliverList.list(
      children: [
        const _ServiceTopBar(title: 'Service requests'),
        _ServiceStatusTabs(
          selectedStatus: _selectedStatus,
          onSelected: (status) => setState(() => _selectedStatus = status),
        ),
        const SizedBox(height: 8),
        for (final request in filtered)
          _ServiceRequestCard(
            request: request,
            onViewRequest: () => setState(() => _selectedRequest = request),
          ),
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 24, 18, 0),
            child: StoreEmptyState(
              icon: LucideIcons.briefcaseBusiness,
              title: 'No service requests here',
              body: 'Requests for this status will appear here.',
            ),
          ),
      ],
    );
  }
}

class _ServiceTopBar extends StatelessWidget {
  final String title;
  final bool showBack;
  final VoidCallback? onBack;

  const _ServiceTopBar({
    required this.title,
    this.showBack = false,
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
        crossAxisAlignment:
            showBack ? CrossAxisAlignment.center : CrossAxisAlignment.start,
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
                if (showBack)
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF060D35),
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
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
                        _NotifiedBell(),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (!showBack) ...[
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF060D35),
                fontSize: 25,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NotifiedBell extends StatelessWidget {
  const _NotifiedBell();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(LucideIcons.bell, color: Color(0xFF060D35), size: 20),
        Positioned(
          right: -2,
          top: -5,
          child: Container(
            width: 9,
            height: 9,
            decoration: const BoxDecoration(
              color: Color(0xFF684AC8),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}

class _ServiceStatusTabs extends StatelessWidget {
  final _ServiceRequestStatus selectedStatus;
  final ValueChanged<_ServiceRequestStatus> onSelected;

  const _ServiceStatusTabs({
    required this.selectedStatus,
    required this.onSelected,
  });

  static const _tabs = [
    (_ServiceRequestStatus.newRequest, 'New'),
    (_ServiceRequestStatus.confirmed, 'Confirmed'),
    (_ServiceRequestStatus.completed, 'Completed'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
      child: Container(
        height: 47,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: const Color(0xFFE1E5EA)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.045),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            for (var i = 0; i < _tabs.length; i++) ...[
              Expanded(
                child: _ServiceStatusTab(
                  label: _tabs[i].$2,
                  selected: selectedStatus == _tabs[i].$1,
                  onTap: () => onSelected(_tabs[i].$1),
                ),
              ),
              if (i != _tabs.length - 1)
                Container(width: 1, height: 22, color: const Color(0xFFE1E5EA)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ServiceStatusTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ServiceStatusTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: selected ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color:
                  selected ? const Color(0xFF078D92) : const Color(0xFF060D35),
              fontSize: 12,
              fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 2,
            width: selected ? 44 : 0,
            decoration: BoxDecoration(
              color: const Color(0xFF078D92),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceRequestCard extends StatelessWidget {
  final _ServiceRequest request;
  final VoidCallback onViewRequest;

  const _ServiceRequestCard({
    required this.request,
    required this.onViewRequest,
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
                _CustomerAvatar(
                  initials: request.customerInitials,
                  color: request.avatarColor,
                  size: 58,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF060D35),
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        request.customerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF684AC8),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _ServiceMetaRow(
                        icon: LucideIcons.calendarDays,
                        text: '${request.date}  •  ${request.time}',
                      ),
                      const SizedBox(height: 7),
                      _ServiceMetaRow(
                        icon: LucideIcons.mapPin,
                        text: request.location,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      request.price,
                      style: const TextStyle(
                        color: Color(0xFF078D92),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const _NewRequestPill(),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ViewRequestButton(onTap: onViewRequest),
          ],
        ),
      ),
    );
  }
}

class _ServiceMetaRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ServiceMetaRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF060D35), size: 15),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF29304D),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _RequestDetailsPage extends StatelessWidget {
  final _ServiceRequest request;
  final VoidCallback onBack;

  const _RequestDetailsPage({
    required this.request,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return SliverList.list(
      children: [
        _ServiceTopBar(
          showBack: true,
          title: 'Request details',
          onBack: onBack,
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 26, 24, 10),
          child: Text(
            'Requested by',
            style: TextStyle(
              color: Color(0xFF060D35),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        _RequestCustomerCard(request: request),
        _RequestScheduleCard(request: request),
        const _PaymentSecuredCard(),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
            decoration: storeSoftCardDecoration(radius: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your earnings',
                        style: TextStyle(
                          color: Color(0xFF060D35),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        request.earnings,
                        style: const TextStyle(
                          color: Color(0xFF078D92),
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(LucideIcons.info,
                    color: Color(0xFF060D35), size: 20),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
          child: _RequestActionButton(
            label: 'Accept request',
            onTap: () {},
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 9, 18, 0),
          child: _RequestActionButton(
            label: 'Propose new time',
            outlined: true,
            onTap: () {},
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 9, 18, 0),
          child: _RequestActionButton(
            label: 'Decline',
            danger: true,
            outlined: true,
            onTap: () {},
          ),
        ),
      ],
    );
  }
}

class _RequestCustomerCard extends StatelessWidget {
  final _ServiceRequest request;

  const _RequestCustomerCard({required this.request});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: storeSoftCardDecoration(radius: 14),
        child: Row(
          children: [
            _CustomerAvatar(
              initials: request.customerInitials,
              color: request.avatarColor,
              size: 74,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.customerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF060D35),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Row(
                    children: [
                      Icon(
                        LucideIcons.badgeCheck,
                        color: Color(0xFF078D92),
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Verified customer',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xFF078D92),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF060D35),
                side: const BorderSide(color: Color(0xFFE1E5EA)),
                fixedSize: const Size(78, 78),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.messageCircle, size: 27),
                  SizedBox(height: 8),
                  Text(
                    'Message',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestScheduleCard extends StatelessWidget {
  final _ServiceRequest request;

  const _RequestScheduleCard({required this.request});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: storeSoftCardDecoration(radius: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailsIconRow(
              icon: LucideIcons.calendarDays,
              text: '${request.date}  •  ${request.time}',
            ),
            const SizedBox(height: 18),
            _DetailsIconRow(
              icon: LucideIcons.mapPin,
              text: request.location,
            ),
            const Divider(height: 34, color: Color(0xFFE5E8EC)),
            const Text(
              'Customer note',
              style: TextStyle(
                color: Color(0xFF060D35),
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              request.note,
              style: const TextStyle(
                color: Color(0xFF29304D),
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailsIconRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DetailsIconRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF060D35), size: 20),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF29304D),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _PaymentSecuredCard extends StatelessWidget {
  const _PaymentSecuredCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xEEF5FFFF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFD8E9EA)),
        ),
        child: const Row(
          children: [
            Icon(LucideIcons.shieldCheck, color: Color(0xFF078D92), size: 24),
            SizedBox(width: 16),
            Text(
              'Payment secured',
              style: TextStyle(
                color: Color(0xFF056A70),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestActionButton extends StatelessWidget {
  final String label;
  final bool outlined;
  final bool danger;
  final VoidCallback onTap;

  const _RequestActionButton({
    required this.label,
    this.outlined = false,
    this.danger = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFE11D32) : const Color(0xFF078D92);
    return SizedBox(
      height: 44,
      width: double.infinity,
      child: outlined
          ? OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            )
          : FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
    );
  }
}

class _ViewRequestButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ViewRequestButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 43,
      width: double.infinity,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF078D92),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Spacer(),
            Text(
              'View request',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
            ),
            Spacer(),
            Icon(LucideIcons.chevronRight, size: 18),
            SizedBox(width: 6),
          ],
        ),
      ),
    );
  }
}

class _NewRequestPill extends StatelessWidget {
  const _NewRequestPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF2ECFA),
        borderRadius: BorderRadius.circular(7),
      ),
      child: const Text(
        'New request',
        style: TextStyle(
          color: Color(0xFF684AC8),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CustomerAvatar extends StatelessWidget {
  final String initials;
  final Color color;
  final double size;

  const _CustomerAvatar({
    required this.initials,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(
            initials,
            style: const TextStyle(
              color: Color(0xFF060D35),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: Color(0xFF078D92),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.check, color: Colors.white, size: 14),
          ),
        ),
      ],
    );
  }
}
