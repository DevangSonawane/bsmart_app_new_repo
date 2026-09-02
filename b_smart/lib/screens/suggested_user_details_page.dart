import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../api/api_client.dart';
import '../api/follows_api.dart';
import '../api/users_api.dart';
import '../api/suggestions_api.dart';
import '../utils/current_user.dart';
import '../utils/url_helper.dart';
import '../widgets/safe_network_image.dart';

class SuggestedUserDetailsPage extends StatefulWidget {
  const SuggestedUserDetailsPage({super.key});

  @override
  State<SuggestedUserDetailsPage> createState() =>
      _SuggestedUserDetailsPageState();
}

class _SuggestedUserDetailsPageState extends State<SuggestedUserDetailsPage> {
  final SuggestionsApi _suggestionsApi = SuggestionsApi();
  final FollowsApi _followsApi = FollowsApi();
  final UsersApi _usersApi = UsersApi();

  bool _loading = true;
  String? _error;
  String? _currentUserId;
  Map<String, String>? _imageHeaders;
  List<_SuggestedUserEntry> _people = const [];
  _SuggestedUserEntry? _heroPerson;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load({bool rotateHero = false}) async {
    if (!mounted) return;
    final previousHeroId = _heroPerson?.id.trim() ?? '';
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = await ApiClient().getToken();
      final currentUserId = (await CurrentUser.id)?.trim() ?? '';
      if (token != null && token.trim().isNotEmpty) {
        _imageHeaders = <String, String>{'Authorization': 'Bearer $token'};
      }
      _currentUserId = currentUserId.isEmpty ? null : currentUserId;

      final rawPeople = await _suggestionsApi.getUserSuggestions(limit: 40);
      final normalized = <_SuggestedUserEntry>[];
      for (final raw in rawPeople) {
        final entry = _SuggestedUserEntry.fromMap(
          raw,
          currentUserId: _currentUserId,
        );
        if (entry == null) continue;
        normalized.add(entry);
      }

      final ids = normalized.map((e) => e.id).toList();
      if (ids.isNotEmpty) {
        try {
          final statuses = await _followsApi.bulkCheckFollowStatus(ids);
          final statusMap = <String, Map<String, dynamic>>{};
          for (final status in statuses) {
            final sid = _pickString(status, const [
              'userId',
              'user_id',
              'followedUserId',
              'followed_user_id',
              'id',
              '_id',
            ]);
            if (sid.isNotEmpty) statusMap[sid] = status;
          }

          for (var i = 0; i < normalized.length; i++) {
            final entry = normalized[i];
            final status = statusMap[entry.id];
            if (status == null) continue;
            normalized[i] = entry.copyWith(
              isFollowing: _boolOf(
                  status,
                  const [
                    'isFollowing',
                    'is_following',
                    'following',
                    'isFollowingMe',
                  ],
                  fallback: entry.isFollowing),
            );
          }
        } catch (_) {
          // If status lookup fails, keep the base suggestion list.
        }
      }

      _SuggestedUserEntry? heroPerson;
      if (normalized.isNotEmpty) {
        heroPerson = _pickHeroPerson(
          normalized,
          avoidId: rotateHero ? previousHeroId : '',
        );
        try {
          final profileResult = await Future.wait([
            _usersApi.getUserProfile(heroPerson.id),
            _usersApi.getUserProfileContent(heroPerson.id),
          ]);
          final profile = profileResult[0];
          final content = profileResult[1];
          final mergedProfile = _mergeProfilePayloads(profile, content);
          if (mergedProfile.isNotEmpty) {
            final merged = _heroEntryFromProfile(mergedProfile);
            if (merged != null) {
              heroPerson = merged;
            }
          }
        } catch (_) {
          // Keep the suggestion fallback if the profile fetch fails.
        }
      }

      if (!mounted) return;
      setState(() {
        _people = normalized;
        _heroPerson = heroPerson;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load suggested users.';
        _loading = false;
      });
    }
  }

  void _dismiss(String id) {
    setState(() {
      _people = _people.where((e) => e.id != id).toList(growable: false);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Removed from suggestions')),
    );
  }

  void _openProfile(String userId) {
    if (userId.trim().isEmpty) return;
    Navigator.of(context).pushNamed('/profile/$userId');
  }

  void _openDiscover() {
    Navigator.of(context).pushNamed('/search');
  }

  void _openMessages() {
    Navigator.of(context).pushNamed('/messages');
  }

  @override
  Widget build(BuildContext context) {
    final people = _people;
    final hero = _heroPerson ?? (people.isNotEmpty ? people.first : null);
    final cards = hero == null
        ? people
        : people
            .where((person) => person.id != hero.id)
            .toList(growable: false);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F2ED),
      body: SafeArea(
        left: false,
        right: false,
        child: RefreshIndicator(
          onRefresh: () => _load(rotateHero: true),
          color: const Color(0xFF111318),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(0, 18, 0, 28),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: _Header(
                  onBack: () => Navigator.of(context).maybePop(),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: _loading
                    ? const _HeroPlaceholder()
                    : hero != null
                        ? _HeroSuggestionCard(
                            person: hero,
                            imageHeaders: _imageHeaders,
                            onTap: () => _openProfile(hero.id),
                          )
                        : _EmptyHero(
                            message: _error ??
                                'No suggested users available right now.',
                            onRetry: _load,
                          ),
              ),
              const SizedBox(height: 26),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Text(
                  'Do you know these?',
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1B1B1F),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_loading)
                const _CardsPlaceholder()
              else if (cards.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Text(
                    'No more suggestions to show.',
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6D6B72),
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 148,
                  child: ListView.separated(
                    padding: const EdgeInsets.only(left: 18),
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: cards.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final person = cards[index];
                      return _SuggestedPersonCard(
                        person: person,
                        imageHeaders: _imageHeaders,
                        onDismiss: () => _dismiss(person.id),
                        onTap: () => _openProfile(person.id),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 34),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 58,
                        child: ElevatedButton(
                          onPressed: _openDiscover,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16181D),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(
                            'Discover',
                            style: GoogleFonts.montserrat(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: SizedBox(
                        height: 58,
                        child: OutlinedButton(
                          onPressed: _openMessages,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1B1B1F),
                            side: const BorderSide(
                              color: Color(0xFF1B1B1F),
                              width: 2.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(
                            'Messages',
                            style: GoogleFonts.montserrat(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

_SuggestedUserEntry _pickHeroPerson(
  List<_SuggestedUserEntry> people, {
  String avoidId = '',
}) {
  final trimmedAvoidId = avoidId.trim();
  if (trimmedAvoidId.isEmpty) {
    return people.first;
  }

  final avoidIndex =
      people.indexWhere((person) => person.id.trim() == trimmedAvoidId);
  if (avoidIndex == -1) return people.first;
  if (people.length == 1) return people.first;

  final nextIndex = (avoidIndex + 1) % people.length;
  if (people[nextIndex].id.trim() == trimmedAvoidId) {
    return people.firstWhere(
      (person) => person.id.trim() != trimmedAvoidId,
      orElse: () => people.first,
    );
  }
  return people[nextIndex];
}

class _Header extends StatelessWidget {
  final VoidCallback onBack;

  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onBack,
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(
              Icons.arrow_back_rounded,
              size: 24,
              color: Colors.black,
            ),
          ),
        ),
        const Spacer(),
        Text(
          'Suggested User Details',
          style: GoogleFonts.montserrat(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF202124),
          ),
        ),
        const Spacer(),
        const SizedBox(width: 46, height: 46),
      ],
    );
  }
}

class _HeroSuggestionCard extends StatelessWidget {
  final _SuggestedUserEntry person;
  final Map<String, String>? imageHeaders;
  final VoidCallback onTap;

  const _HeroSuggestionCard({
    required this.person,
    required this.imageHeaders,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = (person.avatarUrl ?? '').trim().isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(38),
        child: AspectRatio(
          aspectRatio: 0.92,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasImage)
                SafeNetworkImage(
                  url: person.avatarUrl!,
                  headers: imageHeaders,
                  fit: BoxFit.cover,
                  assumeRaster: true,
                  trustExtension: false,
                  placeholder: Container(
                    color: const Color(0xFFD9D2C6),
                  ),
                  errorWidget: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF5A4A3B), Color(0xFF1F2530)],
                      ),
                    ),
                  ),
                )
              else
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF6C5E50), Color(0xFF18202A)],
                    ),
                  ),
                ),
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Color(0x0A000000),
                      Color(0x6E000000),
                      Color(0xD8000000),
                    ],
                    stops: [0.0, 0.36, 0.72, 1.0],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (person.roleLabel.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Text(
                            person.roleLabel.toUpperCase(),
                            style: GoogleFonts.montserrat(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      const SizedBox(height: 10),
                      Text(
                        person.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cormorantGaramond(
                          color: Colors.white,
                          fontSize: 32,
                          height: 0.92,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (person.tagline.isNotEmpty)
                        Text(
                          person.tagline,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.montserrat(
                            color: Colors.white.withValues(alpha: 0.94),
                            fontSize: 14,
                            height: 1.28,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (person.location.isNotEmpty)
                            _MetaPill(
                              icon: Icons.location_on_outlined,
                              label: person.location,
                            ),
                          if (person.company.isNotEmpty)
                            _MetaPill(
                              icon: Icons.business_center_outlined,
                              label: person.company,
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (person.verified)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF134E2F),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xFF2FA15C)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF2FE26E),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Company verified',
                                style: GoogleFonts.montserrat(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (person.verified) const SizedBox(height: 10),
                      if (person.description.isNotEmpty)
                        Text(
                          person.description,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.montserrat(
                            color: Colors.white.withValues(alpha: 0.78),
                            fontSize: 13,
                            height: 1.36,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 19, color: Colors.white.withValues(alpha: 0.86)),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.montserrat(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _SuggestedPersonCard extends StatelessWidget {
  final _SuggestedUserEntry person;
  final Map<String, String>? imageHeaders;
  final VoidCallback onDismiss;
  final VoidCallback onTap;

  const _SuggestedPersonCard({
    required this.person,
    required this.imageHeaders,
    required this.onDismiss,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 116,
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE3E0DA)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: onDismiss,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F0EC),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFC5C2BA)),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 15,
                      color: Color(0xFF4A4A50),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 0),
            Container(
              width: 66,
              height: 66,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFF2F0EC),
              ),
              child: ClipOval(
                child: person.avatarUrl == null || person.avatarUrl!.isEmpty
                    ? Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF8C8A83), Color(0xFF525159)],
                          ),
                        ),
                      )
                    : SafeNetworkImage(
                        url: person.avatarUrl!,
                        headers: imageHeaders,
                        fit: BoxFit.cover,
                        assumeRaster: true,
                        trustExtension: false,
                        placeholder: Container(color: const Color(0xFFF0EBE4)),
                        errorWidget: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF8C8A83), Color(0xFF525159)],
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              person.displayName,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.montserrat(
                color: const Color(0xFF1F2024),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroPlaceholder extends StatelessWidget {
  const _HeroPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(42),
      child: AspectRatio(
        aspectRatio: 0.82,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF5A5349), Color(0xFF171C25)],
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _CardsPlaceholder extends StatelessWidget {
  const _CardsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 136,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 0),
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, __) => Container(
          width: 104,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE3E0DA)),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _EmptyHero extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _EmptyHero({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 420,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(42),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4E463D), Color(0xFF18202A)],
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            'Suggested User Details',
            style: GoogleFonts.cormorantGaramond(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: GoogleFonts.montserrat(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 16,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          TextButton(
            onPressed: onRetry,
            child: const Text(
              'Retry',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestedUserEntry {
  final String id;
  final String displayName;
  final String roleLabel;
  final String tagline;
  final String location;
  final String company;
  final String description;
  final String? avatarUrl;
  final String mutualsLabel;
  final bool verified;
  final bool isFollowing;

  const _SuggestedUserEntry({
    required this.id,
    required this.displayName,
    required this.roleLabel,
    required this.tagline,
    required this.location,
    required this.company,
    required this.description,
    required this.avatarUrl,
    required this.mutualsLabel,
    required this.verified,
    required this.isFollowing,
  });

  _SuggestedUserEntry copyWith({
    String? displayName,
    String? roleLabel,
    String? tagline,
    String? location,
    String? company,
    String? description,
    String? avatarUrl,
    String? mutualsLabel,
    bool? verified,
    bool? isFollowing,
  }) {
    return _SuggestedUserEntry(
      id: id,
      displayName: displayName ?? this.displayName,
      roleLabel: roleLabel ?? this.roleLabel,
      tagline: tagline ?? this.tagline,
      location: location ?? this.location,
      company: company ?? this.company,
      description: description ?? this.description,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      mutualsLabel: mutualsLabel ?? this.mutualsLabel,
      verified: verified ?? this.verified,
      isFollowing: isFollowing ?? this.isFollowing,
    );
  }

  static _SuggestedUserEntry? fromMap(
    Map<String, dynamic> raw, {
    String? currentUserId,
  }) {
    final u = _normalize(raw);
    final id = _pickString(u, const [
      'id',
      '_id',
      'userId',
      'user_id',
      'profileId',
      'profile_id',
    ]);
    if (id.isEmpty) return null;
    if ((currentUserId ?? '').trim().isNotEmpty &&
        id == currentUserId!.trim()) {
      return null;
    }

    final displayName = _pickString(u, const [
      'full_name',
      'fullName',
      'name',
      'displayName',
      'display_name',
    ]);
    final role = _pickString(u, const [
      'role',
      'user_role',
      'userRole',
      'type',
      'account_type',
      'accountType',
    ]);
    final company = _pickString(u, const [
      'company',
      'companyName',
      'company_name',
      'businessName',
      'business_name',
      'organization',
      'organisation',
      'workplace',
      'employer',
    ]);
    final location = _pickString(u, const [
      'location',
      'city',
      'current_city',
      'currentCity',
      'address',
      'region',
    ]);
    final bio = _pickString(u, const [
      'bio',
      'about',
      'summary',
      'headline',
      'tagline',
      'subtitle',
    ]);
    final mutuals = _mutualsLabelOf(u);
    final avatar = _pickString(u, const [
      'avatarUrl',
      'avatar_url',
      'profileImageUrl',
      'profile_image_url',
      'profilePhotoUrl',
      'profile_photo_url',
      'photoUrl',
      'photo_url',
      'avatar',
      'image',
      'picture',
    ]);
    final verified = _boolOf(u, const [
      'verified',
      'is_verified',
      'company_verified',
      'companyVerified',
      'isCompanyVerified',
      'is_company_verified',
    ]);
    final isFollowing = _boolOf(u, const [
      'isFollowing',
      'is_following',
      'following',
      'isFollowingMe',
    ]);

    final title = displayName;
    final tagline = bio;

    final pieces = <String>[];
    if (location.isNotEmpty) pieces.add(location);
    if (company.isNotEmpty) pieces.add(company);
    final description = pieces.isNotEmpty ? pieces.join(' · ') : '';

    return _SuggestedUserEntry(
      id: id,
      displayName: title,
      roleLabel: role,
      tagline: tagline,
      location: location,
      company: company,
      description: description,
      avatarUrl: avatar.isEmpty ? null : UrlHelper.absoluteUrl(avatar),
      mutualsLabel: mutuals,
      verified: verified,
      isFollowing: isFollowing,
    );
  }

  static Map<String, dynamic> _normalize(Map<String, dynamic> raw) {
    final embedded = raw['user'];
    if (embedded is Map) {
      return <String, dynamic>{
        ...raw,
        ...Map<String, dynamic>.from(embedded),
      };
    }
    return raw;
  }
}

_SuggestedUserEntry? _heroEntryFromProfile(Map<String, dynamic> profile) {
  final candidates = <Map<String, dynamic>>[
    profile,
    if (profile['user'] is Map)
      Map<String, dynamic>.from(profile['user'] as Map),
    if (profile['profile'] is Map)
      Map<String, dynamic>.from(profile['profile'] as Map),
    if (profile['data'] is Map)
      Map<String, dynamic>.from(profile['data'] as Map),
  ];

  String firstString(List<String> keys) {
    for (final candidate in candidates) {
      final value = _pickString(candidate, keys);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  bool firstBool(List<String> keys) {
    for (final candidate in candidates) {
      if (_boolOf(candidate, keys)) return true;
    }
    return false;
  }

  final id = firstString(const [
    'id',
    '_id',
    'userId',
    'user_id',
    'profileId',
    'profile_id',
  ]);
  if (id.isEmpty) return null;

  final displayName = firstString(const [
    'username',
    'userName',
    'handle',
    'full_name',
    'fullName',
    'display_name',
    'displayName',
    'name',
  ]);
  final role = firstString(const [
    'role',
    'user_role',
    'userRole',
    'type',
    'account_type',
    'accountType',
  ]);
  final bio = firstString(const [
    'bio',
    'about',
    'summary',
    'headline',
    'tagline',
    'subtitle',
  ]);
  final avatar = firstString(const [
    'avatarUrl',
    'avatar_url',
    'profileImageUrl',
    'profile_image_url',
    'profilePhotoUrl',
    'profile_photo_url',
    'profile_picture',
    'profilePic',
    'profile_pic',
    'profilePicture',
    'photoUrl',
    'photo_url',
    'avatar',
    'image',
    'picture',
  ]);
  final safeName = _cleanProfileText(displayName);
  final safeRole = _cleanProfileText(role);
  final safeBio = _cleanProfileText(bio);
  final safeAvatar = _cleanProfileText(avatar);

  return _SuggestedUserEntry(
    id: id,
    displayName: safeName,
    roleLabel: safeRole,
    tagline: safeBio,
    location: '',
    company: '',
    description: '',
    avatarUrl: safeAvatar.isNotEmpty ? UrlHelper.absoluteUrl(safeAvatar) : null,
    mutualsLabel: '',
    verified: firstBool(const [
      'verified',
      'is_verified',
      'company_verified',
      'companyVerified',
      'isCompanyVerified',
      'is_company_verified',
    ]),
    isFollowing: false,
  );
}

Map<String, dynamic> _mergeProfilePayloads(
  Map<String, dynamic> primary,
  Map<String, dynamic> secondary,
) {
  final merged = <String, dynamic>{...secondary, ...primary};
  for (final key in ['user', 'profile', 'data']) {
    final primaryValue = primary[key];
    final secondaryValue = secondary[key];
    if (primaryValue is Map || secondaryValue is Map) {
      merged[key] = <String, dynamic>{
        if (secondaryValue is Map) ...Map<String, dynamic>.from(secondaryValue),
        if (primaryValue is Map) ...Map<String, dynamic>.from(primaryValue),
      };
    }
  }
  return merged;
}

String _cleanProfileText(String value) {
  final v = value.trim();
  if (v.isEmpty) return '';
  final lower = v.toLowerCase();
  const invalidExact = <String>{
    'string',
    'name',
    'title',
    'role',
    'suggested user',
    'bio',
    'avatar',
    'photo',
    'image',
    'picture',
    'location',
    'company',
    'lat long',
    'lat,long',
    'latitude',
    'longitude',
    'null',
    'undefined',
    'n/a',
    'na',
    '-',
    '--',
  };
  if (invalidExact.contains(lower)) return '';
  if (RegExp(r'^\d+(\.\d+)?\s*,\s*\d+(\.\d+)?$').hasMatch(lower)) {
    return '';
  }
  if (RegExp(r'^(lat|lng|lon|long|latitude|longitude)\b').hasMatch(lower)) {
    return '';
  }
  if (RegExp(r'^\s*\(?\s*-?\d+(\.\d+)?\s*[, ]\s*-?\d+(\.\d+)?\s*\)?\s*$')
      .hasMatch(lower)) {
    return '';
  }
  return v;
}

String _pickString(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return '';
}

bool _boolOf(Map<String, dynamic> map, List<String> keys,
    {bool fallback = false}) {
  for (final key in keys) {
    final value = map[key];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value == null) continue;
    final text = value.toString().trim().toLowerCase();
    if (text.isEmpty) continue;
    if (text == 'true' || text == '1' || text == 'yes' || text == 'y') {
      return true;
    }
    if (text == 'false' || text == '0' || text == 'no' || text == 'n') {
      return false;
    }
  }
  return fallback;
}

String _mutualsLabelOf(Map<String, dynamic> map) {
  final mutuals = _pickString(map, const [
    'mutual_friends_count',
    'mutualFriendsCount',
    'mutualCount',
    'mutuals',
    'mutualFriends',
  ]);
  if (mutuals.isNotEmpty) {
    final parsed = int.tryParse(mutuals);
    if (parsed != null) {
      return '$parsed mutual${parsed == 1 ? '' : 's'}';
    }
    if (mutuals.toLowerCase().contains('mutual')) return mutuals;
    return '$mutuals mutual${mutuals == '1' ? '' : 's'}';
  }
  return '';
}