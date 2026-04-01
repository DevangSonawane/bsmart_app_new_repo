import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/highlight_model.dart';
import '../api/highlights_api.dart';
import '../services/highlight_service.dart';
import '../utils/current_user.dart';
import '../screens/highlight_viewer_screen.dart';
import '../screens/highlight_story_picker_screen.dart';
import '../screens/highlight_edit_screen.dart';

const _kRingColor = Colors.white;
const _kRingWidth = 2.0;
const _kCircleSize = 64.0;
const _kImageSize = 56.0;
const _kLabelStyle = TextStyle(color: Colors.white, fontSize: 11);

/// Drop-in widget that renders Instagram-style highlight circles on a profile.
///
/// Usage in ProfileScreen:
/// ```dart
/// ProfileHighlightsRow(
///   userId: profileUserId,
///   userName: profileUserName,
///   userAvatar: profileUserAvatar,
/// )
/// ```
class ProfileHighlightsRow extends StatefulWidget {
  final String userId;
  final String userName;
  final String? userAvatar;

  const ProfileHighlightsRow({
    super.key,
    required this.userId,
    required this.userName,
    this.userAvatar,
  });

  @override
  State<ProfileHighlightsRow> createState() => _ProfileHighlightsRowState();
}

class _ProfileHighlightsRowState extends State<ProfileHighlightsRow> {
  final HighlightsApi _api = HighlightsApi();
  final HighlightService _highlightService = HighlightService();

  List<Highlight> _highlights = const [];
  bool _loading = true;
  bool _isOwner = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final meId = await CurrentUser.id;
    _isOwner = meId != null && meId == widget.userId;
    await _loadHighlights();
  }

  Future<void> _loadHighlights() async {
    setState(() => _loading = true);
    try {
      final raw = await _api.userHighlights(widget.userId);
      Map<String, dynamic> _normalizeId(Map<String, dynamic> m) {
        final copy = Map<String, dynamic>.from(m);
        final id = copy['_id'];
        if (id != null && id is! String) copy['_id'] = id.toString();
        final id2 = copy['id'];
        if (id2 != null && id2 is! String) copy['id'] = id2.toString();
        return copy;
      }

      final parsed =
          raw.map((m) => Highlight.fromMap(_normalizeId(m))).toList()
        ..sort((a, b) => a.order.compareTo(b.order));
      if (mounted) setState(() => _highlights = parsed);
    } catch (_) {
      // silently fail — highlights are non-critical
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openHighlight(int index) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => HighlightViewerScreen(
          highlights: _highlights,
          initialIndex: index,
          ownerUserName: widget.userName,
          ownerAvatar: widget.userAvatar,
          isOwner: _isOwner,
        ),
      ),
    );
    if (result == true) {
      // Something was deleted / edited — reload
      _loadHighlights();
    }
  }

  Future<void> _openHighlightMenu(Highlight highlight) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.white),
              title: const Text('Edit Highlight',
                  style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.of(ctx).pop('edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete Highlight',
                  style: TextStyle(color: Colors.red)),
              onTap: () => Navigator.of(ctx).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || result == null) return;
    if (result == 'edit') {
      final items = await _highlightService.fetchHighlightItems(
        highlight.id,
        ownerUserName: widget.userName,
        ownerAvatar: widget.userAvatar,
      );
      if (!mounted) return;
      final updated = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => HighlightEditScreen(
            highlight: highlight,
            items: items,
          ),
        ),
      );
      if (updated == true) _loadHighlights();
    } else if (result == 'delete') {
      final confirmed = await _confirmDeleteHighlight(highlight);
      if (confirmed != true || !mounted) return;
      try {
        await _api.delete(highlight.id);
        if (mounted) _loadHighlights();
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete highlight')),
        );
      }
    }
  }

  Future<bool?> _confirmDeleteHighlight(Highlight highlight) async {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Delete highlight?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This will permanently delete "${highlight.title}".',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    shape: const RoundedRectangleBorder(),
                    side: const BorderSide(color: Color(0x1FFFFFFF)),
                  ),
                  child: const Text('Delete'),
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openNewHighlight() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => HighlightStoryPickerScreen(
          userId: widget.userId,
          userName: widget.userName,
          userAvatar: widget.userAvatar,
        ),
      ),
    );
    if (result == true) _loadHighlights();
  }

  @override
  Widget build(BuildContext context) {
    // Avoid shimmer flash on other users' profiles
    if (!_isOwner) {
      if (_loading) return const SizedBox.shrink();
      if (_highlights.isEmpty) return const SizedBox.shrink();
    }

    return SizedBox(
      height: 100,
      child: _loading
          ? _buildShimmer()
          : ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                // "New" button for owner
                if (_isOwner)
                  _NewHighlightButton(onTap: _openNewHighlight),

                // Highlight circles
                ...List.generate(_highlights.length, (i) {
                  return _HighlightCircle(
                    highlight: _highlights[i],
                    onTap: () => _openHighlight(i),
                    onLongPress: _isOwner
                        ? () => _openHighlightMenu(_highlights[i])
                        : null,
                  );
                }),
              ],
            ),
    );
  }

  Widget _buildShimmer() {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(width: 16),
      itemBuilder: (_, __) => Column(
        children: [
          Container(
            width: _kCircleSize,
            height: _kCircleSize,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF2A2D33),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 48,
            height: 10,
            decoration: BoxDecoration(
              color: const Color(0xFF2A2D33),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single highlight circle
// ─────────────────────────────────────────────────────────────────────────────

class _HighlightCircle extends StatelessWidget {
  final Highlight highlight;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _HighlightCircle({
    required this.highlight,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final fg = Theme.of(context).colorScheme.onSurface;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: SizedBox(
          width: 72,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ring + avatar
              Container(
                width: _kCircleSize,
                height: _kCircleSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _kRingColor,
                    width: _kRingWidth,
                  ),
                ),
                padding: const EdgeInsets.all(4),
                child: ClipOval(
                  child: _buildCover(),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                highlight.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: _kLabelStyle.copyWith(color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCover() {
    final url = highlight.coverUrl;
    if (url != null && url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        width: _kImageSize,
        height: _kImageSize,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFF2A2D33),
      child: const Center(
        child: Icon(Icons.image, color: Colors.white38, size: 28),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// "New" button (owner only)
// ─────────────────────────────────────────────────────────────────────────────

class _NewHighlightButton extends StatelessWidget {
  final VoidCallback onTap;

  const _NewHighlightButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = Theme.of(context).colorScheme.onSurface;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: SizedBox(
          width: 72,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: _kCircleSize,
                height: _kCircleSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: fg,
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Icon(Icons.add, color: fg, size: 28),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'New',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: _kLabelStyle.copyWith(color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
