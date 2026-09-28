import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/api_client.dart';
import '../../api/phase2_store_api.dart';
import '../../services/supabase_service.dart';
import '../../utils/url_helper.dart';
import '../../widgets/safe_network_image.dart';
import 'shared/store_shared_widgets.dart';
import 'store_models.dart';
import 'visitor_service_booking_flow_page.dart';

class VisitorServiceDetailPage extends StatefulWidget {
  final String? ownerUserId;
  final StoreMockCatalogItem item;

  const VisitorServiceDetailPage({
    super.key,
    required this.ownerUserId,
    required this.item,
  });

  String get imageUrl => item.imageUrl;
  String get category => item.category;
  String get title => item.title;
  String get description => item.description;
  String get duration => item.duration;
  String get price => item.priceLabel;
  String get rating => item.rating;
  String get reviews => item.reviews;
  IconData get methodIcon => item.icon;

  @override
  State<VisitorServiceDetailPage> createState() =>
      _VisitorServiceDetailPageState();
}

class _VisitorServiceDetailPageState extends State<VisitorServiceDetailPage> {
  late Future<_ProviderInfo?> _providerFuture;
  StoreMockCatalogItem? _freshItem;

  @override
  void initState() {
    super.initState();
    _providerFuture = _loadProvider();
    _refreshDetail();
  }

  /// Refetches the service by id so detail is never stale.
  /// Seed/offline items keep the passed-in data on any failure.
  Future<void> _refreshDetail() async {
    final id = widget.item.id.trim();
    if (!RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(id)) return;
    try {
      final data = await Phase2StoreApi().getService(id);
      if (!mounted || data.isEmpty) return;
      setState(
          () => _freshItem = StoreMockState.serviceFromApi(data));
    } catch (_) {
      // Keep the listed data; browse/search already show server content.
    }
  }

  Future<_ProviderInfo?> _loadProvider() async {
    final ownerId = widget.ownerUserId?.trim();
    if (ownerId == null || ownerId.isEmpty) return null;

    final user = await SupabaseService().getUserById(ownerId);
    if (user == null) return null;

    final name = _firstString(user, const [
      'full_name',
      'fullName',
      'displayName',
      'name',
      'username',
    ]);
    final avatarUrl = UrlHelper.absoluteUrl(
      _firstString(user, const [
            'avatar_url',
            'avatarUrl',
            'profile_picture',
            'profilePicture',
            'profile_image',
            'profileImage',
            'photoUrl',
            'avatar',
          ]) ??
          '',
    );

    Map<String, String>? avatarHeaders;
    if (avatarUrl.isNotEmpty && UrlHelper.shouldAttachAuthHeader(avatarUrl)) {
      final token = await ApiClient().getToken();
      if (token != null && token.isNotEmpty) {
        avatarHeaders = {'Authorization': 'Bearer $token'};
      }
    }

    return _ProviderInfo(
      name: name ?? 'Store owner',
      avatarUrl: avatarUrl,
      avatarHeaders: avatarHeaders,
    );
  }

  static String? _firstString(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Refreshed view when the live fetch completes; getters stay identical.
    final view = _freshItem == null
        ? widget
        : VisitorServiceDetailPage(
            ownerUserId: widget.ownerUserId,
            item: _freshItem!,
          );
    return Scaffold(
      backgroundColor: const Color(0xFFFFFEFC),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  MediaQuery.of(context).padding.top + 8,
                  16,
                  14,
                ),
                children: [
                  const _DetailHeader(),
                  const SizedBox(height: 12),
                  _HeroSummaryCard(widget: view),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(child: _IncludedCard()),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MethodCard(icon: view.methodIcon),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<_ProviderInfo?>(
                    future: _providerFuture,
                    builder: (context, snapshot) {
                      return _ProviderCard(
                        provider: snapshot.data,
                        isLoading:
                            snapshot.connectionState != ConnectionState.done,
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _ReviewCard(
                    imageUrl: view.imageUrl,
                    rating: view.rating,
                    reviews: view.reviews,
                  ),
                  const SizedBox(height: 12),
                  const _PolicyRow(),
                ],
              ),
            ),
            _AvailabilityButton(service: view),
          ],
        ),
      ),
    );
  }
}

