import 'package:b_smart/api/api.dart';
import 'package:b_smart/utils/url_helper.dart';
import 'package:b_smart/utils/app_error_handler.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

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

  static void clearCachedMe() {
    _cachedMe = null;
  }

  late final TextEditingController _controller;
  Map<String, dynamic>? _me;
  final ImagePicker _picker = ImagePicker();
  final List<_TweetDraftMedia> _media = [];
  bool _posting = false;

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

  Future<void> _pickImages() async {
    try {
      final picked = await _picker.pickMultiImage(imageQuality: 100);
      if (picked.isEmpty) return;
      final remaining = 4 - _media.length;
      if (remaining <= 0) return;
      final toAdd = picked.take(remaining).toList();
      final next = <_TweetDraftMedia>[];
      for (final file in toAdd) {
        final bytes = await file.readAsBytes();
        if (bytes.isEmpty) continue;
        next.add(_TweetDraftMedia(filename: file.name, bytes: bytes));
      }
      if (!mounted || next.isEmpty) return;
      setState(() => _media.addAll(next));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to pick images')),
      );
    }
  }

  String _extractUploadUrl(Map<String, dynamic> payload) {
    String pick(dynamic v) {
      final s = (v ?? '').toString().trim();
      return UrlHelper.normalizeUrl(s);
    }

    final mediaAny = payload['media'];
    if (mediaAny is Map) {
      final url =
          pick(mediaAny['url'] ?? mediaAny['fileUrl'] ?? mediaAny['file_url']);
      if (url.isNotEmpty) return url;
    }
    final url =
        pick(payload['url'] ?? payload['fileUrl'] ?? payload['file_url']);
    if (url.isNotEmpty) return url;
    final alt =
        pick(payload['fileUrl'] ?? payload['file_url'] ?? payload['path']);
    if (alt.isNotEmpty) return alt;
    return '';
  }

  Future<void> _submit() async {
    if (_posting) return;
    final content = _controller.text.trim();
    if (content.isEmpty && _media.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Add text or an image to post your tweet.')),
      );
      return;
    }
    setState(() => _posting = true);
    try {
      final tweetMedia = <Map<String, dynamic>>[];
      for (final m in _media) {
        final res = await TweetsApi().uploadTweetMediaBytes(
          bytes: m.bytes,
          filename: m.filename.isNotEmpty
              ? m.filename
              : 'tweet_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        final url = _extractUploadUrl(res);
        if (url.isNotEmpty) {
          tweetMedia.add({'url': url, 'type': 'image'});
        }
      }
      await TweetsApi().createTweet(
        content: content,
        media: tweetMedia.isEmpty ? null : tweetMedia,
        audience: 'everyone',
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e, st) {
      AppErrorHandler.logError('tweet-composer-post', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppErrorHandler.userMessage(
            e,
            fallback: 'Unable to publish right now. Please try again.',
          )),
        ),
      );
      setState(() => _posting = false);
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
                      'New Buzz',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                    const Spacer(),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _controller,
                      builder: (context, value, child) {
                        final canPost = (value.text.trim().isNotEmpty ||
                                _media.isNotEmpty) &&
                            !_posting;
                        return FilledButton(
                          onPressed: canPost ? _submit : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF3B82F6),
                            foregroundColor: Colors.white,
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
                          if (_media.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 86,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _media.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 10),
                                itemBuilder: (context, index) {
                                  final item = _media[index];
                                  return Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: Image.memory(
                                          item.bytes,
                                          width: 86,
                                          height: 86,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Positioned(
                                        top: 6,
                                        right: 6,
                                        child: InkWell(
                                          onTap: _posting
                                              ? null
                                              : () => setState(
                                                  () => _media.removeAt(index)),
                                          child: Container(
                                            width: 22,
                                            height: 22,
                                            decoration: BoxDecoration(
                                              color: Colors.black
                                                  .withValues(alpha: 0.55),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              size: 14,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              actionIcon(Icons.image_outlined,
                                  onTap: _posting ? null : _pickImages),
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

void clearTweetComposerCache() {
  _TweetComposerPageState.clearCachedMe();
}

class _TweetDraftMedia {
  final String filename;
  final Uint8List bytes;

  const _TweetDraftMedia({required this.filename, required this.bytes});
}
