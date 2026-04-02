import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../api/users_api.dart';

class TagPeopleScreen extends StatefulWidget {
  final List<String> mediaPaths;
  final List<bool> isVideos;
  final List<String?>? coverPaths;
  final List<String> filterNames;
  final List<Map<String, int>> adjustments;
  final List<bool> alreadyProcessed;
  final Map<int, List<Map<String, dynamic>>> initialTagsByIndex;
  final int initialIndex;

  const TagPeopleScreen({
    super.key,
    required this.mediaPaths,
    required this.isVideos,
    this.coverPaths,
    required this.filterNames,
    required this.adjustments,
    required this.alreadyProcessed,
    required this.initialTagsByIndex,
    required this.initialIndex,
  });

  @override
  State<TagPeopleScreen> createState() => _TagPeopleScreenState();
}

class _TagPeopleScreenState extends State<TagPeopleScreen> {
  final TextEditingController _searchCtl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final Set<int> _loggedPreviewIndexes = {};

  final Map<int, List<Map<String, dynamic>>> _tagsByIndex = {};
  int _currentIndex = 0;
  PageController? _pageController;
  late final List<Map<String, dynamic>> _initialFlattened;
  String? _selectedTagId;
  String? _draggingTagId;
  bool _tapStartedOnTag = false;
  bool _showSearch = false;
  bool _isSearching = false;
  List<Map<String, dynamic>> _results = [];
  Timer? _debounce;
  String _lastQuery = '';

  double _pendingX = 0.5;
  double _pendingY = 0.5;

  @override
  void initState() {
    super.initState();
    _initialFlattened = widget.initialTagsByIndex.entries
        .expand((entry) => entry.value.map((t) => {
              ...t,
              'mediaIndex': entry.key,
            }))
        .toList();
    for (final entry in widget.initialTagsByIndex.entries) {
      _tagsByIndex[entry.key] =
          entry.value.map((t) => Map<String, dynamic>.from(t)).toList();
    }
    if (widget.mediaPaths.isEmpty) {
      _currentIndex = 0;
      _pageController = PageController();
    } else {
      _currentIndex = widget.initialIndex.clamp(0, widget.mediaPaths.length - 1);
      _pageController = PageController(initialPage: _currentIndex);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtl.dispose();
    _searchFocus.dispose();
    _pageController?.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _tagsForIndex(int index) {
    return _tagsByIndex[index] ?? <Map<String, dynamic>>[];
  }

  void _setTagsForIndex(int index, List<Map<String, dynamic>> tags) {
    if (tags.isEmpty) {
      _tagsByIndex.remove(index);
    } else {
      _tagsByIndex[index] = tags;
    }
  }

  List<Map<String, dynamic>> _flattenTags() {
    final out = <Map<String, dynamic>>[];
    for (final entry in _tagsByIndex.entries) {
      for (final t in entry.value) {
        out.add({
          ...t,
          'mediaIndex': entry.key,
        });
      }
    }
    return out;
  }

  void _openSearchAt(Offset localPosition, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final nx = (localPosition.dx / size.width).clamp(0.0, 1.0);
    final ny = (localPosition.dy / size.height).clamp(0.0, 1.0);
    setState(() {
      _pendingX = nx;
      _pendingY = ny;
      _showSearch = true;
      _results = [];
      _isSearching = false;
      _lastQuery = '';
    });
    _searchCtl.text = '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _searchFocus.requestFocus();
    });
  }

