import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../api/api_client.dart';
import '../models/story_model.dart';
import '../services/feed_service.dart';
import 'package:image_picker/image_picker.dart';
import '../api/api.dart';
import '../api/api_exceptions.dart';

class StoryViewerScreen extends StatefulWidget {
  final List<StoryGroup> storyGroups;
  final int initialIndex;

  const StoryViewerScreen({
    super.key,
    required this.storyGroups,
    this.initialIndex = 0,
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> {
  late PageController _pageController;
  late PageController _storyController;
  int _currentGroupIndex = 0;
  int _currentStoryIndex = 0;
  Timer? _autoPlayTimer;
  double _progress = 0.0;
  bool _paused = false;
  final TextEditingController _messageController = TextEditingController();
  final FeedService _feedService = FeedService();
  final Set<String> _viewedItemIds = <String>{};
  VideoPlayerController? _videoCtl;
  Future<void>? _initVideo;
  Map<String, String>? _videoHeaders;

  @override
  void initState() {
    super.initState();
    _currentGroupIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _storyController = PageController();
    ApiClient().getToken().then((token) {
      if (!mounted) return;
      if (token != null && token.isNotEmpty) {
        setState(() {
          _videoHeaders = {'Authorization': 'Bearer $token'};
        });
      }
    });
    _startAutoPlay();
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    _storyController.dispose();
    _videoCtl?.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    _progress = 0.0;
    _paused = false;
    
    final currentGroup = widget.storyGroups[_currentGroupIndex];
    // Lazy-load all items for current group when only a preview story is present
    if (currentGroup.stories.length <= 1 && (currentGroup.storyId ?? '').isNotEmpty) {
      _fetchGroupItems(_currentGroupIndex);
      return;
    }
    if (_currentStoryIndex >= currentGroup.stories.length) {
      _nextGroup();
      return;
    }

    final currentStory = currentGroup.stories[_currentStoryIndex];
    _setupCurrentStoryMedia(currentStory);

    final isImage = currentStory.mediaType == StoryMediaType.image;
    final durationMs = isImage ? 5000 : ((currentStory.durationSec ?? 5) * 1000);
    final tickMs = 50;
    final ticks = (durationMs / tickMs).clamp(1, 100000).toInt();
    _autoPlayTimer = Timer.periodic(Duration(milliseconds: tickMs), (timer) {
      setState(() {
        _progress += 1.0 / ticks;
      });

      if (_progress >= 1.0) {
        timer.cancel();
        final id = currentStory.id;
        if (!_viewedItemIds.contains(id)) {
          _viewedItemIds.add(id);
          _feedService.markItemViewed(id).catchError((_) {});
        }
        _nextStory();
      }
    });
  }

  void _nextStory() {
    final currentGroup = widget.storyGroups[_currentGroupIndex];
    if (_currentStoryIndex < currentGroup.stories.length - 1) {
      setState(() {
        _currentStoryIndex++;
        _progress = 0.0;
      });
      if (_storyController.hasClients) {
        _storyController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        _storyController.jumpToPage(_currentStoryIndex);
      }
      _setupCurrentStoryMedia(widget.storyGroups[_currentGroupIndex].stories[_currentStoryIndex]);
      _startAutoPlay();
    } else {
      _nextGroup();
    }
  }

  void _previousStory() {
    if (_currentStoryIndex > 0) {
      setState(() {
        _currentStoryIndex--;
        _progress = 0.0;
      });
      if (_storyController.hasClients) {
        _storyController.previousPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        _storyController.jumpToPage(_currentStoryIndex);
      }
      _setupCurrentStoryMedia(widget.storyGroups[_currentGroupIndex].stories[_currentStoryIndex]);
      _startAutoPlay();
    } else {
      _previousGroup();
    }
  }

  void _nextGroup() {
    if (_currentGroupIndex < widget.storyGroups.length - 1) {
      setState(() {
        _currentGroupIndex++;
        _currentStoryIndex = 0;
        _progress = 0.0;
      });
      if (_pageController.hasClients) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        _pageController.jumpToPage(_currentGroupIndex);
      }
      if (_storyController.hasClients) {
        _storyController.jumpToPage(0);
      }
      _fetchGroupItems(_currentGroupIndex);
      _startAutoPlay();
    } else {
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    }
  }

  void _previousGroup() {
    if (_currentGroupIndex > 0) {
      setState(() {
        _currentGroupIndex--;
        final previousGroup = widget.storyGroups[_currentGroupIndex];
        _currentStoryIndex = previousGroup.stories.length - 1;
        _progress = 0.0;
      });
      if (_pageController.hasClients) {
        _pageController.previousPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        _pageController.jumpToPage(_currentGroupIndex);
      }
      if (_storyController.hasClients) {
        _storyController.jumpToPage(_currentStoryIndex);
      }
      _startAutoPlay();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.storyGroups.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('No stories available')),
      );
    }

    final currentGroup = widget.storyGroups[_currentGroupIndex];
    final currentStory = currentGroup.stories[_currentStoryIndex];
    final isExpired = currentStory.expiresAt != null && DateTime.now().isAfter(currentStory.expiresAt!);
    final isUnavailable = isExpired || currentStory.isDeleted;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onLongPressStart: (_) {
          _autoPlayTimer?.cancel();
          if (_videoCtl != null && _videoCtl!.value.isInitialized) {
            _videoCtl!.pause();
          }
          setState(() => _paused = true);
        },
        onLongPressEnd: (_) {
          if (_videoCtl != null && _videoCtl!.value.isInitialized && !_videoCtl!.value.isPlaying) {
            _videoCtl!.play();
          }
          setState(() => _paused = false);
          _startAutoPlay();
        },
        onTapUp: (details) {
          final screenWidth = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < screenWidth / 2) {
            _previousStory();
          } else {
            _nextStory();
          }
        },
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! > 0) {
            Navigator.of(context).pop();
          } else {
            final s = currentStory;
            if ((s.productUrl ?? '').isNotEmpty) {
              _openProductSheet(s.productUrl!);
            } else if ((s.externalLink ?? '').isNotEmpty) {
              _openLinkSheet(s.externalLink!);
            } else if (s.hasPollQuiz) {
              _openPollSheet();
            }
          }
        },
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null) {
            if (details.primaryVelocity! > 0) {
              _previousGroup();
            } else {
              _nextGroup();
            }
          }
        },
        child: Stack(
          children: [
            // Story Content
            PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentGroupIndex = index;
                  _currentStoryIndex = 0;
                  _progress = 0.0;
                });
                _storyController.jumpToPage(0);
                final group = widget.storyGroups[_currentGroupIndex];
                if (group.stories.isNotEmpty) {
                  _setupCurrentStoryMedia(group.stories[0]);
                }
                _startAutoPlay();
              },
              itemCount: widget.storyGroups.length,
              itemBuilder: (context, groupIndex) {
                final group = widget.storyGroups[groupIndex];
                return PageView.builder(
                  controller: groupIndex == _currentGroupIndex
                      ? _storyController
                      : PageController(),
                  itemCount: group.stories.length,
                  itemBuilder: (context, storyIndex) {
                    final story = group.stories[storyIndex];
                    return _buildStoryContent(story);
                  },
                );
              },
            ),

            // Progress Bar
            Positioned(
              top: 40,
              left: 8,
              right: 8,
              child: Column(
                children: [
                  Row(
                    children: List.generate(
                      currentGroup.stories.length,
                      (index) => Expanded(
                        child: Container(
                          height: 2,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(1),
                          ),
                          child: index == _currentStoryIndex
                              ? FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: _progress,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(1),
                                    ),
                                  ),
                                )
                              : index < _currentStoryIndex
                                  ? Container(color: Colors.white)
                                  : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // User Info
                  Row(
                    children: [
                      InkWell(
                        onTap: currentGroup.userId.isNotEmpty
                            ? () => Navigator.of(context).pushNamed('/profile/${currentGroup.userId}')
                            : null,
                        borderRadius: BorderRadius.circular(24),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.blue,
                              child: Text(
                                currentGroup.userName[0].toUpperCase(),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentGroup.userName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _formatTimestamp(currentStory.createdAt),
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_horiz, color: Colors.white),
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'report', child: Text('Report')),
                          PopupMenuItem(value: 'mute', child: Text('Mute ${currentGroup.userName}\'s story')),
                          if (currentGroup.isCloseFriend) const PopupMenuItem(value: 'close_friends', child: Text('Close Friends')),
                        ],
                      ),
                      IconButton(
                        icon: Icon(LucideIcons.x, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isUnavailable)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withAlpha(160),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.white70, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          isExpired ? 'This story has expired' : 'This story is no longer available',
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(onPressed: _nextGroup, child: const Text('Next story')),
                      ],
                    ),
                  ),
                ),
              ),
            // Bottom message bar
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('❤️ 😂 😮 😢 👏 🔥 🎉 💯', style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Send message',
                            hintStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: Colors.white10,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _messageController.text.isNotEmpty ? () {} : null,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                        child: const Text('Send'),
                      ),
                      const SizedBox(width: 8),
                      IconButton(onPressed: _quickAddStory, icon: const Icon(Icons.camera_alt, color: Colors.white)),
                    ],
                  ),
                ],
              ),
            ),
          ],
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

  Future<void> _fetchGroupItems(int groupIndex) async {
    final g = widget.storyGroups[groupIndex];
    final sid = g.storyId;
    if (sid == null || sid.isEmpty) return;
    try {
      final items = await _feedService.fetchStoryItems(sid, ownerUserName: g.userName, ownerAvatar: g.userAvatar);
      setState(() {
        widget.storyGroups[groupIndex] = StoryGroup(
          userId: g.userId,
          userName: g.userName,
          userAvatar: g.userAvatar,
          isOnline: g.isOnline,
          isCloseFriend: g.isCloseFriend,
          isSubscribedCreator: g.isSubscribedCreator,
          storyId: g.storyId,
          stories: items,
        );
        _currentStoryIndex = 0;
        _progress = 0.0;
      });
      _startAutoPlay();
    } catch (_) {
      // ignore
    }
  }

  Widget _buildStoryContent(Story story) {
    final isImage = story.mediaType == StoryMediaType.image;
    final hasUrl = story.mediaUrl.isNotEmpty && (story.mediaUrl.startsWith('http://') || story.mediaUrl.startsWith('https://'));
    return LayoutBuilder(
      builder: (context, constraints) {
        final cw = constraints.maxWidth;
        final ch = constraints.maxHeight;
        return Stack(
          children: [
            Positioned.fill(
              child: Container(
                color: Colors.black,
                child: isImage && hasUrl
                    ? CachedNetworkImage(
                        imageUrl: story.mediaUrl,
                        httpHeaders: _videoHeaders,
                        fit: BoxFit.contain,
                        placeholder: (_, __) => const Center(child: CircularProgressIndicator(color: Colors.white)),
                        errorWidget: (_, __, ___) => Center(child: Icon(LucideIcons.image, size: 100, color: Colors.white54)),
                      )
                    : (story.mediaType == StoryMediaType.video && hasUrl && _videoCtl != null && _videoCtl!.value.isInitialized)
                        ? FittedBox(
                            fit: BoxFit.contain,
                            child: SizedBox(
                              width: _videoCtl!.value.size.width,
                              height: _videoCtl!.value.size.height,
                              child: VideoPlayer(_videoCtl!),
                            ),
                          )
                        : Center(
                            child: story.mediaType == StoryMediaType.video
                                ? Icon(LucideIcons.play, size: 100, color: Colors.white54)
                                : Icon(LucideIcons.image, size: 100, color: Colors.white54),
                          ),
              ),
            ),
            ...((story.mentions ?? []).asMap().entries.map((e) {
              final m = e.value;
              final left = ((m['x'] as num?) ?? 0) * cw;
              final top = ((m['y'] as num?) ?? 0) * ch;
              final username = (m['username'] as String?) ?? '';
              return Positioned(
                left: left.clamp(0, cw - 8),
                top: top.clamp(0, ch - 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('@$username', style: const TextStyle(color: Colors.white, fontSize: 12)),
                ),
              );
            }).toList()),
          ],
        );
      },
    );
  }

  void _setupCurrentStoryMedia(Story story) async {
    _videoCtl?.dispose();
    _videoCtl = null;
    _initVideo = null;
    if (story.mediaType == StoryMediaType.video && story.mediaUrl.isNotEmpty) {
      final headers = _videoHeaders ?? {};
      try {
        final uri = Uri.parse(story.mediaUrl);
        _videoCtl = VideoPlayerController.networkUrl(uri, httpHeaders: headers);
        _initVideo = _videoCtl!.initialize().then((_) {
          _videoCtl!.setLooping(true);
          _videoCtl!.setVolume(0);
          _videoCtl!.play();
          if (mounted) setState(() {});
        });
      } catch (_) {
        if (mounted) setState(() {});
      }
    } else {
      if (mounted) setState(() {});
    }
  }

  void _openProductSheet(String url) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('Product'), Text(url)]),
      ),
    );
  }

  void _openLinkSheet(String url) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('Link'), Text(url)]),
      ),
    );
  }

  void _openPollSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Poll / Quiz'),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Vote')),
        ]),
      ),
    );
  }

  String _formatTimestamp(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  TextAlign _toAlign(String a) {
    switch (a) {
      case 'center':
        return TextAlign.center;
      case 'right':
        return TextAlign.right;
      default:
        return TextAlign.left;
    }
  }
}
