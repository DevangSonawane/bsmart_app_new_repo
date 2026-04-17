import 'package:b_smart/api/api.dart';
import 'package:b_smart/utils/url_helper.dart';
import 'package:flutter/material.dart';

class TweetComposerPage extends StatefulWidget {
  final String? username;
  final String? avatarUrl;

  const TweetComposerPage({
    super.key,
    this.username,
    this.avatarUrl,
  });

  @override
  State<TweetComposerPage> createState() => _TweetComposerPageState();
}

class _TweetComposerPageState extends State<TweetComposerPage> {
  static Map<String, dynamic>? _cachedMe;

  late final TextEditingController _controller;
  Map<String, dynamic>? _me;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _loadMe();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _extractUsername(Map<String, dynamic>? me) {
    final provided = widget.username?.trim() ?? '';
    if (provided.isNotEmpty) return provided;
    final raw = me?['username'] ??
        me?['userName'] ??
        me?['full_name'] ??
        me?['fullName'] ??
        me?['name'];
    final s = raw == null ? '' : raw.toString().trim();
    return s.isNotEmpty ? s : 'username';
  }

  String _extractAvatarUrl(Map<String, dynamic>? me) {
    final provided = widget.avatarUrl?.trim() ?? '';
    if (provided.isNotEmpty) return UrlHelper.normalizeUrl(provided);

    final raw = me?['avatar_url'] ??
        me?['avatarUrl'] ??
        me?['profile_pic'] ??
        me?['profilePic'] ??
        me?['profile_image'] ??
        me?['profileImage'] ??
        me?['picture'] ??
        me?['photo_url'] ??
        me?['photoUrl'];
    final s = raw == null ? '' : raw.toString().trim();
    return UrlHelper.normalizeUrl(s);
  }

  Future<void> _loadMe() async {
    final cached = _cachedMe;
    if (cached != null) {
      _me = cached;
      return;
    }
    try {
      final me = await AuthApi().me();
      if (!mounted) return;
      final normalized = Map<String, dynamic>.from(me);
      _cachedMe = normalized;
      setState(() => _me = normalized);
    } catch (_) {
      // ignore (not authenticated / offline)
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final username = _extractUsername(_me);
    final avatarUrl = _extractAvatarUrl(_me);

    Widget actionIcon(IconData icon, {VoidCallback? onTap}) {
      return IconButton(
        onPressed: onTap,
        icon: Icon(icon),
        color: colors.onSurfaceVariant,
        splashRadius: 20,
      );
    }

    Widget avatar() {
      final bg = colors.surfaceContainerHighest;
      if (avatarUrl.isEmpty) {
        return CircleAvatar(
          radius: 18,
          backgroundColor: bg,
          child: Icon(Icons.person, color: colors.onSurfaceVariant),
        );
      }
      return CircleAvatar(
        radius: 18,
        backgroundColor: bg,
        backgroundImage: NetworkImage(avatarUrl),
      );
    }

    return Material(
      color: colors.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close),
                      color: colors.onSurface,
                      splashRadius: 20,
                    ),
                    const Spacer(),
                    Text(
                      'New tweet',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                    const Spacer(),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _controller,
                      builder: (context, value, child) {
                        final canPost = value.text.trim().isNotEmpty;
                        return FilledButton(
                          onPressed: canPost ? () {} : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: colors.primary,
                            foregroundColor: colors.onPrimary,
                            disabledBackgroundColor:
                                colors.surfaceContainerHighest,
                            disabledForegroundColor:
                                colors.onSurfaceVariant.withValues(alpha: 0.7),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            shape: const StadiumBorder(),
                            textStyle: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          child: const Text('Post'),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    avatar(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                username,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colors.onSurface,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: colors.outlineVariant
                                          .withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          'Community or topic',
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: colors.onSurfaceVariant,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Icon(
                                        Icons.keyboard_arrow_down,
                                        size: 16,
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _controller,
                            autofocus: true,
                            maxLines: null,
                            minLines: 6,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: colors.onSurface,
                              height: 1.25,
                            ),
                            decoration: InputDecoration(
                              hintText: "What's new?",
                              hintStyle: theme.textTheme.bodyLarge?.copyWith(
                                color: colors.onSurfaceVariant
                                    .withValues(alpha: 0.8),
                              ),
                              border: InputBorder.none,
                              isCollapsed: true,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              actionIcon(Icons.image_outlined),
                              actionIcon(Icons.gif_box_outlined),
                              actionIcon(Icons.poll_outlined),
                            ],
                          ),
                        ],
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