class _ProviderInfo {
  final String name;
  final String avatarUrl;
  final Map<String, String>? avatarHeaders;

  const _ProviderInfo({
    required this.name,
    required this.avatarUrl,
    required this.avatarHeaders,
  });
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(LucideIcons.chevronLeft, size: 27),
              color: const Color(0xFF060D35),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 34, height: 34),
            ),
          ),
          const StoreBsmartWordmark(),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () {},
                  icon: const Icon(LucideIcons.share2, size: 24),
                  color: const Color(0xFF060D35),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(LucideIcons.heart, size: 26),
                  color: const Color(0xFF060D35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroSummaryCard extends StatelessWidget {
  final VisitorServiceDetailPage widget;

  const _HeroSummaryCard({required this.widget});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: storeSoftCardDecoration(radius: 14),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            alignment: Alignment.bottomCenter,
            children: [
              StoreItemImage(
                imageUrl: widget.imageUrl,
                icon: LucideIcons.briefcaseBusiness,
                width: double.infinity,
                height: 178,
                debugLabel: 'store-service-detail',
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PagerDot(active: true),
                    SizedBox(width: 8),
                    _PagerDot(active: false),
                    SizedBox(width: 8),
                    _PagerDot(active: false),
                    SizedBox(width: 8),
                    _PagerDot(active: false),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.category,
                  style: const TextStyle(
                    color: Color(0xFF684AC8),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: Color(0xFF060D35),
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 11),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 11,
                  runSpacing: 6,
                  children: [
                    _Metric(
                      icon: LucideIcons.star,
                      text: widget.rating,
                      bold: true,
                    ),
                    _MetricText('${widget.reviews} reviews'),
                    _MetricText('From ${widget.price}'),
                    _Metric(
                      icon: LucideIcons.clock3,
                      text: widget.duration,
                    ),
                  ],
                ),
                const SizedBox(height: 11),
                Text(
                  widget.description,
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
        ],
      ),
    );
  }
}

class _PagerDot extends StatelessWidget {
  final bool active;

  const _PagerDot({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: active ? 10 : 9,
      height: active ? 10 : 9,
      decoration: BoxDecoration(
        color: active ? const Color(0xFF078D92) : Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool bold;

  const _Metric({
    required this.icon,
    required this.text,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFF078D92), size: 18),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: const Color(0xFF060D35),
            fontSize: 13.5,
            fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _MetricText extends StatelessWidget {
  final String text;

  const _MetricText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF29304D),
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _IncludedCard extends StatelessWidget {
  const _IncludedCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 124,
      padding: const EdgeInsets.all(12),
      decoration: storeSoftCardDecoration(radius: 14),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "What's included",
            style: TextStyle(
              color: Color(0xFF060D35),
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 10),
          _IncludedRow('Kitchen and bathroom'),
          SizedBox(height: 7),
          _IncludedRow('Dusting and floors'),
          SizedBox(height: 7),
          _IncludedRow('Eco-friendly supplies'),
        ],
      ),
    );
  }
}

class _IncludedRow extends StatelessWidget {
  final String label;

