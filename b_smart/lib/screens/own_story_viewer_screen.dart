import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/story_model.dart';
import 'package:image_picker/image_picker.dart';
import '../api/api.dart';
import '../api/api_exceptions.dart';
import '../services/feed_service.dart';

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
  Timer? _timer;
  List<Map<String, dynamic>> _viewers = const [];
  int _viewsCount = 0;
  int _uniqueViewersCount = 0;
  double _dragStartX = 0;
  late List<Story> _stories;
  final FeedService _feedService = FeedService();

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _stories = List<Story>.from(widget.stories);
     _viewsCount = widget.stories.isNotEmpty ? widget.stories.first.views : 0;
    _start();
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
      _start();
    } catch (_) {
      // ignore
    }
  }

  Future<void> _loadAnalyticsIfNeeded() async {
    final sid = widget.storyId;
    if (sid == null || sid.isEmpty) return;
    try {
      final viewers = await StoriesApi().viewers(sid);
      if (!mounted) return;
      final uniqueUsers = viewers
          .map((v) => (v['user_id'] ?? v['id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet()
          .length;
      setState(() {
        _viewers = viewers;
        _viewsCount = viewers.length;
        _uniqueViewersCount = uniqueUsers;
      });
    } catch (_) {
      // ignore analytics errors for UI
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    _progress = 0.0;
    _timer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      setState(() => _progress += 0.01);
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
      if (_controller.hasClients) {
        _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      } else {
        _controller.jumpToPage(_index);
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
      if (_controller.hasClients) {
        _controller.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      } else {
        _controller.jumpToPage(_index);
      }
      _start();
    } else {
      Navigator.pop(context);
    }
  }

  void _openViewers() {
    if (widget.storyId == null || widget.storyId!.isEmpty) {
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        if (_viewers.isNotEmpty) {
          final viewers = _viewers;
          return SafeArea(
            child: ListView.builder(
              itemCount: viewers.length,
              itemBuilder: (_, i) {
                final v = viewers[i];
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
              },
            ),
          );
        }
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: StoriesApi().viewers(widget.storyId!),
          builder: (ctx, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SafeArea(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                ),
              );
            }
            if (snapshot.hasError) {
              return const SafeArea(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No viewers yet'),
                  ),
                ),
              );
            }
            final viewers = snapshot.data ?? const [];
            if (viewers.isEmpty) {
              return const SafeArea(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No viewers yet'),
                  ),
                ),
              );
            }
            return SafeArea(
              child: ListView.builder(
                itemCount: viewers.length,
                itemBuilder: (_, i) {
                  final v = viewers[i];
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
                },
              ),
            );
          },
        );
      },
    );
  }

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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Uploading...')));
      final bytes = await xfile.readAsBytes();
      final upload = await UploadApi().uploadFileBytes(bytes: bytes.toList(), filename: 'story.jpg');
      final url = (upload['fileUrl'] as String?) ??
          (upload['url'] as String?) ??
          (upload['file_url'] as String?) ??
          (upload['data'] is Map ? (upload['data']['url'] as String?) : null) ??
          '';
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Posted to your story')));
    } catch (e) {
      final msg = e is ApiException ? e.message : 'Failed to add story';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _deleteCurrentStory() async {
    if (_stories.isEmpty) return;
    _timer?.cancel();
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
    if (confirmed != true) {
      _start();
      return;
    }
    try {
      final sid = widget.storyId;
      if (sid != null && sid.isNotEmpty) {
        await StoriesApi().delete(sid);
      } else {
        final current = _stories[_index];
        await StoriesApi().deleteItem(current.id);
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Story deleted')));
      Navigator.pop(context);
    } catch (e) {
      final msg = e is ApiException ? e.message : 'Failed to delete story';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      _start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final story = _stories[_index];
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
            _openInsights();
          }
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: story.mediaUrl.isNotEmpty
                  ? Image.network(
                      story.mediaUrl,
                      fit: BoxFit.cover,
                    )
                  : Container(color: Colors.black),
            ),
            Positioned(
              top: 40,
              left: 8,
              right: 8,
              child: Column(
                children: [
                  Row(
                    children: List.generate(
                      _stories.length,
                      (i) => Expanded(
                        child: Container(
                          height: 2,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(color: Colors.white.withAlpha(80), borderRadius: BorderRadius.circular(2)),
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
                      Text(widget.userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(onPressed: _deleteCurrentStory, icon: const Icon(Icons.more_horiz, color: Colors.white)),
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(LucideIcons.x, color: Colors.white)),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  TextButton(
                    onPressed: _openViewers,
                    child: Text('👁️ $_viewsCount views', style: const TextStyle(color: Colors.white)),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _quickAddStory,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                    child: const Text('Add to Story'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
