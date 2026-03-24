import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:math' as math;
import 'package:extended_image/extended_image.dart';
import '../models/media_model.dart' as app_models;
import '../services/create_service.dart';
import 'create_post_screen.dart';
import 'create_reel_details_screen.dart';
import 'edit_video_screen.dart';
import '../instagram_text_editor/instagram_text_editor.dart';
import '../instagram_text_editor/instagram_text_result.dart';
import '../instagram_overlay/overlay_shape.dart';
import '../instagram_overlay/overlay_sticker.dart';
import '../instagram_overlay/overlay_sticker_widget.dart';

class _PreviewTextOverlay {
  final String text;
  final TextStyle style;
  final TextAlign alignment;
  final Color textColor;
  final BackgroundStyle backgroundStyle;
  final Offset position;
  final double scale;
  final double rotation;
  final String fontName;
  final double fontSize;

  const _PreviewTextOverlay({
    required this.text,
    required this.style,
    required this.alignment,
    required this.textColor,
    required this.backgroundStyle,
    required this.position,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.fontName = 'Modern',
    this.fontSize = 32.0,
  });

  _PreviewTextOverlay copyWith({
    String? text,
    TextStyle? style,
    TextAlign? alignment,
    Color? textColor,
    BackgroundStyle? backgroundStyle,
    Offset? position,
    double? scale,
    double? rotation,
    String? fontName,
    double? fontSize,
  }) {
    return _PreviewTextOverlay(
      text: text ?? this.text,
      style: style ?? this.style,
      alignment: alignment ?? this.alignment,
      textColor: textColor ?? this.textColor,
      backgroundStyle: backgroundStyle ?? this.backgroundStyle,
      position: position ?? this.position,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      fontName: fontName ?? this.fontName,
      fontSize: fontSize ?? this.fontSize,
    );
  }
}

class _ImageToolSpec {
  final String key;
  final String label;
  final IconData icon;
  final int min;
  final int max;

  const _ImageToolSpec({
    required this.key,
    required this.label,
    required this.icon,
    this.min = -100,
    this.max = 100,
  });
}

class CreateEditPreviewScreen extends StatefulWidget {
  final app_models.MediaItem media;
  final String? selectedFilter;
  final bool isPostFlow;

  const CreateEditPreviewScreen({
    super.key,
    required this.media,
    this.selectedFilter,
    this.isPostFlow = false,
  });

  @override
  State<CreateEditPreviewScreen> createState() => _CreateEditPreviewScreenState();
}

class _CreateEditPreviewScreenState extends State<CreateEditPreviewScreen> {
  final CreateService _createService = CreateService();
  late app_models.MediaItem _currentMedia;
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
  int _zCounter = 0;
  final Map<String, int> _layerZOrder = {};
  Offset _textLastFocalPoint = Offset.zero;
  Offset _textLastLocalFocalPoint = Offset.zero;
  double _textTransformBaseScale = 1.0;
  double _textTransformBaseRotation = 0.0;
  final List<OverlaySticker> _stickerOverlays = [];
  int? _activeStickerIndex;
  Offset _stickerLastFocalPoint = Offset.zero;
  Offset _stickerLastLocalFocalPoint = Offset.zero;
  double _stickerBaseScale = 1.0;
  double _stickerBaseRotation = 0.0;
  bool _isStickerDeleteMode = false;
  Offset _stickerLastGlobalFocalPoint = Offset.zero;
  final Map<String, double> _stickerDeleteScale = {};
  final Set<String> _deletingStickerIds = {};
  Timer? _stickerHoldTimer;
  bool _suppressStickerTap = false;
  bool _isTextDeleteMode = false;
  final Map<int, double> _textDeleteScale = {};
  final Set<int> _deletingTextIndexes = {};
  Timer? _textHoldTimer;
  bool _suppressTextTap = false;
  bool _hideTextOverlaysForCapture = false;
  bool _captureWithoutRadius = false;
  ImageProvider? _cachedTextEditorBackground;
  Offset? _cachedTrashCenter;
  double? _imageAspectRatio;
  Size? _imagePixelSize;
  ImageStream? _imageStream;
  ImageStreamListener? _imageStreamListener;
  final GlobalKey<ExtendedImageGestureState> _postGestureKey = GlobalKey<ExtendedImageGestureState>();
  final GlobalKey _previewRepaintKey = GlobalKey();
  Size? _postViewportSize;
  Map<String, int> _imageAdjustments = <String, int>{
    'brightness': 0,
    'contrast': 0,
    'saturate': 0,
    'lux': 0,
    'sepia': 0,
    'opacity': 0,
    'vignette': 0,
  };

  double _clampInstagramPostAspect(double aspect) {
    if (aspect.isNaN || aspect.isInfinite || aspect <= 0) return 1.0;
    const minLandscape = 1.91;
    const maxPortrait = 4 / 5; // 0.8
    return aspect.clamp(maxPortrait, minLandscape);
  }

  double _postFrameAspect() {
    if (widget.media.type == app_models.MediaType.video) {
      final controller = _videoController;
      final a = (controller != null && controller.value.isInitialized)
          ? controller.value.aspectRatio
          : 1.0;
      return _clampInstagramPostAspect(a);
    }
    return _clampInstagramPostAspect(_imageAspectRatio ?? 1.0);
  }

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

