import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/api_client.dart';
import '../../services/supabase_service.dart';
import '../../utils/url_helper.dart';
import '../../widgets/safe_network_image.dart';
import 'shared/store_shared_widgets.dart';

class VisitorStoreHomePage extends StatefulWidget {
  final String? ownerUserId;

  const VisitorStoreHomePage({super.key, this.ownerUserId});

  @override
  State<VisitorStoreHomePage> createState() => _VisitorStoreHomePageState();
}

enum _VisitorStoreFilter { all, services, products }

class _VisitorStoreHomePageState extends State<VisitorStoreHomePage> {
  _VisitorStoreFilter _selectedFilter = _VisitorStoreFilter.all;
  late Future<_VisitorStoreOwner?> _ownerFuture;

  @override
  void initState() {
    super.initState();
    _ownerFuture = _loadOwner();
  }

  @override
  void didUpdateWidget(covariant VisitorStoreHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerUserId != widget.ownerUserId) {
      _ownerFuture = _loadOwner();
    }
  }

  Future<_VisitorStoreOwner?> _loadOwner() async {
    final ownerId = widget.ownerUserId?.trim();
    if (ownerId == null || ownerId.isEmpty) return null;

    final user = await SupabaseService().getUserById(ownerId);
    if (user == null) return null;

    final displayName = _firstString(user, const [
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

    return _VisitorStoreOwner(
      displayName: displayName ?? 'Store owner',
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
    return SliverList.list(
      children: [
        const _VisitorStoreTopBar(),
        FutureBuilder<_VisitorStoreOwner?>(
          future: _ownerFuture,
          builder: (context, snapshot) {
            return _SellerHeroCard(
              owner: snapshot.data,
              isLoading: snapshot.connectionState != ConnectionState.done,
            );
          },
        ),
        _StoreFilterTabs(
          selectedFilter: _selectedFilter,
          onSelected: (filter) => setState(() => _selectedFilter = filter),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
          child: _StoreItemsContent(filter: _selectedFilter),
        ),
      ],
    );
  }
}

class _VisitorStoreOwner {
  final String displayName;
  final String avatarUrl;
  final Map<String, String>? avatarHeaders;

  const _VisitorStoreOwner({
    required this.displayName,
    required this.avatarUrl,
    required this.avatarHeaders,
  });
}

class _VisitorStoreTopBar extends StatelessWidget {
  const _VisitorStoreTopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + 10,
        16,
        0,
      ),
      child: const SizedBox(
        height: 32,
        child: Row(
          children: [
            Expanded(child: StoreBsmartWordmark()),
            Icon(LucideIcons.search, color: Color(0xFF060D35), size: 23),
            SizedBox(width: 18),
            _NotifiedBell(),
          ],
        ),
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
        const Icon(LucideIcons.bell, color: Color(0xFF060D35), size: 23),
        Positioned(
          right: -2,
          top: -4,
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

class _SellerHeroCard extends StatelessWidget {
  final _VisitorStoreOwner? owner;
  final bool isLoading;

  const _SellerHeroCard({
    required this.owner,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final name = owner?.displayName.trim().isNotEmpty == true
        ? owner!.displayName.trim()
        : (isLoading ? 'Loading store...' : 'Store owner');
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
        decoration: storeSoftCardDecoration(radius: 16),
        child: Row(
          children: [
            _VerifiedAvatar(
              initials: _initialsFor(name),
              avatarUrl: owner?.avatarUrl ?? '',
              avatarHeaders: owner?.avatarHeaders,
              size: 78,
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
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Personal Store',
                    style: TextStyle(
                      color: Color(0xFF684AC8),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    children: [
                      Icon(LucideIcons.star,
                          color: Color(0xFF078D92), size: 15),
                      SizedBox(width: 5),
                      Text(
                        '4.9',
                        style: TextStyle(
                          color: Color(0xFF060D35),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(width: 9),
                      SizedBox(
                        height: 16,
                        child: VerticalDivider(
                          color: Color(0xFFD4D8DD),
                          thickness: 1,
                        ),
                      ),
                      SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          '128 reviews',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xFF29304D),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Professional • Trusted • Reliable',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFF29304D),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF060D35),
                side: const BorderSide(color: Color(0xFFE1E5EA)),
                fixedSize: const Size(56, 56),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.messageCircle, size: 21),
                  SizedBox(height: 4),
                  Text(
                    'Message',
                    style:
                        TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _initialsFor(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'S';
    final first = parts.first.characters.first.toUpperCase();
    if (parts.length == 1) return first;
    return '$first${parts.last.characters.first.toUpperCase()}';
  }
}

class _VerifiedAvatar extends StatelessWidget {
  final String initials;
  final String avatarUrl;
  final Map<String, String>? avatarHeaders;
  final double size;

  const _VerifiedAvatar({
    required this.initials,
    required this.avatarUrl,
    required this.avatarHeaders,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipOval(
          child: Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              color: Color(0xFFEAD8CC),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: avatarUrl.trim().isEmpty
                ? Text(
                    initials,
                    style: const TextStyle(
                      color: Color(0xFF060D35),
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                : SafeNetworkImage(
                    url: avatarUrl,
                    headers: avatarHeaders,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    debugLabel: 'visitor-store-owner-avatar',
                    errorWidget: Center(
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Color(0xFF060D35),
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
        Positioned(
          right: -2,
          bottom: 3,
          child: Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Color(0xFF078D92),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.check, color: Colors.white, size: 16),
          ),
        ),
      ],
    );
  }
}

class _StoreFilterTabs extends StatelessWidget {
  final _VisitorStoreFilter selectedFilter;
  final ValueChanged<_VisitorStoreFilter> onSelected;

  const _StoreFilterTabs({
    required this.selectedFilter,
    required this.onSelected,
  });

  static const _tabs = [
    (_VisitorStoreFilter.all, LucideIcons.layoutGrid, 'All'),
    (_VisitorStoreFilter.services, LucideIcons.briefcaseBusiness, 'Services'),
    (_VisitorStoreFilter.products, LucideIcons.box, 'Products'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
      child: Container(
        height: 46,
        decoration: storeSoftCardDecoration(radius: 18),
        child: Row(
          children: [
            for (var i = 0; i < _tabs.length; i++) ...[
              Expanded(
                child: _StoreFilterTab(
                  icon: _tabs[i].$2,
                  label: _tabs[i].$3,
                  selected: selectedFilter == _tabs[i].$1,
                  onTap: () => onSelected(_tabs[i].$1),
                ),
              ),
              if (i != _tabs.length - 1)
                Container(width: 1, height: 22, color: const Color(0xFFE2E5EA)),
            ],
          ],
        ),
      ),
    );
  }
}

class _StoreFilterTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _StoreFilterTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF078D92) : const Color(0xFF060D35);
    return InkWell(
      onTap: selected ? null : onTap,
      borderRadius: BorderRadius.circular(18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 2,
            width: selected ? 32 : 0,
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

class _StoreItemsContent extends StatelessWidget {
  final _VisitorStoreFilter filter;

  const _StoreItemsContent({required this.filter});

  @override
  Widget build(BuildContext context) {
    return switch (filter) {
      _VisitorStoreFilter.services => const _VisitorServiceList(),
      _VisitorStoreFilter.products => const _VisitorProductList(),
      _VisitorStoreFilter.all => const _StoreItemsGrid(
          children: [
            _ServiceFeatureCard(),
            _ProductCard(
              imageAsset: 'assets/bSmart_Store/mockimages/vegetables.jpg',
              title: 'Eco Cleaning Kit',
              price: r'$24.99',
              rating: '4.8',
              reviews: '64',
            ),
            _ProductCard(
              imageAsset: 'assets/bSmart_Store/mockimages/electronics.jpg',
              title: 'Aroma Diffuser',
              price: r'$32.00',
              rating: '4.7',
              reviews: '38',
            ),
          ],
        ),
    };
  }
}

class _StoreItemsGrid extends StatelessWidget {
  final List<Widget> children;

  const _StoreItemsGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final columnWidth = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: 12,
          children: [
            for (final child in children)
              SizedBox(width: columnWidth, child: child),
          ],
        );
      },
    );
  }
}

class _VisitorServiceList extends StatelessWidget {
  const _VisitorServiceList();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _VisitorServiceCard(
          imageAsset: 'assets/bSmart_Store/mockimages/clothes.jpg',
          icon: LucideIcons.house,
          title: 'Home Cleaning',
          description:
              'Thorough and reliable cleaning for a fresh, healthy home.',
          duration: '2-3 hrs',
          price: r'$40',
          rating: '4.8',
          reviews: '64',
        ),
        SizedBox(height: 10),
        _VisitorServiceCard(
          imageAsset: 'assets/bSmart_Store/mockimages/electronics.jpg',
          icon: LucideIcons.briefcaseBusiness,
          title: 'Business Consulting',
          description: 'Expert advice to help your business grow and succeed.',
          duration: '60 min',
          price: r'$60',
          rating: '4.9',
          reviews: '52',
        ),
        SizedBox(height: 10),
        _VisitorServiceCard(
          imageAsset: 'assets/bSmart_Store/mockimages/vegetables.jpg',
          icon: LucideIcons.flower2,
          title: 'Yoga Coaching',
          description: 'Personalized sessions to improve your mind and body.',
          duration: '45 min',
          price: r'$35',
          rating: '4.9',
          reviews: '48',
        ),
      ],
    );
  }
}

class _VisitorServiceCard extends StatelessWidget {
  final String imageAsset;
  final IconData icon;
  final String title;
  final String description;
  final String duration;
  final String price;
  final String rating;
  final String reviews;

  const _VisitorServiceCard({
    required this.imageAsset,
    required this.icon,
    required this.title,
    required this.description,
    required this.duration,
    required this.price,
    required this.rating,
    required this.reviews,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 158,
      decoration: storeSoftCardDecoration(radius: 12),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Expanded(
            flex: 49,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    imageAsset,
                    fit: BoxFit.cover,
                    cacheWidth: 420,
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    width: 31,
                    height: 31,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(7),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: const Color(0xFF078D92), size: 18),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 51,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(11, 9, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF060D35),
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                            height: 1.08,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          LucideIcons.heart,
                          color: Color(0xFF060D35),
                          size: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF29304D),
                      fontSize: 10.5,
                      height: 1.28,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Divider(height: 10, color: Color(0xFFE1E5EA)),
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.clock3,
                        color: Color(0xFF29304D),
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          duration,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF29304D),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        'From ',
                        style: TextStyle(
                          color: Color(0xFF29304D),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        price,
                        style: const TextStyle(
                          color: Color(0xFF078D92),
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.star,
                        color: Color(0xFF078D92),
                        size: 11,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        rating,
                        style: const TextStyle(
                          color: Color(0xFF060D35),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '($reviews)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF29304D),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 26,
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {},
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF078D92),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'View service',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(width: 7),
                            Icon(LucideIcons.chevronRight, size: 15),
                          ],
                        ),
                      ),
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

class _ServiceFeatureCard extends StatelessWidget {
  const _ServiceFeatureCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: storeSoftCardDecoration(radius: 14),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Image.asset(
                'assets/bSmart_Store/mockimages/clothes.jpg',
                width: double.infinity,
                height: 160,
                fit: BoxFit.cover,
                cacheWidth: 360,
              ),
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(7),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    LucideIcons.house,
                    color: Color(0xFF078D92),
                    size: 21,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(11, 12, 11, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Home Cleaning',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFF060D35),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Thorough and reliable cleaning for a fresh, healthy home.',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFF29304D),
                    fontSize: 11.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Divider(height: 22, color: Color(0xFFE1E5EA)),
                const Row(
                  children: [
                    Icon(LucideIcons.clock3,
                        color: Color(0xFF29304D), size: 14),
                    SizedBox(width: 5),
                    Text(
                      '2-3 hrs',
                      style: TextStyle(
                        color: Color(0xFF29304D),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Spacer(),
                    Text(
                      'From ',
                      style: TextStyle(
                        color: Color(0xFF29304D),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      r'$40',
                      style: TextStyle(
                        color: Color(0xFF078D92),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 38,
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {},
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF078D92),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'View service',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(LucideIcons.chevronRight, size: 17),
                        ],
                      ),
                    ),
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

class _ProductCard extends StatelessWidget {
  final String imageAsset;
  final String title;
  final String price;
  final String rating;
  final String reviews;

  const _ProductCard({
    required this.imageAsset,
    required this.title,
    required this.price,
    required this.rating,
    required this.reviews,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: storeSoftCardDecoration(radius: 14),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Image.asset(
                imageAsset,
                width: double.infinity,
                height: 108,
                fit: BoxFit.cover,
                cacheWidth: 360,
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 9,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    LucideIcons.heart,
                    color: Color(0xFF060D35),
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 11, 10, 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF060D35),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  price,
                  style: const TextStyle(
                    color: Color(0xFF078D92),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    const Icon(
                      LucideIcons.star,
                      color: Color(0xFF078D92),
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      rating,
                      style: const TextStyle(
                        color: Color(0xFF060D35),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        '($reviews)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF29304D),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 34,
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF078D92),
                      side: const BorderSide(color: Color(0xFFD5DEE4)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.shoppingCart, size: 15),
                        SizedBox(width: 7),
                        Text(
                          'Add',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
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

class _VisitorProductList extends StatelessWidget {
  const _VisitorProductList();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const _VisitorProductGrid(
          children: [
            _VisitorProductGridCard(
              imageAsset: 'assets/bSmart_Store/mockimages/vegetables.jpg',
              title: 'Eco Cleaning Kit',
              price: r'$24.99',
              rating: '4.8',
              reviews: '64',
            ),
            _VisitorProductGridCard(
              imageAsset: 'assets/bSmart_Store/mockimages/electronics.jpg',
              title: 'Aroma Diffuser',
              price: r'$32.00',
              rating: '4.7',
              reviews: '38',
            ),
            _VisitorProductGridCard(
              imageAsset: 'assets/bSmart_Store/mockimages/clothes.jpg',
              title: 'Handmade Notebook',
              price: r'$15.00',
              rating: '4.9',
              reviews: '57',
            ),
            _VisitorProductGridCard(
              imageAsset:
                  'assets/bSmart_Store/mockimages/clothes_clean_test.jpg',
              title: 'Wellness Candle',
              price: r'$18.00',
              rating: '4.8',
              reviews: '42',
            ),
          ],
        ),
        Positioned(
          right: 6,
          bottom: 8,
          child: _FloatingCartShortcut(onTap: () {}),
        ),
      ],
    );
  }
}

class _VisitorProductGrid extends StatelessWidget {
  final List<Widget> children;

  const _VisitorProductGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final columnWidth = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: 12,
          children: [
            for (final child in children)
              SizedBox(width: columnWidth, child: child),
          ],
        );
      },
    );
  }
}

class _VisitorProductGridCard extends StatelessWidget {
  final String imageAsset;
  final String title;
  final String price;
  final String rating;
  final String reviews;

  const _VisitorProductGridCard({
    required this.imageAsset,
    required this.title,
    required this.price,
    required this.rating,
    required this.reviews,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: storeSoftCardDecoration(radius: 14),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Image.asset(
                imageAsset,
                width: double.infinity,
                height: 132,
                fit: BoxFit.cover,
                cacheWidth: 360,
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 9,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    LucideIcons.heart,
                    color: Color(0xFF060D35),
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF060D35),
                    fontSize: 14.5,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  price,
                  style: const TextStyle(
                    color: Color(0xFF078D92),
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    const Icon(
                      LucideIcons.star,
                      color: Color(0xFF078D92),
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      rating,
                      style: const TextStyle(
                        color: Color(0xFF060D35),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        '($reviews)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF29304D),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 34,
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF078D92),
                      side: const BorderSide(color: Color(0xFFD5DEE4)),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.shoppingCart, size: 15),
                          SizedBox(width: 8),
                          Text(
                            'Add',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
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

class _FloatingCartShortcut extends StatelessWidget {
  final VoidCallback onTap;

  const _FloatingCartShortcut({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: const Color(0xFF078D92),
            shape: const CircleBorder(),
            elevation: 8,
            shadowColor: Colors.black.withValues(alpha: 0.16),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      LucideIcons.shoppingCart,
                      color: Colors.white,
                      size: 25,
                    ),
                    SizedBox(height: 3),
                    Text(
                      'My Cart',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 4,
            child: Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Text(
                '2',
                style: TextStyle(
                  color: Color(0xFF078D92),
                  fontSize: 12,
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
