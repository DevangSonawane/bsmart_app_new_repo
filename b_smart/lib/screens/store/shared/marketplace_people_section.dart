// PEOPLE tab of the marketplace home ("iPhone 18 Pro - 7" in the Bsmart
// Figma file). There is no creator directory endpoint, so creators are
// derived from the live marketplace catalog: every listing carries its owner
// under `user_id` ({_id, full_name, username, avatar_url}).
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../api/follows_api.dart';
import '../../../services/supabase_service.dart';
import '../store_models.dart';
import 'marketplace_creator_page.dart';
import 'marketplace_figma_home.dart';
import 'store_shared_widgets.dart';

const _asset = 'assets/store/marketplace/home';

// ─────────────────────────── Data ───────────────────────────

class MkCreator {
  final String id;
  final String name;
  final String avatarUrl;
  final bool verified;
  final String mainCategory;
  final Set<String> categories;
  final int productCount;
  final int serviceCount;
  final double? rating;
  final int reviews;
  final DateTime? lastListedAt;

  const MkCreator({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.verified,
    required this.mainCategory,
    required this.categories,
    required this.productCount,
    required this.serviceCount,
    required this.rating,
    required this.reviews,
    required this.lastListedAt,
  });

  int get offerings => productCount + serviceCount;

  String get subtitle =>
      mainCategory.isEmpty ? 'Creator' : '$mainCategory Creator';

  /// Red dot on the avatar: listed something in the last 7 days.
  bool get hasNewListing =>
      lastListedAt != null &&
      DateTime.now().difference(lastListedAt!).inDays <= 7;
}

Map<String, dynamic>? _ownerOf(Map<String, dynamic> raw) {
  for (final key in const [
    'user_id',
    'influencer',
    'seller',
    'owner',
    'user'
  ]) {
    final v = raw[key];
    if (v is Map) return Map<String, dynamic>.from(v);
  }
  return null;
}

String _ownerId(Map<String, dynamic> raw, Map<String, dynamic>? owner) {
  final fromMap = (owner?['_id'] ?? owner?['id'])?.toString().trim() ?? '';
  if (fromMap.isNotEmpty) return fromMap;
  for (final key in const [
    'user_id',
    'influencer_id',
    'seller_id',
    'owner_id'
  ]) {
    final v = raw[key];
    if (v is String && v.trim().isNotEmpty) return v.trim();
  }
  return '';
}

/// Groups catalog listings by owner, most offerings first.
List<MkCreator> mkCreatorsFromCatalog(
  List<StoreMockCatalogItem> products,
  List<StoreMockCatalogItem> services,
) {
  final byId = <String, _CreatorAcc>{};
  void add(StoreMockCatalogItem item, bool isProduct) {
    final owner = _ownerOf(item.raw);
    final id = _ownerId(item.raw, owner);
    if (id.isEmpty) return;
    final acc = byId.putIfAbsent(id, () => _CreatorAcc(id));
    if (owner != null) acc.absorbOwner(owner);
    acc.absorbItem(item, isProduct);
  }

  for (final p in products) {
    add(p, true);
  }
  for (final s in services) {
    add(s, false);
  }
  final out = byId.values.map((a) => a.build()).toList()
    ..sort((a, b) {
      final byCount = b.offerings.compareTo(a.offerings);
      if (byCount != 0) return byCount;
      return b.reviews.compareTo(a.reviews);
    });
  return out;
}

class _CreatorAcc {
  final String id;
  String name = '';
  String avatar = '';
  bool verified = false;
  final Map<String, int> categoryCounts = {};
  int products = 0;
  int services = 0;
  double ratingSum = 0;
  int ratingCount = 0;
  int reviews = 0;
  DateTime? last;

  _CreatorAcc(this.id);

