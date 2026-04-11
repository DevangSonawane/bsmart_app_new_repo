import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class SuggestionUser {
  final String id;
  final String title;
  final String? avatarUrl;

  const SuggestionUser({
    required this.id,
    required this.title,
    required this.avatarUrl,
  });

  SuggestionUser copyWith({
    String? id,
    String? title,
    String? avatarUrl,
  }) {
    return SuggestionUser(
      id: id ?? this.id,
      title: title ?? this.title,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}

class SuggestionFollowSection {
  final String title;
  final String? helperText;
  final List<SuggestionUser> users;
  final VoidCallback? onSeeAll;
  final VoidCallback? onOverflow;

  const SuggestionFollowSection({
    required this.title,
    this.helperText,
    required this.users,
    this.onSeeAll,
    this.onOverflow,
  });
}

class SuggestionFollowBlock extends StatelessWidget {
  final List<SuggestionFollowSection> sections;
  final bool isLoading;
  final Map<String, String>? imageHeaders;
  final void Function(String userId)? onDismissUser;
  final void Function(String userId)? onUserTap;
  final void Function(SuggestionUser user)? onFollow;

  const SuggestionFollowBlock({
    super.key,
    required this.sections,
    this.isLoading = false,
    this.imageHeaders,
    this.onDismissUser,
    this.onUserTap,
    this.onFollow,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark ||
        theme.scaffoldBackgroundColor.computeLuminance() < 0.35;
    final titleColor = theme.textTheme.titleSmall?.color ??
        (isDark ? Colors.white : theme.colorScheme.onSurface);
    final subColor = theme.textTheme.bodySmall?.color ??
        (isDark ? Colors.white60 : theme.colorScheme.onSurfaceVariant);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final section in sections) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: _SectionHeader(
                title: section.title,
                helperText: section.helperText,
                titleColor: titleColor,
                helperColor: subColor,
                onSeeAll: section.onSeeAll,
                onOverflow: section.onOverflow,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 248,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: (isLoading || section.users.isEmpty)
                    ? 6
                    : section.users.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  if (isLoading || section.users.isEmpty) {
                    return _SuggestionCard.loading(isDark: isDark);
                  }
                  final user = section.users[index];
                  return _SuggestionCard(
                    user: user,
                    isDark: isDark,
                    imageHeaders: imageHeaders,
                    onDismiss: onDismissUser == null
                        ? null
                        : () => onDismissUser!(user.id),
                    onTap: onUserTap == null ? null : () => onUserTap!(user.id),
                    onFollow: onFollow == null ? null : () => onFollow!(user),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? helperText;
  final Color titleColor;
  final Color helperColor;
  final VoidCallback? onSeeAll;
  final VoidCallback? onOverflow;

  const _SectionHeader({
    required this.title,
    required this.helperText,
    required this.titleColor,
    required this.helperColor,
    required this.onSeeAll,
    required this.onOverflow,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: titleColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (onSeeAll != null)
              GestureDetector(
                onTap: onSeeAll,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  child: Text(
                    'See all',
                    style: TextStyle(
                      color: Color(0xFF60A5FA),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            if (onOverflow != null)
              IconButton(
                onPressed: onOverflow,
                icon: const Icon(LucideIcons.ellipsis, size: 18),
                color: titleColor.withValues(alpha: 0.8),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              ),
          ],
        ),
        if (helperText != null && helperText!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              helperText!,
              style: TextStyle(
                color: helperColor,
                fontSize: 12,
                height: 1.25,
              ),
            ),
          ),
      ],
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final SuggestionUser user;
  final bool isDark;
  final Map<String, String>? imageHeaders;
  final VoidCallback? onDismiss;
  final VoidCallback? onTap;
  final VoidCallback? onFollow;
  final bool _loading;

  const _SuggestionCard({
    required this.user,
    required this.isDark,
    required this.imageHeaders,
    required this.onDismiss,
    required this.onTap,
    required this.onFollow,
  }) : _loading = false;

  const _SuggestionCard.loading({required this.isDark})
      : user = const SuggestionUser(
          id: '',
          title: '',
          avatarUrl: null,
        ),
        imageHeaders = null,
        onDismiss = null,
        onTap = null,
        onFollow = null,
        _loading = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseSurface = theme.colorScheme.surface;
    final overlay = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.04);
    final cardBg = Color.alphaBlend(overlay, baseSurface);
    final titleColor =
        theme.textTheme.titleSmall?.color ?? (isDark ? Colors.white : Colors.black87);
    const primary = Color(0xFF3B82F6);
    const w = 190.0;

    Widget circleAvatar() {
      final url = user.avatarUrl?.trim() ?? '';
      if (_loading) {
        return Container(
          width: 104,
          height: 104,
          decoration: const BoxDecoration(
            color: Color(0xFF3A3D42),
            shape: BoxShape.circle,
          ),
        );
      }
      if (url.isEmpty) {
        final ch = user.title.isEmpty ? 'U' : user.title[0].toUpperCase();
        return CircleAvatar(
          radius: 52,
          backgroundColor: const Color(0xFFF97316),
          child: Text(
            ch,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),
        );
      }
      final fallback = CircleAvatar(
        radius: 52,
        backgroundColor: const Color(0xFFF97316),
        child: Text(
          user.title.isEmpty ? 'U' : user.title[0].toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
      );
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: url,
          httpHeaders: imageHeaders,
          width: 104,
          height: 104,
          fit: BoxFit.cover,
          placeholder: (_, __) => const SizedBox(
            width: 104,
            height: 104,
            child: DecoratedBox(
              decoration: BoxDecoration(color: Color(0xFF1B1B1F)),
            ),
          ),
          errorWidget: (_, __, ___) => fallback,
        ),
      );
    }

    Widget followButton() {
      if (_loading) {
        return Container(
          height: 40,
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(10),
          ),
        );
      }
      return SizedBox(
        height: 40,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onFollow,
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text(
            'Follow',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
      );
    }

    return SizedBox(
      width: w,
      child: Material(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: _loading ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: _loading
                      ? const SizedBox(height: 24, width: 24)
                      : IconButton(
                          onPressed: onDismiss,
                          icon: const Icon(Icons.close, size: 18),
                          color: titleColor.withValues(alpha: 0.72),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                              width: 28, height: 28),
                        ),
                ),
                const SizedBox(height: 6),
                circleAvatar(),
                const SizedBox(height: 12),
                if (_loading)
                  Container(
                    height: 14,
                    width: 140,
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black)
                          .withValues(alpha: isDark ? 0.10 : 0.06),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  )
                else
                  Text(
                    user.title,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 12),
                followButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
