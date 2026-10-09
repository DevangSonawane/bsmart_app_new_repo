import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/api_client.dart';
import '../../api/phase2_store_api.dart';
import '../../services/supabase_service.dart';
import '../../utils/url_helper.dart';
import '../../widgets/safe_network_image.dart';
import 'shared/store_money.dart';
import 'shared/store_shared_widgets.dart';
import 'store_models.dart';
import 'store_profile_page.dart';
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
      setState(() => _freshItem = StoreMockState.serviceFromApi(data));
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

  static String? _rawText(Map<String, dynamic> raw, List<String> keys) {
    for (final key in keys) {
      final value = raw[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static List<String> _rawStringList(
      Map<String, dynamic> raw, List<String> keys) {
    for (final key in keys) {
      final value = raw[key];
      if (value is List) {
        final out = value
            .map((e) => e?.toString().trim() ?? '')
            .where((e) => e.isNotEmpty)
            .toList();
        if (out.isNotEmpty) return out;
      } else if (value is String) {
        final out = value
            .split(RegExp(r'[\n\u2022\-]+'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        if (out.isNotEmpty) return out;
      }
    }
    return const [];
  }

  List<String> _highlights(StoreMockCatalogItem item) =>
      _rawStringList(item.raw, const [
        'key_highlights',
        'keyHighlights',
        'highlights',
        'key_features',
        'features',
        'keyFeatures',
        'includes',
        'included',
        'whats_included',
      ]);

  List<String> _galleryImages(StoreMockCatalogItem item) {
    final out = <String>[];
    void add(String? url) {
      final trimmed = (url ?? '').trim();
      if (trimmed.isEmpty || trimmed == 'null') return;
      final resolved = UrlHelper.absoluteUrl(trimmed);
      if (resolved.isNotEmpty && !out.contains(resolved)) out.add(resolved);
    }

    for (final key in const [
      'images',
      'image_urls',
      'imageUrls',
      'media',
      'photos',
      'gallery',
      'attachments',
      'files',
    ]) {
      final value = item.raw[key];
      if (value is! List) continue;
      for (final entry in value) {
        if (entry is String) {
          add(entry);
        } else if (entry is Map) {
          final map = entry.map((k, v) => MapEntry(k.toString(), v));
          for (final rk in const [
            'fileUrl',
            'file_url',
            'secure_url',
            'downloadUrl',
            'download_url',
            'url',
            'src',
            'image_url',
            'imageUrl',
            'image',
            'path',
          ]) {
            final candidate = map[rk]?.toString() ?? '';
            if (candidate.trim().isNotEmpty) {
              add(candidate);
              break;
            }
          }
        }
      }
    }
    add(item.imageUrl);
    return out;
  }

  List<_SubserviceInfo> _subservices(StoreMockCatalogItem item) {
    final raw = item.raw['subservices'];
    if (raw is! List) return const [];
    final out = <_SubserviceInfo>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final map = entry.map((k, v) => MapEntry(k.toString(), v));
      final name = map['name']?.toString().trim() ?? '';
      if (name.isEmpty) continue;
      out.add(_SubserviceInfo(
        name: name,
        price: map['price']?.toString().trim() ?? '',
        hours: (map['hours'] ?? map['duration'])?.toString().trim() ?? '',
      ));
    }
    return out;
  }

  String _cancellationPolicy(StoreMockCatalogItem item) =>
      _rawText(item.raw, const [
        'cancellation_policy',
        'cancellationPolicy',
        'cancellation',
        'return_policy',
        'returnPolicy',
      ]) ??
      'Free cancellation up to 24 hours before the appointment.';

  double? _ratingValue(StoreMockCatalogItem item) =>
      double.tryParse(item.rating.trim());

  int _reviewsCount(StoreMockCatalogItem item) {
    final digits = item.reviews.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits) ?? 0;
  }

  List<StoreMockCatalogItem> _similarServices(StoreMockCatalogItem item) {
    final pool = StoreMockState.catalog
        .where((e) => e.type == StoreMockItemType.service && e.id != item.id)
        .toList();
    int score(StoreMockCatalogItem e) {
      var s = 0;
      if (e.category.trim().toLowerCase() ==
          item.category.trim().toLowerCase()) {
        s += 2;
      }
      return s;
    }

    pool.sort((a, b) => score(b).compareTo(score(a)));
    return pool.take(8).toList();
  }

  void _openStore() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StoreProfilePage(ownerUserId: widget.ownerUserId),
      ),
    );
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
    final item = view.item;
    final highlights = _highlights(item);
    final galleryImages = _galleryImages(item);
    final subservices = _subservices(item);
    final similar = _similarServices(item);
    final hasOwner = (widget.ownerUserId?.trim().isNotEmpty == true);
    return Scaffold(
      backgroundColor: const Color(0xFFFFFEFC),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 14),
                physics: const BouncingScrollPhysics(),
                children: [
                  _ServiceGallery(
                    images: galleryImages,
                    duration: view.duration,
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _ServiceTitleCard(
                      category: view.category,
                      title: view.title,
                      ratingValue: _ratingValue(item),
                      ratingLabel: view.rating,
                      reviewsCount: _reviewsCount(item),
                      priceLabel: view.price,
                      duration: view.duration,
                      description: view.description,
                    ),
                  ),
                  if (subservices.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _SubservicesCard(subservices: subservices),
                    ),
                  ],
                  if (highlights.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _ServiceHighlightsCard(highlights: highlights),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _ServiceDetailsAccordion(
                      duration: view.duration,
                      category: view.category,
                      serviceId: item.id,
                      cancellationPolicy: _cancellationPolicy(item),
                    ),
                  ),
                  if (hasOwner) ...[
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: FutureBuilder<_ProviderInfo?>(
                        future: _providerFuture,
                        builder: (context, snapshot) {
                          return _ProviderCard(
                            provider: snapshot.data,
                            isLoading: snapshot.connectionState !=
                                ConnectionState.done,
                            onViewStore: _openStore,
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _ServiceReviewsSummary(
                      ratingValue: _ratingValue(item),
                      ratingLabel: view.rating,
                      reviewsCount: _reviewsCount(item),
                    ),
                  ),
                  if (similar.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _SimilarServicesCarousel(
                      items: similar,
                      onTap: (next) => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => VisitorServiceDetailPage(
                            ownerUserId: widget.ownerUserId,
                            item: next,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ],
              ),
            ),
            _BookingBottomBar(service: view),
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

class _SubserviceInfo {
  final String name;
  final String price;
  final String hours;

  const _SubserviceInfo({
    required this.name,
    required this.price,
    required this.hours,
  });
}

class _ServiceGallery extends StatefulWidget {
  final List<String> images;
  final String duration;

  const _ServiceGallery({
    required this.images,
    required this.duration,
  });

  @override
  State<_ServiceGallery> createState() => _ServiceGalleryState();
}

class _ServiceGalleryState extends State<_ServiceGallery> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images.isEmpty ? const [''] : widget.images;
    return SizedBox(
      height: 304,
      width: double.infinity,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: images.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => StoreItemImage(
              imageUrl: images[i],
              icon: LucideIcons.briefcaseBusiness,
              width: double.infinity,
              height: 304,
              debugLabel: 'store-service-detail',
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).padding.top + 64,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.38),
                    Colors.black.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 14,
            child: GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.arrowLeft,
                    color: Color(0xFF060D35), size: 21),
              ),
            ),
          ),
          if (images.length > 1)
            Positioned(
              bottom: 14,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.44),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${_index + 1}/${images.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          if (images.length > 1)
            Positioned(
              bottom: 18,
              left: 0,
              right: 0,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < images.length; i++) ...[
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: _index == i ? 20 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: _index == i
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.58),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      if (i != images.length - 1) const SizedBox(width: 5),
                    ],
                  ],
                ),
              ),
            ),
          if (widget.duration.trim().isNotEmpty)
            Positioned(
              bottom: 14,
              left: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.clock3,
                        color: Color(0xFF078D92), size: 14),
                    const SizedBox(width: 6),
                    Text(
                      widget.duration.trim(),
                      style: const TextStyle(
                        color: Color(0xFF060D35),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
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

class _ServiceTitleCard extends StatelessWidget {
  final String category;
  final String title;
  final double? ratingValue;
  final String ratingLabel;
  final int reviewsCount;
  final String priceLabel;
  final String duration;
  final String description;

  const _ServiceTitleCard({
    required this.category,
    required this.title,
    required this.ratingValue,
    required this.ratingLabel,
    required this.reviewsCount,
    required this.priceLabel,
    required this.duration,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      decoration: storeSoftCardDecoration(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1ECFA),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    category.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF684AC8),
                      fontSize: 11,
                      letterSpacing: 0.4,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF060D35),
              fontSize: 22,
              height: 1.16,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (description.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              description.trim(),
              style: const TextStyle(
                color: Color(0xFF29304D),
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            priceLabel,
            style: const TextStyle(
              color: Color(0xFF060D35),
              fontSize: 25,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            duration.trim().isEmpty ? 'Service booking' : duration,
            style: const TextStyle(
              color: Color(0xFF55607A),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (ratingValue != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF388E3C),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        ratingValue!.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(LucideIcons.star,
                          color: Colors.white, size: 12),
                    ],
                  ),
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F2F6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    ratingLabel.isEmpty ? 'New' : ratingLabel,
                    style: const TextStyle(
                      color: Color(0xFF29304D),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  reviewsCount > 0
                      ? '$reviewsCount review${reviewsCount == 1 ? '' : 's'}'
                      : 'No reviews yet',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF55607A),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
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

class _SubservicesCard extends StatelessWidget {
  final List<_SubserviceInfo> subservices;

  const _SubservicesCard({required this.subservices});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: storeSoftCardDecoration(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Color(0xFFF1ECFA),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.listChecks,
                    color: Color(0xFF684AC8), size: 19),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Subservices',
                      style: TextStyle(
                        color: Color(0xFF060D35),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${subservices.length} option${subservices.length == 1 ? '' : 's'} available',
                      style: const TextStyle(
                        color: Color(0xFF55607A),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          for (var i = 0; i < subservices.length; i++) ...[
            _SubserviceRow(info: subservices[i]),
            if (i != subservices.length - 1) const SizedBox(height: 9),
          ],
        ],
      ),
    );
  }
}

class _SubserviceRow extends StatelessWidget {
  final _SubserviceInfo info;

  const _SubserviceRow({required this.info});

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (info.hours.isNotEmpty) '${info.hours}h',
      if (info.price.isNotEmpty) _formatSubPrice(info.price),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3E7EA)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF7F6),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.check,
                color: Color(0xFF078D92), size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              info.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF060D35),
                fontSize: 14,
                height: 1.25,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(width: 10),
            Text(
              meta.join(' · '),
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFF078D92),
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ServiceHighlightsCard extends StatelessWidget {
  final List<String> highlights;

  const _ServiceHighlightsCard({required this.highlights});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEAF7F6), Color(0xFFDDF0EE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF078D92), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Color(0xFF078D92),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.packageCheck,
                    color: Colors.white, size: 19),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Text(
                  "What's included",
                  style: TextStyle(
                    color: Color(0xFF060D35),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF078D92),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${highlights.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < highlights.length; i++) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: Color(0xFF078D92),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.check,
                        color: Colors.white, size: 14),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      highlights[i],
                      style: const TextStyle(
                        color: Color(0xFF060D35),
                        fontSize: 13.5,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (i != highlights.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _ServiceDetailsAccordion extends StatelessWidget {
  final String duration;
  final String category;
  final String serviceId;
  final String cancellationPolicy;

  const _ServiceDetailsAccordion({
    required this.duration,
    required this.category,
    required this.serviceId,
    required this.cancellationPolicy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: storeSoftCardDecoration(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.clipboardList,
                  color: Color(0xFF684AC8), size: 19),
              SizedBox(width: 9),
              Text(
                'Service details',
                style: TextStyle(
                  color: Color(0xFF060D35),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ServiceSpecRow(
            icon: LucideIcons.clock3,
            label: 'Duration',
            value: duration,
          ),
          const SizedBox(height: 10),
          _ServiceSpecRow(
            icon: LucideIcons.layoutGrid,
            label: 'Category',
            value: category,
          ),
          const SizedBox(height: 10),
          _ServiceSpecRow(
            icon: LucideIcons.hash,
            label: 'Service ID',
            value: serviceId.length > 14
                ? '${serviceId.substring(0, 14)}\u2026'
                : serviceId,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF6E7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF0D9A8)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(LucideIcons.shieldCheck,
                      color: Color(0xFFB7791F), size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cancellation policy',
                        style: TextStyle(
                          color: Color(0xFF060D35),
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        cancellationPolicy,
                        style: const TextStyle(
                          color: Color(0xFF6B5B3E),
                          fontSize: 12.5,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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

class _ServiceSpecRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ServiceSpecRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: Color(0xFFF1ECFA),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFF684AC8), size: 17),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF55607A),
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
                  color: Color(0xFF060D35),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProviderCard extends StatelessWidget {
  final _ProviderInfo? provider;
  final bool isLoading;
  final VoidCallback onViewStore;

  const _ProviderCard({
    required this.provider,
    required this.isLoading,
    required this.onViewStore,
  });

  @override
  Widget build(BuildContext context) {
    final name = provider?.name.trim().isNotEmpty == true
        ? provider!.name.trim()
        : (isLoading ? 'Loading provider...' : 'Store owner');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: storeSoftCardDecoration(radius: 16),
      child: Row(
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
                const Text(
                  'Provided by',
                  style: TextStyle(
                    color: Color(0xFF55607A),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF060D35),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                const Row(
                  children: [
                    Icon(
                      LucideIcons.badgeCheck,
                      color: Color(0xFF684AC8),
                      size: 14,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Verified provider',
                      style: TextStyle(
                        color: Color(0xFF684AC8),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 38,
            child: FilledButton(
              onPressed: isLoading ? null : onViewStore,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF078D92),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'View Store',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
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

class _ServiceReviewsSummary extends StatelessWidget {
  final double? ratingValue;
  final String ratingLabel;
  final int reviewsCount;

  const _ServiceReviewsSummary({
    required this.ratingValue,
    required this.ratingLabel,
    required this.reviewsCount,
  });

  @override
  Widget build(BuildContext context) {
    final full = (ratingValue ?? 0).round().clamp(0, 5);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF078D92), Color(0xFF056B70)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.messageSquareHeart,
                  color: Colors.white, size: 18),
              SizedBox(width: 9),
              Text(
                'Customer ratings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                ratingValue != null
                    ? ratingValue!.toStringAsFixed(1)
                    : (ratingLabel.isEmpty ? 'New' : ratingLabel),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 44,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 6),
              const Padding(
                padding: EdgeInsets.only(bottom: 5),
                child: Text(
                  '/ 5',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      for (var i = 0; i < 5; i++)
                        Padding(
                          padding: EdgeInsets.only(left: i == 0 ? 0 : 2),
                          child: Icon(
                            LucideIcons.star,
                            size: 15,
                            color: i < full
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.35),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    reviewsCount > 0
                        ? '$reviewsCount verified review${reviewsCount == 1 ? '' : 's'}'
                        : 'No reviews yet',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SimilarServicesCarousel extends StatelessWidget {
  final List<StoreMockCatalogItem> items;
  final ValueChanged<StoreMockCatalogItem> onTap;

  const _SimilarServicesCarousel({required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Similar Services',
            style: TextStyle(
              color: Color(0xFF060D35),
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 208,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final item = items[i];
              return InkWell(
                onTap: () => onTap(item),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 152,
                  decoration: storeSoftCardDecoration(radius: 14),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StoreItemImage(
                        imageUrl: item.imageUrl,
                        icon: item.icon,
                        width: double.infinity,
                        height: 104,
                        debugLabel: 'store-service-similar',
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF060D35),
                                fontSize: 12.5,
                                height: 1.25,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              item.priceLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF078D92),
                                fontSize: 14.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BookingBottomBar extends StatelessWidget {
  final VisitorServiceDetailPage service;

  const _BookingBottomBar({required this.service});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  service.price,
                  style: const TextStyle(
                    color: Color(0xFF060D35),
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  service.duration,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF55607A),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 48,
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
                padding: const EdgeInsets.symmetric(horizontal: 26),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Book Now',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatSubPrice(dynamic raw) {
  final text = raw?.toString().trim() ?? '';
  if (text.isEmpty) return '';
  final parsed = num.tryParse(text);
  if (parsed == null) return '₹$text';
  return formatStoreMoney(parsed.toDouble());
}