  void absorbOwner(Map<String, dynamic> o) {
    if (name.isEmpty) {
      for (final k in const ['full_name', 'fullName', 'name', 'username']) {
        final s = o[k]?.toString().trim() ?? '';
        if (s.isNotEmpty) {
          name = s;
          break;
        }
      }
    }
    if (avatar.isEmpty) {
      for (final k in const ['avatar_url', 'avatarUrl', 'profile_picture']) {
        final s = o[k]?.toString().trim() ?? '';
        if (s.startsWith('http')) {
          avatar = s;
          break;
        }
      }
    }
    verified = verified ||
        o['is_verified'] == true ||
        o['verified'] == true ||
        o['isVerified'] == true;
  }

  void absorbItem(StoreMockCatalogItem item, bool isProduct) {
    isProduct ? products++ : services++;
    final c = item.category.trim();
    if (c.isNotEmpty) categoryCounts[c] = (categoryCounts[c] ?? 0) + 1;
    final r = double.tryParse(item.rating);
    if (r != null && r > 0) {
      ratingSum += r;
      ratingCount++;
    }
    reviews += int.tryParse(item.reviews) ?? 0;
    final created = DateTime.tryParse(
        '${item.raw['created_at'] ?? item.raw['createdAt'] ?? ''}');
    if (created != null && (last == null || created.isAfter(last!))) {
      last = created;
    }
  }

  MkCreator build() {
    final main = categoryCounts.entries.isEmpty
        ? ''
        : (categoryCounts.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .first
            .key;
    return MkCreator(
      id: id,
      name: name.isEmpty ? 'Creator' : name,
      avatarUrl: avatar,
      verified: verified,
      mainCategory: main,
      categories: categoryCounts.keys.toSet(),
      productCount: products,
      serviceCount: services,
      rating: ratingCount == 0 ? null : ratingSum / ratingCount,
      reviews: reviews,
      lastListedAt: last,
    );
  }
}

/// Ids of accounts the signed-in user follows, loaded once per session.
class MkFollowing {
  MkFollowing._();
  static Future<Set<String>>? _future;

  /// Current ids; the home page listens so follows made on a creator page
  /// show up in "Your Favorite Creators" straight away.
  static final ValueNotifier<Set<String>> ids = ValueNotifier(const {});

  static Future<Set<String>> load() => _future ??= _fetch().then((v) {
        if (v.isNotEmpty) ids.value = {...ids.value, ...v};
        return ids.value;
      });

  static bool isFollowing(String id) => ids.value.contains(id);

  /// Follows or unfollows [id]; returns the new state. Optimistic, rolled
  /// back if the request fails.
  static Future<bool> toggle(String id) async {
    final was = isFollowing(id);
    void set(bool on) =>
        ids.value = on ? {...ids.value, id} : ({...ids.value}..remove(id));
    set(!was);
    try {
      if (was) {
        await FollowsApi().unfollow(id);
      } else {
        await FollowsApi().follow(id);
      }
      MkFollowerCounts.invalidate(id);
      return !was;
    } catch (_) {
      set(was);
      rethrow;
    }
  }

  static Future<Set<String>> _fetch() async {
    try {
      final rows = await FollowsApi().getAllFollowing();
      final ids = <String>{};
      for (final row in rows) {
        for (final key in const [
          'following',
          'followed',
          'user',
          'followedUser'
        ]) {
          final v = row[key];
          if (v is Map) {
            final id = (v['_id'] ?? v['id'])?.toString() ?? '';
            if (id.isNotEmpty) ids.add(id);
          } else if (v is String && v.isNotEmpty && key != 'user') {
            ids.add(v);
          }
        }
        for (final key in const [
          'followedUserId',
          'following_id',
          'followingId'
        ]) {
          final v = row[key]?.toString() ?? '';
          if (v.isNotEmpty) ids.add(v);
        }
        final own = (row['_id'] ?? row['id'])?.toString() ?? '';
        if (own.isNotEmpty) ids.add(own);
      }
      return ids;
    } on Exception catch (_) {
      _future = null; // retry on the next visit
      return <String>{};
    }
  }
}

/// Follower counts, fetched lazily per creator and kept for the session.
class MkFollowerCounts {
  MkFollowerCounts._();
  static final Map<String, Future<int>> _cache = {};
  // Same source the public profile screen uses (the follower list length);
  // the dedicated /followers/count endpoint is not used anywhere in the app.
  static void invalidate(String userId) => _cache.remove(userId);