  Widget _applyImageAdjustments(Widget child) {
    final adj = _imageAdjustments;
    final lux = ((adj['lux'] ?? 0).clamp(0, 100) / 100.0);
    final luxBC = 1.0 + (lux * 0.35);
    final luxS = 1.0 + (lux * 0.2);
    final b = ((adj['brightness'] ?? 0) / 100.0 + 1.0) * luxBC;
    final c = ((adj['contrast'] ?? 0) / 100.0 + 1.0) * luxBC;
    final s = ((adj['saturate'] ?? 0) / 100.0 + 1.0) * luxS;
    final fade = 1.0 - (adj['opacity'] ?? 0) / 100.0;
    final tempRaw = (adj['sepia'] ?? 0).abs().clamp(0, 100);
    final sepiaAmount = (tempRaw / 100.0) * 0.35;
    final vignette = ((adj['vignette'] ?? 0).clamp(0, 100) / 100.0) * 0.65;

    Widget out = child;
    if (sepiaAmount > 0) {
      out = ColorFiltered(
        colorFilter: ColorFilter.matrix(_buildSepiaMatrix(amount: sepiaAmount, brightness: 1.0, contrast: 1.0, saturation: 1.0)),
        child: out,
      );
    }
    out = ColorFiltered(
      colorFilter: ColorFilter.matrix(_buildAdjustmentMatrix(brightness: b, contrast: c, saturation: s)),
      child: out,
    );
    out = Opacity(
      opacity: fade.clamp(0.0, 1.0),
      child: out,
    );
    if (vignette > 0) {
      out = Stack(
        fit: StackFit.expand,
        children: [
          out,
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.85,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: vignette),
                  ],
                  stops: const [0.55, 1.0],
                ),
              ),
            ),
          ),
        ],
      );
    }
    return out;
  }

  @override
  void initState() {
    super.initState();
    _currentMedia = widget.media;
    _selectedFilter = widget.selectedFilter;
    _primeTextEditorBackground();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateCachedTrashCenter();
    });
    if (_selectedFilter != null) {
      final filters = _createService.getFilters();
      final match = filters.where((f) => f.id == _selectedFilter).toList();
      if (match.isNotEmpty) {
        _selectedFilterName = match.first.name;
      }
    }
    if (_currentMedia.type == app_models.MediaType.video && _currentMedia.filePath != null) {
      final controller = VideoPlayerController.file(File(_currentMedia.filePath!));
      _videoController = controller;
      _videoInit = controller.initialize().then((_) {
        if (!mounted) return;
        controller.setLooping(false);
        controller.addListener(_handlePreviewVideoTick);
        setState(() => _isPlaying = false);
      });
    } else if (_currentMedia.type == app_models.MediaType.image && _currentMedia.filePath != null) {
      final provider = FileImage(File(_currentMedia.filePath!));
      final stream = provider.resolve(const ImageConfiguration());
      _imageStream = stream;
      _imageStreamListener = ImageStreamListener((info, _) {
        final w = info.image.width.toDouble();
        final h = info.image.height.toDouble();
        if (!mounted || h == 0) return;
        setState(() {
          _imageAspectRatio = w / h;
          _imagePixelSize = Size(w, h);
        });
      });
      stream.addListener(_imageStreamListener!);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateCachedTrashCenter();
    });
  }

  @override
  void dispose() {
    _stickerHoldTimer?.cancel();
    _textHoldTimer?.cancel();
    _videoController?.removeListener(_handlePreviewVideoTick);
    _videoController?.dispose();
    final stream = _imageStream;
    final listener = _imageStreamListener;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    super.dispose();
  }

  @override
  void deactivate() {
    // Prevent background audio when another route (e.g. reel details) is pushed.
    if (_videoController?.value.isInitialized == true) {
      _videoController?.pause();
      _isPlaying = false;
    }
    super.deactivate();
  }

  void _handlePreviewVideoTick() {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    final pos = controller.value.position;
    final duration = controller.value.duration;
    final start = _trimStart;
    final end = _trimEnd;
    if (start != null && end != null && end > start) {
      if (pos < start) {
        controller.seekTo(start);
      }
      if (pos >= end) {
        controller.pause();
        if (mounted) {
          setState(() => _isPlaying = false);
        }
      }
      return;
    }
    if (duration != null && duration != Duration.zero && pos >= duration) {
      controller.pause();
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    }
  }

  // ── Navigate to EditVideoScreen and capture the returned trim values
  Future<void> _openVideoEditor() async {
    // Pause preview while editing
    _videoController?.pause();
    setState(() => _isPlaying = false);

    final result = await Navigator.of(context).push<VideoEditResult>(
      MaterialPageRoute(
        builder: (_) => EditVideoScreen(media: _currentMedia),
      ),
    );

    if (!mounted) return;

    if (result != null) {
      setState(() {
        _trimStart = result.trimStart;
        _trimEnd = result.trimEnd;
      });

      if (result.outputPath != null && result.outputPath!.isNotEmpty) {
        _videoController?.removeListener(_handlePreviewVideoTick);
        await _videoController?.dispose();
        _videoController = null;
        final newMedia = app_models.MediaItem(
          id: _currentMedia.id,
          type: _currentMedia.type,
          filePath: result.outputPath,
          thumbnailPath: _currentMedia.thumbnailPath,
          duration: _currentMedia.duration,
          createdAt: _currentMedia.createdAt,
        );
        _currentMedia = newMedia;
        final controller = VideoPlayerController.file(File(newMedia.filePath!));
        _videoController = controller;
        _videoInit = controller.initialize().then((_) {
          if (!mounted) return;
          controller.setLooping(false);
          controller.addListener(_handlePreviewVideoTick);
          setState(() => _isPlaying = false);
        });
        setState(() {}); // Trigger immediate rebuild to show loading for the NEW future
      } else {
      // Seek preview to the new trim start (do not auto-play)
      final controller = _videoController;
      if (controller != null && controller.value.isInitialized) {
        await controller.seekTo(_trimStart!);
        setState(() => _isPlaying = false);
      }
      }
    } else {
      // User cancelled – do not auto-play
      setState(() => _isPlaying = false);
    }
  }

  Future<void> _openFilterPicker() async {
    if (_currentMedia.filePath == null) return;
    final filters = _createService.getFilters();
    final initialFilterId = _selectedFilter ?? 'none';
    final initialFilterName = _selectedFilterName;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          top: false,
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return SizedBox(
                height: MediaQuery.of(context).size.height * 0.32,
                child: Column(
                  children: [
                    const SizedBox(height: 6),
                    Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: filters.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, i) {
                          final f = filters[i];
                          final isActive = (_selectedFilter ?? 'none') == f.id;
                          final file = File(_currentMedia.filePath!);
                          final base = Image.file(file, fit: BoxFit.cover);
                          final preview = (f.id == 'none')
                              ? base
                              : ColorFiltered(
                                  colorFilter: ColorFilter.matrix(_reelFilterMatrixFor(f.id)),
                                  child: base,
                                );
                          final displayName = f.id == 'none' ? 'Normal' : f.name;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedFilter = f.id;
                                _selectedFilterName = displayName;
                                _cachedTextEditorBackground = null;
                              });
                              setSheetState(() {});
                            },
                            child: SizedBox(
                              width: 88,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isActive ? Colors.white : Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isActive ? Colors.white : Colors.white24,
                                          width: 1,
                                        ),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: preview,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
                        child: Row(
                          children: [
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _selectedFilter = initialFilterId;
                                  _selectedFilterName = initialFilterName;
                                  _cachedTextEditorBackground = null;
                                });
                                Navigator.of(context).pop();
                              },
                              child: const Text(
                                'Cancel',
                                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                              ),
                            ),
                            const Spacer(),
                            const Text(
                              'Filter',
                              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text(
                                'Done',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
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
          ),
        );
      },
    );
  }

  void _openImageAdjustmentsEditor() {
    const tools = <_ImageToolSpec>[
      _ImageToolSpec(key: 'lux', label: 'Lux', icon: Icons.auto_fix_high, min: 0, max: 100),
      _ImageToolSpec(key: 'brightness', label: 'Brightness', icon: Icons.wb_sunny_outlined, min: -100, max: 100),
      _ImageToolSpec(key: 'contrast', label: 'Contrast', icon: Icons.contrast, min: -100, max: 100),
      _ImageToolSpec(key: 'saturate', label: 'Saturation', icon: Icons.palette_outlined, min: -100, max: 100),
      _ImageToolSpec(key: 'sepia', label: 'Temperature', icon: Icons.thermostat_outlined, min: -100, max: 100),
      _ImageToolSpec(key: 'opacity', label: 'Fade', icon: Icons.blur_on_outlined, min: 0, max: 100),
      _ImageToolSpec(key: 'vignette', label: 'Vignette', icon: Icons.vignette_outlined, min: 0, max: 100),
    ];
    final initial = Map<String, int>.from(_imageAdjustments);
    String? selectedKey;
    final scrollController = ScrollController();
    bool didCenterScroll = false;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          top: false,
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              Widget sliderForTool(_ImageToolSpec tool) {
                final current = _imageAdjustments[tool.key] ?? 0;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: SizedBox()),
                        Text(current.toString(), style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                    Slider(
                      value: current.toDouble(),
                      min: tool.min.toDouble(),
                      max: tool.max.toDouble(),
                      onChanged: (v) {
                        final next = v.round();
                        setState(() {
                          _imageAdjustments = {
                            ..._imageAdjustments,
                            tool.key: next,
                          };
                          _cachedTextEditorBackground = null;
                        });
                        setSheetState(() {});
                      },
                      activeColor: const Color(0xFF0095F6),
                      inactiveColor: Colors.white24,
                    ),
                  ],
                );
              }

              final selectedTool = selectedKey == null
                  ? null
                  : tools.firstWhere((t) => t.key == selectedKey, orElse: () => tools[0]);

              final sheetHeightFactor = selectedTool == null ? 0.36 : 0.28;
              if (!didCenterScroll && selectedTool == null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!scrollController.hasClients) return;
                  scrollController.jumpTo(0.0);
                });
                didCenterScroll = true;
              }
              return SizedBox(
                height: MediaQuery.of(context).size.height * sheetHeightFactor,
                child: Column(
                  children: [
                    const SizedBox(height: 6),
                    Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: selectedTool == null
                            ? SizedBox(
                                key: const ValueKey('toolPicker'),
                                child: ListView.separated(
                                  controller: scrollController,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  scrollDirection: Axis.horizontal,
                                  itemCount: tools.length,
                                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                                  itemBuilder: (context, i) {
                                    final t = tools[i];
                                    return GestureDetector(
                                      onTap: () {
                                        setSheetState(() {
                                          selectedKey = t.key;
                                        });
                                      },
                                      child: SizedBox(
                                        width: 88,
                                        child: Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                t.label,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Container(
                                                width: 64,
                                                height: 64,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Colors.white.withValues(alpha: 0.06),
                                                  border: Border.all(
                                                    color: Colors.white24,
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Icon(
                                                  t.icon,
                                                  color: Colors.white70,
                                                  size: 26,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              )
                            : Padding(
                                key: const ValueKey('toolSlider'),
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: SingleChildScrollView(
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          IconButton(
                                            onPressed: () {
                                              setSheetState(() {
                                                selectedKey = null;
                                              });
                                            },
                                            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 18),
                                          ),
                                          Expanded(
                                            child: Center(
                                              child: Text(
                                                selectedTool.label,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 48),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      sliderForTool(selectedTool),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
                        child: Row(
                          children: [
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _imageAdjustments = initial;
                                  _cachedTextEditorBackground = null;
                                });
                                Navigator.of(context).pop();
                              },
                              child: const Text(
                                'Cancel',
                                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text(
                                'Done',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
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
          ),
        );
      },
    );
  }

  Widget _buildPostZoomableImagePreview(BoxConstraints viewport) {
    if (widget.media.filePath == null) {
      return const Icon(Icons.image, size: 100, color: Colors.white54);
    }
    _postViewportSize = viewport.biggest;
    final imageAspect = _imageAspectRatio ?? 1.0;
    final viewportAspect = (viewport.maxHeight <= 0) ? 1.0 : (viewport.maxWidth / viewport.maxHeight);
    final ratio = math.max(imageAspect / viewportAspect, viewportAspect / imageAspect).clamp(1.0, 5.0);
    final initialScale = ratio;
    final media = _applyImageAdjustments(_applySelectedFilter(
      ExtendedImage.file(
        key: ValueKey(
          'postZoom-${_imageAspectRatio?.toStringAsFixed(4) ?? 'na'}',
        ),
        extendedImageGestureKey: _postGestureKey,
        File(widget.media.filePath!),
        width: viewport.maxWidth,
        height: viewport.maxHeight,
        fit: BoxFit.contain,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        mode: ExtendedImageMode.gesture,
        initGestureConfigHandler: (state) {
          return GestureConfig(
            minScale: initialScale,
            maxScale: math.max(4.0, initialScale * 2.0),
            initialScale: initialScale,
            speed: 1.0,
            inertialSpeed: 100.0,
            cacheGesture: true,
            inPageView: false,
          );
        },
        onDoubleTap: (ExtendedImageGestureState s) {
          final begin = s.gestureDetails?.totalScale ?? 1.0;
          final end = begin < (initialScale * 1.5) ? math.max(initialScale * 2.0, 2.0) : initialScale;
          s.handleDoubleTap(scale: end);
        },
      ),
    ));
    return SizedBox(
      width: viewport.maxWidth,
      height: viewport.maxHeight,
      child: media,
    );
  }

  Rect? _computeVisibleCropRect({
    required Size viewport,
    required Size imagePx,
    required double totalScale,
    required Offset totalOffset,
  }) {
    if (viewport.width <= 0 || viewport.height <= 0 || imagePx.width <= 0 || imagePx.height <= 0) {
      return null;
    }
    final baseScale = math.min(viewport.width / imagePx.width, viewport.height / imagePx.height);
    if (baseScale <= 0) return null;

    final scale = (baseScale * totalScale).clamp(0.0001, 100000.0);
    final drawnW = imagePx.width * scale;
    final drawnH = imagePx.height * scale;
    final imgLeft = (viewport.width - drawnW) / 2.0 + totalOffset.dx;
    final imgTop = (viewport.height - drawnH) / 2.0 + totalOffset.dy;

    final left = (0 - imgLeft) / scale;
    final top = (0 - imgTop) / scale;
    final right = (viewport.width - imgLeft) / scale;
    final bottom = (viewport.height - imgTop) / scale;

    final clampedLeft = left.clamp(0.0, imagePx.width);
    final clampedTop = top.clamp(0.0, imagePx.height);
    final clampedRight = right.clamp(0.0, imagePx.width);
    final clampedBottom = bottom.clamp(0.0, imagePx.height);

    final w = (clampedRight - clampedLeft);
    final h = (clampedBottom - clampedTop);
    if (w <= 1 || h <= 1) return null;
    return Rect.fromLTRB(clampedLeft, clampedTop, clampedRight, clampedBottom);
  }

  Rect? _computeVisibleCropRectFromGestureDetails({
    required Size viewport,
    required Size imagePx,
    required dynamic details,
  }) {
    if (viewport.isEmpty || imagePx.isEmpty) return null;
    if (details == null) return null;

    Rect? destinationRect;
    Rect? layoutRect;
    try {
      final v = details.destinationRect;
      if (v is Rect) destinationRect = v;
    } catch (_) {}
    destinationRect ??= (() {
      try {
        final v = details.rawDestinationRect;
        if (v is Rect) return v;
      } catch (_) {}
      return null;
    })();
    try {
      final v = details.layoutRect;
      if (v is Rect) layoutRect = v;
    } catch (_) {}
    layoutRect ??= Offset.zero & viewport;

    final dest = destinationRect;
    if (dest == null || dest.width <= 0 || dest.height <= 0) return null;

    final vis = layoutRect.intersect(dest);
    if (vis.isEmpty) return null;

    final scaleX = dest.width / imagePx.width;
    final scaleY = dest.height / imagePx.height;
    if (scaleX <= 0 || scaleY <= 0) return null;

    final left = (vis.left - dest.left) / scaleX;
    final top = (vis.top - dest.top) / scaleY;
    final right = (vis.right - dest.left) / scaleX;
    final bottom = (vis.bottom - dest.top) / scaleY;

    final clampedLeft = left.clamp(0.0, imagePx.width);
    final clampedTop = top.clamp(0.0, imagePx.height);
    final clampedRight = right.clamp(0.0, imagePx.width);
    final clampedBottom = bottom.clamp(0.0, imagePx.height);

    final w = (clampedRight - clampedLeft);
    final h = (clampedBottom - clampedTop);
    if (w <= 1 || h <= 1) return null;
    return Rect.fromLTRB(clampedLeft, clampedTop, clampedRight, clampedBottom);
  }

  Future<String?> _writeCroppedImageFile({
    required String sourcePath,
    required Rect cropRect,
  }) async {
    final srcFile = File(sourcePath);
    if (!await srcFile.exists()) return null;
    final bytes = await srcFile.readAsBytes();
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, (img) => completer.complete(img));
    final image = await completer.future;

    final srcRect = ui.Rect.fromLTWH(
      cropRect.left,
      cropRect.top,
      cropRect.width,
      cropRect.height,
    );
    final outW = cropRect.width.round().clamp(1, image.width);
    final outH = cropRect.height.round().clamp(1, image.height);

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()));
    final paint = Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high;
    final dstRect = ui.Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble());
    canvas.drawImageRect(image, srcRect, dstRect, paint);
    final picture = recorder.endRecording();
    final outImage = await picture.toImage(outW, outH);
    final byteData = await outImage.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;
    final pngBytes = Uint8List.view(byteData.buffer);

    final filename = 'bsmart_crop_${DateTime.now().millisecondsSinceEpoch}_${pngBytes.lengthInBytes}.png';
    final outPath = '${Directory.systemTemp.path}/$filename';
    final outFile = File(outPath);
    await outFile.writeAsBytes(pngBytes, flush: true);
    return outPath;
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

  Future<String?> _writeProcessedImageFile({
    required String sourcePath,
    required String? filterId,
    required Map<String, int> adjustments,
  }) async {
    final srcFile = File(sourcePath);
    if (!await srcFile.exists()) return null;
    final bytes = await srcFile.readAsBytes();
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, (img) => completer.complete(img));
    final image = await completer.future;

    final lux = ((adjustments['lux'] ?? 0).clamp(0, 100) / 100.0);
    final luxBC = 1.0 + (lux * 0.35);
    final luxS = 1.0 + (lux * 0.2);
    final b = ((adjustments['brightness'] ?? 0) / 100.0 + 1.0) * luxBC;
    final c = ((adjustments['contrast'] ?? 0) / 100.0 + 1.0) * luxBC;
    final s = ((adjustments['saturate'] ?? 0) / 100.0 + 1.0) * luxS;
    final fade = 1.0 - (adjustments['opacity'] ?? 0) / 100.0;
    final tempRaw = (adjustments['sepia'] ?? 0).abs().clamp(0, 100);
    final sepiaAmount = (tempRaw / 100.0) * 0.35;
    final vignette = ((adjustments['vignette'] ?? 0).clamp(0, 100) / 100.0) * 0.65;

    final preset = (filterId == null || filterId == 'none')
        ? _buildAdjustmentMatrix(brightness: 1.0, contrast: 1.0, saturation: 1.0)
        : _reelFilterMatrixFor(filterId);
    final sepiaMatrix = (sepiaAmount <= 0)
        ? _buildAdjustmentMatrix(brightness: 1.0, contrast: 1.0, saturation: 1.0)
        : _buildSepiaMatrix(amount: sepiaAmount, brightness: 1.0, contrast: 1.0, saturation: 1.0);
    final adjust = _buildAdjustmentMatrix(brightness: b, contrast: c, saturation: s);
    final combined = _combineColorMatrices(adjust, _combineColorMatrices(sepiaMatrix, preset));

    final outW = image.width;
    final outH = image.height;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()));
    final paint = Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high
      ..color = Colors.white.withValues(alpha: fade.clamp(0.0, 1.0))
      ..colorFilter = ui.ColorFilter.matrix(combined);
    final srcRect = ui.Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble());
    canvas.drawImageRect(image, srcRect, srcRect, paint);

    if (vignette > 0) {
      final shader = ui.Gradient.radial(
        Offset(outW / 2.0, outH / 2.0),
        math.min(outW, outH) * 0.85,
        [
          const Color(0x00000000),
          Colors.black.withValues(alpha: vignette),
        ],
        const [0.55, 1.0],
      );
      canvas.drawRect(
        srcRect,
        Paint()..shader = shader,
      );
    }

    final picture = recorder.endRecording();
    final outImage = await picture.toImage(outW, outH);
    final byteData = await outImage.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;
    final pngBytes = Uint8List.view(byteData.buffer);

    final filename = 'bsmart_post_${DateTime.now().millisecondsSinceEpoch}_${pngBytes.lengthInBytes}.png';
    final outPath = '${Directory.systemTemp.path}/$filename';
    final outFile = File(outPath);
    await outFile.writeAsBytes(pngBytes, flush: true);
    return outPath;
  }

  Future<Size?> _readImagePixelSizeFromFile(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, (img) => completer.complete(img));
    final img = await completer.future;
    return Size(img.width.toDouble(), img.height.toDouble());
  }

  // ── Proceed to post details, passing trim values along
  Future<void> _proceedToPostDetails() async {
    final fallbackViewport =
        _postViewportSize ?? Size(MediaQuery.of(context).size.width, MediaQuery.of(context).size.width);
    final isVideo = _currentMedia.type == app_models.MediaType.video;
    final hasOverlays = _textOverlays.isNotEmpty || _stickerOverlays.isNotEmpty;
    if (_videoController?.value.isInitialized == true) {
      await _videoController?.pause();
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    }

    app_models.MediaItem nextMedia = _currentMedia;
    double nextAspect = 1.0;
    bool usedComposite = false;
    final filePath = _currentMedia.filePath;
    if (widget.isPostFlow && !isVideo && hasOverlays) {
      final compositePath = await _exportPreviewCompositeToFile();
      if (compositePath != null && compositePath.isNotEmpty) {
        nextMedia = app_models.MediaItem(
          id: _currentMedia.id,
          type: _currentMedia.type,
          filePath: compositePath,
          thumbnailPath: _currentMedia.thumbnailPath,
          duration: _currentMedia.duration,
          createdAt: _currentMedia.createdAt,
        );
        final size = await _readImagePixelSizeFromFile(compositePath);
        if (size != null) {
          nextAspect = _clampInstagramPostAspect(size.width / size.height);
        }
        usedComposite = true;
      }
    }
    if (!usedComposite && !isVideo && filePath != null) {
      final viewport = _postViewportSize ?? fallbackViewport;
      final imagePx = _imagePixelSize ?? await _readImagePixelSizeFromFile(filePath);
      if (imagePx == null) {
      } else {
      final dynamic details = _postGestureKey.currentState?.gestureDetails;
      Rect? cropRect;
      if (details != null) {
        cropRect = _computeVisibleCropRectFromGestureDetails(
          viewport: viewport,
          imagePx: imagePx,
          details: details,
        );
      }
      if (cropRect == null) {
        double totalScale = 1.0;
        if (details != null) {
          try {
            final v = details.totalScale;
            if (v is num) totalScale = v.toDouble();
          } catch (_) {}
        }
        Offset totalOffset = Offset.zero;
        if (details != null) {
          try {
            final v = details.userOffset;
            if (v is Offset) totalOffset = v;
          } catch (_) {}
          if (totalOffset == Offset.zero) {
            try {
              final v = details.offset;
              if (v is Offset) totalOffset = v;
            } catch (_) {}
          }
        }
        cropRect = _computeVisibleCropRect(
          viewport: viewport,
          imagePx: imagePx,
          totalScale: totalScale,
          totalOffset: totalOffset,
        );
      }
      if (cropRect != null) {
        nextAspect = _clampInstagramPostAspect(cropRect.width / cropRect.height);
        final croppedPath = await _writeCroppedImageFile(
          sourcePath: filePath,
          cropRect: cropRect,
        );
        if (croppedPath != null && croppedPath.isNotEmpty) {
          nextMedia = app_models.MediaItem(
            id: _currentMedia.id,
            type: _currentMedia.type,
            filePath: croppedPath,
            thumbnailPath: _currentMedia.thumbnailPath,
            duration: _currentMedia.duration,
            createdAt: _currentMedia.createdAt,
          );
        }
      }
      }
    }

    if (!usedComposite && !isVideo && nextMedia.filePath != null) {
      final hasFilter = (_selectedFilter ?? 'none') != 'none';
      final hasAdjustments = _imageAdjustments.values.any((v) => v != 0);
      if (hasFilter || hasAdjustments) {
        final processedPath = await _writeProcessedImageFile(
          sourcePath: nextMedia.filePath!,
          filterId: _selectedFilter,
          adjustments: _imageAdjustments,
        );
        if (processedPath != null && processedPath.isNotEmpty) {
          nextMedia = app_models.MediaItem(
            id: nextMedia.id,
            type: nextMedia.type,
            filePath: processedPath,
            thumbnailPath: nextMedia.thumbnailPath,
            duration: nextMedia.duration,
            createdAt: nextMedia.createdAt,
          );
          nextAspect = 0.0;
        }
      }
    }

    if (!mounted) return;
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => widget.isPostFlow
            ? CreatePostScreen(
                initialMedia: nextMedia,
                initialAspect: nextAspect,
                initialFilterName: null,
                initialAdjustments: null,
              )
            : CreateReelDetailsScreen(
                media: _currentMedia,
                selectedFilter: _selectedFilter,
                selectedMusic: _selectedMusic,
                musicVolume: _musicVolume,
                trimStart: _trimStart,
                trimEnd: _trimEnd,
              ),
      ),
    );
    if (!mounted) return;
    if (result == true) {
      Navigator.of(context).pop(true);
      return;
    }
    // Resume preview only when user comes back from next screen.
    if (_videoController != null &&
        _videoController!.value.isInitialized) {
      await _videoController!.play();
      if (mounted) {
        setState(() => _isPlaying = true);
      }
    }
  }

  void _handleTextScaleStart(ScaleStartDetails details) {
    if (_textOverlays.isEmpty) return;
    final activeIndex = _activeTextIndex ?? (_textOverlays.length - 1);
    _bringTextToFront(activeIndex);
    _textLastFocalPoint = details.focalPoint;
    _textLastLocalFocalPoint = _toPreviewLocal(details.focalPoint);
    final overlay = _textOverlays[activeIndex];
    _textTransformBaseScale = overlay.scale;
    _textTransformBaseRotation = overlay.rotation;
  }

  void _handleTextScaleUpdate(ScaleUpdateDetails details) {
    if (_textOverlays.isEmpty) return;
    final activeIndex = _activeTextIndex ?? (_textOverlays.length - 1);
    final overlay = _textOverlays[activeIndex];
    final local = _toPreviewLocal(details.focalPoint);
    final delta = local - _textLastLocalFocalPoint;
    _textLastLocalFocalPoint = local;
    _textLastFocalPoint = details.focalPoint;

    double newScale = overlay.scale;
    double newRotation = overlay.rotation;

    if (details.pointerCount > 1) {
      newScale = (_textTransformBaseScale * details.scale).clamp(0.2, 8.0);
      newRotation = _textTransformBaseRotation + details.rotation;
    }

    final nextPosition =
        _clampTextPosition(overlay, overlay.position + delta, newScale);
    setState(() {
      _textOverlays[activeIndex] = overlay.copyWith(
        position: nextPosition,
        scale: newScale,
        rotation: newRotation,
      );
      _updateTextDeleteScale(activeIndex, overlay);
    });
  }

  void _updateTextDeleteScale(int index, _PreviewTextOverlay overlay) {
    if (!_isTextDeleteMode) return;
    final center = _trashCenterLocal();
    final distance = (center - _textLastLocalFocalPoint).distance;
    const threshold = 120.0;
    final t = (distance / threshold).clamp(0.0, 1.0);
    final scale = 0.2 + (0.8 * t);
    _textDeleteScale[index] = scale;
  }

  void _handleTextScaleEnd() {
    _cancelTextHold();
    if (!_isTextDeleteMode) return;
    final index = _activeTextIndex;
    if (index == null || index < 0 || index >= _textOverlays.length) {
      _exitTextDeleteMode();
      return;
    }
    final center = _trashCenterLocal();
    final distance = (center - _textLastLocalFocalPoint).distance;
    if (distance <= 44) {
      _deleteTextByIndex(index);
    } else {
      _exitTextDeleteMode();
    }
  }

  void _deleteTextByIndex(int index) {
    if (_deletingTextIndexes.contains(index)) return;
    setState(() {
      _deletingTextIndexes.add(index);
    });
    Future.delayed(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      setState(() {
        if (index >= 0 && index < _textOverlays.length) {
          _textOverlays.removeAt(index);
        }
        _layerZOrder.remove('text_$index');
        final newZOrder = <String, int>{};
        _layerZOrder.forEach((key, value) {
          if (key.startsWith('sticker_')) {
            newZOrder[key] = value;
          } else {
            final i = int.tryParse(key.replaceFirst('text_', ''));
            if (i != null && i > index) {
              newZOrder['text_${i - 1}'] = value;
            } else if (i != null && i < index) {
              newZOrder[key] = value;
            }
          }
        });
        _layerZOrder
          ..clear()
          ..addAll(newZOrder);
        _deletingTextIndexes.remove(index);
        _activeTextIndex = null;
        _isTextDeleteMode = false;
        _textDeleteScale.clear();
      });
    });
  }

  void _handleStickerScaleStart(ScaleStartDetails details) {
    if (_stickerOverlays.isEmpty) return;
    final activeIndex = _activeStickerIndex ?? (_stickerOverlays.length - 1);
    _bringStickerToFront(activeIndex);
    _stickerLastFocalPoint = details.focalPoint;
    _stickerLastLocalFocalPoint = _toPreviewLocal(details.focalPoint);
    _stickerLastGlobalFocalPoint = details.focalPoint;
    final overlay = _stickerOverlays[activeIndex];
    _stickerBaseScale = overlay.scale;
    _stickerBaseRotation = overlay.rotation;
  }

  void _handleStickerScaleUpdate(
    ScaleUpdateDetails details,
    BuildContext context,
  ) {
    if (_stickerOverlays.isEmpty) return;
    final activeIndex = _activeStickerIndex ?? (_stickerOverlays.length - 1);
    final overlay = _stickerOverlays[activeIndex];
    final local = _toPreviewLocal(details.focalPoint);
    final delta = local - _stickerLastLocalFocalPoint;
    _stickerLastLocalFocalPoint = local;
    _stickerLastFocalPoint = details.focalPoint;
    _stickerLastGlobalFocalPoint = details.focalPoint;

    double newScale = overlay.scale;
    double newRotation = overlay.rotation;

    if (details.pointerCount > 1) {
      newScale = (_stickerBaseScale * details.scale).clamp(0.2, 8.0);
      newRotation = _stickerBaseRotation + details.rotation;
    }

    setState(() {
      _stickerOverlays[activeIndex] = overlay.copyWith(
        position: overlay.position + delta,
        scale: newScale,
        rotation: newRotation,
      );
      _updateDeleteScale(context, overlay);
    });
  }

  Future<ImageProvider> _buildTextEditorBackground() async {
    if (mounted) {
      setState(() => _hideTextOverlaysForCapture = true);
      await WidgetsBinding.instance.endOfFrame;
    }
    final boundary = _previewRepaintKey.currentContext?.findRenderObject();
    try {
      if (boundary is RenderRepaintBoundary) {
        final pixelRatio =
            math.min(2.0, View.of(context).devicePixelRatio);
        final image = await boundary.toImage(pixelRatio: pixelRatio);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data != null) {
          final img = MemoryImage(data.buffer.asUint8List());
          _cachedTextEditorBackground = img;
          return img;
        }
      }
    } catch (_) {
      // Fallback to file-based background if snapshot fails.
    } finally {
      if (mounted) {
        setState(() => _hideTextOverlaysForCapture = false);
      }
    }
    final fallback = await _baseTextEditorBackgroundFromMedia();
    _cachedTextEditorBackground ??= fallback;
    return _cachedTextEditorBackground!;
  }

  Future<void> _primeTextEditorBackground() async {
    if (_cachedTextEditorBackground != null) return;
    _cachedTextEditorBackground = await _baseTextEditorBackgroundFromMedia();
  }

  Future<ImageProvider> _baseTextEditorBackgroundFromMedia() async {
    final path = _currentMedia.filePath;
    if (path == null || path.isEmpty) {
      return const AssetImage('assets/images/dashboard_sample.png');
    }
    if (_currentMedia.type == app_models.MediaType.video) {
      final bytes = await VideoThumbnail.thumbnailData(
        video: path,
        imageFormat: ImageFormat.JPEG,
        quality: 70,
      );
      if (bytes != null) {
        return MemoryImage(bytes);
      }
      return const AssetImage('assets/images/dashboard_sample.png');
    }
    return FileImage(File(path));
  }

  Future<String?> _exportPreviewCompositeToFile() async {
    if (mounted) {
      setState(() => _captureWithoutRadius = true);
      await WidgetsBinding.instance.endOfFrame;
    }
    final boundary = _previewRepaintKey.currentContext?.findRenderObject();
    try {
      if (boundary is RenderRepaintBoundary) {
        final pixelRatio = math.min(3.0, View.of(context).devicePixelRatio);
        final image = await boundary.toImage(pixelRatio: pixelRatio);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) return null;
        final bytes = data.buffer.asUint8List();
        final filename =
            'bsmart_composite_${DateTime.now().millisecondsSinceEpoch}_${bytes.lengthInBytes}.png';
        final outPath = '${Directory.systemTemp.path}/$filename';
        final outFile = File(outPath);
        await outFile.writeAsBytes(bytes, flush: true);
        return outPath;
      }
    } catch (_) {
      return null;
    } finally {
      if (mounted) {
        setState(() => _captureWithoutRadius = false);
      }
    }
    return null;
  }

  Future<void> _openPreviewTextEditor({int? index}) async {
    final existing = index != null && index >= 0 && index < _textOverlays.length
        ? _textOverlays[index]
        : null;
    if (widget.isPostFlow) {
      _cachedTextEditorBackground = null;
    }
    final background = await _buildTextEditorBackground();
    if (!mounted) return;
    final normalizedInitialPosition = existing != null
        ? _normalizePreviewPosition(existing.position)
        : null;
    final result = await InstagramTextEditor.open(
      context,
      backgroundImage: background,
      initialText: existing?.text,
      initialColor: existing?.textColor ?? Colors.white,
      initialAlignment: existing?.alignment ?? TextAlign.center,
      initialBackgroundStyle:
          existing?.backgroundStyle ?? BackgroundStyle.none,
      initialScale: existing?.scale ?? 1.0,
      initialRotation: existing?.rotation ?? 0.0,
      initialPosition: normalizedInitialPosition,
      initialFont: existing?.fontName ?? 'Modern',
      initialFontSize: existing?.fontSize ?? 32.0,
    );

    if (result == null || !mounted) return;
    if (result.text.trim().isEmpty) return;
    final resolvedPosition = _denormalizePreviewPosition(result.position);
    final overlay = _PreviewTextOverlay(
      text: result.text,
      style: result.style,
      alignment: result.alignment,
      textColor: result.textColor,
      backgroundStyle: result.backgroundStyle,
      position: resolvedPosition,
      scale: result.scale,
      rotation: result.rotation,
      fontName: result.fontName,
      fontSize: result.fontSize,
    );
    final clamped = overlay.copyWith(
      position: _clampTextPosition(overlay, overlay.position, overlay.scale),
    );

    setState(() {
      final targetIndex = index ?? _activeTextIndex;
      if (targetIndex != null &&
          targetIndex >= 0 &&
          targetIndex < _textOverlays.length) {
        _textOverlays[targetIndex] = clamped;
        _activeTextIndex = targetIndex;
      } else {
        _textOverlays.add(clamped);
        _activeTextIndex = _textOverlays.length - 1;
      }
    });
  }

  void _onTapText() {
    _openPreviewTextEditor();
  }

  Future<void> _openOverlayPicker() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    final file = File(picked.path);
    final center = _overlayCenterForPreview();
    setState(() {
      _stickerOverlays.add(
        OverlaySticker(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          imageFile: file,
          shape: OverlayShape.none,
          position: center,
        ),
      );
      _activeStickerIndex = _stickerOverlays.length - 1;
    });
  }

  Offset _overlayCenterForPreview() {
    final render = _previewRepaintKey.currentContext?.findRenderObject();
    if (render is RenderBox) {
      final size = render.size;
      return Offset(
        (size.width - 120) / 2,
        (size.height - 120) / 2,
      );
    }
    return const Offset(120, 200);
  }

  OverlayShape _nextShape(OverlayShape shape) {
    final values = OverlayShape.values;
    final next = (values.indexOf(shape) + 1) % values.length;
    return values[next];
  }

  void _exitStickerDeleteMode() {
    if (_isStickerDeleteMode) {
      setState(() {
        _isStickerDeleteMode = false;
        _stickerDeleteScale.clear();
        _suppressStickerTap = false;
      });
    }
  }

  void _exitTextDeleteMode() {
    if (_isTextDeleteMode) {
      setState(() {
        _isTextDeleteMode = false;
        _textDeleteScale.clear();
        _suppressTextTap = false;
      });
    }
  }

  void _startStickerHold(int index) {
    _stickerHoldTimer?.cancel();
    _stickerHoldTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _activeStickerIndex = index;
        _isStickerDeleteMode = true;
        _suppressStickerTap = true;
      });
    });
  }

  void _cancelStickerHold() {
    _stickerHoldTimer?.cancel();
    _stickerHoldTimer = null;
  }

  void _startTextHold(int index) {
    _textHoldTimer?.cancel();
    _textHoldTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _activeTextIndex = index;
        _isTextDeleteMode = true;
        _suppressTextTap = true;
      });
    });
  }

  void _cancelTextHold() {
    _textHoldTimer?.cancel();
    _textHoldTimer = null;
  }

  void _deleteActiveSticker() {
    final index = _activeStickerIndex;
    if (index == null || index < 0 || index >= _stickerOverlays.length) {
      _exitStickerDeleteMode();
      return;
    }
    _deleteStickerById(_stickerOverlays[index].id);
  }

  void _deleteStickerById(String id) {
    if (_deletingStickerIds.contains(id)) return;
    setState(() {
      _deletingStickerIds.add(id);
    });
    Future.delayed(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      setState(() {
        _stickerOverlays.removeWhere((s) => s.id == id);
        _deletingStickerIds.remove(id);
        _layerZOrder.remove('sticker_$id');
        if (_activeStickerIndex != null &&
            _activeStickerIndex! >= _stickerOverlays.length) {
          _activeStickerIndex = null;
        }
        _isStickerDeleteMode = false;
        _stickerDeleteScale.clear();
      });
    });
  }

  void _updateCachedTrashCenter() {
    final renderBox =
        _previewRepaintKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !mounted) return;
    final size = renderBox.size;
    final topLeft = renderBox.localToGlobal(Offset.zero);
    setState(() {
      _cachedTrashCenter = Offset(
        topLeft.dx + size.width / 2,
        topLeft.dy + size.height - 60,
      );
    });
  }

  void _bringTextToFront(int index) {
    _zCounter++;
    _layerZOrder['text_$index'] = _zCounter;
    _activeTextIndex = index;
  }

  void _bringStickerToFront(int index) {
    if (index < 0 || index >= _stickerOverlays.length) return;
    _zCounter++;
    _layerZOrder['sticker_${_stickerOverlays[index].id}'] = _zCounter;
    _activeStickerIndex = index;
  }

  List<Map<String, dynamic>> _buildSortedLayers() {
    final layers = <Map<String, dynamic>>[];
    for (int i = 0; i < _textOverlays.length; i++) {
      layers.add({
        'type': 'text',
        'index': i,
        'zOrder': _layerZOrder['text_$i'] ?? i,
      });
    }
    for (int i = 0; i < _stickerOverlays.length; i++) {
      layers.add({
        'type': 'sticker',
        'index': i,
        'zOrder': _layerZOrder['sticker_${_stickerOverlays[i].id}'] ??
            (_textOverlays.length + i),
      });
    }
    layers.sort((a, b) =>
        (a['zOrder'] as int).compareTo(b['zOrder'] as int));
    return layers;
  }

  Offset _effectiveTrashCenter(BuildContext context) {
    final fallback = Offset(
      MediaQuery.of(context).size.width / 2,
      MediaQuery.of(context).size.height - 100,
    );
    return _cachedTrashCenter ?? fallback;
  }

  Offset _toPreviewLocal(Offset global) {
    final renderBox =
        _previewRepaintKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return global;
    return renderBox.globalToLocal(global);
  }

  Size? _previewSize() {
    final renderBox =
        _previewRepaintKey.currentContext?.findRenderObject() as RenderBox?;
    return renderBox?.size;
  }

  Offset _normalizePreviewPosition(Offset position) {
    final size = _previewSize();
    if (size == null || size.width == 0 || size.height == 0) {
      return position;
    }
    final dx = (position.dx / size.width).clamp(0.0, 1.0);
    final dy = (position.dy / size.height).clamp(0.0, 1.0);
    return Offset(dx, dy);
  }

  Offset _denormalizePreviewPosition(Offset normalized) {
    final size = _previewSize();
    if (size == null || size.width == 0 || size.height == 0) {
      return normalized;
    }
    return Offset(
      normalized.dx * size.width,
      normalized.dy * size.height,
    );
  }

  Size _measureTextSize(_PreviewTextOverlay overlay, double maxWidth) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: overlay.text,
        style: overlay.style.copyWith(color: overlay.textColor),
      ),
      textAlign: overlay.alignment,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    return textPainter.size;
  }

  Offset _clampTextPosition(
    _PreviewTextOverlay overlay,
    Offset position,
    double scale,
  ) {
    final renderBox =
        _previewRepaintKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return position;
    final bounds = renderBox.size;
    final textSize = _measureTextSize(overlay, bounds.width);
    final scaled = Size(textSize.width * scale, textSize.height * scale);
    final maxX = (bounds.width - scaled.width).clamp(0.0, bounds.width);
    final maxY = (bounds.height - scaled.height).clamp(0.0, bounds.height);
    final clampedX = position.dx.clamp(0.0, maxX);
    final clampedY = position.dy.clamp(0.0, maxY);
    return Offset(clampedX, clampedY);
  }

  Offset _trashCenterLocal() {
    final renderBox =
        _previewRepaintKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return const Offset(0, 0);
    final size = renderBox.size;
    return Offset(size.width / 2, size.height - 24 - 28);
  }

  void _updateDeleteScale(BuildContext context, OverlaySticker sticker) {
    if (!_isStickerDeleteMode) return;
    final center = _trashCenterLocal();
    final distance = (center - _stickerLastLocalFocalPoint).distance;
    const threshold = 120.0;
    final t = (distance / threshold).clamp(0.0, 1.0);
    final scale = 0.2 + (0.8 * t);
    _stickerDeleteScale[sticker.id] = scale;
  }

  void _handleStickerScaleEnd(BuildContext context) {
    _cancelStickerHold();
    if (!_isStickerDeleteMode) return;
    final index = _activeStickerIndex;
    if (index == null || index < 0 || index >= _stickerOverlays.length) {
      _exitStickerDeleteMode();
      return;
    }
    final center = _trashCenterLocal();
    final distance = (center - _stickerLastLocalFocalPoint).distance;
    if (distance <= 44) {
      _deleteStickerById(_stickerOverlays[index].id);
    } else {
      _exitStickerDeleteMode();
    }
  }

  Widget _buildOverlayVisual(_PreviewTextOverlay overlay, bool isActive) {
    final text = overlay.text;
    final baseStyle = overlay.style
        .copyWith(color: overlay.textColor, fontSize: overlay.fontSize);
    Widget content = _buildOverlayStyledText(overlay);

    if (overlay.backgroundStyle == BackgroundStyle.perChar) {
      final spans = text.split('').map((ch) {
        return TextSpan(
          text: ch,
          style: baseStyle.copyWith(
            backgroundColor: overlay.textColor.withValues(alpha: 0.2),
          ),
        );
      }).toList();
      content = Text.rich(
        TextSpan(children: spans),
        textAlign: overlay.alignment,
      );
    } else if (overlay.backgroundStyle == BackgroundStyle.solid ||
        overlay.backgroundStyle == BackgroundStyle.transparent) {
      final bgColor = overlay.backgroundStyle == BackgroundStyle.solid
          ? overlay.textColor.withValues(alpha: 0.9)
          : overlay.textColor.withValues(alpha: 0.35);
      final fgColor = overlay.backgroundStyle == BackgroundStyle.solid
          ? Colors.black
          : overlay.textColor;
      content = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: DefaultTextStyle.merge(
          style: baseStyle.copyWith(color: fgColor),
          child: content,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: content,
    );
  }

  Widget _buildOverlayStyledText(_PreviewTextOverlay overlay) {
    final text = overlay.text;
    final baseStyle = overlay.style
        .copyWith(color: overlay.textColor, fontSize: overlay.fontSize);

    if (overlay.fontName == 'Contour') {
      return Text(
        text,
        textAlign: overlay.alignment,
        style: baseStyle.copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = overlay.textColor,
        ),
      );
    }

    if (overlay.fontName == 'Neon') {
      return Stack(
        children: [
          Text(
            text,
            textAlign: overlay.alignment,
            style: baseStyle.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 4
                ..color = overlay.textColor.withValues(alpha: 0.8),
            ),
          ),
          Text(
            text,
            textAlign: overlay.alignment,
            style: baseStyle.copyWith(
              shadows: [
                Shadow(color: overlay.textColor, blurRadius: 14),
                Shadow(
                    color: overlay.textColor.withValues(alpha: 0.8),
                    blurRadius: 24),
              ],
            ),
          ),
        ],
      );
    }

    return Text(text, textAlign: overlay.alignment, style: baseStyle);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isPostFlow) {
      final screenWidth = MediaQuery.of(context).size.width;
      final frameAspect = _postFrameAspect();
      return Scaffold(
        backgroundColor: const Color(0xFF07121E),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 160),
                    opacity: (_isStickerDeleteMode || _isTextDeleteMode) ? 0 : 1,
                    child: IgnorePointer(
                      ignoring: _isStickerDeleteMode || _isTextDeleteMode,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        const Spacer(),
                        SizedBox(
                          width: double.infinity,
                          child: Center(
                            child: SizedBox(
                              width: screenWidth,
                              child: AspectRatio(
                                aspectRatio: frameAspect,
                                child: RepaintBoundary(
                                  key: _previewRepaintKey,
                                  child: ClipRRect(
                                    borderRadius: _captureWithoutRadius
                                        ? BorderRadius.zero
                                        : BorderRadius.circular(24),
                                    child: Container(
                                      color: Colors.black,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          if (widget.media.type ==
                                              app_models.MediaType.video)
                                            _buildVideoPreview()
                                          else
                                            LayoutBuilder(
                                              builder: (context, viewport) {
                                                return _buildPostZoomableImagePreview(
                                                    viewport);
                                              },
                                            ),
                                          if (!_isStickerDeleteMode &&
                                              _selectedFilterName != null &&
                                              _selectedFilter != null &&
                                              _selectedFilter != 'none')
                                            Positioned(
                                              top: 16,
                                              right: 16,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: Colors.black54,
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  'Filter: $_selectedFilterName',
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12),
                                                ),
                                              ),
                                            ),
                                          if (!_hideTextOverlaysForCapture)
                                            ..._buildSortedLayers().map((layer) {
                                              if (layer['type'] == 'text') {
                                                final index = layer['index'] as int;
                                                if (index >= _textOverlays.length) {
                                                  return const SizedBox.shrink();
                                                }
                                                final overlay = _textOverlays[index];
                                                final isActive = _activeTextIndex == index;
                                                return Positioned(
                                                  key: ValueKey('text_$index'),
                                                  left: overlay.position.dx,
                                                  top: overlay.position.dy,
                                                  child: GestureDetector(
                                                    onTapDown: (_) => _startTextHold(index),
                                                    onTapUp: (_) => _cancelTextHold(),
                                                    onTapCancel: _cancelTextHold,
                                                    onTap: () {
                                                      if (_suppressTextTap) {
                                                        _suppressTextTap = false;
                                                        return;
                                                      }
                                                      setState(() => _bringTextToFront(index));
                                                      _openPreviewTextEditor(index: index);
                                                    },
                                                    onScaleStart: (d) {
                                                      setState(() => _bringTextToFront(index));
                                                      _cancelTextHold();
                                                      _handleTextScaleStart(d);
                                                    },
                                                    onScaleUpdate: _handleTextScaleUpdate,
                                                    onScaleEnd: (_) => _handleTextScaleEnd(),
                                                    child: AnimatedOpacity(
                                                      duration: const Duration(milliseconds: 180),
                                                      opacity: _deletingTextIndexes.contains(index) ? 0.0 : 1.0,
                                                      child: AnimatedScale(
                                                        duration: const Duration(milliseconds: 180),
                                                        scale: _deletingTextIndexes.contains(index) ? 0.0 : 1.0,
                                                        child: Transform.rotate(
                                                          angle: overlay.rotation,
                                                          child: Transform.scale(
                                                            scale: overlay.scale * (_textDeleteScale[index] ?? 1.0),
                                                            child: _buildOverlayVisual(overlay, isActive),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              } else {
                                                final i = layer['index'] as int;
                                                if (i >= _stickerOverlays.length) {
                                                  return const SizedBox.shrink();
                                                }
                                                final s = _stickerOverlays[i];
                                                final isActive = _activeStickerIndex == i;
                                                return Positioned(
                                                  key: ValueKey('sticker_${s.id}'),
                                                  left: s.position.dx,
                                                  top: s.position.dy,
                                                  child: GestureDetector(
                                                    onTapDown: (_) => _startStickerHold(i),
                                                    onTapUp: (_) => _cancelStickerHold(),
                                                    onTapCancel: () => _cancelStickerHold(),
                                                    onTap: () {
                                                      if (_suppressStickerTap) {
                                                        _suppressStickerTap = false;
                                                        return;
                                                      }
                                                      setState(() {
                                                        if (_activeStickerIndex == i) {
                                                          _stickerOverlays[i] = s.copyWith(
                                                            shape: _nextShape(s.shape),
                                                          );
                                                        }
                                                        _bringStickerToFront(i);
                                                      });
                                                    },
                                                    onScaleStart: (d) {
                                                      setState(() => _bringStickerToFront(i));
                                                      _cancelStickerHold();
                                                      _handleStickerScaleStart(d);
                                                    },
                                                    onScaleUpdate: (d) => _handleStickerScaleUpdate(d, context),
                                                    onScaleEnd: (_) => _handleStickerScaleEnd(context),
                                                    child: AnimatedOpacity(
                                                      duration: const Duration(milliseconds: 180),
                                                      opacity: _deletingStickerIds.contains(s.id) ? 0.0 : 1.0,
                                                      child: AnimatedScale(
                                                        duration: const Duration(milliseconds: 180),
                                                        scale: _deletingStickerIds.contains(s.id) ? 0.0 : 1.0,
                                                        child: Transform(
                                                          alignment: Alignment.center,
                                                          transform: Matrix4.identity()
                                                            ..rotateZ(s.rotation)
                                                            ..scale(
                                                              s.scale * (_stickerDeleteScale[s.id] ?? 1.0),
                                                            ),
                                                          child: OverlayStickerWidget(
                                                            sticker: s,
                                                            isActive: isActive,
                                                            onDelete: () {},
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }
                                            }),
                                          if (_isStickerDeleteMode ||
                                              _isTextDeleteMode)
                                            Positioned.fill(
                                              child: GestureDetector(
                                                behavior:
                                                    HitTestBehavior.translucent,
                                                onTap: () {
                                                  _exitStickerDeleteMode();
                                                  _exitTextDeleteMode();
                                                },
                                              ),
                                            ),
                                          Positioned(
                                            left: 0,
                                            right: 0,
                                            bottom: 24,
                                            child: IgnorePointer(
                                              ignoring: !(_isStickerDeleteMode ||
                                                  _isTextDeleteMode),
                                              child: AnimatedOpacity(
                                                duration: const Duration(
                                                    milliseconds: 160),
                                                curve: Curves.easeOut,
                                                opacity:
                                                    (_isStickerDeleteMode ||
                                                            _isTextDeleteMode)
                                                        ? 1
                                                        : 0,
                                                child: AnimatedScale(
                                                  duration: const Duration(
                                                      milliseconds: 160),
                                                  curve: Curves.easeOut,
                                                  scale: _isStickerDeleteMode
                                                      ? 1
                                                      : _isTextDeleteMode
                                                          ? 1
                                                          : 0.9,
                                                  child: Center(
                                                    child: GestureDetector(
                                                      onTap:
                                                          _deleteActiveSticker,
                                                      child: Container(
                                                        width: 56,
                                                        height: 56,
                                                        decoration:
                                                            const BoxDecoration(
                                                          color: Colors.black87,
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                        child: const Icon(
                                                            Icons.delete_outline,
                                                            color: Colors.white,
                                                            size: 28),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 160),
                    opacity: (_isStickerDeleteMode || _isTextDeleteMode) ? 0 : 1,
                    child: IgnorePointer(
                      ignoring: _isStickerDeleteMode || _isTextDeleteMode,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
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
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildPostBottomPill(
                                    icon: Icons.music_note,
                                    label: 'Audio',
                                    onTap: () {
                                      setState(() {
                                        _showMusicControls = !_showMusicControls;
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 10),
                                  _buildPostBottomPill(
                                    icon: Icons.text_fields,
                                    label: 'Text',
                                    onTap: _onTapText,
                                  ),
                                  const SizedBox(width: 10),
                                  _buildPostBottomPill(
                                    icon: Icons.layers_outlined,
                                    label: 'Overlay',
                                    onTap: _openOverlayPicker,
                                  ),
                                  const SizedBox(width: 10),
                                  _buildPostBottomPill(
                                    icon: Icons.filter_alt_outlined,
                                    label: 'Filter',
                                    onTap: _openFilterPicker,
                                    isActive: (_selectedFilter ?? 'none') != 'none',
                                  ),
                                  const SizedBox(width: 10),
                                  _buildPostBottomPill(
                                    icon: Icons.tune,
                                    label: 'Edit',
                                    onTap:
                                        widget.media.type == app_models.MediaType.video
                                            ? _openVideoEditor
                                            : _openImageAdjustmentsEditor,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 160),
                    opacity: (_isStickerDeleteMode || _isTextDeleteMode) ? 0 : 1,
                    child: IgnorePointer(
                      ignoring: _isStickerDeleteMode || _isTextDeleteMode,
                      child: SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          child: Row(
                            children: [
                              const Spacer(),
                              ElevatedButton(
                                onPressed: _proceedToPostDetails,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0095F6),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 26, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(26)),
                                ),
                                child: const Text('Next →'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFF07121E),
      body: SafeArea(
          child: Stack(
            children: [
            Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: widget.media.type == app_models.MediaType.video
                        ? EdgeInsets.zero
                        : const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: RepaintBoundary(
                      key: _previewRepaintKey,
                      child: ClipRRect(
                        borderRadius: (_captureWithoutRadius ||
                                widget.media.type == app_models.MediaType.video)
                            ? BorderRadius.zero
                            : BorderRadius.circular(24),
                        child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () {
                          if (_activeStickerIndex != null) {
                            setState(() => _activeStickerIndex = null);
                          }
                          if (_activeTextIndex != null) {
                            setState(() => _activeTextIndex = null);
                          }
                          _exitStickerDeleteMode();
                          _exitTextDeleteMode();
                        },
                        onScaleStart: _handleTextScaleStart,
                        onScaleUpdate: _handleTextScaleUpdate,
                        onScaleEnd: (_) => _handleTextScaleEnd(),
                          child: Stack(
                            fit: StackFit.expand,
                            alignment: Alignment.center,
                            children: [
                              if (widget.media.type == app_models.MediaType.video)
                                _buildVideoPreview()
                              else
                                _buildImagePreview(),
                              if (!_isStickerDeleteMode &&
                                  _selectedFilterName != null &&
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
                              if (!_isStickerDeleteMode &&
                                  _trimStart != null && _trimEnd != null)
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
                            if (!_hideTextOverlaysForCapture)
                              ..._buildSortedLayers().map((layer) {
                                if (layer['type'] == 'text') {
                                  final index = layer['index'] as int;
                                  if (index >= _textOverlays.length) {
                                    return const SizedBox.shrink();
                                  }
                                  final overlay = _textOverlays[index];
                                  final isActive = _activeTextIndex == index;
                                  return Positioned(
                                    key: ValueKey('text_$index'),
                                    left: overlay.position.dx,
                                    top: overlay.position.dy,
                                    child: GestureDetector(
                                      onTapDown: (_) => _startTextHold(index),
                                      onTapUp: (_) => _cancelTextHold(),
                                      onTapCancel: _cancelTextHold,
                                      onTap: () {
                                        if (_suppressTextTap) {
                                          _suppressTextTap = false;
                                          return;
                                        }
                                        setState(() => _bringTextToFront(index));
                                        _openPreviewTextEditor(index: index);
                                      },
                                      onScaleStart: (d) {
                                        setState(() => _bringTextToFront(index));
                                        _cancelTextHold();
                                        _handleTextScaleStart(d);
                                      },
                                      onScaleUpdate: _handleTextScaleUpdate,
                                      onScaleEnd: (_) => _handleTextScaleEnd(),
                                      child: AnimatedOpacity(
                                        duration: const Duration(milliseconds: 180),
                                        opacity: _deletingTextIndexes.contains(index) ? 0.0 : 1.0,
                                        child: AnimatedScale(
                                          duration: const Duration(milliseconds: 180),
                                          scale: _deletingTextIndexes.contains(index) ? 0.0 : 1.0,
                                          child: Transform.rotate(
                                            angle: overlay.rotation,
                                            child: Transform.scale(
                                              scale: overlay.scale * (_textDeleteScale[index] ?? 1.0),
                                              child: _buildOverlayVisual(overlay, isActive),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                } else {
                                  final i = layer['index'] as int;
                                  if (i >= _stickerOverlays.length) {
                                    return const SizedBox.shrink();
                                  }
                                  final s = _stickerOverlays[i];
                                  final isActive = _activeStickerIndex == i;
                                  return Positioned(
                                    key: ValueKey('sticker_${s.id}'),
                                    left: s.position.dx,
                                    top: s.position.dy,
                                    child: GestureDetector(
                                      onTapDown: (_) => _startStickerHold(i),
                                      onTapUp: (_) => _cancelStickerHold(),
                                      onTapCancel: () => _cancelStickerHold(),
                                      onTap: () {
                                        if (_suppressStickerTap) {
                                          _suppressStickerTap = false;
                                          return;
                                        }
                                        setState(() {
                                          if (_activeStickerIndex == i) {
                                            _stickerOverlays[i] = s.copyWith(
                                              shape: _nextShape(s.shape),
                                            );
                                          }
                                          _bringStickerToFront(i);
                                        });
                                      },
                                      onScaleStart: (d) {
                                        setState(() => _bringStickerToFront(i));
                                        _cancelStickerHold();
                                        _handleStickerScaleStart(d);
                                      },
                                      onScaleUpdate: (d) => _handleStickerScaleUpdate(d, context),
                                      onScaleEnd: (_) => _handleStickerScaleEnd(context),
                                      child: AnimatedOpacity(
                                        duration: const Duration(milliseconds: 180),
                                        opacity: _deletingStickerIds.contains(s.id) ? 0.0 : 1.0,
                                        child: AnimatedScale(
                                          duration: const Duration(milliseconds: 180),
                                          scale: _deletingStickerIds.contains(s.id) ? 0.0 : 1.0,
                                          child: Transform(
                                            alignment: Alignment.center,
                                            transform: Matrix4.identity()
                                              ..rotateZ(s.rotation)
                                              ..scale(
                                                s.scale * (_stickerDeleteScale[s.id] ?? 1.0),
                                              ),
                                            child: OverlayStickerWidget(
                                              sticker: s,
                                              isActive: isActive,
                                              onDelete: () {},
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              }),
                                      if (_isStickerDeleteMode ||
                                          _isTextDeleteMode)
                                        Positioned.fill(
                                          child: GestureDetector(
                                            behavior: HitTestBehavior.translucent,
                                            onTap: () {
                                              _exitStickerDeleteMode();
                                              _exitTextDeleteMode();
                                            },
                                          ),
                                        ),
                                      Positioned(
                                        left: 0,
                                        right: 0,
                                        bottom: 24,
                                        child: IgnorePointer(
                                          ignoring: !(_isStickerDeleteMode ||
                                              _isTextDeleteMode),
                                          child: AnimatedOpacity(
                                            duration:
                                                const Duration(milliseconds: 160),
                                            curve: Curves.easeOut,
                                            opacity:
                                                (_isStickerDeleteMode ||
                                                        _isTextDeleteMode)
                                                    ? 1
                                                    : 0,
                                            child: AnimatedScale(
                                              duration: const Duration(
                                                  milliseconds: 160),
                                              curve: Curves.easeOut,
                                              scale:
                                                  (_isStickerDeleteMode ||
                                                          _isTextDeleteMode)
                                                      ? 1
                                                      : 0.9,
                                              child: Center(
                                                child: GestureDetector(
                                                  onTap: _deleteActiveSticker,
                                                  child: Container(
                                                    width: 56,
                                                    height: 56,
                                                    decoration:
                                                        const BoxDecoration(
                                                      color: Colors.black87,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(
                                                        Icons.delete_outline,
                                                        color: Colors.white,
                                                        size: 28),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                      ),
                    ),
                  ),
                ),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 160),
                  opacity: (_isStickerDeleteMode || _isTextDeleteMode) ? 0 : 1,
                  child: IgnorePointer(
                    ignoring: _isStickerDeleteMode || _isTextDeleteMode,
                    child: Container(
                      height: 72,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      color: Colors.black,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (widget.isPostFlow)
                            Row(
                              children: [
                                _buildPostBottomPill(
                                  icon: Icons.tune,
                                  label: 'Edit',
                                  onTap: widget.media.type ==
                                          app_models.MediaType.video
                                      ? _openVideoEditor
                                      : _openImageAdjustmentsEditor,
                                ),
                                const SizedBox(width: 10),
                                _buildPostBottomPill(
                                  icon: Icons.filter_alt_outlined,
                                  label: 'Filter',
                                  onTap: _openFilterPicker,
                                  isActive: (_selectedFilter ?? 'none') != 'none',
                                ),
                              ],
                            )
                          else
                            OutlinedButton(
                              onPressed: widget.media.type ==
                                      app_models.MediaType.video
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
                  ),
                ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 72 + 16,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 160),
                opacity: (_isStickerDeleteMode || _isTextDeleteMode) ? 0 : 1,
                child: IgnorePointer(
                  ignoring: _isStickerDeleteMode || _isTextDeleteMode,
                  child: widget.isPostFlow
                      ? const SizedBox.shrink()
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_showMusicControls)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _buildMusicPanel(),
                              ),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildEditOption(
                                    icon: Icons.text_fields,
                                    label: 'Text',
                                    onTap: _onTapText,
                                  ),
                                  const SizedBox(width: 8),
                                  if (widget.media.type ==
                                      app_models.MediaType.video)
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
              ),
            ),
            Positioned(
              top: 16,
              left: 16,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 160),
                opacity: (_isStickerDeleteMode || _isTextDeleteMode) ? 0 : 1,
                child: IgnorePointer(
                  ignoring: _isStickerDeleteMode || _isTextDeleteMode,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),
                                      if (_isStickerDeleteMode ||
                                          _isTextDeleteMode)
                                        Positioned.fill(
                                          child: GestureDetector(
                                            behavior: HitTestBehavior.translucent,
                                            onTap: () {
                                              _exitStickerDeleteMode();
                                              _exitTextDeleteMode();
                                            },
                                          ),
                                        ),
                                      Positioned(
                                        left: 0,
                                        right: 0,
                                        bottom: 24,
                                        child: IgnorePointer(
                                          ignoring: !(_isStickerDeleteMode ||
                                              _isTextDeleteMode),
                                          child: AnimatedOpacity(
                                            duration:
                                                const Duration(milliseconds: 160),
                                            curve: Curves.easeOut,
                                            opacity:
                                                (_isStickerDeleteMode ||
                                                        _isTextDeleteMode)
                                                    ? 1
                                                    : 0,
                                            child: AnimatedScale(
                                              duration: const Duration(
                                                  milliseconds: 160),
                                              curve: Curves.easeOut,
                                              scale:
                                                  (_isStickerDeleteMode ||
                                                          _isTextDeleteMode)
                                                      ? 1
                                                      : 0.9,
                                              child: Center(
                                                child: GestureDetector(
                                                  onTap: _deleteActiveSticker,
                                                  child: Container(
                                                    width: 56,
                                                    height: 56,
                                                    decoration:
                                                        const BoxDecoration(
                                                      color: Colors.black87,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(
                                                        Icons.delete_outline,
                                                        color: Colors.white,
                                                        size: 28),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
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
        final Size videoSize = controller.value.size;

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
          child: _applyImageAdjustments(_applySelectedFilter(
            Stack(
              alignment: Alignment.center,
              children: [
                Container(color: Colors.blue),
                SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: math.min(videoSize.width, videoSize.height),
                      height: math.max(videoSize.width, videoSize.height),
                      child: Center(
                        child: RotatedBox(
                          quarterTurns: 1,
                          child: SizedBox(
                            width: videoSize.width,
                            height: videoSize.height,
                            child: VideoPlayer(controller),
                          ),
                        ),
                      ),
                    ),
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
          )),
        );
      },
    );
  }

  Widget _buildImagePreview() {
    if (widget.media.filePath != null) {
      return Container(
        color: Colors.red,
        child: Center(
          child: RotatedBox(
            quarterTurns: 1,
            child: Image.file(
              File(widget.media.filePath!),
              fit: BoxFit.contain,
            ),
          ),
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

  Widget _buildPostBottomPill({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: isActive ? Border.all(color: const Color(0xFF0095F6)) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? const Color(0xFF0095F6) : Colors.white,
              size: 16,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? const Color(0xFF0095F6) : Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
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
            padding: const EdgeInsets.all(10),
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
                size: 20),
          ),
          const SizedBox(height: 3),
          Text(label,
              style: TextStyle(
                  color: isActive
                      ? const Color(0xFF0095F6)
                      : Colors.white,
                  fontSize: 11)),
        ],
      ),
    );
  }

  void _showComingSoon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label coming soon')),
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
