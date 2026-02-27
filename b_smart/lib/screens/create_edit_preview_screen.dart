import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/media_model.dart';
import '../services/create_service.dart';
import 'create_post_details_screen.dart';
import 'create_reel_details_screen.dart';
import 'edit_video_screen.dart';

class _PreviewTextOverlay {
  final String text;
  final Color color;
  final Offset position;
  final double scale;
  final double rotation;

  const _PreviewTextOverlay({
    required this.text,
    required this.color,
    required this.position,
    this.scale = 1.0,
    this.rotation = 0.0,
  });

  _PreviewTextOverlay copyWith({
    String? text,
    Color? color,
    Offset? position,
    double? scale,
    double? rotation,
  }) {
    return _PreviewTextOverlay(
      text: text ?? this.text,
      color: color ?? this.color,
      position: position ?? this.position,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
    );
  }
}

class CreateEditPreviewScreen extends StatefulWidget {
  final MediaItem media;
  final String? selectedFilter;

  const CreateEditPreviewScreen({
    super.key,
    required this.media,
    this.selectedFilter,
  });

  @override
  State<CreateEditPreviewScreen> createState() => _CreateEditPreviewScreenState();
}

class _CreateEditPreviewScreenState extends State<CreateEditPreviewScreen> {
  final CreateService _createService = CreateService();
  String? _selectedFilter;
  String? _selectedFilterName;
  String? _selectedMusic;
  double _musicVolume = 0.5;
  bool _showMusicControls = false;
  VideoPlayerController? _videoController;
  Future<void>? _videoInit;
  bool _isPlaying = false;
  Duration? _trimStart;
  Duration? _trimEnd;
  final List<_PreviewTextOverlay> _textOverlays = [];
  int? _activeTextIndex;
  Offset _textLastFocalPoint = Offset.zero;
  double _textTransformBaseScale = 1.0;
  double _textTransformBaseRotation = 0.0;