  Future<void> _search(String query) async {
    _debounce?.cancel();
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
        _lastQuery = '';
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      if (!mounted) return;
      setState(() {
        _isSearching = true;
        _lastQuery = query;
      });
      try {
        final list = await UsersApi().search(query);
        if (!mounted) return;
        setState(() {
          _results = list;
          _isSearching = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _results = [];
          _isSearching = false;
        });
      }
    });
  }

  void _addTag(Map<String, dynamic> user) {
    final id = '${DateTime.now().millisecondsSinceEpoch}_${user['id'] ?? user['_id'] ?? ''}';
    setState(() {
      final list = List<Map<String, dynamic>>.from(_tagsForIndex(_currentIndex));
      list.add({
        'id': id,
        'x': _pendingX,
        'y': _pendingY,
        'user': user,
      });
      _setTagsForIndex(_currentIndex, list);
      _selectedTagId = id;
      _showSearch = false;
    });
    _searchCtl.text = '';
    _searchFocus.unfocus();
  }

  void _removeTag(String id) {
    setState(() {
      final list = List<Map<String, dynamic>>.from(_tagsForIndex(_currentIndex));
      list.removeWhere((t) => t['id'] == id);
      _setTagsForIndex(_currentIndex, list);
      if (_selectedTagId == id) _selectedTagId = null;
      if (_draggingTagId == id) _draggingTagId = null;
    });
  }

  void _moveTagByDelta(String id, Offset delta, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final list = List<Map<String, dynamic>>.from(_tagsForIndex(_currentIndex));
    final idx = list.indexWhere((t) => (t['id'] ?? '').toString() == id);
    if (idx < 0) return;
    final current = list[idx];
    final cx = (current['x'] as num?)?.toDouble() ?? 0.5;
    final cy = (current['y'] as num?)?.toDouble() ?? 0.5;
    final nextX = ((cx * size.width) + delta.dx) / size.width;
    final nextY = ((cy * size.height) + delta.dy) / size.height;
    setState(() {
      list[idx] = {
        ...current,
        'x': nextX.clamp(0.0, 1.0),
        'y': nextY.clamp(0.0, 1.0),
      };
      _setTagsForIndex(_currentIndex, list);
    });
  }

  List<double> _buildAdjustmentMatrix({
    required double brightness,
    required double contrast,
    required double saturation,
  }) {
    final b = brightness;
    final c = contrast;
    final s = saturation;
    final invSat = 1 - s;
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    final scale = c * b;
    return [
      (invSat * lr + s) * scale, invSat * lg * scale, invSat * lb * scale, 0, 0,
      invSat * lr * scale, (invSat * lg + s) * scale, invSat * lb * scale, 0, 0,
      invSat * lr * scale, invSat * lg * scale, (invSat * lb + s) * scale, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }

  List<double> _buildFilterMatrixBase({double brightness = 1, double contrast = 1, double saturation = 1}) {
    return _buildAdjustmentMatrix(brightness: brightness, contrast: contrast, saturation: saturation);
  }

  List<double> _buildSepiaMatrix({double amount = 0.2, double brightness = 1.0, double contrast = 1.0, double saturation = 1.0}) {
    final t = 1 - amount;
    final r = 0.393 + 0.607 * t;
    final g = 0.769 - 0.769 * amount;
    final b = 0.189 - 0.189 * amount;
    final r2 = 0.349 - 0.349 * amount;
    final g2 = 0.686 + 0.314 * t;
    final b2 = 0.168 - 0.168 * amount;
    final r3 = 0.272 - 0.272 * amount;
    final g3 = 0.534 - 0.534 * amount;
    final b3 = 0.131 + 0.869 * t;
    final adj = _buildAdjustmentMatrix(brightness: brightness, contrast: contrast, saturation: saturation);
    final List<double> sepia = [
      r, g, b, 0.0, 0.0,
      r2, g2, b2, 0.0, 0.0,
      r3, g3, b3, 0.0, 0.0,
      0.0, 0.0, 0.0, 1.0, 0.0,
    ];
    return _combineColorMatrices(adj, sepia);
  }

  List<double> _filterMatrixFor(String name) {
    final lower = name.toLowerCase();
    final key = lower.replaceAll('&', 'and').replaceAll(' ', '_');
    switch (name) {
      case 'Clarendon':
        return _buildFilterMatrixBase(brightness: 1.0, contrast: 1.2, saturation: 1.25);
      case 'Gingham':
        return _buildFilterMatrixBase(brightness: 1.05, contrast: 1.0, saturation: 1.0);
      case 'Moon':
        return _buildFilterMatrixBase(brightness: 1.1, contrast: 1.1, saturation: 0.0);
      case 'Lark':
        return _buildFilterMatrixBase(brightness: 1.0, contrast: 0.9, saturation: 1.0);
      case 'Reyes':
        return _buildSepiaMatrix(amount: 0.22, brightness: 1.1, contrast: 0.85, saturation: 0.75);
      case 'Juno':
        return _buildSepiaMatrix(amount: 0.2, brightness: 1.1, contrast: 1.2, saturation: 1.4);
      case 'Slumber':
        return _buildSepiaMatrix(amount: 0.2, brightness: 1.05, contrast: 1.0, saturation: 0.66);
      case 'Crema':
        return _buildSepiaMatrix(amount: 0.2, brightness: 1.0, contrast: 0.9, saturation: 0.9);
      case 'Ludwig':
        return _buildFilterMatrixBase(brightness: 1.1, contrast: 0.9, saturation: 0.9);
      case 'Aden':
        return _buildFilterMatrixBase(brightness: 1.2, contrast: 0.9, saturation: 0.85);
      case 'Perpetua':
        return _buildFilterMatrixBase(brightness: 1.1, contrast: 1.1, saturation: 1.1);
      case 'Original':
      default:
        break;
    }
    switch (key) {
      case 'none':
      case 'original':
        return _buildFilterMatrixBase(brightness: 1.0, contrast: 1.0, saturation: 1.0);
      case 'vintage':
        return _buildSepiaMatrix(amount: 0.35, brightness: 1.05, contrast: 0.95, saturation: 0.9);
      case 'black_white':
      case 'black_and_white':
        return _buildFilterMatrixBase(brightness: 1.1, contrast: 1.1, saturation: 0.0);
      case 'warm':
        return _buildSepiaMatrix(amount: 0.25, brightness: 1.05, contrast: 1.0, saturation: 1.1);
      case 'cool':
        return _buildFilterMatrixBase(brightness: 1.0, contrast: 1.0, saturation: 0.85);
      case 'dramatic':
        return _buildFilterMatrixBase(brightness: 1.0, contrast: 1.3, saturation: 1.2);
      case 'beauty':
        return _buildSepiaMatrix(amount: 0.15, brightness: 1.1, contrast: 1.05, saturation: 1.05);
      case 'ar_effect_1':
        return _buildFilterMatrixBase(brightness: 1.05, contrast: 1.05, saturation: 1.2);
      case 'ar_effect_2':
        return _buildFilterMatrixBase(brightness: 0.95, contrast: 1.1, saturation: 0.9);
      default:
        return _buildFilterMatrixBase(brightness: 1.0, contrast: 1.0, saturation: 1.0);
    }
  }

  List<double> _combineColorMatrices(List<double> a, List<double> b) {
    final out = List<double>.filled(20, 0);
    for (int r = 0; r < 4; r++) {
      final r0 = r * 5;
      for (int c = 0; c < 4; c++) {
        out[r0 + c] = a[r0 + 0] * b[0 + c] + a[r0 + 1] * b[5 + c] + a[r0 + 2] * b[10 + c] + a[r0 + 3] * b[15 + c];
      }
      out[r0 + 4] = a[r0 + 0] * b[4] + a[r0 + 1] * b[9] + a[r0 + 2] * b[14] + a[r0 + 3] * b[19] + a[r0 + 4];
    }
    out[15] = 0;
    out[16] = 0;
    out[17] = 0;
    out[18] = 1;
    out[19] = 0;
    return out;
  }

  Widget _buildMediaPreview(int index) {
    final theme = Theme.of(context);
    if (index < 0 ||
        index >= widget.mediaPaths.length ||
        index >= widget.isVideos.length ||
        index >= widget.filterNames.length ||
        index >= widget.adjustments.length ||
        index >= widget.alreadyProcessed.length) {
      return const SizedBox();
    }
    if (widget.isVideos[index]) {
      final coverPath = widget.coverPaths != null &&
              index < (widget.coverPaths?.length ?? 0)
          ? widget.coverPaths![index]
          : null;
      if (!_loggedPreviewIndexes.contains(index)) {
        _loggedPreviewIndexes.add(index);
        debugPrint(
          '[TagPeopleScreen] preview index=$index video=true '
          'source=${widget.mediaPaths[index]} cover=$coverPath '
          'filter=${widget.filterNames[index]} adjustments=${widget.adjustments[index]} '
          'processed=${widget.alreadyProcessed[index]}',
        );
      }
      if (coverPath != null && File(coverPath).existsSync()) {
        debugPrint('[TagPeopleScreen] using cover for index=$index: $coverPath');
        return _applyFilteredImage(
          Image.file(File(coverPath), fit: BoxFit.cover),
          index,
        );
      }
      return FutureBuilder<Uint8List?>(
        future: VideoThumbnail.thumbnailData(
          video: widget.mediaPaths[index],
          imageFormat: ImageFormat.JPEG,
          quality: 70,
        ),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done || snap.data == null) {
            return Container(
              color: theme.colorScheme.surface,
              child: Center(
                child: Icon(
                  LucideIcons.video,
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 56,
                ),
              ),
            );
          }
          debugPrint(
            '[TagPeopleScreen] thumbnailData ready index=$index '
            'bytes=${snap.data?.length ?? 0}',
          );
          final base = Stack(
            fit: StackFit.expand,
            children: [
              Image.memory(snap.data!, fit: BoxFit.cover),
              const Center(
                child: Icon(LucideIcons.play, size: 36, color: Colors.white),
              ),
            ],
          );
          return _applyFilteredImage(base, index);
        },
      );
    }
    final file = File(widget.mediaPaths[index]);
    return _applyFilteredImage(Image.file(file, fit: BoxFit.cover), index);
  }

  Widget _applyFilteredImage(Widget image, int index) {
    if (widget.alreadyProcessed[index]) return image;
    final adj = widget.adjustments[index];
    final lux = ((adj['lux'] ?? 0).clamp(0, 100) / 100.0);
    final luxBC = 1.0 + (lux * 0.35);
    final luxS = 1.0 + (lux * 0.2);
    final b = ((adj['brightness'] ?? 0) / 100.0 + 1.0) * luxBC;
    final c = ((adj['contrast'] ?? 0) / 100.0 + 1.0) * luxBC;
    final s = ((adj['saturate'] ?? 0) / 100.0 + 1.0) * luxS;
    final opacity = 1.0 - (adj['opacity'] ?? 0) / 100.0;
    final presetMatrix = _filterMatrixFor(widget.filterNames[index]);
    final adjustmentMatrix = _buildAdjustmentMatrix(brightness: b, contrast: c, saturation: s);
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: ColorFiltered(
        colorFilter: ColorFilter.matrix(presetMatrix),
        child: ColorFiltered(
          colorFilter: ColorFilter.matrix(adjustmentMatrix),
          child: image,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = theme.colorScheme.onSurface;
    final muted = theme.colorScheme.onSurfaceVariant;
    final appBarBg =
        theme.appBarTheme.backgroundColor ?? theme.scaffoldBackgroundColor;
    final appBarFg =
        theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface;
    final currentTags = _tagsForIndex(_currentIndex);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: appBarBg,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Tag people',
          style: TextStyle(color: appBarFg, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: Icon(Icons.close, color: appBarFg.withValues(alpha: 0.7)),
          onPressed: () => Navigator.of(context).pop(_initialFlattened),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_flattenTags()),
            child: Text(
              'Done',
              style: TextStyle(
                color: const Color(0xFF4F6EF7),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Builder(
                  builder: (context) {
                    final screenW = MediaQuery.of(context).size.width;
                    final side = math.min(screenW * 0.78, 340.0);
                    return Padding(
                      padding: const EdgeInsets.only(top: 14, bottom: 14),
                      child: Center(
                        child: SizedBox(
                          width: side,
                          height: side,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: PageView.builder(
                            controller: _pageController,
                            itemCount: widget.mediaPaths.length,
                            onPageChanged: (i) {
                              setState(() {
                                _currentIndex = i;
                                _selectedTagId = null;
                                _draggingTagId = null;
                                _showSearch = false;
                              });
                            },
                            itemBuilder: (context, index) {
                              return LayoutBuilder(
                                builder: (context, constraints) {
                                  final size = constraints.biggest;
                                  final tags = _tagsForIndex(index);
                                  return GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTapUp: (d) {
                                      if (_currentIndex != index) return;
                                      if (_tapStartedOnTag || _draggingTagId != null) {
                                        _tapStartedOnTag = false;
                                        return;
                                      }
                                      setState(() => _selectedTagId = null);
                                      _openSearchAt(d.localPosition, size);
                                    },
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        _buildMediaPreview(index),
                                        for (final t in tags)
                                          Positioned(
                                            left: (((t['x'] as num?)?.toDouble() ?? 0.5) * size.width) - 8,
                                            top: (((t['y'] as num?)?.toDouble() ?? 0.5) * size.height) - 34,
                                            child: GestureDetector(
                                              behavior: HitTestBehavior.opaque,
                                              onTapDown: (_) => _tapStartedOnTag = true,
                                              onTap: () {
                                                if (_currentIndex != index) return;
                                                setState(() {
                                                  final id = (t['id'] ?? '').toString();
                                                  _selectedTagId = (_selectedTagId == id) ? null : id;
                                                });
                                                _tapStartedOnTag = false;
                                              },
                                              onPanStart: (_) {
                                                if (_currentIndex != index) return;
                                                _tapStartedOnTag = true;
                                                setState(() {
                                                  final id = (t['id'] ?? '').toString();
                                                  _draggingTagId = id;
                                                  _selectedTagId = id;
                                                });
                                              },
                                              onPanUpdate: (d) {
                                                if (_currentIndex != index) return;
                                                final id = (t['id'] ?? '').toString();
                                                if (_draggingTagId != id) return;
                                                _moveTagByDelta(id, d.delta, size);
                                              },
                                              onPanEnd: (_) {
                                                if (_currentIndex != index) return;
                                                _tapStartedOnTag = false;
                                                setState(() => _draggingTagId = null);
                                              },
                                              onPanCancel: () {
                                                if (_currentIndex != index) return;
                                                _tapStartedOnTag = false;
                                                setState(() => _draggingTagId = null);
                                              },
                                              child: Stack(
                                                clipBehavior: Clip.none,
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black.withValues(
                                                        alpha: isDark ? 0.65 : 0.5,
                                                      ),
                                                      borderRadius: BorderRadius.circular(14),
                                                    ),
                                                    child: Text(
                                                      ((t['user'] as Map<String, dynamic>)['username'] as String?) ?? '',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                  if (_selectedTagId == (t['id'] ?? '').toString())
                                                    Positioned(
                                                      top: -6,
                                                      right: -6,
                                                      child: GestureDetector(
                                                        behavior: HitTestBehavior.opaque,
                                                        onTapDown: (_) => _tapStartedOnTag = true,
                                                        onTap: () {
                                                          if (_currentIndex != index) return;
                                                          _tapStartedOnTag = false;
                                                          _removeTag((t['id'] ?? '').toString());
                                                        },
                                                        child: Container(
                                                          width: 18,
                                                          height: 18,
                                                          decoration: BoxDecoration(
                                                            color: Colors.black.withValues(
                                                              alpha: isDark ? 0.75 : 0.6,
                                                            ),
                                                            shape: BoxShape.circle,
                                                            border: Border.all(color: Colors.white24, width: 1),
                                                          ),
                                                          child: const Center(
                                                            child: Icon(Icons.close, size: 12, color: Colors.white),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 6),
                Text(
                  'Tap the photo to tag people.',
                  style: TextStyle(color: muted, fontSize: 13),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: currentTags.isEmpty
                        ? const SizedBox()
                        : ListView.separated(
                            padding: const EdgeInsets.only(top: 6, bottom: 10),
                            itemCount: currentTags.length,
                            separatorBuilder: (_, __) => Container(
                              height: 1,
                              color: theme.dividerColor.withValues(alpha: 0.3),
                            ),
                            itemBuilder: (context, i) {
                              final t = currentTags[i];
                              final user = (t['user'] as Map<String, dynamic>);
                              final username = (user['username'] as String?) ?? '';
                              final fullName = (user['full_name'] as String?) ?? '';
                              final avatar = (user['avatar_url'] as String?) ?? '';
                              final id = (t['id'] ?? '').toString();
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                                  child: avatar.isEmpty ? const Icon(LucideIcons.user, size: 16) : null,
                                ),
                                title: Text(username, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 14)),
                                subtitle: Text(fullName, style: TextStyle(color: muted, fontSize: 12)),
                                trailing: IconButton(
                                  onPressed: () => _removeTag(id),
                                  icon: Icon(Icons.close, color: muted, size: 18),
                                ),
                                onTap: () => setState(() => _selectedTagId = id),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
            if (_showSearch)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _showSearch = false);
                    _searchFocus.unfocus();
                  },
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      color: (isDark ? Colors.black : Colors.black)
                          .withValues(alpha: isDark ? 0.25 : 0.12),
                    ),
                  ),
                ),
              ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              left: 0,
              right: 0,
              bottom: _showSearch ? 0 : -420,
              child: SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.dividerColor.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _searchCtl,
                        focusNode: _searchFocus,
                        style: TextStyle(color: fg),
                        decoration: InputDecoration(
                          hintText: 'Search user',
                          hintStyle: TextStyle(color: muted),
                          prefixIcon: Icon(LucideIcons.search, size: 18, color: muted),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.6),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        onChanged: _search,
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 260,
                        child: _isSearching
                            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                            : _results.isEmpty
                                ? Center(
                                    child: Text(
                                      _lastQuery.isEmpty ? 'Type a name to search...' : 'No users found',
                                      style: TextStyle(color: muted, fontSize: 12),
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: _results.length,
                                    itemBuilder: (_, i) {
                                      final u = _results[i];
                                      final username = (u['username'] as String?) ?? '';
                                      final fullName = (u['full_name'] as String?) ?? '';
                                      final avatar = (u['avatar_url'] as String?) ?? '';
                                      return ListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        leading: CircleAvatar(
                                          radius: 16,
                                          backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                                          child: avatar.isEmpty ? const Icon(LucideIcons.user, size: 16) : null,
                                        ),
                                        title: Text(username, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 14)),
                                        subtitle: Text(fullName, style: TextStyle(color: muted, fontSize: 12)),
                                        onTap: () => _addTag(u),
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
