import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../utils/url_helper.dart';

class SuggestionUser {
  final String id;
  final String title;
  final String? subtitle;
  final String? avatarUrl;

  const SuggestionUser({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.avatarUrl,
  });

  SuggestionUser copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? avatarUrl,
  }) {
    return SuggestionUser(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
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
  final bool compact;
  final void Function(String userId)? onDismissUser;
  final void Function(String userId)? onUserTap;
  final void Function(SuggestionUser user)? onFollow;

  const SuggestionFollowBlock({
    super.key,
    required this.sections,
    this.isLoading = false,
    this.imageHeaders,
    this.compact = false,
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
    final textScale =
        MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.4);
    final baseHeight = compact ? 200.0 : 210.0;
    final listHeight = baseHeight + ((textScale - 1.0) * 36.0);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 8 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final section in sections) ...[
            if (section.title.trim().isNotEmpty ||
                (section.helperText?.trim().isNotEmpty ?? false) ||
                section.onSeeAll != null ||
                section.onOverflow != null) ...[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 14),
                child: _SectionHeader(
                  title: section.title,
                  helperText: section.helperText,
                  titleColor: titleColor,
                  helperColor: subColor,
                  onSeeAll: section.onSeeAll,
                  onOverflow: section.onOverflow,
                ),
              ),
              SizedBox(height: compact ? 8 : 10),
            ],
            SizedBox(
              height: listHeight,
              child: ListView.separated(
                padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 14),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: (isLoading || section.users.isEmpty)
                    ? 6
                    : section.users.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  if (isLoading || section.users.isEmpty) {
                    return _SuggestionCard.loading(
                      isDark: isDark,
                      compact: compact,
                    );
                  }
                  final user = section.users[index];
                  return _SuggestionCard(
                    user: user,
                    isDark: isDark,
                    imageHeaders: imageHeaders,
                    compact: compact,
                    onDismiss: onDismissUser == null
                        ? null
                        : () => onDismissUser!(user.id),
                    onTap: onUserTap == null ? null : () => onUserTap!(user.id),
                    onFollow: onFollow == null ? null : () => onFollow!(user),
                  );
                },
              ),
            ),
            SizedBox(height: compact ? 10 : 14),
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
                constraints:
                    const BoxConstraints.tightFor(width: 32, height: 32),
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
  final bool compact;
  final VoidCallback? onDismiss;
  final VoidCallback? onTap;
  final VoidCallback? onFollow;
  final bool _loading;

  const _SuggestionCard({
    required this.user,
    required this.isDark,
    required this.imageHeaders,
    required this.compact,
    required this.onDismiss,
    required this.onTap,
    required this.onFollow,
  }) : _loading = false;

  const _SuggestionCard.loading({required this.isDark, this.compact = false})
      : user = const SuggestionUser(
          id: '',
          title: '',
          subtitle: null,
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
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.03);
    final cardBg = Color.alphaBlend(overlay, baseSurface);
    final titleColor = theme.textTheme.titleSmall?.color ??
        (isDark ? Colors.white : Colors.black87);
    final subColor = isDark
        ? Colors.white.withValues(alpha: 0.55)
        : Colors.black.withValues(alpha: 0.45);
    const primary = Color(0xFF3B82F6);
    final w = compact ? 160.0 : 160.0;
    final h = compact ? 220.0 : 220.0;
    final avatarSize = compact ? 56.0 : 56.0;
    final avatarRadius = avatarSize / 2;
    final gapSm = compact ? 10.0 : 10.0;
    final gapXs = compact ? 4.0 : 4.0;

    Widget circleAvatar() {
      final url = user.avatarUrl?.trim() ?? '';
      if (_loading) {
        return Container(
          width: avatarSize,
          height: avatarSize,
          decoration: const BoxDecoration(
            color: Color(0xFF3A3D42),
            shape: BoxShape.circle,
          ),
        );
      }
      if (url.isEmpty) {
        final ch = user.title.isEmpty ? 'U' : user.title[0].toUpperCase();
        return Container(
          width: avatarSize,
          height: avatarSize,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
            ),
          ),
          child: Center(
            child: Text(
              ch,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
        );
      }
      final fallback = CircleAvatar(
        radius: avatarRadius,
        backgroundColor: const Color(0xFFEC4899),
        child: Text(
          user.title.isEmpty ? 'U' : user.title[0].toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      );
      return Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEC4899), Color(0xFF8B5CF6), Color(0xFFF59E0B)],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: url,
            httpHeaders:
                UrlHelper.shouldAttachAuthHeader(url) ? imageHeaders : null,
            width: avatarSize,
            height: avatarSize,
            fit: BoxFit.cover,
            placeholder: (_, __) => SizedBox(
              width: avatarSize,
              height: avatarSize,
              child: const DecoratedBox(
                decoration: BoxDecoration(color: Color(0xFF1B1B1F)),
              ),
            ),
            errorWidget: (_, __, ___) => fallback,
          ),
        ),
      );
    }

    Widget followButton() {
      if (_loading) {
        return Container(
          height: 36,
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(10),
          ),
        );
      }
      return SizedBox(
        height: 36,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onFollow,
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.userPlus, size: 12),
              SizedBox(width: 6),
              Text(
                'Follow',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      width: w,
      height: h,
      child: Material(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: _loading ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              12,
              12,
              12,
              12,
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -12,
                  right: -12,
                  child: _loading
                      ? const SizedBox(height: 24, width: 24)
                      : IconButton(
                          onPressed: onDismiss,
                          icon: const Icon(Icons.close, size: 12),
                          color: titleColor.withValues(alpha: 0.75),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 24,
                            height: 24,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            surfaceTintColor: Colors.transparent,
                          ),
                        ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    // Reserve space for the top-right close button so the
                    // avatar can sit at the very top without overlapping.
                    const SizedBox(height: 18),
                    SizedBox(height: compact ? 2 : gapXs),
                    Align(
                      alignment: Alignment.topCenter,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: circleAvatar(),
                      ),
                    ),
                    SizedBox(height: gapSm),
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
                      (user.title.trim().isEmpty
                          ? const SizedBox(height: 14)
                          : Text(
                              user.title,
                              style: TextStyle(
                                color: titleColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            )),
                    if (!_loading &&
                        user.subtitle != null &&
                        user.subtitle!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        user.subtitle!,
                        style: TextStyle(
                          fontSize: 10,
                          color: subColor,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const Spacer(),
                    followButton(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
