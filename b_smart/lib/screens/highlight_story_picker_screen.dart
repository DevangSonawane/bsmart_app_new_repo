import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../api/highlights_api.dart';
import '../api/stories_api.dart';
import '../models/story_model.dart';
import '../services/feed_service.dart';
import '../services/highlight_service.dart';
import '../utils/current_user.dart';

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
  State<HighlightStoryPickerScreen> createState() => _HighlightStoryPickerScreenState();
}

class _HighlightStoryPickerScreenState extends State<HighlightStoryPickerScreen> {
  final FeedService _feedService = FeedService();
  final StoriesApi _storiesApi = StoriesApi();
  final HighlightService _highlightService = HighlightService();

  final Set<String> _selectedIds = {};
  List<Story> _stories = const [];
  bool _loading = true;
  bool _error = false;
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    _loadStories();
  }

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
      final byId = <String, Story>{};
      for (final s in [...activeItems, ...archivedItems]) {
        if (s.id.isEmpty) continue;
        byId[s.id] = s;
      }
      final merged = byId.values.toList();
      merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!mounted) return;
      setState(() {
        _stories = merged;
        _loading = false;
        _error = false;
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
    if (items.isEmpty) return const <Story>[];
    return _highlightService.mapHighlightItems(
      items,
      ownerUserName: widget.userName,
      ownerAvatar: widget.userAvatar,
    );
  }

  Future<void> _createNewHighlight() async {
    if (_selectedIds.isEmpty || _actionLoading) return;
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Highlight'),
        content: TextField(
          controller: controller,
          maxLength: 30,
          decoration: const InputDecoration(
            labelText: 'Title',
            hintText: 'e.g. Travel',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (title == null || title.isEmpty) return;

    setState(() => _actionLoading = true);
    try {
      final coverUrl = _stories
          .firstWhere((s) => _selectedIds.contains(s.id), orElse: () => _stories.first)
          .mediaUrl;
      final created = await HighlightsApi().create(title: title, coverUrl: coverUrl);
      final highlightId = (created['_id'] as String?) ?? (created['id'] as String?) ?? '';
      if (highlightId.isEmpty) {
        throw Exception('Missing highlight id');
      }
      await HighlightsApi().addItems(highlightId, _selectedIds.toList());
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create highlight')),
      );
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _addToExistingHighlight() async {
    if (_selectedIds.isEmpty || _actionLoading) return;
    final highlights = await HighlightsApi().userHighlights(widget.userId);
    highlights.sort((a, b) {
      final ao = (a['order'] as num?)?.toInt() ?? 0;
      final bo = (b['order'] as num?)?.toInt() ?? 0;
      return ao.compareTo(bo);
    });
    if (!mounted) return;
    if (highlights.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No highlights to add into')),
      );
      return;
    }
    final selectedHighlightId = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF2A2D33),
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: highlights.length + 1,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white12),
              itemBuilder: (ctx, i) {
                if (i == 0) {
                  return ListTile(
                    title: const Text('Select a highlight',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    trailing: IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  );
                }
                final h = highlights[i - 1];
                final title = (h['title'] ?? 'Highlight').toString();
                final id = (h['_id'] as String?) ?? (h['id'] as String?) ?? '';
                return ListTile(
                  title: Text(title, style: const TextStyle(color: Colors.white)),
                  onTap: id.isEmpty ? null : () => Navigator.of(ctx).pop(id),
                );
              },
            ),
          ),
        );
      },
    );
    if (selectedHighlightId == null || selectedHighlightId.isEmpty) return;

    setState(() => _actionLoading = true);
    try {
      await HighlightsApi().addItems(selectedHighlightId, _selectedIds.toList());
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to add to highlight')),
      );
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Stories'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error
              ? const Center(child: Text('Failed to load stories'))
              : _stories.isEmpty
                  ? const Center(child: Text('No stories found'))
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.65,
                      ),
                      itemCount: _stories.length,
                      itemBuilder: (ctx, i) {
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
                          child: Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: selected
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.white24,
                                    width: selected ? 2 : 1,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: CachedNetworkImage(
                                  imageUrl: story.mediaUrl,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => Container(color: Colors.black12),
                                ),
                              ),
                              if (story.mediaType == StoryMediaType.video)
                                const Positioned(
                                  right: 6,
                                  bottom: 6,
                                  child: Icon(Icons.play_circle_fill, color: Colors.white70),
                                ),
                              if (selected)
                                Positioned(
                                  right: 6,
                                  top: 6,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.check, size: 14, color: Colors.white),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_selectedIds.length} selected',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _selectedIds.isEmpty || _actionLoading
                          ? null
                          : _addToExistingHighlight,
                      child: _actionLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Add to Existing'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed:
                          _selectedIds.isEmpty || _actionLoading ? null : _createNewHighlight,
                      child: _actionLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('New Highlight'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
