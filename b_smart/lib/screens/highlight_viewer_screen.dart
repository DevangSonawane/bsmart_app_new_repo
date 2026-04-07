import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../api/api_client.dart';
import '../models/story_model.dart';
import '../models/highlight_model.dart';
import '../services/highlight_service.dart';
import '../api/highlights_api.dart';
import '../utils/url_helper.dart';
import '../widgets/safe_network_image.dart';
import '../utils/system_ui.dart';
import 'highlight_edit_screen.dart';

const _kSheet = Color(0xFF1C1C1E);
const _kBg = Color(0xFF000000);

/// Full-screen Instagram-style highlight viewer.
/// Tap right  → next item
/// Tap left   → previous item
/// Long press → pause
/// Swipe down → dismiss
class HighlightViewerScreen extends StatefulWidget {
  /// All highlights of this user (for swipe-between-highlights).
  final List<Highlight> highlights;

  /// Which highlight to start on.
  final int initialIndex;

  final String ownerUserName;
  final String? ownerAvatar;

  /// Whether the current user owns these highlights (shows edit option).
  final bool isOwner;

  const HighlightViewerScreen({
    super.key,
    required this.highlights,
    required this.initialIndex,
    required this.ownerUserName,
    this.ownerAvatar,
    this.isOwner = false,
  });

  @override
  State<HighlightViewerScreen> createState() => _HighlightViewerScreenState();
}

