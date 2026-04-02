import 'package:flutter/material.dart';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/design_tokens.dart';

class ProfileHeader extends StatelessWidget {
  final String username;
  final String? fullName;
  final String? bio;
  final String? avatarUrl;
  final int posts;
  final int followers;
  final int following;
  final int ads;
  final bool isMe;
  final bool isVendor;
  final bool isFollowing;
  final bool isFavorite;
  final bool hasStory;
  final VoidCallback? onEdit;
  final VoidCallback? onFollow;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onAvatarEdit;
  final VoidCallback? onMessage;
  final VoidCallback? onShare;
  final VoidCallback? onFavorite;
  final VoidCallback? onMore;
  final VoidCallback? onUser;

  const ProfileHeader({
    super.key,
    required this.username,
    this.fullName,
    this.bio,
    this.avatarUrl,
    this.posts = 0,
    this.followers = 0,
    this.following = 0,
    this.ads = 0,
    this.isMe = false,
    this.isVendor = false,
    this.isFollowing = false,
    this.isFavorite = false,
    this.hasStory = false,
    this.onEdit,
    this.onFollow,
    this.onAvatarTap,
    this.onAvatarEdit,
    this.onMessage,
    this.onShare,
    this.onFavorite,
    this.onMore,
    this.onUser,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fgColor = theme.colorScheme.onSurface;
    final mutedColor = theme.textTheme.bodyMedium?.color ?? Colors.black54;
    final cleanUsername = username.trim();
    final displayName =
        fullName?.trim().isNotEmpty == true ? fullName!.trim() : '';
    final hasDisplayName =
        displayName.isNotEmpty && displayName.toLowerCase() != cleanUsername.toLowerCase();
    final stats = <_StatItem>[
      _StatItem(posts, 'Posts'),
      _StatItem(followers, 'Followers'),
      _StatItem(following, 'Following'),
      if (isVendor) _StatItem(ads, 'Ads'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: onAvatarTap,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _StoryAvatarRing(
                      hasStory: hasStory,
                      child: Builder(
                        builder: (context) {
                          final hasAvatar =
                              avatarUrl != null && avatarUrl!.trim().isNotEmpty;
                          return CircleAvatar(
                            radius: 38,
                            backgroundImage: hasAvatar
                                ? CachedNetworkImageProvider(avatarUrl!)
                                : null,
                            backgroundColor: theme.cardColor,
                            child: !hasAvatar
                                ? Text(
                                    username.isNotEmpty
                                        ? username[0].toUpperCase()
                                        : '',
                                    style: TextStyle(
                                      fontSize: 22,
                                      color: fgColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  )
                                : null,
                          );
                        },
                      ),
                    ),
                    if (isMe && onAvatarEdit != null)
                      Positioned(
                        bottom: -2,
                        right: -2,
                        child: _avatarEditButton(onAvatarEdit!),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Align(
                    alignment: Alignment.center,
                  child: Wrap(
                    spacing: 18,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      ...stats.map((item) => _statPill(
                            context,
                            item.count,
                            item.label,
                            fgColor,
                            mutedColor,
                          )),
                      if (!isVendor)
                        _statIconButton(
                          context,
                          icon: Icons.person_outline,
                          onTap: onUser,
                        ),
                    ],
                  ),
                ),
              ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text(
                cleanUsername.isNotEmpty ? cleanUsername : 'user',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: fgColor,
                ),
              ),
              if (isVendor)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEDD5),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Vendor',
                    style: TextStyle(
                      color: Color(0xFFEA580C),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          if (hasDisplayName) ...[
            const SizedBox(height: 4),
            Text(
              displayName,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: fgColor.withValues(alpha: 0.9),
              ),
            ),
          ],
          if (bio != null && bio!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              bio!,
              style: TextStyle(fontSize: 13.5, color: fgColor.withValues(alpha: 0.8)),
            ),
          ],
          const SizedBox(height: 12),
          if (isMe)
            Row(
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 160),
                  child: _primaryButton(
                    label: 'Edit profile',
                    onTap: onEdit,
                  ),
                ),
                const SizedBox(width: 16),
                _actionIconButton(
                  context,
                  icon: Icons.share_outlined,
                  onTap: onShare ?? () {},
                ),
                const SizedBox(width: 12),
                _actionIconButton(
                  context,
                  icon: isFavorite ? Icons.star : Icons.star_border,
                  onTap: onFavorite ?? () {},
                ),
                const SizedBox(width: 12),
                _actionIconButton(
                  context,
                  icon: LucideIcons.messageCircle,
                  onTap: onMessage ?? () {},
                ),
              ],
            )
          else if (isVendor)
            Row(
              children: [
                Expanded(
                  child: _followButton(onTap: onFollow),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _secondaryButton(
                    context: context,
                    label: 'Message',
                    onTap: onMessage,
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: _followButton(onTap: onFollow),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _secondaryButton(
                    context: context,
                    label: 'Message',
                    onTap: onMessage,
                  ),
                ),
                const SizedBox(width: 8),
                _actionIconButton(
                  context,
                  icon: LucideIcons.ellipsis,
                  onTap: onMore ?? () {},
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
          decoration: const BoxDecoration(
            gradient: DesignTokens.instaGradient,
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _followButton({required VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: isFollowing ? null : DesignTokens.instaGradient,
            color: isFollowing ? Colors.grey.withValues(alpha: 0.15) : null,
            borderRadius: const BorderRadius.all(Radius.circular(10)),
            border: isFollowing
                ? Border.all(color: Colors.grey.withValues(alpha: 0.25))
                : null,
          ),
          alignment: Alignment.center,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              isFollowing ? 'Following' : 'Follow',
              key: ValueKey<bool>(isFollowing),
              style: TextStyle(
                color: isFollowing ? Colors.grey : Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _secondaryButton({
    required BuildContext context,
    required String label,
    required VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = isDark ? Colors.white : Colors.black87;
    final bg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.grey.withValues(alpha: 0.12);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.all(Radius.circular(10)),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionIconButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
    bool useFloatingStyle = false,
  }) {
    final theme = Theme.of(context);
    final fgColor = theme.colorScheme.onSurface;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.transparent,
          ),
          child: Icon(icon, size: 22, color: fgColor),
        ),
      ),
    );
  }

  Widget _avatarEditButton(VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: const Color(0xFF3B82F6),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          LucideIcons.plus,
          size: 14,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _statPill(
    BuildContext context,
    int count,
    String label,
    Color fgColor,
    Color mutedColor,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          count.toString(),
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: fgColor),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: mutedColor, fontSize: 11),
        ),
      ],
    );
  }

  Widget _statIconButton(
    BuildContext context, {
    required IconData icon,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final fgColor = theme.colorScheme.onSurface;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 2),
          Icon(icon, size: 30, color: fgColor),
          const SizedBox(height: 4),
          const Text(
            ' ',
            style: TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _StatItem {
  final int count;
  final String label;
  const _StatItem(this.count, this.label);
}

class _StoryAvatarRing extends StatelessWidget {
  final bool hasStory;
  final Widget child;

  const _StoryAvatarRing({
    required this.hasStory,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ringColor = theme.brightness == Brightness.dark
        ? Colors.white24
        : Colors.grey.shade400;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: hasStory
          ? const BoxDecoration(
              shape: BoxShape.circle,
              gradient: DesignTokens.instaGradient,
            )
          : BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
            ),
      child: hasStory
          ? child
          : CustomPaint(
              painter: _DottedCirclePainter(
                color: ringColor,
                strokeWidth: 2,
                dashLength: 4,
                gap: 3,
              ),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: child,
              ),
            ),
    );
  }
}

class _DottedCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double gap;

  const _DottedCirclePainter({
    required this.color,
    required this.strokeWidth,
    required this.dashLength,
    required this.gap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2;
    final rect = Rect.fromCircle(
      center: Offset(radius, radius),
      radius: radius - strokeWidth / 2,
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final circumference = 2 * pi * rect.width / 2;
    final dashCount = (circumference / (dashLength + gap)).floor().clamp(6, 200);
    final r = rect.width / 2;
    final dashAngle = dashLength / r;
    final gapAngle = gap / r;
    double start = -pi / 2;
    for (int i = 0; i < dashCount; i++) {
      canvas.drawArc(rect, start, dashAngle, false, paint);
      start += dashAngle + gapAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DottedCirclePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashLength != dashLength ||
        oldDelegate.gap != gap;
  }
}