  static Future<int> of(String userId) => _cache.putIfAbsent(
      userId, () => SupabaseService().getFollowersCount(userId));
}

String mkCompactCount(int n) {
  if (n >= 1000000) {
    final v = n / 1000000;
    return '${v.toStringAsFixed(v >= 10 ? 0 : 1).replaceAll('.0', '')}M';
  }
  if (n >= 1000) {
    final v = n / 1000;
    return '${v.toStringAsFixed(v >= 10 ? 0 : 1).replaceAll('.0', '')}K';
  }
  return '$n';
}

// ─────────────────────────── Shared bits ───────────────────────────

TextStyle _title() => GoogleFonts.sourceSans3(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: MkColors.ink,
      height: 1.25,
    );

class MkSectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;
  const MkSectionHeader({super.key, required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(child: Text(title, style: _title())),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'See All',
                  style: _title().copyWith(color: const Color(0xFFFA3F5E)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class MkRingAvatar extends StatelessWidget {
  final MkCreator creator;
  const MkRingAvatar({super.key, required this.creator});

  @override
  Widget build(BuildContext context) {
    final initial = creator.name.isEmpty
        ? '?'
        : creator.name.characters.first.toUpperCase();
    return Container(
      width: 70,
      height: 70,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFFA3F5E)),
      ),
      child: ClipOval(
        child: creator.avatarUrl.isEmpty
            ? ColoredBox(
                color: const Color(0xFF1B1F4A),
                child: Center(
                  child: Text(initial,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700)),
                ),
              )
            : StoreItemImage(
                imageUrl: creator.avatarUrl,
                icon: LucideIcons.user,
                fit: BoxFit.cover,
                debugLabel: 'mk-creator-avatar',
              ),
      ),
    );
  }
}

/// Owner (creator) id of a catalog listing.
String mkOwnerIdOf(Map<String, dynamic> raw) => _ownerId(raw, _ownerOf(raw));

/// Opens the creator page (Figma "iPhone 18 Pro - 9").
void mkOpenCreatorStore(BuildContext context, MkCreator creator) {
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => MkCreatorPage(creator: creator),
  ));
}

// ─────────────────────────── Your Favorite Creators ───────────────────────────

