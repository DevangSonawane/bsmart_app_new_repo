import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/feed_post_model.dart';
import '../utils/url_helper.dart';
import '../widgets/post_card.dart';
import '../widgets/posts_grid.dart';
import '../widgets/safe_network_image.dart';
import 'messaging_screen.dart';

enum ProfileHomeSection {
  overview,
  content,
}

enum ProfileContentTab {
  posts,
  reels,
  tweets,
  stories,
}

class ProfileHomePage extends StatefulWidget {
  final Map<String, dynamic>? profile;
  final String username;
  final String? fullName;
  final String? bio;
  final String? avatarUrl;
  final Map<String, String>? avatarHeaders;
  final int postsCount;
  final int followers;
  final int following;
  final int likesCount;
  final bool isMe;
  final bool isValidated;
  final List<FeedPost> posts;
  final List<FeedPost> reels;
  final List<FeedPost> tweets;
  final List<FeedPost> promotes;
  final VoidCallback? onOpenStories;
  final Future<void> Function(FeedPost post)? onDeletePromote;
  final VoidCallback? onBack;
  final VoidCallback? onMenu;
  final VoidCallback? onFollow;
  final VoidCallback? onMessage;
  final VoidCallback? onShare;

  const ProfileHomePage({
    super.key,
    required this.profile,
    required this.username,
    required this.fullName,
    required this.bio,
    required this.avatarUrl,
    required this.avatarHeaders,
    required this.postsCount,
    required this.followers,
    required this.following,
    required this.likesCount,
    required this.isMe,
    required this.isValidated,
    required this.posts,
    required this.reels,
    required this.tweets,
    required this.promotes,
    required this.onOpenStories,
    this.onDeletePromote,
    required this.onBack,
    required this.onMenu,
    required this.onFollow,
    required this.onMessage,
    required this.onShare,
  });

  static const Color _goldSoft = Color(0xFFFFD77A);

  @override
  State<ProfileHomePage> createState() => _ProfileHomePageState();
}

class _ProfileHomePageState extends State<ProfileHomePage> {
  ProfileHomeSection _section = ProfileHomeSection.overview;
  ProfileContentTab _contentTab = ProfileContentTab.posts;

  static const Color _gold = Color(0xFFD4AF37);
  static const Color _goldSoft = Color(0xFFFFD77A);
  static const Color _panel = Color(0xFF101010);
  static const String _missingText = 'Null';

  Map<String, dynamic>? get profile => widget.profile;
  String get username => widget.username;
  String? get fullName => widget.fullName;
  String? get bio => widget.bio;
  String? get avatarUrl => widget.avatarUrl;
  Map<String, String>? get avatarHeaders => widget.avatarHeaders;
  int get postsCount => widget.postsCount;
  int get followers => widget.followers;
  int get following => widget.following;
  int get likesCount => widget.likesCount;
  bool get isMe => widget.isMe;
  bool get isValidated => widget.isValidated;
  List<FeedPost> get posts => widget.posts;
  List<FeedPost> get reels => widget.reels;
  List<FeedPost> get tweets => widget.tweets;
  List<FeedPost> get promotes => widget.promotes;
  VoidCallback? get onOpenStories => widget.onOpenStories;
  Future<void> Function(FeedPost post)? get onDeletePromote =>
      widget.onDeletePromote;
  VoidCallback? get onBack => widget.onBack;
  VoidCallback? get onMenu => widget.onMenu;
  VoidCallback? get onFollow => widget.onFollow;
  VoidCallback? get onMessage => widget.onMessage;
  VoidCallback? get onShare => widget.onShare;

