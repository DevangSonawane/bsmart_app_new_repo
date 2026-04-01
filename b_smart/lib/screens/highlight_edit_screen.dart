import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../models/story_model.dart';
import '../models/highlight_model.dart';
import '../api/highlights_api.dart';
import '../api/upload_api.dart';
import '../api/stories_api.dart';
import '../services/highlight_service.dart';

const _kBlue = Color(0xFF3897F0);
const _kSheet = Color(0xFF1C1C1E);
const _kBg = Color(0xFF000000);
const _kField = Color(0xFF1C1C1E);

/// Edit screen for a highlight: rename, change cover, remove individual items.
class HighlightEditScreen extends StatefulWidget {
  final Highlight highlight;
  final List<Story> items;

  const HighlightEditScreen({
    super.key,
    required this.highlight,
    required this.items,
  });

  @override
  State<HighlightEditScreen> createState() => _HighlightEditScreenState();
}

class _HighlightEditScreenState extends State<HighlightEditScreen> {
  final HighlightsApi _api = HighlightsApi();
  final StoriesApi _storiesApi = StoriesApi();
  final HighlightService _highlightService = HighlightService();
  late final TextEditingController _titleController;

  late List<Story> _items;
  final Set<String> _itemsToRemove = {}; // highlight item ids (_itemId)
  final Set<String> _itemsToAdd = {}; // story ids from archive
  final Set<String> _existingMediaUrls = {};
  List<Story> _archiveStories = const [];
  bool _archiveLoading = true;
  String? _newCoverUrl; // either picked local path or existing URL
  File? _newCoverFile;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.highlight.title);
    _items = List.from(widget.items);
    _newCoverUrl = widget.highlight.coverUrl;
    _existingMediaUrls.addAll(_items.map((e) => e.mediaUrl));
    _loadArchivedStoryItems();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() {
      _newCoverFile = File(picked.path);
      _newCoverUrl = null; // will be uploaded on save
    });
  }

  void _toggleRemoveItem(Story item) {
    setState(() {
      if (_itemsToRemove.contains(item.id)) {
        _itemsToRemove.remove(item.id);
      } else {
        _itemsToRemove.add(item.id);
      }
    });
  }

  void _toggleAddItem(Story item) {
    if (_existingMediaUrls.contains(item.mediaUrl)) return;
    setState(() {
      if (_itemsToAdd.contains(item.id)) {
        _itemsToAdd.remove(item.id);
      } else {
        _itemsToAdd.add(item.id);
      }
    });
  }

  Future<void> _loadArchivedStoryItems() async {
    setState(() => _archiveLoading = true);
    try {
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
      final mapped = _highlightService.mapHighlightItems(items);
      if (!mounted) return;
      setState(() {
        _archiveStories = mapped;
        _archiveLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _archiveStories = const [];
        _archiveLoading = false;
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title cannot be empty')),
      );
      return;
    }
    setState(() => _saving = true);

    try {
      // 1. Upload new cover if local file was picked
      String? uploadedCoverUrl;
      if (_newCoverFile != null) {
        final upload = UploadApi();
        final uploaded = await upload.uploadFile(_newCoverFile!.path);
        uploadedCoverUrl =
            (uploaded['fileUrl'] as String?) ?? (uploaded['url'] as String?);
      }

      // 2. Add newly selected archive items
      if (_itemsToAdd.isNotEmpty) {
        await _api.addItems(widget.highlight.id, _itemsToAdd.toList());
      }

      // 3. Remove marked items
      for (final itemId in _itemsToRemove) {
        await _api.deleteItem(widget.highlight.id, itemId);
      }

      // 4. Update title / cover on server
      final titleChanged = title != widget.highlight.title;
      final coverChanged =
          uploadedCoverUrl != null || _newCoverUrl != widget.highlight.coverUrl;
      if (titleChanged || coverChanged) {
        await _api.update(
          widget.highlight.id,
          title: titleChanged ? title : null,
          coverUrl: uploadedCoverUrl ?? _newCoverUrl,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: _kBg,
        appBar: AppBar(
          backgroundColor: _kBg,
          elevation: 0,
          title: const Text(
            'Edit Highlight',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Done',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                controller: _titleController,
                maxLength: 30,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: _kField,
                  counterStyle:
                      const TextStyle(color: Colors.white38, fontSize: 11),
                  hintText: 'Highlight name',
                  hintStyle: const TextStyle(color: Colors.white38),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: GestureDetector(
                onTap: _showCoverPickerSheet,
                child: Row(
                  children: [
                    _buildCoverThumb(),
                    const SizedBox(width: 12),
                    const Text(
                      'Edit Cover',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    const Spacer(),
                    const Icon(Icons.chevron_right,
                        color: Colors.white38),
                  ],
                ),
              ),
            ),
            const TabBar(
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: [
                Tab(text: 'Archive'),
                Tab(text: 'Selected'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildArchiveTab(),
                  _buildSelectedTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverThumb() {
    final size = 48.0;
    final child = _newCoverFile != null
        ? Image.file(_newCoverFile!, width: size, height: size, fit: BoxFit.cover)
        : (widget.highlight.coverUrl != null
            ? CachedNetworkImage(
                imageUrl: widget.highlight.coverUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _coverPlaceholder(size),
              )
            : _coverPlaceholder(size));
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: _kField,
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _buildArchiveTab() {
    if (_archiveLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    if (_archiveStories.isEmpty) {
      return const Center(
        child: Text('No stories', style: TextStyle(color: Colors.white38)),
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
      itemCount: _archiveStories.length,
      itemBuilder: (_, i) {
        final story = _archiveStories[i];
        final alreadyInHighlight = _existingMediaUrls.contains(story.mediaUrl);
        final selected = _itemsToAdd.contains(story.id) || alreadyInHighlight;
        return GestureDetector(
          onTap: () => _toggleAddItem(story),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: story.thumbnailUrl ?? story.mediaUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(color: _kField),
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
                    child: const Icon(Icons.check,
                        size: 16, color: Colors.white),
                  ),
                ),
              if (story.mediaType == StoryMediaType.video)
                const Positioned(
                  left: 6,
                  bottom: 6,
                  child: Icon(Icons.play_arrow,
                      color: Colors.white, size: 16),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSelectedTab() {
    if (_items.isEmpty) {
      return const Center(
        child: Text('No items', style: TextStyle(color: Colors.white38)),
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
      itemCount: _items.length,
      itemBuilder: (_, i) {
        final item = _items[i];
        final markedForRemove = _itemsToRemove.contains(item.id);
        return GestureDetector(
          onTap: () => _toggleRemoveItem(item),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: item.thumbnailUrl ?? item.mediaUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                    Container(color: Colors.black26),
              ),
              if (markedForRemove)
                Container(color: Colors.red.withValues(alpha: 0.25)),
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: markedForRemove
                        ? Colors.red
                        : Colors.grey.shade700,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    markedForRemove ? Icons.remove : Icons.close,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
              if (markedForRemove)
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 6,
                  child: Text(
                    'Will be removed',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red, fontSize: 10),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showCoverPickerSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _kSheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white),
              title: const Text('Choose from library',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickCover();
              },
            ),
            ListTile(
              leading: const Icon(Icons.close, color: Colors.white70),
              title: const Text('Cancel',
                  style: TextStyle(color: Colors.white70)),
              onTap: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _coverPlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      color: _kField,
      child: const Icon(Icons.photo, color: Colors.white38, size: 24),
    );
  }
}