class MkFavoriteCreators extends StatelessWidget {
  final List<MkCreator> creators;
  final VoidCallback onSeeAll;
  const MkFavoriteCreators(
      {super.key, required this.creators, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MkSectionHeader(title: 'Your Favorite Creators', onSeeAll: onSeeAll),
        const SizedBox(height: 21),
        SizedBox(
          height: 119,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            itemCount: creators.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, i) {
              final c = creators[i];
              return GestureDetector(
                onTap: () => mkOpenCreatorStore(context, c),
                child: SizedBox(
                  width: 100,
                  child: Column(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          MkRingAvatar(creator: c),
                          if (c.hasNewListing)
                            Positioned(
                              right: -2,
                              top: 4,
                              child: Container(
                                width: 18,
                                height: 18,
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Color(0xFFFA3F5E),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        c.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.sourceSans3(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: MkColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        c.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.roboto(
                            fontSize: 12, color: MkColors.subtle),
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

// ─────────────────────────── Creators by categories ───────────────────────────

class MkCreatorCategory {
  final String title;
  final String subtitle;
  final String asset;

  /// Art offset relative to the card (it spills over the top / text panel).
  final Offset artOffset;
  final List<String> keywords;
  const MkCreatorCategory(
      this.title, this.subtitle, this.asset, this.artOffset, this.keywords);

  bool matches(MkCreator c) => c.categories.any((cat) {
        final l = cat.toLowerCase();
        return keywords.any(l.contains);
      });
}

const mkCreatorCategories = <MkCreatorCategory>[
  MkCreatorCategory(
      'Fashion',
      'Clothing & Accessories',
      'fashion',
      Offset(87, -9),
      ['fashion', 'cloth', 'apparel', 'wear', 'footwear', 'accessor']),
  MkCreatorCategory('Tech', 'Gadgets & repair', 'tech', Offset(73, -7),
      ['tech', 'electronic', 'gadget', 'mobile', 'laptop', 'computer']),
  MkCreatorCategory('Beauty', 'Cares & Salon at home', 'beauty',
      Offset(95, -13), ['beauty', 'salon', 'makeup', 'skin', 'hair', 'care']),
  MkCreatorCategory('Services', 'Cleaning & Repair', 'services', Offset(87, -9),
      ['service', 'clean', 'repair', 'plumb', 'electric']),
  MkCreatorCategory('Education', 'Classes & Coaching', 'education',
      Offset(95, -8), ['education', 'class', 'coach', 'tutor', 'course']),
  MkCreatorCategory('Events', 'Parties & Celebrations', 'events',
      Offset(83, -6), ['event', 'party', 'celebrat', 'wedding', 'photo']),
];

class MkCreatorsByCategory extends StatelessWidget {
  final MkCreatorCategory? selected;
  final ValueChanged<MkCreatorCategory> onTap;
  final VoidCallback onSeeAll;
  const MkCreatorsByCategory({
    super.key,
    required this.selected,
    required this.onTap,
    required this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < mkCreatorCategories.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: 19));
      rows.add(Row(
        children: [
          Expanded(child: _card(mkCreatorCategories[i])),
          const SizedBox(width: 16),
          Expanded(child: _card(mkCreatorCategories[i + 1])),
        ],
      ));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MkSectionHeader(title: 'Creators by categories', onSeeAll: onSeeAll),
        const SizedBox(height: 33),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: rows),
        ),
      ],
    );
  }

  Widget _card(MkCreatorCategory cat) {
    final isSelected = selected?.title == cat.title;
    return GestureDetector(
      onTap: () => onTap(cat),
      child: SizedBox(
        height: 95,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFE73A57)
                        .withValues(alpha: isSelected ? 1 : 0.5),
                    width: isSelected ? 1.6 : 1,
                  ),
                  boxShadow: const [
                    BoxShadow(
                        color: MkColors.shadow,
                        blurRadius: 10,
                        offset: Offset(0, 4)),
                  ],
                ),
              ),
            ),
            Positioned(
              left: cat.artOffset.dx,
              top: cat.artOffset.dy,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Image.asset(
                  '$_asset/creatorcat_${cat.asset}.webp',
                  fit: BoxFit.fill,
                ),
              ),
            ),
            Positioned(
              left: 8,
              top: 15,
              width: 79,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cat.title,
                    style: GoogleFonts.sourceSans3(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: MkColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    cat.subtitle,
                    maxLines: 2,
                    style: GoogleFonts.roboto(
                      fontSize: 12,
                      color: MkColors.subtle,
                      height: 1.58,
                    ),
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

// ─────────────────────────── Popular Creators ───────────────────────────

enum MkCreatorFilter { all, products, services }

class MkPopularCreators extends StatelessWidget {
  final List<MkCreator> creators;
  final MkCreatorFilter filter;
  final ValueChanged<MkCreatorFilter> onFilter;
  final MkCreatorCategory? category;
  final VoidCallback onClearCategory;
  final VoidCallback onSeeAll;

  const MkPopularCreators({
    super.key,
    required this.creators,
    required this.filter,
    required this.onFilter,
    required this.category,
    required this.onClearCategory,
    required this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, bool selected, VoidCallback onTap,
        {bool closable = false}) {
      return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: ShapeDecoration(
            color: selected
                ? const Color(0xFFFA3F5E).withValues(alpha: 0.10)
                : Colors.white,
            shape: StadiumBorder(
              side: BorderSide(
                color: selected
                    ? const Color(0xFFFA3F5E)
                    : const Color(0xFF3B3B3B),
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                  color: selected ? const Color(0xFFFA3F5E) : MkColors.ink,
                ),
              ),
              if (closable) ...[
                const SizedBox(width: 6),
                const Icon(LucideIcons.x, size: 14, color: Color(0xFFFA3F5E)),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MkSectionHeader(title: 'Popular Creators', onSeeAll: onSeeAll),
        const SizedBox(height: 16),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            children: [
              if (category != null) ...[
                chip(category!.title, true, onClearCategory, closable: true),
                const SizedBox(width: 10),
              ],
              chip('All', filter == MkCreatorFilter.all,
                  () => onFilter(MkCreatorFilter.all)),
              const SizedBox(width: 10),
              chip('Products', filter == MkCreatorFilter.products,
                  () => onFilter(MkCreatorFilter.products)),
              const SizedBox(width: 10),
              chip('Services', filter == MkCreatorFilter.services,
                  () => onFilter(MkCreatorFilter.services)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (creators.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: StoreEmptyState(
              icon: LucideIcons.users,
              title: 'No creators here yet',
              body:
                  'Creators who publish listings in this category will show up here.',
            ),
          )
        else
          for (var i = 0; i < creators.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: MkCreatorCard(creator: creators[i]),
            ),
          ],
      ],
    );
  }
}

class MkCreatorCard extends StatelessWidget {
  final MkCreator creator;
  const MkCreatorCard({super.key, required this.creator});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => mkOpenCreatorStore(context, creator),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
                color: MkColors.shadow, blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                MkRingAvatar(creator: creator),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              creator.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.notoSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: MkColors.ink,
                              ),
                            ),
                          ),
                          if (creator.verified) ...[
                            const SizedBox(width: 5),
                            const Icon(Icons.verified,
                                size: 16, color: Color(0xFF22A447)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        creator.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.notoSans(
                            fontSize: 12, color: MkColors.subtle),
                      ),
                      const SizedBox(height: 4),
                      FutureBuilder<int>(
                        future: MkFollowerCounts.of(creator.id),
                        builder: (context, snap) {
                          final n = snap.data;
                          return Text(
                            n == null
                                ? ' '
                                : n < 0
                                    ? ''
                                    : '${mkCompactCount(n)} Follower${n == 1 ? '' : 's'}',
                            style: GoogleFonts.notoSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFFFA3F5E),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: const Color(0xFFFA3F5E),
                  shape: const StadiumBorder(),
                  child: InkWell(
                    onTap: () => mkOpenCreatorStore(context, creator),
                    customBorder: const StadiumBorder(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Text(
                        'Visit Store',
                        style: GoogleFonts.redHatDisplay(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFDFE8E9),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${creator.offerings} Offering${creator.offerings == 1 ? '' : 's'}',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 14, color: MkColors.ink),
                    ),
                  ),
                  // Always shown, as in Figma; 0.0 (0) until listings are rated.
                  ...[
                    const Icon(Icons.star_rounded,
                        size: 20, color: Color(0xFFFFAC38)),
                    const SizedBox(width: 2),
                    Text(
                      '${(creator.rating ?? 0).toStringAsFixed(1)} (${creator.reviews})',
                      style: GoogleFonts.notoSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF878787),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Post your Services ───────────────────────────

class MkPostServicesBanner extends StatelessWidget {
  final VoidCallback onSeeBenefits;
  const MkPostServicesBanner({super.key, required this.onSeeBenefits});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Container(
        height: 175,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF9EC1F0),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Post your Services',
              style: GoogleFonts.sourceSans3(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: MkColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Reach new customers and earn from your skills on bSmart.',
              style: GoogleFonts.roboto(fontSize: 12, color: MkColors.body),
            ),
            const SizedBox(height: 12),
            MkPillButton(label: 'See Benefits', onTap: onSeeBenefits),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── See All page ───────────────────────────

class MkCreatorListPage extends StatelessWidget {
  final String title;
  final List<MkCreator> creators;
  const MkCreatorListPage(
      {super.key, required this.title, required this.creators});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(title, style: _title()),
      ),
      body: creators.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: StoreEmptyState(
                  icon: LucideIcons.users,
                  title: 'No creators yet',
                  body:
                      'Creators will show up here once they publish listings.',
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: creators.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, i) => MkCreatorCard(creator: creators[i]),
            ),
    );
  }
}