  String _stringValue(List<String> keys, {String fallback = ''}) {
    final source = profile;
    if (source == null) return fallback;
    for (final key in keys) {
      dynamic value = source;
      for (final part in key.split('.')) {
        if (value is! Map) {
          value = null;
          break;
        }
        value = value[part];
      }
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  List<String> _listValue(List<String> keys, {required List<String> fallback}) {
    final source = profile;
    if (source == null) return fallback;
    for (final key in keys) {
      final value = source[key];
      if (value is List) {
        final items =
            value.map((e) => e.toString().trim()).where((e) => e.isNotEmpty);
        final result = items.toList();
        if (result.isNotEmpty) return result;
      } else if (value is String && value.trim().isNotEmpty) {
        final result = value
            .split(RegExp(r'[,|/]'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        if (result.isNotEmpty) return result;
      }
    }
    return fallback;
  }

  String _titleCase(String text) {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return cleaned;
    return cleaned
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) {
      if (part.length <= 1) return part.toUpperCase();
      return part[0].toUpperCase() + part.substring(1).toLowerCase();
    }).join(' ');
  }

  String _location() {
    final direct = _stringValue([
      'location',
      'city',
      'hometown',
      'address',
      'place',
    ], fallback: '');
    if (direct.isNotEmpty) return _titleCase(direct);
    final city = _stringValue(['city']);
    final state = _stringValue(['state', 'province']);
    final country = _stringValue(['country']);
    final parts = <String>[city, state, country]
        .where((part) => part.trim().isNotEmpty)
        .toList();
    if (parts.isNotEmpty) return parts.join(', ');
    return _missingText;
  }

  String _dateLine() {
    return _stringValue([
      'date_of_birth',
      'dob',
      'birth_date',
      'birthdate',
      'dateOfBirth',
    ], fallback: _missingText);
  }

  String _profession() {
    return _stringValue([
      'profession',
      'contact.profession',
      'occupation',
      'job_title',
      'designation',
      'class',
      'grade',
      'account_type',
      'accountType',
      'role',
    ], fallback: _missingText);
  }

  String _aboutText() {
    final direct = bio?.trim().isNotEmpty == true
        ? bio!.trim()
        : _stringValue([
            'about_me',
            'aboutMe',
            'bio',
            'description',
            'intro',
          ], fallback: '');
    if (direct.isNotEmpty) return direct;
    return _missingText;
  }

  List<String> _hobbies() {
    return _listValue(
      ['hobbies', 'interests', 'tags', 'favoriteThings'],
      fallback: const [],
    );
  }

  int _likesFallback() {
    if (likesCount > 0) return likesCount;
    return 0;
  }

  bool _isFollowed() {
    final source = profile;
    if (source == null) return false;
    final value = source['is_followed_by_me'] ??
        source['isFollowing'] ??
        source['is_following'] ??
        source['followed_by_me'] ??
        source['followed'];
    if (value is bool) return value;
    if (value == null) return false;
    final text = value.toString().trim().toLowerCase();
    return text == 'true' || text == '1' || text == 'yes' || text == 'followed';
  }

  void _openContentSection() {
    if (!isMe) return;
    setState(() {
      _section = ProfileHomeSection.content;
      _contentTab = ProfileContentTab.posts;
    });
  }

  void _showOverviewSection() {
    setState(() => _section = ProfileHomeSection.overview);
  }

  void _openMessagingPage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MessagingScreen()),
    );
  }

  void _selectContentTab(ProfileContentTab tab) {
    if (_contentTab == tab) return;
    setState(() => _contentTab = tab);
  }

  String _profileSummary() {
    final direct = _stringValue([
      'tagline',
      'headline',
      'status',
      'bio',
      'about_me',
      'aboutMe',
    ], fallback: '');
    if (direct.isNotEmpty) return direct;
    return _missingText;
  }

  Widget _topIconButton({
    required BuildContext context,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.black.withValues(alpha: 0.50),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }

  Future<void> _showQuickActionsSheet(
    BuildContext buttonContext,
    List<String> hobbies,
  ) async {
    final buttonBox = buttonContext.findRenderObject() as RenderBox?;
    final overlayBox =
        Overlay.of(buttonContext).context.findRenderObject() as RenderBox?;
    const menuWidth = 190.0;
    final position = buttonBox != null && overlayBox != null
        ? buttonBox.localToGlobal(Offset.zero, ancestor: overlayBox)
        : Offset.zero;
    final left = buttonBox != null && overlayBox != null
        ? (position.dx + buttonBox.size.width - menuWidth).clamp(
            12.0,
            overlayBox.size.width - menuWidth - 12.0,
          )
        : 12.0;
    final top = buttonBox != null
        ? position.dy + buttonBox.size.height + 8.0
        : MediaQuery.of(buttonContext).padding.top + 62;

    await showGeneralDialog<void>(
      context: buttonContext,
      barrierDismissible: true,
      barrierLabel: 'Quick actions',
      barrierColor: Colors.black.withValues(alpha: 0.20),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              Positioned(
                left: left,
                top: top,
                child: Material(
                  color: const Color(0xFF111111),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: menuWidth,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _quickActionRow(
                          context: dialogContext,
                          icon: Icons.settings_rounded,
                          iconColor: _gold,
                          title: 'Settings',
                          onTap: () {
                            Navigator.of(dialogContext).pop();
                            onMenu?.call();
                          },
                        ),
                        const SizedBox(height: 8),
                        _quickActionRow(
                          context: dialogContext,
                          icon: Icons.favorite_rounded,
                          iconColor: _goldSoft,
                          title: 'Hobbies',
                          onTap: () {
                            Navigator.of(dialogContext).pop();
                            _showHobbiesSheet(buttonContext, hobbies);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.965, end: 1.0).animate(curved),
            alignment: Alignment.topRight,
            child: child,
          ),
        );
      },
    );
  }

  Widget _quickActionRow({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.03),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showHobbiesSheet(
    BuildContext context,
    List<String> hobbies,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Hobbies & Interests',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final hobby in hobbies)
                      Chip(
                        label: Text(hobby),
                        backgroundColor: Colors.white.withValues(alpha: 0.04),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                        labelStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sectionTitle(String title) {
    return Row(
      children: [
        const Icon(LucideIcons.user, size: 16, color: _gold),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: _gold,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _goldChip({
    required IconData icon,
    required String label,
    bool compact = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 14 : 16, color: _gold),
          SizedBox(width: compact ? 6 : 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: TextStyle(
                color: Colors.white70,
                fontSize: compact ? 12.0 : 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileInfoTile({
    required IconData icon,
    required String label,
    required String value,
    Color iconColor = _gold,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statsCard(BuildContext context) {
    final statItems = <_StatItem>[
      _StatItem('Posts', postsCount.toString(), LucideIcons.grid2x2),
      _StatItem('Followers', _formatCompact(followers), LucideIcons.users),
      _StatItem('Following', _formatCompact(following), LucideIcons.userRound),
      _StatItem('Likes', _formatCompact(_likesFallback()), LucideIcons.heart),
    ];

    return Container(
      padding: const EdgeInsets.all(1.2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFFF7D67A),
            Color(0xFFB88414),
            Color(0xFFFFE3A0),
            Color(0xFF7A5310),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.30, 0.68, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: _gold.withValues(alpha: 0.14),
            blurRadius: 18,
            spreadRadius: 0.2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF201309),
                      Color(0xFF0C0C0C),
                      Color(0xFF130F0B),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            Positioned(
              top: -46,
              left: -28,
              child: Container(
                width: 142,
                height: 142,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFFFF1C7).withValues(alpha: 0.26),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.08),
                        Colors.transparent,
                        Colors.transparent,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
              child: Row(
                children: [
                  for (var i = 0; i < statItems.length; i++) ...[
                    Expanded(
                      child: i == 0 && isMe
                          ? Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(18),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: _openContentSection,
                                child: _StatTile(
                                  item: statItems[i],
                                ),
                              ),
                            )
                          : _StatTile(item: statItems[i]),
                    ),
                    if (i != statItems.length - 1)
                      Container(
                        width: 1,
                        height: 68,
                        color: Colors.white.withValues(alpha: 0.10),
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

  Widget _buildContentSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildContentTabs(),
        const SizedBox(height: 6),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: KeyedSubtree(
            key: ValueKey(_contentTab),
            child: _buildContentTabBody(context),
          ),
        ),
      ],
    );
  }

  Widget _buildContentTabs() {
    const tabs = <_ProfileTabData>[
      _ProfileTabData(
        tab: ProfileContentTab.posts,
        label: 'Posts',
        icon: LucideIcons.grid2x2,
      ),
      _ProfileTabData(
        tab: ProfileContentTab.reels,
        label: 'bSparks',
        icon: LucideIcons.clapperboard,
      ),
      _ProfileTabData(
        tab: ProfileContentTab.tweets,
        label: 'Buzz',
        icon: LucideIcons.messageCircle,
      ),
      _ProfileTabData(
        tab: ProfileContentTab.stories,
        label: 'Campaigns',
        icon: LucideIcons.sparkles,
      ),
    ];

    const activeColor = Color(0xFFB07CFF);
    const inactiveColor = Color(0xFFB9A9D4);
    final activeIndex = _contentTabIndex;

    return LayoutBuilder(
      builder: (context, constraints) {
        final tabWidth = constraints.maxWidth / tabs.length;
        return SizedBox(
          height: 38,
          child: Stack(
            children: [
              Row(
                children: [
                  for (var i = 0; i < tabs.length; i++)
                    Expanded(
                      child: _contentTabButton(
                        tabs[i],
                        active: _contentTab == tabs[i].tab,
                        activeColor: activeColor,
                        inactiveColor: inactiveColor,
                        onTap: () => _selectContentTab(tabs[i].tab),
                      ),
                    ),
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                left: activeIndex * tabWidth + 20,
                bottom: 0,
                width: tabWidth - 40,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: activeColor,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.35),
                        blurRadius: 10,
                        spreadRadius: 0.5,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _contentTabButton(
    _ProfileTabData tab, {
    required bool active,
    required Color activeColor,
    required Color inactiveColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              tab.icon,
              size: 13,
              color:
                  active ? activeColor : inactiveColor.withValues(alpha: 0.8),
            ),
            const SizedBox(width: 5),
            Text(
              tab.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color:
                    active ? activeColor : inactiveColor.withValues(alpha: 0.8),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  int get _contentTabIndex {
    switch (_contentTab) {
      case ProfileContentTab.posts:
        return 0;
      case ProfileContentTab.reels:
        return 1;
      case ProfileContentTab.tweets:
        return 2;
      case ProfileContentTab.stories:
        return 3;
    }
  }

  Widget _buildContentTabBody(BuildContext context) {
    switch (_contentTab) {
      case ProfileContentTab.posts:
        return _buildPostsTab(context, posts);
      case ProfileContentTab.reels:
        return _buildPostsTab(context, reels, emptyLabel: 'No bSparks yet');
      case ProfileContentTab.tweets:
        return _buildTweetsTab(context);
      case ProfileContentTab.stories:
        return _buildStoriesTab(context);
    }
  }

  Widget _buildPostsTab(
    BuildContext context,
    List<FeedPost> items, {
    String emptyLabel = 'No posts yet',
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (items.isEmpty)
          _emptyContentState(
            title: emptyLabel,
            subtitle: 'Posts will appear here once they are available.',
            icon: LucideIcons.grid2x2,
          )
        else
          PostsGrid(
            posts: items,
            onTap: (post) {
              Navigator.of(context).pushNamed('/post/${post.id}');
            },
          ),
        const SizedBox(height: 18),
        _buildPostsActionCards(context),
      ],
    );
  }

  Widget _buildTweetsTab(BuildContext context) {
    if (tweets.isEmpty) {
      return _emptyContentState(
        title: 'No Buzz yet',
        subtitle: 'Buzz posts will appear here once they are available.',
        icon: LucideIcons.messageCircle,
      );
    }
    return Column(
      children: [
        for (final tweet in tweets)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PostCard(
              post: tweet,
              isOwnPost: isMe,
              onComment: () => Navigator.of(context)
                  .pushNamed('/post/${tweet.id}?type=tweet'),
              onUserTap: () {},
            ),
          ),
      ],
    );
  }

  Widget _buildStoriesTab(BuildContext context) {
    if (!isMe) {
      return _emptyContentState(
        title: 'Campaigns',
        subtitle: 'Campaign tools will appear here when available.',
        icon: LucideIcons.sparkles,
      );
    }
    final items = promotes;
    if (items.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _emptyContentState(
            title: 'No campaigns yet',
            subtitle: 'Your uploaded promote reels will appear here.',
            icon: LucideIcons.sparkles,
          ),
          const SizedBox(height: 18),
          _buildPostsActionCards(context),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 280,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            itemCount: items.length,
            itemBuilder: (context, index) {
              return SizedBox(
                width: 172,
                child: _CampaignPromoCard(
                  post: items[index],
                  isOwnProfile: isMe,
                  onMore: onDeletePromote == null
                      ? null
                      : () => _showCampaignActions(context, items[index]),
                  onTap: () => Navigator.of(context)
                      .pushNamed('/post/${items[index].id}'),
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(width: 12),
          ),
        ),
        const SizedBox(height: 18),
        _buildPostsActionCards(context),
      ],
    );
  }

  Future<void> _showCampaignActions(
    BuildContext context,
    FeedPost post,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text(
                    'Delete campaign',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            backgroundColor: const Color(0xFF111111),
                            title: const Text(
                              'Delete campaign?',
                              style: TextStyle(color: Colors.white),
                            ),
                            content: const Text(
                              'This campaign will be removed from your profile.',
                              style: TextStyle(color: Colors.white70),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(true),
                                child: const Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.redAccent),
                                ),
                              ),
                            ],
                          ),
                        ) ??
                        false;
                    if (!confirmed || onDeletePromote == null) return;
                    await onDeletePromote!(post);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPostsActionCards(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final cardWidth = availableWidth >= 420 ? 170.0 : 156.0;
        const gap = 12.0;
        return SizedBox(
          height: 226,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            clipBehavior: Clip.none,
            child: Row(
              children: [
                SizedBox(
                  width: cardWidth,
                  child: _PostsActionCard(
                    data: _PostsActionCardData(
                      title: 'Promote',
                      subtitle: 'Boost your content and grow faster',
                      buttonLabel: 'Create Promote',
                      icon: Icons.campaign_rounded,
                      iconColor: const Color(0xFFF0D7FF),
                      iconBackground: const LinearGradient(
                        colors: [Color(0xFF9B5CF6), Color(0xFF5C2EC5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      cardBackground: const LinearGradient(
                        colors: [Color(0xFF1A1230), Color(0xFF120D22)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      buttonBackground: const Color(0xFF2C2148),
                      buttonForeground: const Color(0xFFB07CFF),
                      onButtonTap: () =>
                          Navigator.of(context).pushNamed('/promote/create'),
                    ),
                  ),
                ),
                const SizedBox(width: gap),
                SizedBox(
                  width: cardWidth,
                  child: const _PostsActionCard(
                    data: _PostsActionCardData(
                      title: 'Miles',
                      subtitle: 'Keep engaging, keep earning!',
                      buttonLabel: 'Lvl 8',
                      icon: Icons.monetization_on_rounded,
                      iconColor: Color(0xFFFFE7A8),
                      iconBackground: LinearGradient(
                        colors: [Color(0xFFFFC44D), Color(0xFFE29A17)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      cardBackground: LinearGradient(
                        colors: [Color(0xFF191614), Color(0xFF11100F)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      buttonBackground: Color(0xFF2B2412),
                      buttonForeground: Color(0xFFF0B63A),
                      showProgress: true,
                      progress: 0.62,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _emptyContentState({
    required String title,
    required String subtitle,
    required IconData icon,
    String? actionLabel,
    VoidCallback? onActionTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 44,
            color: Colors.white.withValues(alpha: 0.45),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 13,
            ),
          ),
          if (actionLabel != null && onActionTap != null) ...[
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: onActionTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: Text(actionLabel),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChatPreviewSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF111418),
            Color(0xFF0B0E12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF7CFF6B).withValues(alpha: 0.22),
                      const Color(0xFF7CFF6B).withValues(alpha: 0.06),
                    ],
                  ),
                ),
                child: const Icon(
                  LucideIcons.messageCircle,
                  color: Color(0xFF8CFF6E),
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Chat',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Material(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => _openMessagingPage(context),
                  child: const Padding(
                    padding: EdgeInsets.all(7),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white70,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Open your chat inbox to continue conversations.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Material(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _openMessagingPage(context),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Icon(LucideIcons.messageCircle,
                        color: Color(0xFF8CFF6E), size: 16),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Open Messages',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: Colors.white70, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatCompact(int value) {
    if (value >= 1000000) {
      final n = value / 1000000;
      return '${n.toStringAsFixed(n >= 10 ? 0 : 1)}M';
    }
    if (value >= 1000) {
      final n = value / 1000;
      return '${n.toStringAsFixed(n >= 10 ? 0 : 1)}K';
    }
    return value.toString();
  }

  Widget _stickyActions(BuildContext context) {
    if (isMe) return const SizedBox.shrink();
    final isFollowed = _isFollowed();
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.98),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF6C453), Color(0xFFE0A91F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: onFollow,
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (!isFollowed) ...[
                            const Icon(
                              LucideIcons.userPlus,
                              color: Colors.black,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            isFollowed ? 'Followed' : 'Follow',
                            style: TextStyle(
                              color: isFollowed ? Colors.black : Colors.black,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _gold.withValues(alpha: 0.85)),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: onMessage,
                    child: const Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.messageCircle,
                              color: _gold, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Message',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: onShare,
                  child: const Icon(
                    LucideIcons.send,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final heroUrl = (avatarUrl ?? '').trim();
    final hasHero = heroUrl.isNotEmpty;
    final shouldAttachAuth =
        hasHero && UrlHelper.shouldAttachAuthHeader(heroUrl);
    final heroHeaders = shouldAttachAuth ? avatarHeaders : null;
    final displayName = fullName?.trim().isNotEmpty == true
        ? fullName!.trim()
        : username.trim();
    final hobbies = _hobbies();
    const showBadge = true;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black, Colors.black],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 340,
                    width: double.infinity,
                    child: Stack(
                      clipBehavior: Clip.none,
                      fit: StackFit.expand,
                      children: [
                        if (hasHero)
                          SafeNetworkImage(
                            url: heroUrl,
                            headers: heroHeaders,
                            fit: BoxFit.cover,
                            placeholder: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF2B2B2B),
                                    Color(0xFF0F0F0F)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                            ),
                            errorWidget: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF2B2B2B),
                                    Color(0xFF0F0F0F)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                            ),
                          )
                        else
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF2B2B2B), Color(0xFF0F0F0F)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                          ),
                        const Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0x00000000),
                                  Color(0x00000000),
                                  Color(0x66000000),
                                  Color(0xE6000000),
                                ],
                                stops: [0.0, 0.72, 0.90, 1.0],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: topInset + 14,
                          left: 16,
                          child: _topIconButton(
                            context: context,
                            icon: LucideIcons.chevronLeft,
                            onTap: onBack,
                          ),
                        ),
                        Positioned(
                          top: topInset + 14,
                          right: 16,
                          child: Builder(
                            builder: (buttonContext) => _topIconButton(
                              context: buttonContext,
                              icon: Icons.more_horiz_rounded,
                              onTap: () => _showQuickActionsSheet(
                                buttonContext,
                                hobbies,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Center(
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _goldSoft.withValues(alpha: 0.96),
                                      width: 2.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _gold.withValues(alpha: 0.24),
                                        blurRadius: 16,
                                        spreadRadius: 0.4,
                                      ),
                                    ],
                                  ),
                                  child: CircleAvatar(
                                    radius: 53,
                                    backgroundColor: _panel,
                                    child: ClipOval(
                                      child: SizedBox(
                                        width: 106,
                                        height: 106,
                                        child: hasHero
                                            ? SafeNetworkImage(
                                                url: heroUrl,
                                                headers: heroHeaders,
                                                fit: BoxFit.cover,
                                                placeholder: const ColoredBox(
                                                  color: Color(0xFF222222),
                                                ),
                                                errorWidget: const ColoredBox(
                                                  color: Color(0xFF222222),
                                                ),
                                              )
                                            : const ColoredBox(
                                                color: Color(0xFF222222),
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (showBadge)
                                  const Positioned(
                                    right: 4,
                                    bottom: 4,
                                    child: Icon(
                                      Icons.verified_rounded,
                                      color: _gold,
                                      size: 22,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    color: Colors.black,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 220),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 8),
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _showOverviewSection,
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                displayName,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w700,
                                  height: 1.0,
                                ),
                              ),
                              if (showBadge) ...[
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.verified_rounded,
                                  color: _gold,
                                  size: 22,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _profileSummary(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: _goldChip(
                                icon: LucideIcons.mapPin,
                                label: _location(),
                                compact: true,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _goldChip(
                                icon: LucideIcons.calendarDays,
                                label: _dateLine(),
                                compact: true,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _goldChip(
                                icon: LucideIcons.graduationCap,
                                label: _profession(),
                                compact: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _statsCard(context),
                        if (isMe && _section == ProfileHomeSection.content) ...[
                          const SizedBox(height: 24),
                          _buildContentSection(context),
                        ] else ...[
                          const SizedBox(height: 28),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _sectionTitle('About Me'),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _aboutText(),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.82),
                                fontSize: 15,
                                height: 1.6,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF101010),
                                  Color(0xFF0E0E0E),
                                  Color(0xFF090909),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.065),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  blurRadius: 24,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 18,
                              ),
                              child: IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _profileInfoTile(
                                            icon: LucideIcons.calendarDays,
                                            label: 'Date of Birth',
                                            value: _dateLine(),
                                          ),
                                          const SizedBox(height: 18),
                                          _profileInfoTile(
                                            icon: LucideIcons.mapPin,
                                            label: 'Location',
                                            value: _location(),
                                          ),
                                          const SizedBox(height: 18),
                                          _profileInfoTile(
                                            icon: LucideIcons.graduationCap,
                                            label: 'Class',
                                            value: _profession(),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: 1,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      color:
                                          Colors.white.withValues(alpha: 0.08),
                                    ),
                                    Expanded(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _profileInfoTile(
                                            icon: LucideIcons.heart,
                                            label: 'Hobbies',
                                            value: hobbies.isNotEmpty
                                                ? hobbies.join(', ')
                                                : _missingText,
                                            iconColor: const Color(0xFFF48FAF),
                                          ),
                                          const SizedBox(height: 18),
                                          _profileInfoTile(
                                            icon: LucideIcons.palette,
                                            label: 'Favorite Color',
                                            value: _stringValue(
                                              [
                                                'favorite_color',
                                                'favoriteColor'
                                              ],
                                              fallback: _missingText,
                                            ),
                                            iconColor: const Color(0xFFB68CFF),
                                          ),
                                          const SizedBox(height: 18),
                                          _profileInfoTile(
                                            icon: LucideIcons.bookOpen,
                                            label: 'Favorite Subject',
                                            value: _stringValue(
                                              [
                                                'favorite_subject',
                                                'favoriteSubject'
                                              ],
                                              fallback: _missingText,
                                            ),
                                            iconColor: const Color(0xFFB68CFF),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _sectionTitle('Hobbies & Interests'),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              if (hobbies.isEmpty)
                                Chip(
                                  label: const Text(_missingText),
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.03),
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.08),
                                  ),
                                  labelStyle: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                )
                              else
                                for (final hobby in hobbies.take(6))
                                  Chip(
                                    label: Text(hobby),
                                    backgroundColor:
                                        Colors.white.withValues(alpha: 0.03),
                                    side: BorderSide(
                                      color:
                                          Colors.white.withValues(alpha: 0.08),
                                    ),
                                    labelStyle: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _buildChatPreviewSection(context),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.0),
                      Colors.black.withValues(alpha: 0.55),
                      Colors.black,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: _stickyActions(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTabData {
  final ProfileContentTab tab;
  final String label;
  final IconData icon;

  const _ProfileTabData({
    required this.tab,
    required this.label,
    required this.icon,
  });
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem(this.label, this.value, this.icon);
}

class _StatTile extends StatelessWidget {
  final _StatItem item;

  const _StatTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(item.icon, color: ProfileHomePage._goldSoft, size: 22),
        const SizedBox(height: 10),
        Text(
          item.value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 29,
            fontWeight: FontWeight.w700,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          item.label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.68),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _PostsActionCardData {
  final String title;
  final String subtitle;
  final String buttonLabel;
  final IconData icon;
  final Color iconColor;
  final Gradient iconBackground;
  final Gradient cardBackground;
  final Color buttonBackground;
  final Color buttonForeground;
  final bool showProgress;
  final double progress;
  final VoidCallback? onButtonTap;

  const _PostsActionCardData({
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.cardBackground,
    required this.buttonBackground,
    required this.buttonForeground,
    this.showProgress = false,
    this.progress = 0.0,
    this.onButtonTap,
  });
}

class _PostsActionCard extends StatelessWidget {
  final _PostsActionCardData data;

  const _PostsActionCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 218,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: data.cardBackground,
        border: Border.all(color: Colors.white.withValues(alpha: 0.075)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white70,
                size: 17,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: data.iconBackground,
              boxShadow: [
                BoxShadow(
                  color: data.iconColor.withValues(alpha: 0.24),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(data.icon, color: data.iconColor, size: 26),
          ),
          const SizedBox(height: 16),
          Text(
            data.subtitle,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 12.2,
              height: 1.3,
            ),
          ),
          const Spacer(),
          if (data.showProgress) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Container(
                height: 5,
                color: Colors.white.withValues(alpha: 0.08),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: data.progress.clamp(0.0, 1.0),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFF7C14A), Color(0xFFEEA827)],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: data.onButtonTap,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: data.buttonBackground,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.04),
                    ),
                  ),
                  child: Text(
                    data.buttonLabel,
                    style: TextStyle(
                      color: data.buttonForeground,
                      fontSize: 12.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CampaignPromoCard extends StatelessWidget {
  final FeedPost post;
  final bool isOwnProfile;
  final VoidCallback? onTap;
  final VoidCallback? onMore;

  const _CampaignPromoCard({
    required this.post,
    required this.isOwnProfile,
    this.onTap,
    this.onMore,
  });

  String? _thumbUrl() {
    final thumb = (post.thumbnailUrl ?? '').trim();
    if (thumb.isNotEmpty) return thumb;
    if (post.mediaUrls.isNotEmpty) {
      final first = post.mediaUrls.first.trim();
      if (first.isNotEmpty) return first;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final thumb = _thumbUrl();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          height: 276,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(
              colors: [Color(0xFF151515), Color(0xFF0D0D0D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 0.82,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (thumb != null && thumb.isNotEmpty)
                      SafeNetworkImage(
                        url: thumb,
                        fit: BoxFit.cover,
                        placeholder: Container(
                          color: const Color(0xFF171717),
                        ),
                        errorWidget: Container(
                          color: const Color(0xFF171717),
                          child: const Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white54,
                          ),
                        ),
                      )
                    else
                      Container(
                        color: const Color(0xFF171717),
                        child: const Icon(
                          Icons.campaign_rounded,
                          color: Colors.white54,
                          size: 40,
                        ),
                      ),
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0x11000000),
                              Color(0x66000000),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Campaign',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    if (onMore != null)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Material(
                          color: Colors.black.withValues(alpha: 0.40),
                          borderRadius: BorderRadius.circular(999),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: onMore,
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(
                                Icons.more_horiz_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.caption?.trim().isNotEmpty == true
                            ? post.caption!.trim()
                            : 'Untitled campaign',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          const Icon(
                            Icons.favorite_border_rounded,
                            size: 15,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _compactCount(post.likes),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Icon(
                            Icons.mode_comment_outlined,
                            size: 15,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _compactCount(post.comments),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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

  String _compactCount(int value) {
    if (value >= 1000000) {
      final n = value / 1000000;
      return '${n.toStringAsFixed(n >= 10 ? 0 : 1)}M';
    }
    if (value >= 1000) {
      final n = value / 1000;
      return '${n.toStringAsFixed(n >= 10 ? 0 : 1)}K';
    }
    return value.toString();
  }
}