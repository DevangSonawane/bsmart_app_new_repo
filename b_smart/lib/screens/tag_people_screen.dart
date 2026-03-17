import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/users_api.dart';

class TagPeopleScreen extends StatefulWidget {
  final String mediaPath;
  final bool isVideo;
  final String filterName;
  final Map<String, int> adjustments;
  final bool alreadyProcessed;
  final List<Map<String, dynamic>> initialTags;

  const TagPeopleScreen({
    super.key,
    required this.mediaPath,
    required this.isVideo,
    required this.filterName,
    required this.adjustments,
    required this.alreadyProcessed,
    required this.initialTags,
  });

  @override
  State<TagPeopleScreen> createState() => _TagPeopleScreenState();
}

class _TagPeopleScreenState extends State<TagPeopleScreen> {
  final TextEditingController _searchCtl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  List<Map<String, dynamic>> _tags = [];
  String? _selectedTagId;
  String? _draggingTagId;
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
    _tags = widget.initialTags.map((t) => Map<String, dynamic>.from(t)).toList();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtl.dispose();
    _searchFocus.dispose();
    super.dispose();
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
      _tags.add({
        'id': id,
        'x': _pendingX,
        'y': _pendingY,
        'user': user,
      });
      _selectedTagId = id;
      _showSearch = false;
    });
    _searchCtl.text = '';
    _searchFocus.unfocus();
  }

  void _removeTag(String id) {
    setState(() {
      _tags.removeWhere((t) => t['id'] == id);
      if (_selectedTagId == id) _selectedTagId = null;
      if (_draggingTagId == id) _draggingTagId = null;
    });
  }

  void _moveTagByDelta(String id, Offset delta, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final idx = _tags.indexWhere((t) => (t['id'] ?? '').toString() == id);
    if (idx < 0) return;
    final current = _tags[idx];
    final cx = (current['x'] as num?)?.toDouble() ?? 0.5;
    final cy = (current['y'] as num?)?.toDouble() ?? 0.5;
    final nextX = ((cx * size.width) + delta.dx) / size.width;
    final nextY = ((cy * size.height) + delta.dy) / size.height;
    setState(() {
      _tags[idx] = {
        ...current,
        'x': nextX.clamp(0.0, 1.0),
        'y': nextY.clamp(0.0, 1.0),
      };
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

  Widget _buildMediaPreview() {
    if (widget.isVideo) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Icon(LucideIcons.video, color: Colors.white70, size: 56),
        ),
      );
    }
    final file = File(widget.mediaPath);
    Widget image = Image.file(file, fit: BoxFit.cover);
    if (!widget.alreadyProcessed) {
      final adj = widget.adjustments;
      final lux = ((adj['lux'] ?? 0).clamp(0, 100) / 100.0);
      final luxBC = 1.0 + (lux * 0.35);
      final luxS = 1.0 + (lux * 0.2);
      final b = ((adj['brightness'] ?? 0) / 100.0 + 1.0) * luxBC;
      final c = ((adj['contrast'] ?? 0) / 100.0 + 1.0) * luxBC;
      final s = ((adj['saturate'] ?? 0) / 100.0 + 1.0) * luxS;
      final opacity = 1.0 - (adj['opacity'] ?? 0) / 100.0;
      final presetMatrix = _filterMatrixFor(widget.filterName);
      final adjustmentMatrix = _buildAdjustmentMatrix(brightness: b, contrast: c, saturation: s);
      image = Opacity(
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
    return image;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07121E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF07121E),
        elevation: 0,
        centerTitle: true,
        title: const Text('Tag people', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white70),
          onPressed: () => Navigator.of(context).pop(widget.initialTags),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_tags),
            child: const Text('Done', style: TextStyle(color: Color(0xFF0095F6), fontWeight: FontWeight.w700)),
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
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final size = constraints.biggest;
                                return GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTapUp: (d) {
                                    setState(() => _selectedTagId = null);
                                    _openSearchAt(d.localPosition, size);
                                  },
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      _buildMediaPreview(),
                                      for (final t in _tags)
                                        Positioned(
                                          left: (t['x'] as num).toDouble() * size.width,
                                          top: (t['y'] as num).toDouble() * size.height,
                                          child: GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                final id = (t['id'] ?? '').toString();
                                                _selectedTagId = (_selectedTagId == id) ? null : id;
                                              });
                                            },
                                            onPanStart: (_) {
                                              setState(() {
                                                final id = (t['id'] ?? '').toString();
                                                _draggingTagId = id;
                                                _selectedTagId = id;
                                              });
                                            },
                                            onPanUpdate: (d) {
                                              final id = (t['id'] ?? '').toString();
                                              if (_draggingTagId != id) return;
                                              _moveTagByDelta(id, d.delta, size);
                                            },
                                            onPanEnd: (_) => setState(() => _draggingTagId = null),
                                            onPanCancel: () => setState(() => _draggingTagId = null),
                                            child: Transform.translate(
                                              offset: const Offset(-8, -28),
                                              child: Stack(
                                                clipBehavior: Clip.none,
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black.withValues(alpha: 0.65),
                                                      borderRadius: BorderRadius.circular(14),
                                                    ),
                                                    child: Text(
                                                      ((t['user'] as Map<String, dynamic>)['username'] as String?) ?? '',
                                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                                                    ),
                                                  ),
                                                  if (_selectedTagId == (t['id'] ?? '').toString())
                                                    Positioned(
                                                      top: -8,
                                                      right: -8,
                                                      child: GestureDetector(
                                                        onTap: () => _removeTag((t['id'] ?? '').toString()),
                                                        child: Container(
                                                          width: 18,
                                                          height: 18,
                                                          decoration: BoxDecoration(
                                                            color: Colors.black.withValues(alpha: 0.75),
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
                                        ),
                                    ],
                                  ),
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
                const Text('Tap the photo to tag people.', style: TextStyle(color: Colors.white60, fontSize: 13)),
                const SizedBox(height: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _tags.isEmpty
                        ? const SizedBox()
                        : ListView.separated(
                            padding: const EdgeInsets.only(top: 6, bottom: 10),
                            itemCount: _tags.length,
                            separatorBuilder: (_, __) => Container(
                              height: 1,
                              color: Colors.white.withValues(alpha: 0.06),
                            ),
                            itemBuilder: (context, i) {
                              final t = _tags[i];
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
                                title: Text(username, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                                subtitle: Text(fullName, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                                trailing: IconButton(
                                  onPressed: () => _removeTag(id),
                                  icon: const Icon(Icons.close, color: Colors.white70, size: 18),
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
                    child: Container(color: Colors.black.withValues(alpha: 0.25)),
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
                  decoration: const BoxDecoration(
                    color: Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.only(
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
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _searchCtl,
                        focusNode: _searchFocus,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Search user',
                          hintStyle: const TextStyle(color: Colors.white54),
                          prefixIcon: const Icon(LucideIcons.search, size: 18, color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.06),
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
                                      style: const TextStyle(color: Colors.white60, fontSize: 12),
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
                                        title: Text(username, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                                        subtitle: Text(fullName, style: const TextStyle(color: Colors.white60, fontSize: 12)),
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
