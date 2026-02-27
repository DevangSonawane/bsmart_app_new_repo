import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/design_tokens.dart';

class ProfileHeader extends StatelessWidget {
  final String username;
  final String? fullName;
  final String? bio;
  final String? avatarUrl;
  final int posts;
  final int followers;
  final int following;
  final bool isMe;
  final bool isFollowing;
  final VoidCallback? onEdit;
  final VoidCallback? onFollow;
  final VoidCallback? onAvatarTap;

  const ProfileHeader({
    Key? key,
    required this.username,
    this.fullName,
    this.bio,
    this.avatarUrl,
    this.posts = 0,
    this.followers = 0,
    this.following = 0,
    this.isMe = false,
    this.isFollowing = false,
    this.onEdit,
    this.onFollow,
    this.onAvatarTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fgColor = theme.colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: onAvatarTap,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: DesignTokens.instaGradient,
                  ),
                  child: Builder(
                    builder: (context) {
                      final hasAvatar = avatarUrl != null && avatarUrl!.trim().isNotEmpty;
                      return CircleAvatar(
                        radius: 40,
                        backgroundImage: hasAvatar ? CachedNetworkImageProvider(avatarUrl!) : null,
                        backgroundColor: theme.cardColor,
                        child: !hasAvatar
                            ? Text(
                                username.isNotEmpty ? username[0].toUpperCase() : '',
                                style: TextStyle(fontSize: 24, color: fgColor),
                              )
                            : null,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 24),
              // Stats centered vertically
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _statColumn(context, posts, 'posts'),
                    _statColumn(context, followers, 'followers'),
                    _statColumn(context, following, 'following'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            fullName?.trim().isNotEmpty == true ? fullName!.trim() : username,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: fgColor),
          ),
          if (bio != null && bio!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(bio!, style: TextStyle(fontSize: 14, color: fgColor)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (isMe)
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onEdit,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: const BoxDecoration(
                          gradient: DesignTokens.instaGradient,
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                        alignment: Alignment.center,
                        child: const Text('Edit Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onFollow,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: const BoxDecoration(
                          gradient: DesignTokens.instaGradient,
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          isFollowing ? 'Following' : 'Follow',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {},
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: const BoxDecoration(
                        gradient: DesignTokens.instaGradient,
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                      alignment: Alignment.center,
                      child: const Text('Share profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statColumn(BuildContext context, int count, String label) {
    final theme = Theme.of(context);
    final fgColor = theme.colorScheme.onSurface;
    final mutedColor = theme.textTheme.bodyMedium?.color ?? Colors.black54;
    return Column(
      children: [
        Text(count.toString(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: fgColor)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: mutedColor, fontSize: 12)),
      ],
    );
  }
}
