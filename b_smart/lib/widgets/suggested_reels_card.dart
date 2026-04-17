import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/reel_model.dart';
import 'safe_network_image.dart';

class SuggestedReelsCard extends StatelessWidget {
  final List<Reel> reels;
  final Map<String, String>? imageHeaders;
  final void Function(Reel reel)? onOpenReel;

  const SuggestedReelsCard({
    super.key,
    required this.reels,
    required this.imageHeaders,
    required this.onOpenReel,
  });

  @override
  Widget build(BuildContext context) {
    if (reels.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D0D0F) : Colors.white;
    final border = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);
    final titleColor = isDark ? Colors.white : Colors.black;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          top: BorderSide(color: border),
          bottom: BorderSide(color: border),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Suggested reels',
                    style: TextStyle(
                      color: titleColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: null,
                  icon: const Icon(LucideIcons.ellipsis, size: 18),
                  color: titleColor.withValues(alpha: 0.75),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 290,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                final reel = reels[index];
                return _ReelSuggestionTile(
                  reel: reel,
                  imageHeaders: imageHeaders,
                  onTap: onOpenReel == null ? null : () => onOpenReel!(reel),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemCount: reels.length,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReelSuggestionTile extends StatelessWidget {
  final Reel reel;
  final Map<String, String>? imageHeaders;
  final VoidCallback? onTap;

  const _ReelSuggestionTile({
    required this.reel,
    required this.imageHeaders,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = Colors.white.withValues(alpha: isDark ? 0.10 : 0.14);
    final caption = (reel.caption ?? '').trim();
    final username = reel.userName.trim().isNotEmpty ? reel.userName.trim() : 'reel';

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 160,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: reel.thumbnailUrl != null && reel.thumbnailUrl!.trim().isNotEmpty
                    ? SafeNetworkImage(
                        url: reel.thumbnailUrl!,
                        headers: imageHeaders,
                        fit: BoxFit.cover,
                        placeholder: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF1F2937), Color(0xFF030712)],
                            ),
                          ),
                        ),
                        errorWidget: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF1F2937), Color(0xFF030712)],
                            ),
                          ),
                        ),
                      )
                    : Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF1F2937), Color(0xFF030712)],
                          ),
                        ),
                      ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                  ),
                  child: const Icon(
                    LucideIcons.ellipsis,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 46, 12, 12),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Color(0x99000000),
                        Color(0xE6000000),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _Avatar(
                            url: reel.userAvatarUrl,
                            headers: imageHeaders,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              username,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        caption.isNotEmpty ? caption : username,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.96),
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          height: 1.25,
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

class _Avatar extends StatelessWidget {
  final String? url;
  final Map<String, String>? headers;

  const _Avatar({required this.url, required this.headers});

  @override
  Widget build(BuildContext context) {
    final u = url?.trim() ?? '';
    if (u.isEmpty) {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SafeNetworkImage(
        url: u,
        headers: headers,
        width: 28,
        height: 28,
        fit: BoxFit.cover,
        placeholder: Container(
          width: 28,
          height: 28,
          color: Colors.white.withValues(alpha: 0.14),
        ),
        errorWidget: Container(
          width: 28,
          height: 28,
          color: Colors.white.withValues(alpha: 0.14),
        ),
      ),
    );
  }
}

