import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/design_tokens.dart';

class StoriesRow extends StatelessWidget {
  final List<Map<String, dynamic>> users;
  final VoidCallback? onYourStoryTap;
  /// Called when a user story is tapped. Index 0 = first user in [users].
  final void Function(int userIndex)? onUserStoryTap;
  final bool yourStoryHasActive;
  final Map<String, Map<String, bool>>? userStatuses;
  final double? yourStoryUploadProgress;
  final VoidCallback? onYourStoryAddTap;
  final bool showYourStory;

  const StoriesRow({
    Key? key,
    required this.users,
    this.onYourStoryTap,
    this.onUserStoryTap,
    this.yourStoryHasActive = false,
    this.userStatuses,
    this.yourStoryUploadProgress,
    this.onYourStoryAddTap,
    this.showYourStory = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return SizedBox(
      height: 100,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        scrollDirection: Axis.horizontal,
        itemCount: users.length + (showYourStory ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final offset = showYourStory ? 1 : 0;
          if (showYourStory && index == 0) {
            return _StoryItem(
              label: 'Your Story',
              avatarUrl: null,
              ringGradient: yourStoryHasActive
                  ? DesignTokens.instaGradient
                  : const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF3B82F6),
                        Color(0xFF60A5FA),
                      ],
                    ),
              onTap: onYourStoryTap,
              showAddBadge: true,
              segmentsCount: 1,
              uploadProgress: yourStoryUploadProgress,
              onAddTap: onYourStoryAddTap,
            );
          }
          final user = users[index - offset];
          final uid = (user['id'] ?? user['_id'] ?? '').toString();
          final status = userStatuses?[uid] ?? const {};
          final isCloseFriend = status['isCloseFriend'] == true;
          final hasUnseen = status['hasUnseen'] == true;
          final allViewed = status['allViewed'] == true;
          final isSubscribed = status['isSubscribedCreator'] == true;
          final segmentsCount = (status['segments'] == true ? 2 : 1); // boolean presence indicates multi for simplicity
          Gradient ring;
          if (isSubscribed) {
            ring = const LinearGradient(
              colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            );
          } else if (isCloseFriend) {
            ring = const LinearGradient(
              colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            );
          } else if (hasUnseen) {
            ring = DesignTokens.instaGradient;
          } else if (allViewed) {
            ring = LinearGradient(colors: [Colors.grey.shade300, Colors.grey.shade300]);
          } else {
            ring = DesignTokens.instaGradient;
          }
          return _StoryItem(
            label: (user['username'] ?? user['full_name'] ?? '').toString(),
            avatarUrl: user['avatar_url'] as String?,
            ringGradient: ring,
            onTap: onUserStoryTap != null ? () => onUserStoryTap!(index - offset) : null,
            segmentsCount: segmentsCount,
          );
        },
      ),
    );
  }
}

class _StoryItem extends StatelessWidget {
  final String label;
  final String? avatarUrl;
  final Gradient ringGradient;
  final VoidCallback? onTap;
  final bool showAddBadge;
  final int segmentsCount;
  final double? uploadProgress;
  final VoidCallback? onAddTap;

  const _StoryItem({required this.label, this.avatarUrl, required this.ringGradient, this.onTap, this.showAddBadge = false, this.segmentsCount = 1, this.uploadProgress, this.onAddTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: ringGradient,
            ),
            padding: EdgeInsets.all(segmentsCount > 1 ? 2 : 3),
            child: CircleAvatar(
              radius: 28,
              backgroundColor: isDark ? Colors.black : Colors.white,
              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
              child: avatarUrl == null ? Icon(LucideIcons.user, color: Colors.grey) : null,
            ),
              ),
              if (uploadProgress != null && (uploadProgress! > 0 && uploadProgress! < 1))
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: CircularProgressIndicator(
                        value: uploadProgress!.clamp(0, 1),
                        strokeWidth: 3,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                        backgroundColor: Colors.white24,
                      ),
                    ),
                  ),
                ),
              if (showAddBadge)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: GestureDetector(
                    onTap: onAddTap,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.add, size: 14, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 72,
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface),
          ),
        ),
      ],
    );
  }
}
