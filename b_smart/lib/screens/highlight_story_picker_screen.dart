import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../api/stories_api.dart';
import '../models/story_model.dart';
import '../services/feed_service.dart';
import '../services/highlight_service.dart';
import '../utils/current_user.dart';
import 'highlight_name_screen.dart';

const _kBlue = Color(0xFF3897F0);
const _kBg = Color(0xFF000000);
const _kField = Color(0xFF1C1C1E);

/// Instagram-style story picker: select stories → create new highlight or add
/// to an existing one. Loads both active and archived stories.
class HighlightStoryPickerScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String? userAvatar;

  const HighlightStoryPickerScreen({
    super.key,
    required this.userId,
    required this.userName,
    this.userAvatar,
  });

  @override
  State<HighlightStoryPickerScreen> createState() =>
      _HighlightStoryPickerScreenState();
}

class _HighlightStoryPickerScreenState
    extends State<HighlightStoryPickerScreen> {
  final FeedService _feedService = FeedService();
  final StoriesApi _storiesApi = StoriesApi();
  final HighlightService _highlightService = HighlightService();

  final Set<String> _selectedIds = {};
  List<Story> _stories = const [];
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _loadStories();
  }

  // ── Data loading ────────────────────────────────────────────────────────

  Future<void> _loadStories() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final meId = await CurrentUser.id;
      if (meId == null || meId.isEmpty || meId != widget.userId) {
        throw Exception('Only your stories can be highlighted');
      }
      final activeItems = await _loadActiveStoryItems(meId);
      final archivedItems = await _loadArchivedStoryItems();

      // Merge, deduplicate by id, sort newest first
      final byId = <String, Story>{};
      for (final s in [...activeItems, ...archivedItems]) {
        if (s.id.isNotEmpty) byId[s.id] = s;
      }
      final merged = byId.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (!mounted) return;
      setState(() {
        _stories = merged;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  Future<List<Story>> _loadActiveStoryItems(String userId) async {
    final groups = await _feedService.fetchStoriesFeed();
    final group = groups.firstWhere(
      (g) => g.userId == userId,
      orElse: () => StoryGroup(
        userId: userId,
        userName: widget.userName,
        userAvatar: widget.userAvatar,
        stories: const [],
      ),
    );
    if ((group.storyId ?? '').isNotEmpty) {
      return _feedService.fetchStoryItems(
        group.storyId!,
        ownerUserName: widget.userName,
        ownerAvatar: widget.userAvatar,
      );
    }
    return group.stories;
  }

  Future<List<Story>> _loadArchivedStoryItems() async {
    final rawStories = await _storiesApi.archive();
    final items = <Map<String, dynamic>>[];
    for (final raw in rawStories) {
      final rawItems = raw['items'];
      if (rawItems is List && rawItems.isNotEmpty) {
        for (final item in rawItems.whereType<Map>()) {
          items.add(Map<String, dynamic>.from(item));
        }
      } else {
        items.add(Map<String, dynamic>.from(raw));
      }
    }
    if (items.isEmpty) return const [];
    return _highlightService.mapHighlightItems(
      items,
      ownerUserName: widget.userName,
      ownerAvatar: widget.userAvatar,
    );
  }

  Future<void> _goNext() async {
    if (_selectedIds.isEmpty) return;
    final selectedStories =
        _stories.where((s) => _selectedIds.contains(s.id)).toList();
    if (selectedStories.isEmpty) return;
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => HighlightNameScreen(
          selectedStories: selectedStories,
          userId: widget.userId,
          userName: widget.userName,
          userAvatar: widget.userAvatar,
        ),
      ),
    );
    if (updated == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Select',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _selectedIds.isEmpty ? null : _goNext,
            child: const Text('Next',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    if (_error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: Colors.white54, size: 48),
            const SizedBox(height: 12),
            const Text('Failed to load stories',
                style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _loadStories,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_stories.isEmpty) {
      return const Center(
        child: Text('No stories found',
            style: TextStyle(color: Colors.white54)),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 9 / 16,
      ),
      itemCount: _stories.length,
      itemBuilder: (_, i) {
        final story = _stories[i];
        final selected = _selectedIds.contains(story.id);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (selected) {
                _selectedIds.remove(story.id);
              } else {
                _selectedIds.add(story.id);
              }
            });
          },
          child: _StoryThumbnail(
            story: story,
            selected: selected,
          ),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: Container(
        color: _kBg,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: _selectedIds.isEmpty ? null : _goNext,
            style: FilledButton.styleFrom(
              backgroundColor: _kBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text(
              'Next',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Story thumbnail grid cell
// ─────────────────────────────────────────────────────────────────────────────

class _StoryThumbnail extends StatelessWidget {
  final Story story;
  final bool selected;

  const _StoryThumbnail({required this.story, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: story.thumbnailUrl ?? story.mediaUrl,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => Container(color: _kField),
        ),
        if (selected) Container(color: Colors.black.withValues(alpha: 0.6)),
        if (selected)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
              ),
            ),
          ),
        if (story.mediaType == StoryMediaType.video)
          const Positioned(
            left: 6,
            bottom: 6,
            child: Icon(Icons.play_arrow, color: Colors.white, size: 16),
          ),
        if (selected)
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: _kBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, size: 16, color: Colors.white),
            ),
          ),
      ],
    );
  }
}