  const _IncludedRow(this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          LucideIcons.circleCheck,
          color: Color(0xFF078D92),
          size: 15,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF29304D),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _MethodCard extends StatelessWidget {
  final IconData icon;

  const _MethodCard({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 124,
      padding: const EdgeInsets.all(12),
      decoration: storeSoftCardDecoration(radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Service method',
            style: TextStyle(
              color: Color(0xFF060D35),
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFF3F1EE),
                child: Icon(icon, color: const Color(0xFF078D92), size: 24),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'At your location',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFF060D35),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProviderCard extends StatelessWidget {
  final _ProviderInfo? provider;
  final bool isLoading;

  const _ProviderCard({
    required this.provider,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final name = provider?.name.trim().isNotEmpty == true
        ? provider!.name.trim()
        : (isLoading ? 'Loading provider...' : 'Store owner');
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      decoration: storeSoftCardDecoration(radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Provided by',
            style: TextStyle(
              color: Color(0xFF29304D),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              _ProviderAvatar(
                name: name,
                avatarUrl: provider?.avatarUrl ?? '',
                avatarHeaders: provider?.avatarHeaders,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF060D35),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Row(
                      children: [
                        Icon(
                          LucideIcons.badgeCheck,
                          color: Color(0xFF684AC8),
                          size: 16,
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Verified provider',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Color(0xFF684AC8),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(LucideIcons.messageCircle, size: 18),
                label: const Text('Message'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF060D35),
                  side: const BorderSide(color: Color(0xFFD5DEE4)),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(92, 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProviderAvatar extends StatelessWidget {
  final String name;
  final String avatarUrl;
  final Map<String, String>? avatarHeaders;

  const _ProviderAvatar({
    required this.name,
    required this.avatarUrl,
    required this.avatarHeaders,
  });

  @override
  Widget build(BuildContext context) {
    const size = 52.0;
    final initial =
        name.trim().isEmpty ? 'S' : name.characters.first.toUpperCase();
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipOval(
          child: Container(
            width: size,
            height: size,
            color: const Color(0xFFEAD8CC),
            alignment: Alignment.center,
            child: avatarUrl.trim().isEmpty
                ? Text(
                    initial,
                    style: const TextStyle(
                      color: Color(0xFF060D35),
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                : SafeNetworkImage(
                    url: avatarUrl,
                    headers: avatarHeaders,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    debugLabel: 'visitor-service-detail-provider-avatar',
                    errorWidget: Text(
                      initial,
                      style: const TextStyle(
                        color: Color(0xFF060D35),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
          ),
        ),
        Positioned(
          right: -2,
          bottom: 2,
          child: Container(
            width: 19,
            height: 19,
            decoration: const BoxDecoration(
              color: Color(0xFF078D92),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.check, color: Colors.white, size: 13),
          ),
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final String imageUrl;
  final String rating;
  final String reviews;

  const _ReviewCard({
    required this.imageUrl,
    required this.rating,
    required this.reviews,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: storeSoftCardDecoration(radius: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recent reviews',
                  style: TextStyle(
                    color: Color(0xFF060D35),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                _Metric(icon: LucideIcons.star, text: rating, bold: true),
                const SizedBox(height: 8),
                Text(
                  reviews == '0' || reviews.toLowerCase() == 'new'
                      ? 'No reviews yet. Be the first to book and rate this service.'
                      : 'Based on $reviews customer ${reviews == '1' ? 'review' : 'reviews'}.',
                  style: const TextStyle(
                    color: Color(0xFF29304D),
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          StoreItemImage(
            imageUrl: imageUrl,
            icon: LucideIcons.briefcaseBusiness,
            width: 82,
            height: 82,
            borderRadius: 10,
            debugLabel: 'service-detail-review',
          ),
        ],
      ),
    );
  }
}

class _PolicyRow extends StatelessWidget {
  const _PolicyRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: storeSoftCardDecoration(radius: 14),
      child: const Row(
        children: [
          Icon(LucideIcons.shieldCheck, color: Color(0xFF060D35), size: 22),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Cancellation policy',
              style: TextStyle(
                color: Color(0xFF29304D),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Icon(LucideIcons.chevronRight, color: Color(0xFF060D35), size: 20),
        ],
      ),
    );
  }
}

class _AvailabilityButton extends StatelessWidget {
  final VisitorServiceDetailPage service;

  const _AvailabilityButton({required this.service});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        7,
        16,
        MediaQuery.of(context).padding.bottom + 9,
      ),
      child: SizedBox(
        height: 46,
        width: double.infinity,
        child: FilledButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => VisitorServiceBookingFlowPage(
                  ownerUserId: service.ownerUserId,
                  item: service.item,
                ),
              ),
            );
          },
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF078D92),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text(
            'Select availability',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }
}