  List<double> _buildFilterMatrixBase({double brightness = 1, double contrast = 1, double saturation = 1}) {
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

  List<double> _buildGrayscaleMatrix({double contrast = 1.0, double brightness = 1.0}) {
    const r = 0.2126, g = 0.7152, b = 0.0722;
    return [
      r * contrast * brightness, g * contrast * brightness, b * contrast * brightness, 0, 0,
      r * contrast * brightness, g * contrast * brightness, b * contrast * brightness, 0, 0,
      r * contrast * brightness, g * contrast * brightness, b * contrast * brightness, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }

  List<double> _buildSepiaMatrix({double amount = 0.2, double brightness = 1.0, double contrast = 1.0, double saturation = 1.0}) {
    final t = 1 - amount;
    final r = 0.393 + 0.607 * t;
    final g = 0.769 - 0.769 * amount;
    final b = 0.189 - 0.189 * amount;
    final invSat = 1 - saturation;
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    final c = contrast * brightness;
    return [
      (r * saturation + lr * invSat) * c, (g * saturation + lg * invSat) * c, (b * saturation + lb * invSat) * c, 0, 0,
      (0.349 * t + 0.349 * amount) * saturation * c + lr * invSat * c, (0.686 + 0.314 * t) * saturation * c + lg * invSat * c, (0.168 * t) * saturation * c + lb * invSat * c, 0, 0,
      (0.272 * t) * saturation * c + lr * invSat * c, (0.534 * t - 0.534 * amount) * saturation * c + lg * invSat * c, (0.131 + 0.869 * t) * saturation * c + lb * invSat * c, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }

  List<double> _reelFilterMatrixFor(String id) {
    switch (id) {
      case 'vintage':
        return _buildSepiaMatrix(amount: 0.35, brightness: 1.05, contrast: 0.95, saturation: 0.9);
      case 'black_white':
        return _buildGrayscaleMatrix(contrast: 1.1, brightness: 1.0);
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
      case 'none':
      default:
        return _buildFilterMatrixBase(brightness: 1.0, contrast: 1.0, saturation: 1.0);
    }
  }

  Widget _applySelectedFilter(Widget child) {
    if (_selectedFilter == null || _selectedFilter == 'none') {
      return child;
    }
    final matrix = _reelFilterMatrixFor(_selectedFilter!);
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(matrix),
      child: child,
    );
  }

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.selectedFilter;
    if (_selectedFilter != null) {
      final filters = _createService.getFilters();
      final match = filters.where((f) => f.id == _selectedFilter).toList();
      if (match.isNotEmpty) {
        _selectedFilterName = match.first.name;
      }
    }
    if (widget.media.type == MediaType.video && widget.media.filePath != null) {
      final controller = VideoPlayerController.file(File(widget.media.filePath!));
      _videoController = controller;
      _videoInit = controller.initialize().then((_) {
        if (!mounted) return;
        controller.setLooping(true);
        controller.addListener(_handlePreviewVideoTick);
        controller.play();
        setState(() => _isPlaying = true);
      });
    }
  }

  @override
  void dispose() {
    _videoController?.removeListener(_handlePreviewVideoTick);
    _videoController?.dispose();
    super.dispose();
  }

  void _handlePreviewVideoTick() {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    final start = _trimStart;
    final end = _trimEnd;
    if (start == null || end == null || end <= start) return;
    final pos = controller.value.position;
    if (pos < start || pos > end) {
      controller.seekTo(start);
    }
  }

  // ── Navigate to EditVideoScreen and capture the returned trim values
  Future<void> _openVideoEditor() async {
    // Pause preview while editing
    _videoController?.pause();
    setState(() => _isPlaying = false);

    final result = await Navigator.of(context).push<VideoEditResult>(
      MaterialPageRoute(
        builder: (_) => EditVideoScreen(media: widget.media),
      ),
    );

    if (!mounted) return;

    if (result != null) {
      setState(() {
        _trimStart = result.trimStart;
        _trimEnd = result.trimEnd;
      });

      // Seek preview to the new trim start and resume
      final controller = _videoController;
      if (controller != null && controller.value.isInitialized) {
        await controller.seekTo(_trimStart!);
        controller.play();
        setState(() => _isPlaying = true);
      }
    } else {
      // User cancelled – just resume playback
      _videoController?.play();
      setState(() => _isPlaying = true);
    }
  }

  // ── Proceed to post details, passing trim values along
  void _proceedToPostDetails() {
    final isVideo = widget.media.type == MediaType.video;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => isVideo
            ? CreateReelDetailsScreen(
                media: widget.media,
                selectedFilter: _selectedFilter,
                selectedMusic: _selectedMusic,
                musicVolume: _musicVolume,
                trimStart: _trimStart,
                trimEnd: _trimEnd,
              )
            : CreatePostDetailsScreen(
                media: widget.media,
                selectedFilter: _selectedFilter,
                selectedMusic: _selectedMusic,
                musicVolume: _musicVolume,
                trimStart: _trimStart,
                trimEnd: _trimEnd,
              ),
      ),
    );
  }

  void _handleTextScaleStart(ScaleStartDetails details) {
    if (_textOverlays.isEmpty) return;
    final activeIndex = _activeTextIndex ?? (_textOverlays.length - 1);
    _activeTextIndex = activeIndex;
    _textLastFocalPoint = details.focalPoint;
    final overlay = _textOverlays[activeIndex];
    _textTransformBaseScale = overlay.scale;
    _textTransformBaseRotation = overlay.rotation;
  }

  void _handleTextScaleUpdate(ScaleUpdateDetails details) {
    if (_textOverlays.isEmpty) return;
    final activeIndex = _activeTextIndex ?? (_textOverlays.length - 1);
    final overlay = _textOverlays[activeIndex];
    final delta = details.focalPoint - _textLastFocalPoint;
    _textLastFocalPoint = details.focalPoint;

    double newScale = overlay.scale;
    double newRotation = overlay.rotation;

    if (details.pointerCount > 1) {
      newScale = (_textTransformBaseScale * details.scale).clamp(0.2, 8.0);
      newRotation = _textTransformBaseRotation + details.rotation;
    }

    setState(() {
      _textOverlays[activeIndex] = overlay.copyWith(
        position: overlay.position + delta,
        scale: newScale,
        rotation: newRotation,
      );
    });
  }

  Future<void> _openPreviewTextEditor({int? index}) async {
    final existing = index != null && index >= 0 && index < _textOverlays.length
        ? _textOverlays[index]
        : null;
    final controller = TextEditingController(text: existing?.text ?? '');
    final media = MediaQuery.of(context);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          color: Colors.black.withAlpha(230),
          padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          final text = controller.text.trim();
                          if (text.isEmpty) {
                            Navigator.pop(ctx);
                          } else {
                            Navigator.pop(ctx, text);
                          }
                        },
                        child: const Text(
                          'Done',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      maxLines: null,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Tap to type',
                        hintStyle:
                            TextStyle(color: Colors.white54, fontSize: 28),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) return;
    if (result != null && result.isNotEmpty) {
      setState(() {
        if (index != null &&
            index >= 0 &&
            index < _textOverlays.length) {
          _textOverlays[index] =
              _textOverlays[index].copyWith(text: result);
          _activeTextIndex = index;
        } else {
          _textOverlays.add(
            _PreviewTextOverlay(
              text: result,
              color: Colors.white,
              position: const Offset(120, 200),
            ),
          );
          _activeTextIndex = _textOverlays.length - 1;
        }
      });
    }
  }

  void _onTapText() {
    _openPreviewTextEditor();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    color: Colors.black,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onScaleStart: _handleTextScaleStart,
                        onScaleUpdate: _handleTextScaleUpdate,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (widget.media.type == MediaType.video)
                              _buildVideoPreview()
                            else
                              _buildImagePreview(),
                            if (_selectedFilterName != null &&
                                _selectedFilter != null &&
                                _selectedFilter != 'none')
                              Positioned(
                                top: 16,
                                right: 16,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'Filter: $_selectedFilterName',
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 12),
                                  ),
                                ),
                              ),
                            if (_trimStart != null && _trimEnd != null)
                              Positioned(
                                top: 16,
                                left: 16,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.content_cut,
                                          color: Colors.white, size: 12),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${_formatDuration(_trimStart!)} – ${_formatDuration(_trimEnd!)}',
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ..._textOverlays.asMap().entries.map((entry) {
                              final index = entry.key;
                              final overlay = entry.value;
                              final isActive = _activeTextIndex == null
                                  ? index == _textOverlays.length - 1
                                  : index == _activeTextIndex;
                              return Positioned(
                                left: overlay.position.dx,
                                top: overlay.position.dy,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _activeTextIndex = index;
                                    });
                                    _openPreviewTextEditor(index: index);
                                  },
                                  child: Transform.rotate(
                                    angle: overlay.rotation,
                                    child: Transform.scale(
                                      scale: overlay.scale,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(
                                              isActive ? 0.4 : 0.25),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          overlay.text,
                                          style: TextStyle(
                                            color: overlay.color,
                                            fontSize: 22,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  height: 72,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Colors.black,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      OutlinedButton(
                        onPressed: widget.media.type == MediaType.video
                            ? _openVideoEditor
                            : null,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white24),
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24)),
                        ),
                        child: Row(
                          children: [
                            const Text('Edit video'),
                            if (_trimStart != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF0095F6),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _proceedToPostDetails,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0095F6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24)),
                        ),
                        child: const Text('Next →'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 72 + 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_showMusicControls)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildMusicPanel(),
                    ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildEditOption(
                          icon: Icons.text_fields,
                          label: 'Text',
                          onTap: _onTapText,
                        ),
                        const SizedBox(width: 8),
                        _buildEditOption(
                          icon: Icons.filter_alt,
                          label: 'Filters',
                          onTap: _showFilterOptions,
                        ),
                        const SizedBox(width: 8),
                        if (widget.media.type == MediaType.video)
                          _buildEditOption(
                            icon: Icons.content_cut,
                            label: 'Trim',
                            onTap: _openVideoEditor,
                            isActive: _trimStart != null,
                          ),
                        const SizedBox(width: 8),
                        _buildEditOption(
                          icon: Icons.music_note,
                          label: 'Music',
                          onTap: () {
                            setState(() {
                              _showMusicControls = !_showMusicControls;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 16,
              left: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // VIDEO PREVIEW
  // ─────────────────────────────────────────────
  Widget _buildVideoPreview() {
    final controller = _videoController;
    if (controller == null) {
      return const Icon(Icons.play_circle_outline,
          size: 100, color: Colors.white54);
    }
    return FutureBuilder<void>(
      future: _videoInit,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done ||
            !controller.value.isInitialized) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.white));
        }
        return GestureDetector(
          onTap: () {
            setState(() {
              if (_isPlaying) {
                controller.pause();
              } else {
                if (_trimStart != null) {
                  controller.seekTo(_trimStart!);
                }
                controller.play();
              }
              _isPlaying = !_isPlaying;
            });
          },
          child: _applySelectedFilter(
            Stack(
              alignment: Alignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller.value.size.width,
                    height: controller.value.size.height,
                    child: VideoPlayer(controller),
                  ),
                ),
                if (!_isPlaying)
                  Container(
                    color: Colors.black45,
                    child: const Icon(
                      Icons.play_arrow,
                      size: 72,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildImagePreview() {
    if (widget.media.filePath != null) {
      return _applySelectedFilter(
        Image.file(
          File(widget.media.filePath!),
          fit: BoxFit.cover,
        ),
      );
    }
    return const Icon(Icons.image, size: 100, color: Colors.white54);
  }

  // ─────────────────────────────────────────────
  // MUSIC PANEL
  // ─────────────────────────────────────────────
  Widget _buildMusicPanel() {
    return Container(
      margin: const EdgeInsets.all(0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Music',
                  style: TextStyle(color: Colors.white)),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () =>
                    setState(() => _showMusicControls = false),
              ),
            ],
          ),
          if (_selectedMusic != null)
            Text('Selected: $_selectedMusic',
                style: const TextStyle(color: Colors.white54)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.volume_down, color: Colors.white),
              Expanded(
                child: Slider(
                  value: _musicVolume,
                  onChanged: (v) => setState(() => _musicVolume = v),
                  activeColor: Colors.blue,
                ),
              ),
              const Icon(Icons.volume_up, color: Colors.white),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────
  String _formatDuration(Duration d) {
    final s = d.inSeconds;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  Widget _buildEditOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF0095F6).withOpacity(0.25)
                  : Colors.grey[800],
              shape: BoxShape.circle,
              border: isActive
                  ? Border.all(color: const Color(0xFF0095F6), width: 1.5)
                  : null,
            ),
            child: Icon(icon,
                color: isActive ? const Color(0xFF0095F6) : Colors.white,
                size: 24),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: isActive
                      ? const Color(0xFF0095F6)
                      : Colors.white,
                  fontSize: 12)),
        ],
      ),
    );
  }

  void _showFilterOptions() {
    final filters = _createService.getFilters();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select Filter',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: filters.length,
                itemBuilder: (context, index) {
                  final filter = filters[index];
                  final isSelected = _selectedFilter == filter.id;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedFilter = filter.id;
                        _selectedFilterName = filter.name;
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 80,
                      margin:
                          const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        children: [
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey[800],
                              border: Border.all(
                                color: isSelected
                                    ? Colors.blue
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                            child: Center(
                              child: Text(filter.name[0],
                                  style: const TextStyle(
                                      color: Colors.white)),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(filter.name,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 10),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAIOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('AI Enhancements',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              childAspectRatio: 2.5,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              children: [
                _buildAIOption('Background Removal', Icons.auto_fix_high),
                _buildAIOption('Face Enhancement', Icons.face),
                _buildAIOption('Auto Crop', Icons.crop),
                _buildAIOption('Stabilize', Icons.video_stable),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIOption(String label, IconData icon) {
    return ElevatedButton.icon(
      onPressed: () async {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Processing $label...')));
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$label applied successfully')));
        }
      },
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
    );
  }
}