class _HighlightViewerScreenState extends State<HighlightViewerScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  int _currentHighlightIndex = 0;

  // Per-highlight state
  final Map<int, _HighlightPageState> _pageStates = {};

  @override
  void initState() {
    super.initState();
    _currentHighlightIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    unawaited(applyAndroidImmersiveSticky());
  }

  @override
  void dispose() {
    _pageController.dispose();
    unawaited(applyAndroidImmersiveSticky());
    super.dispose();
  }

  void _goToNext() {
    if (_currentHighlightIndex < widget.highlights.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  void _goToPrev() {
    if (_currentHighlightIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.horizontal,
        itemCount: widget.highlights.length,
        onPageChanged: (i) => setState(() => _currentHighlightIndex = i),
        itemBuilder: (ctx, i) {
          return _HighlightPage(
            key: ValueKey(widget.highlights[i].id),
            highlight: widget.highlights[i],
            ownerUserName: widget.ownerUserName,
            ownerAvatar: widget.ownerAvatar,
            isOwner: widget.isOwner,
            isActive: i == _currentHighlightIndex,
            onNext: _goToNext,
            onPrev: _goToPrev,
            onDeleted: () {
              Navigator.of(context).pop(true);
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Per-highlight page (loads items, runs progress bar, plays media)
// ─────────────────────────────────────────────────────────────────────────────

class _HighlightPage extends StatefulWidget {
  final Highlight highlight;
  final String ownerUserName;
  final String? ownerAvatar;
  final bool isOwner;
  final bool isActive;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final VoidCallback onDeleted;

  const _HighlightPage({
    super.key,
    required this.highlight,
    required this.ownerUserName,
    required this.ownerAvatar,
    required this.isOwner,
    required this.isActive,
    required this.onNext,
    required this.onPrev,
    required this.onDeleted,
  });

  @override
  State<_HighlightPage> createState() => _HighlightPageState();
}

class _HighlightPageState extends State<_HighlightPage>
    with SingleTickerProviderStateMixin {
  final HighlightService _service = HighlightService();
  final HighlightsApi _api = HighlightsApi();

  List<Story> _items = const [];
  bool _loading = true;
  bool _error = false;
  int _currentIndex = 0;
  Map<String, String>? _mediaHeaders;

  // Progress animation
  late AnimationController _progressController;
  bool _paused = false;
  bool _holding = false;
  double _dragDistance = 0;

  VideoPlayerController? _videoController;
  bool _videoReady = false;

  static const Duration _imageDuration = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(vsync: this);
    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _advance();
      }
    });
    _loadMediaHeaders();
    _loadItems();
  }

  @override
  void didUpdateWidget(_HighlightPage old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) {
      _resumeProgress();
    } else if (!widget.isActive && old.isActive) {
      _pauseProgress();
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final items = await _service.fetchHighlightItems(
        widget.highlight.id,
        ownerUserName: widget.ownerUserName,
        ownerAvatar: widget.ownerAvatar,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
      if (items.isNotEmpty && widget.isActive) {
        _showItem(0);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  Future<void> _loadMediaHeaders() async {
    if (_mediaHeaders != null) return;
    final token = await ApiClient().getToken();
    if (!mounted) return;
    if (token != null && token.isNotEmpty) {
      setState(() => _mediaHeaders = {'Authorization': 'Bearer $token'});
    } else {
      _mediaHeaders = const <String, String>{};
    }
  }

  Future<Map<String, String>> _headersFor(String url) async {
    if (!UrlHelper.shouldAttachAuthHeader(url)) return const <String, String>{};
    if (_mediaHeaders != null) return _mediaHeaders!;
    await _loadMediaHeaders();
    return _mediaHeaders ?? const <String, String>{};
  }

  void _showItem(int index) {
    if (index < 0 || index >= _items.length) return;
    _videoController?.dispose();
    _videoController = null;
    _videoReady = false;
    setState(() => _currentIndex = index);

    final item = _items[index];
    if (item.mediaType == StoryMediaType.video) {
      _initVideo(item.mediaUrl);
    } else {
      if (UrlHelper.shouldAttachAuthHeader(item.mediaUrl) &&
          _mediaHeaders == null) {
        // Wait for token before starting timer; otherwise image fetch may cache a 401/HTML response.
        unawaited(
            _loadMediaHeaders().then((_) => _startProgress(_imageDuration)));
        return;
      }
      _startProgress(_imageDuration);
    }
  }

  Future<void> _initVideo(String url) async {
    _progressController.stop();
    final headers = await _headersFor(url);
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
      httpHeaders: headers,
    );
    _videoController = controller;
    try {
      await controller.initialize();
      if (!mounted) return;
      setState(() => _videoReady = true);
      final duration = controller.value.duration;
      controller.play();
      _startProgress(
        duration.inMilliseconds == 0 ? _imageDuration : duration,
      );
    } catch (_) {
      if (!mounted) return;
      _startProgress(_imageDuration);
    }
  }

  void _startProgress(Duration duration) {
    _progressController.duration = duration;
    _progressController.forward(from: 0);
  }

  void _pauseProgress() {
    _progressController.stop();
    _videoController?.pause();
    _paused = true;
    _holding = true;
  }

  void _resumeProgress() {
    if (!_paused) return;
    _paused = false;
    _holding = false;
    if (_videoController != null && _videoReady) {
      _videoController!.play();
    }
    _progressController.forward();
  }

  void _advance() {
    if (_currentIndex < _items.length - 1) {
      _showItem(_currentIndex + 1);
    } else {
      widget.onNext();
    }
  }

  void _retreat() {
    if (_currentIndex > 0) {
      _showItem(_currentIndex - 1);
    } else {
      widget.onPrev();
    }
  }

  void _handleTapDown(TapDownDetails details) {
    final width = MediaQuery.of(context).size.width;
    if (details.globalPosition.dx < width * 0.35) {
      _retreat();
    } else {
      _advance();
    }
  }

  Future<void> _showOptions() async {
    _pauseProgress();
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _HighlightOptionsSheet(
        highlight: widget.highlight,
        currentItem: _items.isNotEmpty ? _items[_currentIndex] : null,
        isOwner: widget.isOwner,
      ),
    );
    if (!mounted) return;

    if (result == 'remove') {
      await _removeCurrentItem();
    } else if (result == 'edit') {
      final updated = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => HighlightEditScreen(
            highlight: widget.highlight,
            items: _items,
          ),
        ),
      );
      if (updated == true) widget.onDeleted();
    } else if (result == 'delete') {
      await _confirmDelete();
    }
    _resumeProgress();
  }

  Future<void> _removeCurrentItem() async {
    if (_items.isEmpty) return;
    final item = _items[_currentIndex];
    try {
      await _api.deleteItem(widget.highlight.id, item.id);
      if (!mounted) return;
      setState(() {
        _items.removeAt(_currentIndex);
        if (_currentIndex >= _items.length) {
          _currentIndex = (_items.length - 1).clamp(0, _items.length);
        }
      });
      if (_items.isEmpty) {
        Navigator.of(context).pop();
        return;
      }
      _showItem(_currentIndex);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Removed from highlight')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to remove item')),
      );
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: _kSheet,
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
                'This will permanently delete "${widget.highlight.title}".',
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
    if (confirmed != true || !mounted) return;
    try {
      await _api.delete(widget.highlight.id);
      if (mounted) widget.onDeleted();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete highlight')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    if (_error || _items.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.white54, size: 48),
              const SizedBox(height: 12),
              Text(
                _error ? 'Failed to load' : 'No items in this highlight',
                style: const TextStyle(color: Colors.white54),
              ),
            ],
          ),
        ),
      );
    }

    final item = _items[_currentIndex];

    return Scaffold(
      backgroundColor: _kBg,
      body: GestureDetector(
        onTapDown: _handleTapDown,
        onLongPressStart: (_) => setState(_pauseProgress),
        onLongPressEnd: (_) => setState(_resumeProgress),
        onVerticalDragStart: (_) => _dragDistance = 0,
        onVerticalDragUpdate: (details) {
          _dragDistance += details.delta.dy;
        },
        onVerticalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity > 300 || _dragDistance > 100) {
            Navigator.of(context).pop();
          }
          _dragDistance = 0;
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildMedia(item),
            if (_holding) Container(color: Colors.black.withValues(alpha: 0.2)),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 12,
              right: 12,
              child: _buildProgressBars(),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 20,
              left: 12,
              right: 12,
              child: _buildHeader(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedia(Story item) {
    if (item.mediaType == StoryMediaType.video) {
      if (_videoReady && _videoController != null) {
        return FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _videoController!.value.size.width,
            height: _videoController!.value.size.height,
            child: VideoPlayer(_videoController!),
          ),
        );
      }
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    final shouldAuth = UrlHelper.shouldAttachAuthHeader(item.mediaUrl);
    if (shouldAuth && _mediaHeaders == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return SafeNetworkImage(
      url: item.mediaUrl,
      headers: shouldAuth ? (_mediaHeaders ?? const <String, String>{}) : null,
      fit: BoxFit.cover,
      placeholder: Container(color: Colors.black),
      errorWidget: Container(
        color: const Color(0xFF1A1A1A),
        child: const Icon(Icons.broken_image, color: Colors.white30, size: 64),
      ),
    );
  }

  Widget _buildProgressBars() {
    return Row(
      children: List.generate(_items.length, (i) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: AnimatedBuilder(
              animation: _progressController,
              builder: (_, __) {
                double value;
                if (i < _currentIndex) {
                  value = 1.0;
                } else if (i == _currentIndex) {
                  value = _progressController.value;
                } else {
                  value = 0.0;
                }
                return LinearProgressIndicator(
                  value: value,
                  minHeight: 4,
                  backgroundColor: Colors.white30,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                );
              },
            ),
          ),
        );
      }),
    );
  }

  Widget _buildHeader() {
    final avatarUrl = (widget.ownerAvatar ?? '').trim();
    final shouldAuth =
        avatarUrl.isNotEmpty && UrlHelper.shouldAttachAuthHeader(avatarUrl);
    final headers =
        shouldAuth ? (_mediaHeaders ?? const <String, String>{}) : null;
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: Colors.white24,
          child: avatarUrl.isEmpty
              ? Text(
                  widget.ownerUserName.isNotEmpty
                      ? widget.ownerUserName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(color: Colors.white),
                )
              : ClipOval(
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: SafeNetworkImage(
                      url: avatarUrl,
                      headers: headers,
                      fit: BoxFit.cover,
                      placeholder: const SizedBox.shrink(),
                      errorWidget: const SizedBox.shrink(),
                    ),
                  ),
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.ownerUserName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              Text(
                widget.highlight.title,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
        // Options (owner only)
        if (widget.isOwner)
          GestureDetector(
            onTap: _showOptions,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.more_horiz, color: Colors.white, size: 22),
            ),
          ),
        // Close
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(Icons.close, color: Colors.white, size: 22),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Options bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _HighlightOptionsSheet extends StatelessWidget {
  final Highlight highlight;
  final Story? currentItem;
  final bool isOwner;

  const _HighlightOptionsSheet({
    required this.highlight,
    required this.currentItem,
    required this.isOwner,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _kSheet,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            if (isOwner) ...[
              SizedBox(
                height: 52,
                child: ListTile(
                  leading:
                      const Icon(Icons.bookmark_remove, color: Colors.white),
                  title: const Text('Remove from Highlight',
                      style: TextStyle(color: Colors.white, fontSize: 15)),
                  onTap: () => Navigator.of(context).pop('remove'),
                ),
              ),
              SizedBox(
                height: 52,
                child: ListTile(
                  leading: const Icon(Icons.edit_outlined, color: Colors.white),
                  title: const Text('Edit Highlight',
                      style: TextStyle(color: Colors.white, fontSize: 15)),
                  onTap: () => Navigator.of(context).pop('edit'),
                ),
              ),
              SizedBox(
                height: 52,
                child: ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Delete Highlight',
                      style: TextStyle(color: Colors.red, fontSize: 15)),
                  onTap: () => Navigator.of(context).pop('delete'),
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
