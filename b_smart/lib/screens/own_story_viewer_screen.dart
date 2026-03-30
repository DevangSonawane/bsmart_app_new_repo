import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';
import '../models/story_model.dart';
import 'package:image_picker/image_picker.dart';
import '../api/api.dart';
import '../services/feed_service.dart';
import '../utils/current_user.dart';
import 'package:http/http.dart' as http;
import 'package:photo_manager/photo_manager.dart';

class OwnStoryViewerScreen extends StatefulWidget {
  final List<Story> stories;
  final String userName;
  final String? storyId;
  const OwnStoryViewerScreen({super.key, required this.stories, required this.userName, this.storyId});

  @override
  State<OwnStoryViewerScreen> createState() => _OwnStoryViewerScreenState();
}

class _OwnStoryViewerScreenState extends State<OwnStoryViewerScreen> {
  late PageController _controller;
  int _index = 0;
  double _progress = 0.0;
  bool _waitingForMedia = false;
  Timer? _timer;
  VideoPlayerController? _videoCtl;
  List<Map<String, dynamic>> _viewers = const [];
  double _dragStartX = 0;
  bool _controlsTap = false;
  bool _sheetOpen = false;
  bool _commentingEnabled = true;
  late List<Story> _stories;
  final FeedService _feedService = FeedService();

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _stories = List<Story>.from(widget.stories);
    _start();
    _loadVideoForCurrent();
    _loadItemsIfNeeded();
    _loadAnalyticsIfNeeded();
  }

  Future<void> _loadItemsIfNeeded() async {
    final sid = widget.storyId;
    if (sid == null || sid.isEmpty) return;
    try {
      final items = await _feedService.fetchStoryItems(
        sid,
        ownerUserName: widget.userName,
        ownerAvatar: _stories.isNotEmpty ? _stories.first.userAvatar : null,
      );
      if (!mounted || items.isEmpty) return;
      setState(() {
        _stories = items;
        _index = 0;
        _progress = 0.0;
      });
      _loadVideoForCurrent();
      _start();
    } catch (_) {
      // ignore
    }
  }

  Future<void> _loadVideoForCurrent() async {
    if (_stories.isEmpty) return;
    final story = _stories[_index];
    if (story.thumbnailUrl != null && story.thumbnailUrl!.isNotEmpty) {
      try {
        await precacheImage(
          NetworkImage(story.thumbnailUrl!),
          context,
        );
      } catch (_) {
        // ignore thumbnail precache errors
      }
    }
    if (story.mediaType == StoryMediaType.video && story.mediaUrl.isNotEmpty) {
      try {
        _videoCtl?.dispose();
        _videoCtl = VideoPlayerController.networkUrl(Uri.parse(story.mediaUrl));
        await _videoCtl!.initialize();
        await _videoCtl!.setLooping(false);
        await _videoCtl!.play();
        if (!mounted) return;
        setState(() {});
        if (_waitingForMedia) {
          _start();
        }
      } catch (_) {
        // ignore
      }
    } else {
      _videoCtl?.dispose();
      _videoCtl = null;
      _waitingForMedia = false;
    }
  }

  Future<void> _loadAnalyticsIfNeeded() async {
    final sid = widget.storyId;
    if (sid == null || sid.isEmpty) return;
    try {
      final viewers = await StoriesApi().viewers(sid);
      if (!mounted) return;
      setState(() {
        _viewers = viewers;
      });
    } catch (_) {
      // ignore analytics errors for UI
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _videoCtl?.dispose();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    _progress = 0.0;
    if (_stories.isNotEmpty) {
      final story = _stories[_index];
      if (story.mediaType == StoryMediaType.video &&
          !(_videoCtl?.value.isInitialized ?? false)) {
        _waitingForMedia = true;
        return;
      }
    }
    _waitingForMedia = false;
    final story = _stories.isNotEmpty ? _stories[_index] : null;
    int durationMs = 5000;
    if (story != null && story.mediaType == StoryMediaType.video) {
      final dur = _videoCtl?.value.duration.inMilliseconds ?? 0;
      if (dur > 0) {
        durationMs = dur;
      } else {
        durationMs = (story.durationSec ?? 5) * 1000;
      }
    }
    const tickMs = 50;
    final ticks = (durationMs / tickMs).clamp(1, 100000).toInt();
    _timer = Timer.periodic(const Duration(milliseconds: tickMs), (t) {
      setState(() => _progress += 1.0 / ticks);
      if (_progress >= 1.0) {
        t.cancel();
        _next();
      }
    });
  }

  void _next() {
    if (_index < _stories.length - 1) {
      setState(() {
        _index++;
        _progress = 0.0;
      });
      _loadVideoForCurrent();
      if (_controller.hasClients) {
        _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      }
      _start();
    } else {
      Navigator.pop(context);
    }
  }

  void _prev() {
    if (_index > 0) {
      setState(() {
        _index--;
        _progress = 0.0;
      });
      _loadVideoForCurrent();
      if (_controller.hasClients) {
        _controller.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      }
      _start();
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _openViewers() async {
    if (_sheetOpen) return;
    _sheetOpen = true;
    _timer?.cancel();
    final result = await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        if (_viewers.isNotEmpty) {
          return _buildViewersSheet(_viewers);
        }
        final sid = widget.storyId;
        if (sid == null || sid.isEmpty) {
          return _buildEmptyViewers();
        }
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: StoriesApi().viewers(sid),
          builder: (ctx, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SafeArea(
                  child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ));
            }
            if (snapshot.hasError) {
              return _buildEmptyViewers();
            }
            final viewers = snapshot.data ?? const [];
            if (viewers.isEmpty) {
              return _buildEmptyViewers();
            }
            return _buildViewersSheet(viewers);
          },
        );
      },
    );
    if (!mounted) return;
    _sheetOpen = false;
    if (result is int) {
      _jumpToIndex(result);
      await Future.delayed(const Duration(milliseconds: 50));
      if (mounted) {
        await _openViewers();
        return;
      }
    }
    _start();
  }

  void _jumpToIndex(int idx) {
    if (idx < 0 || idx >= _stories.length) return;
    setState(() {
      _index = idx;
      _progress = 0.0;
    });
    _loadVideoForCurrent();
    if (_controller.hasClients) {
      _controller.animateToPage(
        idx,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
    _start();
  }

  Future<void> _openHighlightPicker() async {
    if (_sheetOpen) return;
    _sheetOpen = true;
    _timer?.cancel();
    await _videoCtl?.pause();
    final userId = await CurrentUser.id;
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        if (userId == null || userId.isEmpty) {
          return _buildSimpleSheet('Please login to add highlights.');
        }
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: HighlightsApi().userHighlights(userId),
          builder: (ctx, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildSimpleSheet('Loading highlights...');
            }
            if (snapshot.hasError) {
              return _buildSimpleSheet('Failed to load highlights');
            }
            final list = snapshot.data ?? const <Map<String, dynamic>>[];
            return _buildHighlightSheet(list);
          },
        );
      },
    );
    if (!mounted) return;
    _sheetOpen = false;
    _start();
  }

  Future<void> _openMentionPicker() async {
    if (_sheetOpen) return;
    _sheetOpen = true;
    _timer?.cancel();
    await _videoCtl?.pause();

    final results = <Map<String, dynamic>>[];
    final selected = <String, Map<String, dynamic>>{};
    bool loading = false;
    Timer? debounce;
    bool sheetActive = true;

    Future<void> runSearch(String query, void Function(void Function()) setLocal) async {
      debounce?.cancel();
      debounce = Timer(const Duration(milliseconds: 250), () async {
        if (!mounted || !sheetActive) return;
        setLocal(() => loading = true);
        try {
          final data = await UsersApi().search(query);
          if (!mounted || !sheetActive) return;
          setLocal(() {
            results
              ..clear()
              ..addAll(data);
            loading = false;
          });
        } catch (_) {
          if (!mounted || !sheetActive) return;
          setLocal(() {
            results.clear();
            loading = false;
          });
        }
      });
    }

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (results.isEmpty && !loading) {
              runSearch('', setLocal);
            }
          });
          final viewInsets = MediaQuery.of(ctx).viewInsets.bottom;
          return SafeArea(
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final maxH = constraints.maxHeight.isFinite
                    ? constraints.maxHeight
                    : MediaQuery.of(ctx).size.height;
                final sheetHeight = maxH * 0.5;
                return Padding(
                  padding: EdgeInsets.only(bottom: viewInsets),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: sheetHeight),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFF2A2D33),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                      ),
                      child: Column(
                        children: [
                      const SizedBox(height: 10),
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            const Text('Tag people',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                            const Spacer(),
                            IconButton(
                              onPressed: () {
                                sheetActive = false;
                                Navigator.of(ctx).pop();
                              },
                              icon: const Icon(LucideIcons.x, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          height: 44,
                          child: TextField(
                            style: const TextStyle(color: Colors.white),
                            onChanged: (q) => runSearch(q, setLocal),
                            decoration: InputDecoration(
                              hintText: 'Search people',
                              hintStyle: const TextStyle(color: Colors.white54),
                              filled: true,
                              fillColor: Colors.white12,
                              prefixIcon: const Icon(Icons.search, color: Colors.white54),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Colors.white24),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Colors.white24),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Colors.white54),
                              ),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 56,
                        child: selected.isEmpty
                            ? const Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Text('Select people to tag',
                                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                scrollDirection: Axis.horizontal,
                                itemCount: selected.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 8),
                                itemBuilder: (_, i) {
                                  final u = selected.values.elementAt(i);
                                  final name =
                                      (u['username'] ?? u['full_name'] ?? 'User').toString();
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white12,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('@$name',
                                            style: const TextStyle(color: Colors.white, fontSize: 12)),
                                        const SizedBox(width: 6),
                                        GestureDetector(
                                          onTap: () => setLocal(() {
                                            selected.removeWhere((key, value) =>
                                                (value['username'] ?? value['full_name']) ==
                                                (u['username'] ?? u['full_name']));
                                          }),
                                          child: const Icon(LucideIcons.x,
                                              size: 12, color: Colors.white70),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: loading
                            ? const Center(child: CircularProgressIndicator(color: Colors.white))
                            : results.isEmpty
                                ? const Center(
                                    child: Text('No results',
                                        style: TextStyle(color: Colors.white70)),
                                  )
                                : ListView.separated(
                                    padding: EdgeInsets.zero,
                                    itemCount: results.length,
                                    separatorBuilder: (_, __) =>
                                        const Divider(height: 1, color: Colors.white10),
                                    itemBuilder: (ctx, i) {
                                      final u = results[i];
                                      final id =
                                          (u['id'] ?? u['_id'] ?? u['user_id'])?.toString() ?? '';
                                      final name =
                                          (u['username'] ?? u['full_name'] ?? 'User').toString();
                                      final key = id.isNotEmpty ? id : name;
                                      final avatar = u['avatar_url'] as String?;
                                      final isSelected = key.isNotEmpty && selected.containsKey(key);
                                      return SizedBox(
                                        height: 56,
                                        child: ListTile(
                                          dense: true,
                                          leading: CircleAvatar(
                                            backgroundImage: (avatar != null && avatar.isNotEmpty)
                                                ? NetworkImage(avatar)
                                                : null,
                                            backgroundColor: Colors.white24,
                                            child: (avatar == null || avatar.isEmpty)
                                                ? Text(
                                                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                                    style: const TextStyle(color: Colors.white),
                                                  )
                                                : null,
                                          ),
                                          title: Text(name,
                                              style: const TextStyle(color: Colors.white)),
                                          trailing: Icon(
                                            isSelected
                                                ? Icons.check_circle
                                                : Icons.radio_button_unchecked,
                                            color:
                                                isSelected ? Colors.greenAccent : Colors.white38,
                                          ),
                                          onTap: () {
                                            if (key.isEmpty) return;
                                            setLocal(() {
                                              if (isSelected) {
                                                selected.remove(key);
                                              } else {
                                                selected[key] = u;
                                              }
                                            });
                                          },
                                        ),
                                      );
                                    },
                                  ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () {
                              if (selected.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Select at least one person')),
                                );
                                return;
                              }
                              sheetActive = false;
                              Navigator.of(ctx).pop();
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('User mentioned successfully')),
                              );
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF4F7DFF),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: const Color(0xFF4F7DFF),
                              disabledForegroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: const BorderSide(color: Colors.white24),
                              ),
                            ),
                            child: Text(
                              selected.isEmpty
                                  ? 'Tag people'
                                  : 'Tag ${selected.length} people',
                            ),
                          ),
                        ),
                      ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );

    sheetActive = false;
    debounce?.cancel();
    if (!mounted) return;
    _sheetOpen = false;
    _start();
  }

  Future<void> _openMoreMenu() async {
    if (_sheetOpen) return;
    _sheetOpen = true;
    _timer?.cancel();
    await _videoCtl?.pause();
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2D33),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 6, 6),
                        child: Row(
                          children: [
                            const Icon(Icons.history_toggle_off, color: Colors.white70, size: 18),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                "Archive stories while they're active.",
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              icon: const Icon(LucideIcons.x, color: Colors.white70, size: 18),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Colors.white12),
                      _buildMoreAction(
                        label: 'Delete story',
                        color: const Color(0xFFFF5D5D),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _deleteCurrentStory();
                          });
                        },
                      ),
                      _buildMoreAction(
                        label: 'Archive',
                        onTap: () {
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Story archived')),
                          );
                        },
                      ),
                      _buildMoreAction(
                        label: 'Highlight',
                        onTap: () {
                          Navigator.of(ctx).pop();
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _openHighlightPicker();
                          });
                        },
                      ),
                      _buildMoreAction(
                        label: 'Save...',
                        onTap: () {
                          Navigator.of(ctx).pop();
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _saveCurrentStoryToGallery();
                          });
                        },
                      ),
                      _buildMoreAction(
                        label: 'Edit AI label',
                        onTap: () {
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Edit AI label')),
                          );
                        },
                      ),
                      _buildMoreAction(
                        label: 'Story settings',
                        onTap: () {
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Story settings')),
                          );
                        },
                      ),
                      _buildMoreAction(
                        label: _commentingEnabled ? 'Turn off commenting' : 'Turn on commenting',
                        onTap: () {
                          Navigator.of(ctx).pop();
                          if (!mounted) return;
                          setState(() => _commentingEnabled = !_commentingEnabled);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                _commentingEnabled
                                    ? 'Commenting turned on'
                                    : 'Commenting turned off',
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2A2D33),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted) return;
    _sheetOpen = false;
    _start();
  }

  Widget _buildMoreAction({
    required String label,
    VoidCallback? onTap,
    Color color = Colors.white,
  }) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 48,
        width: double.infinity,
        child: Center(
          child: Text(
            label,
            style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }

  Future<void> _saveCurrentStoryToGallery() async {
    if (_stories.isEmpty) return;
    try {
      final PermissionState ps = await PhotoManager.requestPermissionExtend();
      if (!ps.isAuth) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gallery permission is required to save.')),
        );
        return;
      }

      final story = _stories[_index];
      final url = story.mediaUrl;
      if (url.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No media to save.')),
        );
        return;
      }

      final stamp = DateTime.now().millisecondsSinceEpoch;
      final title = 'bsmart_story_$stamp';

      if (story.mediaType == StoryMediaType.video || _isVideoUrl(url)) {
        final res = await http.get(Uri.parse(url));
        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw Exception('Download failed');
        }
        final tmp = File('${Directory.systemTemp.path}/$title.mp4');
        await tmp.writeAsBytes(res.bodyBytes, flush: true);
        final saved = await PhotoManager.editor.saveVideo(tmp, title: title);
        if (saved == null) {
          throw Exception('Save failed');
        }
      } else {
        final res = await http.get(Uri.parse(url));
        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw Exception('Download failed');
        }
        final Uint8List bytes = res.bodyBytes;
        final saved = await PhotoManager.editor.saveImage(
          bytes,
          title: title,
          filename: '$title.jpg',
        );
        if (saved == null) {
          throw Exception('Save failed');
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved to gallery.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  Widget _buildSimpleSheet(String message) {
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF2A2D33),
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(message, style: const TextStyle(color: Colors.white70)),
        ),
      ),
    );
  }

  Widget _buildHighlightSheet(List<Map<String, dynamic>> highlights) {
    const sheetColor = Color(0xFF2A2D33);
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (ctx, scroll) {
          return Container(
            decoration: const BoxDecoration(
              color: sheetColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Text('Add to highlight',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(LucideIcons.x, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Colors.white12),
                Expanded(
                  child: ListView.builder(
                    controller: scroll,
                    itemCount: highlights.length + 1,
                    itemBuilder: (ctx, i) {
                      if (i == 0) {
                        return ListTile(
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.add, color: Colors.white),
                          ),
                          title: const Text('New highlight',
                              style: TextStyle(color: Colors.white)),
                          onTap: () => _promptCreateHighlight(),
                        );
                      }
                      final h = highlights[i - 1];
                      final title = (h['title'] ?? h['name'] ?? 'Highlight').toString();
                      final cover = (h['cover_url'] ?? h['coverUrl'])?.toString();
                      final id = (h['id'] ?? h['_id'])?.toString() ?? '';
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: (cover != null && cover.isNotEmpty)
                              ? NetworkImage(cover)
                              : null,
                          backgroundColor: Colors.white24,
                          child: (cover == null || cover.isEmpty)
                              ? Text(title.isNotEmpty ? title[0].toUpperCase() : 'H',
                                  style: const TextStyle(color: Colors.white))
                              : null,
                        ),
                        title: Text(title, style: const TextStyle(color: Colors.white)),
                        onTap: id.isEmpty ? null : () => _addStoryToHighlight(id, highlight: h),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _promptCreateHighlight() async {
    final nameController = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2D33),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('New highlight',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        content: TextField(
          controller: nameController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Highlight name',
            hintStyle: const TextStyle(color: Colors.white54),
            filled: true,
            fillColor: Colors.white12,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.white24),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.white24),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.white54),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(nameController.text.trim()),
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (title == null || title.isEmpty) return;
    await _createHighlightAndAdd(title);
  }

  Future<void> _createHighlightAndAdd(String title) async {
    final story = _stories.isNotEmpty ? _stories[_index] : null;
    final currentUserId = await CurrentUser.id;
    if (currentUserId != null &&
        story != null &&
        story.userId.isNotEmpty &&
        story.userId != currentUserId) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only your stories can be highlighted')),
      );
      return;
    }
    final storyItem = await _resolveStoryItem(currentUserId: currentUserId);
    final storyId = storyItem?.id;
    final coverUrl = story?.mediaUrl;
    if (storyId == null || storyId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to add highlight (story item not found)')),
      );
      return;
    }
    String highlightId = '';
    try {
      debugPrint(
        'Highlight create/add: userId=$currentUserId storyId=$storyId storyUser=${storyItem?.userId} title=$title cover=$coverUrl',
      );
      final created = await HighlightsApi().create(title: title, coverUrl: coverUrl);
      highlightId = (created['id'] ?? created['_id'])?.toString() ?? '';
      if (highlightId.isNotEmpty) {
        debugPrint('Highlight created: id=$highlightId, adding items...');
        await HighlightsApi().addItems(highlightId, [storyId]);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Highlight added')),
      );
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
    } catch (e) {
      if (e is ApiException) {
        debugPrint('Highlight add error: ${e.statusCode} ${e.message} body=${e.body}');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException ? '${e.message} (HTTP ${e.statusCode})' : 'Failed to add highlight',
          ),
        ),
      );
    }
  }

  Future<void> _addStoryToHighlight(String highlightId, {Map<String, dynamic>? highlight}) async {
    final story = _stories.isNotEmpty ? _stories[_index] : null;
    final currentUserId = await CurrentUser.id;
    if (currentUserId != null &&
        story != null &&
        story.userId.isNotEmpty &&
        story.userId != currentUserId) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only your stories can be highlighted')),
      );
      return;
    }
    final storyItem = await _resolveStoryItem(currentUserId: currentUserId);
    final storyId = storyItem?.id;
    if (storyId == null || storyId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to add highlight (story item not found)')),
      );
      return;
    }
    try {
      final highlightOwner = (highlight?['user_id'] as String?) ?? '';
      String? authUserId;
      try {
        final me = await AuthApi().me();
        authUserId = (me['id'] ?? me['_id'])?.toString();
      } catch (_) {}
      if (currentUserId != null &&
          highlightOwner.isNotEmpty &&
          highlightOwner != currentUserId) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Highlight ownership mismatch')),
        );
        return;
      }
      if (authUserId != null &&
          authUserId.isNotEmpty &&
          highlightOwner.isNotEmpty &&
          authUserId != highlightOwner) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Auth user mismatch')),
        );
        return;
      }
      debugPrint(
        'Highlight add item: userId=$currentUserId authUser=$authUserId highlightOwner=$highlightOwner highlightId=$highlightId storyId=$storyId storyUser=${storyItem?.userId}',
      );
      debugPrint('Highlight add payload: story_item_ids=[$storyId]');
      await HighlightsApi().addItems(highlightId, [storyId]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Highlight added')),
      );
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
    } catch (e) {
      if (e is ApiException) {
        debugPrint('Highlight add error: ${e.statusCode} ${e.message} body=${e.body}');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException ? '${e.message} (HTTP ${e.statusCode})' : 'Failed to add highlight',
          ),
        ),
      );
    }
  }

  Future<Story?> _resolveStoryItem({String? currentUserId}) async {
    final sid = widget.storyId;
    if (sid != null && sid.isNotEmpty) {
      try {
        final items = await _feedService.fetchStoryItems(
          sid,
          ownerUserName: widget.userName,
          ownerAvatar: _stories.isNotEmpty ? _stories.first.userAvatar : null,
        );
        if (items.isNotEmpty) {
          final idx = _index.clamp(0, items.length - 1);
          final current = _stories.isNotEmpty ? _stories[_index] : null;
          Story match;
          if (current != null) {
            match = items.firstWhere(
              (s) => s.mediaUrl == current.mediaUrl,
              orElse: () => items[idx],
            );
          } else {
            match = items[idx];
          }
          if (currentUserId != null &&
              currentUserId.isNotEmpty &&
              match.userId.isNotEmpty &&
              match.userId != currentUserId) {
            return null;
          }
          final id = match.id;
          if (id.isNotEmpty && id != 'item') return match;
          final fallback = items.first;
          if (fallback.id.isNotEmpty && fallback.id != 'item') return fallback;
        }
      } catch (_) {}
    }
    if (_stories.isNotEmpty) {
      final fallback = _stories[_index];
      if (fallback.id.isNotEmpty && fallback.id != 'item') return fallback;
    }
    return null;
  }

  Widget _buildEmptyViewers() {
    return _buildViewersSheet(const <Map<String, dynamic>>[]);
  }

  Widget _buildViewersSheet(List<Map<String, dynamic>> viewers) {
    const sheetColor = Color(0xFF2A2D33);
    const accentBlue = Color(0xFF4F7DFF);
    final story = _stories.isNotEmpty ? _stories[_index] : null;
    final nextStory = (_index + 1 < _stories.length) ? _stories[_index + 1] : null;
    final previewUrl = story?.mediaUrl ?? '';
    final isPreviewVideo =
        story?.mediaType == StoryMediaType.video || _isVideoUrl(previewUrl);
    final nextPreviewUrl = nextStory?.mediaUrl ?? '';
    final isNextPreviewVideo =
        nextStory?.mediaType == StoryMediaType.video || _isVideoUrl(nextPreviewUrl);
    final countText = viewers.isEmpty ? '0' : '${viewers.length}';
    const previewW = 64.0;
    const previewH = 92.0;
    final previewScale = (previewW / 360.0).clamp(0.14, 0.22);
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (ctx, scroll) {
          return Container(
            decoration: const BoxDecoration(
              color: sheetColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Transform.translate(
                  offset: const Offset(0, -2),
                  child: Transform.rotate(
                    angle: pi / 4,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: sheetColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 92,
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: previewW,
                          height: previewH,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: isPreviewVideo
                                      ? Container(
                                          color: Colors.black87,
                                          child: const Center(
                                            child: Icon(
                                              Icons.play_arrow,
                                              color: Colors.white70,
                                              size: 20,
                                            ),
                                          ),
                                        )
                                      : (previewUrl.isNotEmpty
                                          ? Image.network(
                                              previewUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  Container(color: Colors.black87),
                                            )
                                          : Container(color: Colors.black87)),
                                ),
                                Positioned(
                                  bottom: 6,
                                  left: 6,
                                  right: 6,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.remove_red_eye,
                                          size: 12, color: Colors.white70),
                                      const SizedBox(width: 4),
                                      Text(
                                        countText,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ...((story?.texts ?? const [])
                                    .map((t) => Map<String, dynamic>.from(t))
                                    .map((t) {
                                  final left = ((t['x'] as num?) ?? 0) * previewW;
                                  final top = ((t['y'] as num?) ?? 0) * previewH;
                                  final clampedLeft = left.clamp(2.0, previewW - 2);
                                  final clampedTop = top.clamp(2.0, previewH - 2);
                                  final content = (t['content'] as String?) ?? '';
                                  final baseSize =
                                      (t['fontSize'] as num?)?.toDouble() ?? 20.0;
                                  final fontSize =
                                      (baseSize * previewScale).clamp(6.0, 14.0);
                                  final color =
                                      _parseStoryColor(t['color']) ?? Colors.white;
                                  return Positioned(
                                    left: clampedLeft,
                                    top: clampedTop,
                                    child: Text(
                                      content,
                                      style: TextStyle(
                                        color: color,
                                        fontSize: fontSize,
                                        fontWeight: FontWeight.w600,
                                        shadows: const [
                                          Shadow(
                                            offset: Offset(0, 1),
                                            blurRadius: 2,
                                            color: Color(0xAA000000),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList()),
                                ...((story?.mentions ?? const [])
                                    .map((m) => Map<String, dynamic>.from(m))
                                    .map((m) {
                                  final left = ((m['x'] as num?) ?? 0) * previewW;
                                  final top = ((m['y'] as num?) ?? 0) * previewH;
                                  final clampedLeft = left.clamp(2.0, previewW - 2);
                                  final clampedTop = top.clamp(2.0, previewH - 2);
                                  final username = (m['username'] as String?) ?? '';
                                  final scale =
                                      _mentionScaleFor(username, story?.texts ?? const []);
                                  final fontSize =
                                      (10.0 * previewScale * scale).clamp(6.0, 12.0);
                                  return Positioned(
                                    left: clampedLeft,
                                    top: (clampedTop - (10 * previewScale) - 2)
                                        .clamp(2.0, previewH - 2),
                                    child: Text(
                                      '@$username',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: fontSize,
                                        fontWeight: FontWeight.w600,
                                        shadows: const [
                                          Shadow(
                                            offset: Offset(0, 1),
                                            blurRadius: 2,
                                            color: Color(0xAA000000),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList()),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: nextStory == null ? null : () => Navigator.of(context).pop(_index + 1),
                          child: Container(
                            width: 64,
                            height: 92,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: isNextPreviewVideo
                                        ? Container(
                                            color: Colors.black87,
                                            child: const Center(
                                              child: Icon(
                                                Icons.play_arrow,
                                                color: Colors.white70,
                                                size: 20,
                                              ),
                                            ),
                                          )
                                        : (nextPreviewUrl.isNotEmpty
                                            ? Image.network(
                                                nextPreviewUrl,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    Container(color: Colors.black87),
                                              )
                                            : Container(color: Colors.black87)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.bar_chart, color: Colors.white70, size: 18),
                      const SizedBox(width: 14),
                      const Icon(Icons.people_alt_outlined, color: accentBlue, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        countText,
                        style: const TextStyle(color: accentBlue, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).pop();
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _deleteCurrentStory();
                          });
                        },
                        child: const Icon(Icons.delete_outline, color: Colors.white70, size: 18),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: Colors.white12),
                const SizedBox(height: 10),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Who viewed this story',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: viewers.isEmpty
                      ? const Center(
                          child: Text('No viewers yet',
                              style: TextStyle(color: Colors.white70)),
                        )
                      : ListView.separated(
                          controller: scroll,
                          itemCount: viewers.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white10),
                          itemBuilder: (_, i) {
                            final v = viewers[i];
                            final name = (v['username'] ?? v['full_name'] ?? 'Viewer').toString();
                            final avatar = v['avatar_url'] as String?;
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: SizedBox(
                                height: 56,
                                child: ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                    backgroundImage:
                                        avatar != null && avatar.isNotEmpty ? NetworkImage(avatar) : null,
                                    backgroundColor: Colors.white24,
                                    child: (avatar == null || avatar.isEmpty)
                                        ? Text(
                                            name.isNotEmpty ? name[0].toUpperCase() : 'V',
                                            style: const TextStyle(color: Colors.white),
                                          )
                                        : null,
                                  ),
                                  title: Text(name, style: const TextStyle(color: Colors.white)),
                                  trailing: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.more_horiz, color: Colors.white70, size: 18),
                                      SizedBox(width: 12),
                                      Icon(LucideIcons.send, color: Colors.white70, size: 18),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  bool _isVideoUrl(String url) {
    final u = url.toLowerCase();
    return u.endsWith('.mp4') || u.endsWith('.mov') || u.endsWith('.m3u8');
  }

  // ignore: unused_element
  void _openInsights() {
    if (widget.storyId == null || widget.storyId!.isEmpty) {
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (ctx, scroll) => FutureBuilder<List<Map<String, dynamic>>>(
          future: StoriesApi().viewers(widget.storyId!),
          builder: (ctx, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            if (snapshot.hasError) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No viewers yet'),
                ),
              );
            }
            final viewers = snapshot.data ?? const [];
            _viewers = viewers;
            final totalViews = viewers.length;
            final uniqueUsers = viewers
                .map((v) => (v['user_id'] ?? v['id'] ?? '').toString())
                .where((id) => id.isNotEmpty)
                .toSet()
                .length;
            return Container(
              padding: const EdgeInsets.all(16),
              child: ListView(
                controller: scroll,
                children: [
                  const Text('Insights', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text('Total views: $totalViews'),
                  const SizedBox(height: 4),
                  Text('Unique viewers: $uniqueUsers'),
                  const SizedBox(height: 12),
                  const Text('Recent viewers:'),
                  const SizedBox(height: 8),
                  if (viewers.isEmpty)
                    const Text('No viewers yet')
                  else
                    ...viewers.take(20).map((v) {
                      final name = (v['username'] ?? v['full_name'] ?? 'Viewer').toString();
                      final avatar = v['avatar_url'] as String?;
                      final viewedAtRaw = v['viewedAt'] as String? ?? v['createdAt'] as String?;
                      DateTime? viewedAt;
                      if (viewedAtRaw != null && viewedAtRaw.isNotEmpty) {
                        viewedAt = DateTime.tryParse(viewedAtRaw);
                      }
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: avatar != null && avatar.isNotEmpty ? NetworkImage(avatar) : null,
                          child: (avatar == null || avatar.isEmpty) ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'V') : null,
                        ),
                        title: Text(name),
                        subtitle: viewedAt != null ? Text(viewedAt.toLocal().toString()) : null,
                      );
                    }),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Color? _parseStoryColor(dynamic value) {
    if (value == null) return null;
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;
    final lower = raw.toLowerCase();
    if (lower == 'white') return Colors.white;
    if (lower == 'black') return Colors.black;
    var hex = raw.startsWith('#') ? raw.substring(1) : raw;
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    if (hex.length != 8) return null;
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) return null;
    return Color(parsed);
  }

  double _mentionScaleFor(String username, List<dynamic> textData) {
    if (username.isEmpty) return 1.0;
    for (final t in textData) {
      final content = (t['content'] as String?) ?? '';
      if (content.contains('@$username')) {
        final size = (t['fontSize'] as num?)?.toDouble() ?? 32.0;
        return (size / 32.0).clamp(0.6, 1.4);
      }
    }
    return 1.0;
  }

  String _timeAgoShort(DateTime date) {
    final now = DateTime.now();
    var diff = now.difference(date);
    if (diff.isNegative) diff = Duration.zero;
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  Future<void> _quickAddStory() async {
    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Use Camera'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
      if (source == null) return;
      final picker = ImagePicker();
      final xfile = await picker.pickImage(source: source, imageQuality: 85);
      if (xfile == null) return;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploading...')),
      );
      final bytes = await xfile.readAsBytes();
      final upload = await UploadApi().uploadFileBytes(bytes: bytes.toList(), filename: 'story.jpg');
      final url = (upload['fileUrl'] as String?) ??
          (upload['url'] as String?) ??
          (upload['file_url'] as String?) ??
          (upload['data'] is Map ? (upload['data']['url'] as String?) : null) ??
          '';
      if (!mounted) return;
      if (url.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload failed')));
        return;
      }
      final payload = {
        'media': {'url': url, 'type': 'image'},
        'transform': {'x': 0.5, 'y': 0.5, 'scale': 1, 'rotation': 0},
        'filter': {'name': 'none', 'intensity': 0},
        'texts': [],
        'mentions': [],
      };
      await StoriesApi().createFlexible([payload]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Posted to your story')));
    } catch (e) {
      final msg = e is ApiException ? e.message : 'Failed to add story';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  // ignore: unused_element
  Future<void> _deleteCurrentStory() async {
    if (_stories.isEmpty) return;
    _timer?.cancel();
    if (_index < 0 || _index >= _stories.length) {
      _start();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete story?'),
        content: const Text('This will remove the story for everyone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed != true) {
      _start();
      return;
    }
    try {
      final sid = widget.storyId;
      final current = _stories[_index];
      final hasItemId = current.id.isNotEmpty;
      final hasStoryId = sid != null && sid.isNotEmpty;
      if (!hasItemId && !hasStoryId) {
        throw Exception('Missing story id');
      }
      Map<String, dynamic> result = const {};
      if (hasItemId) {
        result = await StoriesApi().deleteItem(current.id);
      } else if (hasStoryId) {
        await StoriesApi().delete(sid);
      }
      final storyDeleted = (result['story_deleted'] == true);
      if (!mounted) return;
      setState(() {
        if (storyDeleted) {
          _stories.clear();
          _index = 0;
        } else {
          if (_stories.isNotEmpty) {
            _stories.removeAt(_index);
          }
          if (_stories.isEmpty) {
            _index = 0;
          } else if (_index >= _stories.length) {
            _index = _stories.length - 1;
          }
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Story deleted')));
      if (_stories.isEmpty) {
        Navigator.pop(context);
      } else {
        _progress = 0.0;
        _start();
      }
    } catch (e) {
      final msg = e is ApiException ? e.message : 'Failed to delete story';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      _start();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_stories.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }
    final story = _stories[_index];
    final mediaUrl = story.mediaUrl;
    final createdAt = story.createdAt;
    final avatarUrl = story.userAvatar;
    final timeLabel = _timeAgoShort(createdAt);
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    final safeTop = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onHorizontalDragStart: (details) {
          _dragStartX = details.globalPosition.dx;
        },
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! > 0 && _dragStartX < 24) {
            _quickAddStory();
            return;
          }
        },
        onTapUp: (d) {
          if (_controlsTap || _sheetOpen) return;
          final w = MediaQuery.of(context).size.width;
          if (d.globalPosition.dx < w / 2) {
            _prev();
          } else {
            _next();
          }
        },
        onLongPressStart: (_) => _timer?.cancel(),
        onLongPressEnd: (_) => _start(),
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! > 0) {
            Navigator.pop(context);
          } else {
            _openViewers();
          }
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: story.mediaType == StoryMediaType.video
                  ? (_videoCtl != null && _videoCtl!.value.isInitialized)
                      ? FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _videoCtl!.value.size.width,
                            height: _videoCtl!.value.size.height,
                            child: VideoPlayer(_videoCtl!),
                          ),
                        )
                      : (mediaUrl.isNotEmpty
                          ? Image.network(
                              mediaUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(color: Colors.black),
                            )
                          : Container(color: Colors.black))
                  : (mediaUrl.isNotEmpty
                      ? Image.network(
                          mediaUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(LucideIcons.image, size: 80, color: Colors.white54),
                          ),
                        )
                      : Container(color: Colors.black)),
            ),
            ...((story.texts ?? const []).asMap().entries.map((e) {
              final t = e.value as Map? ?? const {};
              final left = ((t['x'] as num?) ?? 0) * w;
              final top = ((t['y'] as num?) ?? 0) * h;
              final clampedLeft = left.clamp(8.0, w - 8);
              final clampedTop = top.clamp(8.0, h - 8);
              final content = (t['content'] as String?) ?? '';
              final fontSize = (t['fontSize'] as num?)?.toDouble() ?? 20.0;
              final color = _parseStoryColor(t['color']) ?? Colors.white;
              return Positioned(
                left: clampedLeft,
                top: clampedTop,
                child: Text(
                  content,
                  style: TextStyle(
                    color: color,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                    shadows: const [
                      Shadow(
                        offset: Offset(0, 1),
                        blurRadius: 3,
                        color: Color(0xAA000000),
                      ),
                    ],
                  ),
                ),
              );
            }).toList()),
            ...((story.mentions ?? const []).asMap().entries.map((e) {
              final m = e.value as Map? ?? const {};
              final left = ((m['x'] as num?) ?? 0) * w;
              final top = ((m['y'] as num?) ?? 0) * h;
              final clampedLeft = left.clamp(8.0, w - 8);
              final clampedTop = top.clamp(8.0, h - 8);
              final username = (m['username'] as String?) ?? '';
              final scale = _mentionScaleFor(username, story.texts ?? const []);
              return Positioned(
                left: clampedLeft,
                top: (clampedTop - (18 * scale) - 4).clamp(8.0, h - 8),
                child: Text(
                  '@$username',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12 * scale,
                    fontWeight: FontWeight.w600,
                    shadows: const [
                      Shadow(
                        offset: Offset(0, 1),
                        blurRadius: 3,
                        color: Color(0xAA000000),
                      ),
                    ],
                  ),
                ),
              );
            }).toList()),
            Positioned(
              top: safeTop + 8,
              left: 12,
              right: 12,
              child: Column(
                children: [
                  Row(
                    children: List.generate(
                      _stories.length,
                      (i) => Expanded(
                        child: Container(
                          height: 2,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(80),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: i == _index
                              ? FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: _progress,
                                  child: Container(color: Colors.white),
                                )
                              : i < _index
                                  ? Container(color: Colors.white)
                                  : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                        backgroundColor: Colors.white10,
                        child: (avatarUrl == null || avatarUrl.isEmpty)
                            ? Text(
                                widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : 'U',
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Your story',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '$timeLabel · ${widget.userName}',
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(LucideIcons.x, color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (_) => _controlsTap = true,
                onTapCancel: () => _controlsTap = false,
                onTapUp: (_) => _controlsTap = false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    if (_commentingEnabled) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Row(
                          children: [
                            Text('Say something...',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
                            const Spacer(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Row(
                      children: [
                        _ActionItem(
                          icon: LucideIcons.activity,
                          label: 'Activity',
                          onTap: _openViewers,
                        ),
                        const Spacer(),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _ActionItem(
                              icon: LucideIcons.atSign,
                              label: 'Mention',
                              onTap: _openMentionPicker,
                            ),
                            const SizedBox(width: 12),
                            const _ActionItem(icon: LucideIcons.send, label: 'Send'),
                          ],
                        ),
                        const SizedBox(width: 12),
                        _ActionItem(icon: Icons.more_horiz, label: 'More', onTap: _openMoreMenu),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _ActionItem({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
        ],
      ),
    );
  }
}
