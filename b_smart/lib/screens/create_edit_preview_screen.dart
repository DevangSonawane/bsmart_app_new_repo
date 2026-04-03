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
import 'package:vector_math/vector_math_64.dart' as vector_math;
import 'package:photo_manager/photo_manager.dart';
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
import '../features/reel_timeline/reel_timeline_models.dart';
import '../features/reel_timeline/reel_timeline_renderer.dart';

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

class _ZoomPanImageView extends StatefulWidget {
  final Key imageKey;
  final String filePath;
  final double viewportW;
  final double viewportH;
  final double imagePxW;
  final double imagePxH;
  final double containScale;
  final double coverScale;
  final double maxScale;
  final TransformationController transformController;
  final List<String> filterIds;
  final Map<String, int> adjustments;
  final Widget Function(Widget, {List<String>? filterIds}) applyFilter;
  final Widget Function(Widget, {Map<String, int>? adjustments}) applyAdjustments;

  const _ZoomPanImageView({
    super.key,
    required this.imageKey,
    required this.filePath,
    required this.viewportW,
    required this.viewportH,
    required this.imagePxW,
    required this.imagePxH,
    required this.containScale,
    required this.coverScale,
    required this.maxScale,
    required this.transformController,
    required this.filterIds,
    required this.adjustments,
    required this.applyFilter,
    required this.applyAdjustments,
  });

  @override
  State<_ZoomPanImageView> createState() => _ZoomPanImageViewState();
}

class _ZoomPanImageViewState extends State<_ZoomPanImageView>
    with SingleTickerProviderStateMixin {
  late double _scale;
  double _baseScale = 1.0;
  Offset _offset = Offset.zero;
  Offset _baseOffset = Offset.zero;
  Offset _baseFocalPoint = Offset.zero;
  AnimationController? _animController;
  Animation<Offset>? _offsetAnim;
  Animation<double>? _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scale = (widget.coverScale.isFinite && widget.coverScale > 0)
        ? widget.coverScale
        : 1.0;
    _offset = _centeredOffset(_scale);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addListener(_onAnimTick);
  }

  @override
  void dispose() {
    _animController?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _ZoomPanImageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final mediaChanged = widget.filePath != oldWidget.filePath;
    final geometryChanged =
        widget.viewportW != oldWidget.viewportW ||
        widget.viewportH != oldWidget.viewportH ||
        widget.imagePxW != oldWidget.imagePxW ||
        widget.imagePxH != oldWidget.imagePxH ||
        widget.coverScale != oldWidget.coverScale;
    if (mediaChanged || geometryChanged) {
      _animController?.stop();
      _scale = (widget.coverScale.isFinite && widget.coverScale > 0)
          ? widget.coverScale
          : 1.0;
      _offset = _centeredOffset(_scale);
      _baseScale = _scale;
      _baseOffset = _offset;
    }
  }

  Offset _centeredOffset(double scale) {
    final sw = widget.imagePxW * scale;
    final sh = widget.imagePxH * scale;
    return Offset(
      (widget.viewportW - sw) / 2.0,
      (widget.viewportH - sh) / 2.0,
    );
  }

  Offset _clampOffset(Offset offset, double scale) {
    final sw = widget.imagePxW * scale;
    final sh = widget.imagePxH * scale;

    double clampAxis(double value, double drawn, double viewport) {
      if (drawn <= viewport) {
        return (viewport - drawn) / 2.0;
      } else {
        return value.clamp(viewport - drawn, 0.0);
      }
    }

    return Offset(
      clampAxis(offset.dx, sw, widget.viewportW),
      clampAxis(offset.dy, sh, widget.viewportH),
    );
  }

  void _onAnimTick() {
    if (!mounted) return;
    setState(() {
      if (_scaleAnim != null) {
        _scale = _scaleAnim!.value;
      }
      if (_offsetAnim != null) {
        _offset = _offsetAnim!.value;
      }
      _offset = _clampOffset(_offset, _scale);
    });
  }

  void _onScaleStart(ScaleStartDetails d) {
    _animController?.stop();
    _baseScale = _scale;
    _baseOffset = _offset;
    _baseFocalPoint = d.localFocalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    setState(() {
      final newScale =
          (_baseScale * d.scale).clamp(widget.containScale, widget.maxScale);

      final imgX = (_baseFocalPoint.dx - _baseOffset.dx) / _baseScale;
      final imgY = (_baseFocalPoint.dy - _baseOffset.dy) / _baseScale;

      final ox = d.localFocalPoint.dx - imgX * newScale;
      final oy = d.localFocalPoint.dy - imgY * newScale;

      _scale = newScale;
      _offset = _clampOffset(Offset(ox, oy), newScale);
    });
  }

  void _onScaleEnd(ScaleEndDetails d) {
    if (_scale < widget.containScale) {
      _animateTo(
        targetScale: widget.containScale,
        targetOffset: _centeredOffset(widget.containScale),
      );
      return;
    }

    if (_scale < widget.coverScale &&
        widget.coverScale > widget.containScale) {
      _animateTo(
        targetScale: widget.coverScale,
        targetOffset: _clampOffset(_offset, widget.coverScale),
      );
      return;
    }

    final velocity = d.velocity.pixelsPerSecond;
    if (velocity.distance > 150) {
      final projected = _offset + velocity * 0.10;
      final clamped = _clampOffset(projected, _scale);
      _offsetAnim = Tween<Offset>(begin: _offset, end: clamped).animate(
        CurvedAnimation(parent: _animController!, curve: Curves.easeOutCubic),
      );
      _scaleAnim = null;
      _animController!.forward(from: 0);
    }
  }

  void _animateTo({
    required double targetScale,
    required Offset targetOffset,
  }) {
    _scaleAnim = Tween<double>(begin: _scale, end: targetScale).animate(
      CurvedAnimation(parent: _animController!, curve: Curves.easeOutCubic),
    );
    _offsetAnim = Tween<Offset>(begin: _offset, end: targetOffset).animate(
      CurvedAnimation(parent: _animController!, curve: Curves.easeOutCubic),
    );
    _animController!.forward(from: 0);
  }

  void _onDoubleTapDown(TapDownDetails d) {
    _animController?.stop();
    if (_scale > widget.coverScale * 1.3) {
      _animateTo(
        targetScale: widget.coverScale,
        targetOffset: _clampOffset(
          _centeredOffset(widget.coverScale),
          widget.coverScale,
        ),
      );
      return;
    }
    if (_scale <= widget.containScale * 1.1) {
      _animateTo(
        targetScale: widget.coverScale,
        targetOffset: _clampOffset(
          _centeredOffset(widget.coverScale),
          widget.coverScale,
        ),
      );
      return;
    }
    final newScale =
        (widget.coverScale * 2.5).clamp(widget.coverScale, widget.maxScale);
    final imgX = (d.localPosition.dx - _offset.dx) / _scale;
    final imgY = (d.localPosition.dy - _offset.dy) / _scale;
    final ox = d.localPosition.dx - imgX * newScale;
    final oy = d.localPosition.dy - imgY * newScale;
    _animateTo(
      targetScale: newScale,
      targetOffset: _clampOffset(Offset(ox, oy), newScale),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_scale.isFinite || _scale <= 0) return const SizedBox.shrink();

    final image = widget.applyAdjustments(
      widget.applyFilter(
        Image.file(
          key: widget.imageKey,
          File(widget.filePath),
          width: widget.imagePxW,
          height: widget.imagePxH,
          fit: BoxFit.fill,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
        ),
        filterIds: widget.filterIds,
      ),
      adjustments: widget.adjustments,
    );

    return ClipRect(
      child: GestureDetector(
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd: _onScaleEnd,
        onDoubleTapDown: _onDoubleTapDown,
        child: SizedBox(
          width: widget.viewportW,
          height: widget.viewportH,
          child: Stack(
            children: [
              Positioned(
                left: _offset.dx,
                top: _offset.dy,
                child: Transform.scale(
                  scale: _scale,
                  alignment: Alignment.topLeft,
                  child: image,
                ),
              ),
            ],
          ),
        ),
      ),
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
  final List<app_models.MediaItem>? mediaList;
  final String? selectedFilter;
  final bool isPostFlow;
  final bool isReelFlow;

  const CreateEditPreviewScreen({
    super.key,
    required this.media,
    this.mediaList,
    this.selectedFilter,
    this.isPostFlow = false,
    this.isReelFlow = false,
  });

  @override
  State<CreateEditPreviewScreen> createState() => _CreateEditPreviewScreenState();
}

class _CreateEditPreviewScreenState extends State<CreateEditPreviewScreen> {
  final CreateService _createService = CreateService();
  late app_models.MediaItem _currentMedia;
  late List<app_models.MediaItem> _mediaList;
  int _currentIndex = 0;
  bool _showInlineImageEditor = false;
  final Map<String, Map<String, int>> _mediaAdjustments = {};
  final Map<String, String?> _mediaFilters = {};
  final Map<String, List<_PreviewTextOverlay>> _mediaTextOverlays = {};
  final Map<String, List<OverlaySticker>> _mediaStickerOverlays = {};
  PageController? _postPageController;
  String? _selectedFilter;
  String? _selectedFilterName;
  String? _selectedMusic;
  double _musicVolume = 0.5;
  bool _showMusicControls = false;
  VideoPlayerController? _videoController;
  Future<void>? _videoInit;
  bool _isPlaying = false;
  bool _autoPlayQueued = false;
  Duration? _trimStart;
  Duration? _trimEnd;
  final Map<String, Duration?> _mediaTrimStart = {};
  final Map<String, Duration?> _mediaTrimEnd = {};
  final Map<String, String?> _mediaVideoCoverPath = {};
  final List<_PreviewTextOverlay> _textOverlays = [];
  int? _activeTextIndex;
  int _zCounter = 0;
  final Map<String, int> _layerZOrder = {};
  Offset _textLastLocalFocalPoint = Offset.zero;
  double _textTransformBaseScale = 1.0;
  double _textTransformBaseRotation = 0.0;
  final List<OverlaySticker> _stickerOverlays = [];
  int? _activeStickerIndex;
  Offset _stickerLastLocalFocalPoint = Offset.zero;
  double _stickerBaseScale = 1.0;
  double _stickerBaseRotation = 0.0;
  bool _isStickerDeleteMode = false;
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
  double? _imageAspectRatio;
  Size? _imagePixelSize;
  double? _postFixedAspect;
  double? _autoPostAspect;
  ImageStream? _imageStream;
  ImageStreamListener? _imageStreamListener;
  final TransformationController _transformController = TransformationController();
  final GlobalKey<_ZoomPanImageViewState> _zoomPanKey = GlobalKey<_ZoomPanImageViewState>();
  final GlobalKey _previewRepaintKey = GlobalKey();
  Key _imageKey = const ValueKey('img_0_0');
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

  _ZoomPanImageViewState? get _zoomPanState => _zoomPanKey.currentState;

  double _clampInstagramPostAspect(double aspect) {
    if (aspect.isNaN || aspect.isInfinite || aspect <= 0) return 1.0;
    const minLandscape = 1.91;
    const maxPortrait = 4 / 5; // 0.8
    return aspect.clamp(maxPortrait, minLandscape);
  }

  double _postFrameAspect() {
    bool hasAspect = true;
    double aspect = 1.0;
    if (widget.media.type == app_models.MediaType.video) {
      final controller = _videoController;
      if (controller != null && controller.value.isInitialized) {
        aspect = controller.value.aspectRatio;
      } else {
        hasAspect = false;
      }
    } else {
      if (_imageAspectRatio != null) {
        aspect = _imageAspectRatio!;
      } else {
        hasAspect = false;
      }
    }

    if (widget.isPostFlow) {
      // Special-case: if current item is a square video, keep 1:1.
      if (_isVideoMedia(_currentMedia)) {
        final controller = _videoController;
        final vAspect = controller != null && controller.value.isInitialized
            ? controller.value.aspectRatio
            : aspect;
        if ((vAspect - 1.0).abs() < 0.05) {
          return 1.0;
        }
        // If we already have a fixed aspect from an image, honor it.
        if (_postFixedAspect != null) {
          return _postFixedAspect!;
        }
        // If there's any image in the carousel, default to 4:5 until image sets fixed aspect.
        final hasImage =
            _mediaList.any((m) => !_isVideoMedia(m));
        if (hasImage) {
          return 4.0 / 5.0;
        }
      }
      if (!hasAspect) {
        return 1.0;
      }
      if (_postFixedAspect != null) return _postFixedAspect!;
      final next = _autoPostAspectFor(aspect);
      _autoPostAspect = next;
      _postFixedAspect = next;
      return next;
    }
    if (widget.isReelFlow) {
      // Reel flow: lock the edit frame to 9:16 and letterbox when needed.
      return 9.0 / 16.0;
    }
    return _clampInstagramPostAspect(aspect);
  }

  BoxFit _videoPreviewFit(double videoAspect, double frameAspect) {
    if (videoAspect.isNaN || videoAspect.isInfinite || videoAspect <= 0) {
      return BoxFit.contain;
    }
    const tolerance = 0.04;
    if (videoAspect <= frameAspect + tolerance) {
      return BoxFit.cover;
    }
    return BoxFit.contain;
  }

  double _autoPostAspectFor(double aspect) {
    const double minPortrait = 4.0 / 5.0;
    const double maxLandscape = 1.91;
    if (aspect.isNaN || aspect.isInfinite || aspect <= 0) return 1.0;
    if (aspect < minPortrait) return minPortrait;
    if (aspect >= minPortrait && aspect < 0.95) return minPortrait;
    if (aspect >= 0.95 && aspect <= 1.05) return 1.0;
    if (aspect > 1.05 && aspect <= maxLandscape) return aspect;
    return maxLandscape;
  }

  void _maybeInitPostAspect(double aspect) {
    if (!widget.isPostFlow) return;
    if (_postFixedAspect != null || _autoPostAspect != null) return;
    final hasImage =
        _mediaList.any((m) => !_isVideoMedia(m));
    if (hasImage && _isVideoMedia(_currentMedia)) {
      return;
    }
    final next = _autoPostAspectFor(aspect);
    _autoPostAspect = next;
    _postFixedAspect = next;
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

  Widget _applySelectedFilter(Widget child, {List<String>? filterIds}) {
    final ids = (filterIds ?? const <String>[])
        .where((id) => id != 'none')
        .toList();
    if (ids.isEmpty) return child;
    Widget out = child;
    for (final id in ids) {
      final matrix = _reelFilterMatrixFor(id);
      out = ColorFiltered(
        colorFilter: ColorFilter.matrix(matrix),
        child: out,
      );
    }
    return out;
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

  Widget _applyImageAdjustments(Widget child, {Map<String, int>? adjustments}) {
    final adj = adjustments ?? _imageAdjustments;
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

  Map<String, int> _effectiveAdjustments(app_models.MediaItem media) {
    final base = _imageAdjustments;
    final delta = _mediaAdjustments[media.id];
    if (delta == null) return base;
    return _mergeAdjustments(base, delta);
  }

  String? _effectiveFilter(app_models.MediaItem media) {
    return _mediaFilters.containsKey(media.id)
        ? _mediaFilters[media.id]
        : _selectedFilter;
  }

  List<String> _effectiveFilterIds(app_models.MediaItem media) {
    final ids = <String>[];
    final global = _selectedFilter;
    if (global != null && global != 'none') {
      ids.add(global);
    }
    final per = _mediaFilters[media.id];
    if (per != null && per != 'none' && per != global) {
      ids.add(per);
    }
    return ids;
  }

  String? _filterNameForId(String? id) {
    if (id == null || id.isEmpty || id == 'none') return null;
    final filters = _createService.getFilters();
    for (final f in filters) {
      if (f.id == id) return f.name;
    }
    return null;
  }

  List<double> _buildReelColorMatrixForMedia(app_models.MediaItem media) {
    final adjustments = _effectiveAdjustments(media);
    final lux = ((adjustments['lux'] ?? 0).clamp(0, 100) / 100.0);
    final luxBC = 1.0 + (lux * 0.35);
    final luxS = 1.0 + (lux * 0.2);
    final b = ((adjustments['brightness'] ?? 0) / 100.0 + 1.0) * luxBC;
    final c = ((adjustments['contrast'] ?? 0) / 100.0 + 1.0) * luxBC;
    final s = ((adjustments['saturate'] ?? 0) / 100.0 + 1.0) * luxS;
    final opacity = 1.0 - (adjustments['opacity'] ?? 0) / 100.0;
    final sepiaAmount =
        ((adjustments['sepia'] ?? 0).abs().clamp(0, 100) / 100.0) * 0.35;

    final identity = _buildAdjustmentMatrix(
      brightness: 1.0,
      contrast: 1.0,
      saturation: 1.0,
    );
    var preset = identity;
    for (final id in _effectiveFilterIds(media).where((e) => e != 'none')) {
      preset = _combineColorMatrices(_reelFilterMatrixFor(id), preset);
    }
    final sepiaMatrix = (sepiaAmount <= 0)
        ? _buildAdjustmentMatrix(brightness: 1.0, contrast: 1.0, saturation: 1.0)
        : _buildSepiaMatrix(
            amount: sepiaAmount,
            brightness: 1.0,
            contrast: 1.0,
            saturation: 1.0,
          );
    final adjust = _buildAdjustmentMatrix(brightness: b, contrast: c, saturation: s);
    final combined = _combineColorMatrices(adjust, _combineColorMatrices(sepiaMatrix, preset));

    // Apply opacity as final alpha multiplier (via color matrix A column)
    combined[18] = 1.0;
    combined[19] = 0.0;
    combined[15] = 0.0;
    combined[16] = 0.0;
    combined[17] = 0.0;

    if (opacity < 1.0) {
      combined[15] = 0.0;
      combined[16] = 0.0;
      combined[17] = 0.0;
      combined[18] = opacity.clamp(0.0, 1.0);
      combined[19] = 0.0;
    }
    return combined;
  }

  List<ReelTextOverlay> _buildReelTextOverlaysFor(app_models.MediaItem media) {
    final preview = _previewSize() ?? const Size(1080, 1920);
    final scaleFactor = 1080 / preview.width;
    return _effectiveTextOverlays(media).map((t) {
      final norm = _normalizePreviewPosition(t.position);
      return ReelTextOverlay(
        text: t.text,
        style: t.style,
        alignment: t.alignment,
        textColor: t.textColor,
        backgroundStyle: t.backgroundStyle,
        normalizedPosition: norm,
        scale: t.scale,
        rotation: t.rotation,
        fontSize: t.fontSize * scaleFactor,
      );
    }).toList();
  }

  List<ReelStickerOverlay> _buildReelStickerOverlaysFor(app_models.MediaItem media) {
    final preview = _previewSize() ?? const Size(1080, 1920);
    final scaleFactor = 1080 / preview.width;
    return _effectiveStickerOverlays(media).map((s) {
      final norm = _normalizePreviewPosition(s.position);
      return ReelStickerOverlay(
        imagePath: s.imageFile.path,
        shape: s.shape,
        normalizedPosition: norm,
        scale: s.scale,
        rotation: s.rotation,
        baseSize: 120 * scaleFactor,
      );
    }).toList();
  }

  void _cycleReelFilter(int direction) {
    final filters = _createService.getFilters();
    final ids = <String>['none', ...filters.map((f) => f.id)];
    if (ids.isEmpty) return;
    final currentId = _selectedFilter ?? 'none';
    var index = ids.indexOf(currentId);
    if (index < 0) index = 0;
    var next = index + direction;
    if (next < 0) next = ids.length - 1;
    if (next >= ids.length) next = 0;
    final nextId = ids[next];
    setState(() {
      _selectedFilter = nextId;
      _selectedFilterName = _filterNameForId(nextId);
    });
  }

  Map<String, int> _mergeAdjustments(
    Map<String, int> base,
    Map<String, int> delta,
  ) {
    int clampValue(String key, int value) {
      if (key == 'lux' || key == 'opacity' || key == 'vignette') {
        return value.clamp(0, 100);
      }
      return value.clamp(-100, 100);
    }

    final out = <String, int>{};
    for (final entry in base.entries) {
      final next = entry.value + (delta[entry.key] ?? 0);
      out[entry.key] = clampValue(entry.key, next);
    }
    for (final entry in delta.entries) {
      out[entry.key] ??= clampValue(entry.key, entry.value);
    }
    return out;
  }

  bool _isVideoMedia(app_models.MediaItem media) {
    if (media.type == app_models.MediaType.video) return true;
    final path = media.filePath;
    if (path == null) return false;
    final lower = path.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m4v') ||
        lower.endsWith('.3gp') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.mkv');
  }

  bool get _isCarouselVideo =>
      _mediaList.length > 1 && _isVideoMedia(_currentMedia);

  void _openVideoEditorForCurrent() {
    if (_mediaList.length > 1) {
      _openPerVideoEditor(_currentMedia, _currentIndex);
    } else {
      _openVideoEditor();
    }
  }

  Duration? _trimStartFor(app_models.MediaItem media) {
    if (_mediaList.length > 1) return _mediaTrimStart[media.id];
    return _trimStart;
  }

  Duration? _trimEndFor(app_models.MediaItem media) {
    if (_mediaList.length > 1) return _mediaTrimEnd[media.id];
    return _trimEnd;
  }

  void _setTrimFor(app_models.MediaItem media, Duration? start, Duration? end) {
    if (_mediaList.length > 1) {
      _mediaTrimStart[media.id] = start;
      _mediaTrimEnd[media.id] = end;
    } else {
      _trimStart = start;
      _trimEnd = end;
    }
  }

  String? _coverPathFor(app_models.MediaItem media) {
    return _mediaVideoCoverPath[media.id];
  }

  Widget _buildVideoThumbnail(
    String filePath, {
    String? coverPath,
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
  }) {
    if (coverPath != null) {
      final coverFile = File(coverPath);
      if (coverFile.existsSync()) {
        return Image.file(
          coverFile,
          fit: fit,
          width: width,
          height: height,
        );
      }
    }
    return FutureBuilder<Uint8List?>(
      future: VideoThumbnail.thumbnailData(
        video: filePath,
        imageFormat: ImageFormat.JPEG,
        quality: 70,
      ),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done || snap.data == null) {
          return Container(
            width: width,
            height: height,
            color: Colors.black,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }
        return Image.memory(
          snap.data!,
          fit: fit,
          width: width,
          height: height,
        );
      },
    );
  }

  List<_PreviewTextOverlay> _effectiveTextOverlays(app_models.MediaItem media) {
    return _mediaTextOverlays[media.id] ?? const [];
  }

  List<OverlaySticker> _effectiveStickerOverlays(app_models.MediaItem media) {
    return _mediaStickerOverlays[media.id] ?? const [];
  }

  @override
  void initState() {
    super.initState();
    _mediaList = widget.mediaList != null && widget.mediaList!.isNotEmpty
        ? List<app_models.MediaItem>.from(widget.mediaList!)
        : [widget.media];
    _currentIndex = 0;
    _currentMedia = _mediaList[_currentIndex];
    if (_mediaList.length > 1) {
      _postPageController = PageController();
    }
    _selectedFilter = widget.selectedFilter;
    _primeTextEditorBackground();
    if (_selectedFilter != null) {
      final filters = _createService.getFilters();
      final match = filters.where((f) => f.id == _selectedFilter).toList();
      if (match.isNotEmpty) {
        _selectedFilterName = match.first.name;
      }
    }
    if (_isVideoMedia(_currentMedia) && _currentMedia.filePath != null) {
      final controller = VideoPlayerController.file(File(_currentMedia.filePath!));
      _videoController = controller;
      _videoInit = controller.initialize().then((_) {
        if (!mounted) return;
        controller.setLooping(true);
        controller.addListener(_handlePreviewVideoTick);
        if (widget.isPostFlow) {
          _maybeInitPostAspect(controller.value.aspectRatio);
        }
        controller.play();
        setState(() => _isPlaying = true);
      });
    } else if (!_isVideoMedia(_currentMedia) && _currentMedia.filePath != null) {
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
          _imageKey = ValueKey('img_${w}_${h}');
          if (widget.isPostFlow) {
            _maybeInitPostAspect(_imageAspectRatio ?? 1.0);
          }
        });
      });
      stream.addListener(_imageStreamListener!);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _postPageController?.dispose();
    _stickerHoldTimer?.cancel();
    _textHoldTimer?.cancel();
    _transformController.dispose();
    _videoController?.removeListener(_handlePreviewVideoTick);
    _videoController?.dispose();
    final stream = _imageStream;
    final listener = _imageStreamListener;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    super.dispose();
  }

  Future<void> _setCurrentMedia(app_models.MediaItem media, int index) async {
    if (_currentMedia.id == media.id && _currentIndex == index) return;
    _videoController?.removeListener(_handlePreviewVideoTick);
    await _videoController?.dispose();
    _videoController = null;
    _videoInit = null;
    _isPlaying = false;

    final stream = _imageStream;
    final listener = _imageStreamListener;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    _imageStream = null;
    _imageStreamListener = null;
    _imageAspectRatio = null;
    _imagePixelSize = null;

    setState(() {
      _currentIndex = index;
      _currentMedia = media;
      _cachedTextEditorBackground = null;
    });
    _primeTextEditorBackground();

    if (_isVideoMedia(media) && media.filePath != null) {
      final controller = VideoPlayerController.file(File(media.filePath!));
      _videoController = controller;
      _videoInit = controller.initialize().then((_) {
        if (!mounted) return;
        controller.setLooping(true);
        controller.addListener(_handlePreviewVideoTick);
        controller.play();
        setState(() => _isPlaying = true);
      });
    } else if (!_isVideoMedia(media) && media.filePath != null) {
      final provider = FileImage(File(media.filePath!));
      final stream2 = provider.resolve(const ImageConfiguration());
      _imageStream = stream2;
      _imageStreamListener = ImageStreamListener((info, _) {
        final w = info.image.width.toDouble();
        final h = info.image.height.toDouble();
        if (!mounted || h == 0) return;
        setState(() {
          _imageAspectRatio = w / h;
          _imagePixelSize = Size(w, h);
          _imageKey = ValueKey('img_${w}_${h}');
        });
      });
      stream2.addListener(_imageStreamListener!);
    }
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
    final start = _trimStartFor(_currentMedia);
    final end = _trimEndFor(_currentMedia);
    if (start != null && end != null && end > start) {
      if (pos < start) {
        controller.seekTo(start);
      }
      if (pos >= end) {
        controller.seekTo(start);
        if (!controller.value.isPlaying) {
          controller.play();
        }
      }
      return;
    }
    if (duration != Duration.zero && pos >= duration) {
      controller.seekTo(Duration.zero);
      if (!controller.value.isPlaying) {
        controller.play();
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
        _setTrimFor(_currentMedia, result.trimStart, result.trimEnd);
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
        controller.setLooping(true);
        controller.addListener(_handlePreviewVideoTick);
        controller.play();
        setState(() => _isPlaying = true);
      });
        setState(() {}); // Trigger immediate rebuild to show loading for the NEW future
      } else {
      // Seek preview to the new trim start and resume playback
      final controller = _videoController;
      if (controller != null && controller.value.isInitialized) {
        final seekTo = _trimStartFor(_currentMedia);
        if (seekTo != null) {
          await controller.seekTo(seekTo);
        }
        controller.play();
        setState(() => _isPlaying = true);
      }
      }
    } else {
      // User cancelled – resume playback
      if (_videoController?.value.isInitialized == true) {
        await _videoController?.play();
      }
      setState(() => _isPlaying = true);
    }
  }

  Future<void> _openFilterPicker() async {
    if (_currentMedia.filePath == null) return;
    if (_isVideoMedia(_currentMedia)) return;
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

  Future<void> _openPerImageEditor(app_models.MediaItem media) async {
    if (media.filePath == null) return;
    final result = await Navigator.of(context).push<_PerImageEditResult>(
      MaterialPageRoute(
        builder: (_) => _PerImageEditPage(
          media: media,
          frameAspect: _postFrameAspect(),
          initialFilter: _mediaFilters[media.id] ?? 'none',
          initialAdjustments:
              Map<String, int>.from(_mediaAdjustments[media.id] ?? {}),
          globalFilter: _selectedFilter,
          globalAdjustments: Map<String, int>.from(_imageAdjustments),
          initialTextOverlays:
              List<_PreviewTextOverlay>.from(_effectiveTextOverlays(media)),
          initialStickerOverlays:
              List<OverlaySticker>.from(_effectiveStickerOverlays(media)),
          filters: _createService.getFilters(),
          filterMatrixFor: _reelFilterMatrixFor,
          buildAdjustmentMatrix: _buildAdjustmentMatrix,
          buildSepiaMatrix: _buildSepiaMatrix,
        ),
      ),
    );
    if (result == null) return;
    setState(() {
      _mediaFilters[media.id] = result.filterId;
      _mediaAdjustments[media.id] = Map<String, int>.from(result.adjustments);
      _mediaTextOverlays[media.id] =
          List<_PreviewTextOverlay>.from(result.textOverlays);
      _mediaStickerOverlays[media.id] =
          List<OverlaySticker>.from(result.stickerOverlays);
      _cachedTextEditorBackground = null;
    });
  }

  Future<void> _openPerVideoEditor(
    app_models.MediaItem media,
    int index,
  ) async {
    if (media.filePath == null) return;
    final result = await Navigator.of(context).push<_PerVideoEditResult>(
      MaterialPageRoute(
        builder: (_) => _PerVideoEditPage(
          media: media,
          frameAspect: _postFrameAspect(),
          initialFilter: _mediaFilters[media.id] ?? 'none',
          globalFilter: _selectedFilter,
          initialTrimStart: _trimStartFor(media),
          initialTrimEnd: _trimEndFor(media),
          initialCoverPath: _coverPathFor(media),
          filters: _createService.getFilters(),
          filterMatrixFor: _reelFilterMatrixFor,
        ),
      ),
    );
    if (!mounted || result == null) return;

    setState(() {
      _mediaFilters[media.id] = result.filterId;
      _setTrimFor(media, result.trimStart, result.trimEnd);
      if (result.coverPath != null && result.coverPath!.isNotEmpty) {
        _mediaVideoCoverPath[media.id] = result.coverPath;
        _mediaList[index] = app_models.MediaItem(
          id: media.id,
          type: media.type,
          filePath: media.filePath,
          thumbnailPath: result.coverPath,
          duration: media.duration,
          createdAt: media.createdAt,
        );
        if (_currentIndex == index) {
          _currentMedia = _mediaList[index];
        }
      }
    });

    if (result.outputPath != null && result.outputPath!.isNotEmpty) {
      final updated = app_models.MediaItem(
        id: media.id,
        type: media.type,
        filePath: result.outputPath,
        thumbnailPath: result.coverPath ?? media.thumbnailPath,
        duration: media.duration,
        createdAt: media.createdAt,
      );
      setState(() {
        _mediaList[index] = updated;
        if (_currentIndex == index) {
          _currentMedia = updated;
        }
      });
      if (_currentIndex == index && _isVideoMedia(updated)) {
        _videoController?.removeListener(_handlePreviewVideoTick);
        await _videoController?.dispose();
        _videoController = null;
        final controller = VideoPlayerController.file(File(updated.filePath!));
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
                        const Expanded(child: SizedBox()),
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

  Widget _buildPostZoomableImagePreview(
    BoxConstraints viewport, {
    required bool enableGesture,
  }) {
    return _buildPostZoomableImagePreviewFor(
      _currentMedia,
      viewport,
      enableGesture: enableGesture,
    );
  }

  Widget _buildPostZoomableImagePreviewFor(
    app_models.MediaItem media,
    BoxConstraints viewport, {
    required bool enableGesture,
  }) {
    if (media.filePath == null) {
      return const Icon(Icons.image, size: 100, color: Colors.white54);
    }
    if (_isVideoMedia(media)) {
      final thumb = _applySelectedFilter(
        _buildVideoThumbnail(
          media.filePath!,
          coverPath: _coverPathFor(media),
          fit: BoxFit.cover,
          width: viewport.maxWidth,
          height: viewport.maxHeight,
        ),
        filterIds: _effectiveFilterIds(media),
      );
      return SizedBox(
        width: viewport.maxWidth,
        height: viewport.maxHeight,
        child: thumb,
      );
    }
    _postViewportSize = viewport.biggest;

    final imageAspect = _imageAspectRatio ?? 1.0;
    final viewportW = viewport.maxWidth;
    final viewportH = viewport.maxHeight;
    final viewportAspect = viewportH > 0 ? viewportW / viewportH : 1.0;

    if (viewportW <= 0 || viewportH <= 0) {
      return const SizedBox.shrink();
    }

    final imgW = (_imagePixelSize?.width ?? viewportW).clamp(1.0, double.infinity);
    final imgH = (_imagePixelSize?.height ?? viewportH).clamp(1.0, double.infinity);

    double containScale;
    if (imageAspect > viewportAspect) {
      containScale = viewportW / imgW;
    } else {
      containScale = viewportH / imgH;
    }

    double coverScale;
    if (imageAspect > viewportAspect) {
      coverScale = viewportH / imgH;
    } else {
      coverScale = viewportW / imgW;
    }
    if (!coverScale.isFinite || coverScale <= 0) {
      coverScale = 1.0;
    }
    if (!containScale.isFinite || containScale <= 0) {
      containScale = 1.0;
    }

    final imagePxW = imgW;
    final imagePxH = imgH;

    if (!enableGesture) {
      return SizedBox(
        width: viewportW,
        height: viewportH,
        child: _applyImageAdjustments(
          _applySelectedFilter(
            Image.file(
              File(media.filePath!),
              fit: BoxFit.cover,
              width: viewportW,
              height: viewportH,
            ),
            filterIds: _effectiveFilterIds(media),
          ),
          adjustments: _effectiveAdjustments(media),
        ),
      );
    }

    return _ZoomPanImageView(
      key: _zoomPanKey,
      imageKey: _imageKey,
      filePath: media.filePath!,
      viewportW: viewportW,
      viewportH: viewportH,
      imagePxW: imagePxW,
      imagePxH: imagePxH,
      containScale: containScale,
      coverScale: coverScale,
      maxScale: coverScale * 6.0,
      transformController: _transformController,
      filterIds: _effectiveFilterIds(media),
      adjustments: _effectiveAdjustments(media),
      applyFilter: _applySelectedFilter,
      applyAdjustments: _applyImageAdjustments,
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
    required List<String> filterIds,
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

    final identity = _buildAdjustmentMatrix(
      brightness: 1.0,
      contrast: 1.0,
      saturation: 1.0,
    );
    var preset = identity;
    for (final id in filterIds.where((e) => e != 'none')) {
      preset = _combineColorMatrices(_reelFilterMatrixFor(id), preset);
    }
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
    if (widget.isPostFlow && isVideo) {
      final cover = _coverPathFor(_currentMedia);
      if (cover != null && cover.isNotEmpty) {
        nextMedia = app_models.MediaItem(
          id: _currentMedia.id,
          type: _currentMedia.type,
          filePath: _currentMedia.filePath,
          thumbnailPath: cover,
          duration: _currentMedia.duration,
          createdAt: _currentMedia.createdAt,
        );
      }
    }
    if (!usedComposite && !isVideo && filePath != null) {
      final imagePx = _imagePixelSize ?? await _readImagePixelSizeFromFile(filePath);
      if (imagePx != null) {
        Rect? cropRect;
        final zoomState = _zoomPanState;
        if (zoomState != null) {
          final s = zoomState._scale;
          final o = zoomState._offset;
          final vW =
              _postViewportSize?.width ?? MediaQuery.of(context).size.width;
          final vH = _postViewportSize?.height ?? vW;

          final left = (-o.dx / s).clamp(0.0, imagePx.width);
          final top = (-o.dy / s).clamp(0.0, imagePx.height);
          final right = ((vW - o.dx) / s).clamp(0.0, imagePx.width);
          final bottom = ((vH - o.dy) / s).clamp(0.0, imagePx.height);

          cropRect = Rect.fromLTRB(left, top, right, bottom);
        }

        if (cropRect != null) {
          nextAspect =
              _clampInstagramPostAspect(cropRect.width / cropRect.height);
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
      final hasFilter = _effectiveFilterIds(nextMedia).isNotEmpty;
      final hasAdjustments =
          _effectiveAdjustments(nextMedia).values.any((v) => v != 0);
      if (hasFilter || hasAdjustments) {
        final processedPath = await _writeProcessedImageFile(
          sourcePath: nextMedia.filePath!,
          filterIds: _effectiveFilterIds(nextMedia),
          adjustments: _effectiveAdjustments(nextMedia),
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
    final processedList =
        widget.isPostFlow ? await _buildProcessedMediaList() : null;
    final globalFilterName = _filterNameForId(_selectedFilter);
    final perMediaFilterNames = <String, String>{};
    final listForFilters = _mediaList;
    final perMediaAdjustments = <String, Map<String, int>>{};
    for (final media in listForFilters) {
      final perId = _mediaFilters[media.id];
      final name = _filterNameForId(perId);
      if (name != null && name.isNotEmpty) {
        perMediaFilterNames[media.id] = name;
      }
      perMediaAdjustments[media.id] = Map<String, int>.from(
        _effectiveAdjustments(media),
      );
      debugPrint(
        '[CreateEditPreview] media id=${media.id} type=${media.type} '
        'filterId=$perId filterName=$name '
        'adjustments=${perMediaAdjustments[media.id]}',
      );
    }
    debugPrint(
      '[CreateEditPreview] globalFilterId=$_selectedFilter '
      'globalFilterName=$globalFilterName',
    );
    if (!widget.isPostFlow && _mediaList.length > 1) {
      final renderer = ReelTimelineRenderer(
        outputSize: const Size(1080, 1920),
      );
      final clips = _mediaList.map<ReelClip>((m) {
        final isVideo = _isVideoMedia(m);
        return ReelClip(
          id: m.id,
          type: isVideo ? ReelClipType.video : ReelClipType.image,
          path: m.filePath ?? '',
          duration: isVideo
              ? (m.duration ?? const Duration(seconds: 1))
              : const Duration(seconds: 3),
          trimStart: _trimStartFor(m),
          trimEnd: _trimEndFor(m),
          colorMatrix: _buildReelColorMatrixForMedia(m),
          textOverlays: _buildReelTextOverlaysFor(m),
          stickerOverlays: _buildReelStickerOverlaysFor(m),
        );
      }).where((c) => c.path.isNotEmpty).toList();
      final stitchedPath = await renderer.renderTimeline(clips);
      if (stitchedPath != null && stitchedPath.isNotEmpty) {
        nextMedia = app_models.MediaItem(
          id: 'timeline_${DateTime.now().millisecondsSinceEpoch}',
          type: app_models.MediaType.video,
          filePath: stitchedPath,
          createdAt: DateTime.now(),
          duration: clips.fold<Duration>(
            Duration.zero,
            (sum, c) => sum + c.duration,
          ),
        );
      }
    }

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => widget.isPostFlow
            ? CreatePostScreen(
                initialMedia: nextMedia,
                initialMediaList: processedList,
                initialAspect: nextAspect,
                initialFilterName: globalFilterName,
                initialAdjustments: null,
                initialMediaFilters:
                    perMediaFilterNames.isEmpty ? null : perMediaFilterNames,
                initialMediaAdjustments:
                    perMediaAdjustments.isEmpty ? null : perMediaAdjustments,
                initialMediaTrims: () {
                  final out = <String, Map<String, int>>{};
                  for (final media in listForFilters) {
                    final start = _trimStartFor(media);
                    final end = _trimEndFor(media);
                    if (start != null || end != null) {
                      out[media.id] = {
                        if (start != null)
                          'start_ms': start.inMilliseconds,
                        if (end != null) 'end_ms': end.inMilliseconds,
                      };
                    }
                  }
                  return out.isEmpty ? null : out;
                }(),
              )
            : CreateReelDetailsScreen(
                media: nextMedia,
                trimStart:
                    nextMedia.id == _currentMedia.id ? _trimStartFor(_currentMedia) : null,
                trimEnd:
                    nextMedia.id == _currentMedia.id ? _trimEndFor(_currentMedia) : null,
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

  Future<List<app_models.MediaItem>?> _buildProcessedMediaList() async {
    final list = _mediaList;
    if (list.length <= 1) return null;

    final prevIndex = _currentIndex;
    final prevMedia = _currentMedia;
    final processed = <app_models.MediaItem>[];

    for (int i = 0; i < list.length; i++) {
      final media = list[i];
      if (media.type == app_models.MediaType.video || media.filePath == null) {
        final cover = _coverPathFor(media);
        if (cover != null && cover.isNotEmpty) {
          processed.add(
            app_models.MediaItem(
              id: media.id,
              type: media.type,
              filePath: media.filePath,
              thumbnailPath: cover,
              duration: media.duration,
              createdAt: media.createdAt,
            ),
          );
        } else {
          processed.add(media);
        }
        continue;
      }

      final hasOverlays = _textOverlays.isNotEmpty ||
          _stickerOverlays.isNotEmpty ||
          _effectiveTextOverlays(media).isNotEmpty ||
          _effectiveStickerOverlays(media).isNotEmpty;
      final hasFilter = _effectiveFilterIds(media).isNotEmpty;
      final hasAdjustments =
          _effectiveAdjustments(media).values.any((v) => v != 0);

      String? outPath;
      if (hasOverlays) {
        setState(() {
          _currentIndex = i;
          _currentMedia = media;
        });
        _postPageController?.jumpToPage(i);
        await WidgetsBinding.instance.endOfFrame;
        outPath = await _exportPreviewCompositeToFile();
      }

      if ((outPath == null || outPath.isEmpty) &&
          (hasFilter || hasAdjustments)) {
        outPath = await _writeProcessedImageFile(
          sourcePath: media.filePath!,
          filterIds: _effectiveFilterIds(media),
          adjustments: _effectiveAdjustments(media),
        );
      }

      if (outPath != null && outPath.isNotEmpty) {
        processed.add(
          app_models.MediaItem(
            id: media.id,
            type: media.type,
            filePath: outPath,
            thumbnailPath: media.thumbnailPath,
            duration: media.duration,
            createdAt: media.createdAt,
          ),
        );
      } else {
        processed.add(media);
      }
    }

    setState(() {
      _currentIndex = prevIndex;
      _currentMedia = prevMedia;
    });
    _postPageController?.jumpToPage(prevIndex);
    return processed;
  }

  void _handleTextScaleStart(ScaleStartDetails details) {
    if (_textOverlays.isEmpty) return;
    final activeIndex = _activeTextIndex ?? (_textOverlays.length - 1);
    _bringTextToFront(activeIndex);
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
    _stickerLastLocalFocalPoint = _toPreviewLocal(details.focalPoint);
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
    if (!mounted) {
      return const AssetImage('assets/images/dashboard_sample.png');
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
    if (_isVideoMedia(_currentMedia)) {
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
    if (!mounted) return null;
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

  Future<void> _openAddClips() async {
    final ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Allow photo access to add clips.'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: PhotoManager.openSetting,
          ),
        ),
      );
      return;
    }
    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.all,
      filterOption: FilterOptionGroup(
        orders: [const OrderOption(type: OrderOptionType.createDate, asc: false)],
      ),
    );
    if (paths.isEmpty || !mounted) return;
    final selected = await showModalBottomSheet<List<AssetEntity>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (ctx) => _ClipPickerSheet(
        assetsPath: paths.first,
        isLimited: ps.isLimited,
      ),
    );
    if (selected == null || selected.isEmpty || !mounted) return;

    final existingIds = _mediaList.map((m) => m.id).toSet();
    final newMedia = <app_models.MediaItem>[];
    for (final asset in selected) {
      if (existingIds.contains(asset.id)) continue;
      final file = await asset.originFile;
      if (file == null) continue;
      final pathLower = file.path.toLowerCase();
      final isVideo = asset.type == AssetType.video ||
          (asset.mimeType?.toLowerCase().startsWith('video/') ?? false) ||
          pathLower.endsWith('.mp4') ||
          pathLower.endsWith('.mov') ||
          pathLower.endsWith('.m4v') ||
          pathLower.endsWith('.3gp') ||
          pathLower.endsWith('.webm') ||
          pathLower.endsWith('.mkv');
      final media = app_models.MediaItem(
        id: asset.id,
        type: isVideo ? app_models.MediaType.video : app_models.MediaType.image,
        filePath: file.path,
        createdAt: asset.createDateTime,
        duration: isVideo ? Duration(seconds: asset.duration) : null,
      );
      if (isVideo && !_createService.validateMedia(media)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Video must be 60 seconds or less')),
          );
        }
        continue;
      }
      newMedia.add(media);
    }
    if (newMedia.isEmpty) return;

    final startIndex = _mediaList.length;
    setState(() {
      _mediaList.addAll(newMedia);
      if (_mediaList.length > 1 && _postPageController == null) {
        _postPageController = PageController(initialPage: _currentIndex);
      }
      if (startIndex < _mediaList.length) {
        _currentIndex = startIndex;
        _currentMedia = _mediaList[_currentIndex];
      }
    });
    if (startIndex < _mediaList.length) {
      await _setCurrentMedia(_mediaList[startIndex], startIndex);
    }
    if (_postPageController != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _postPageController?.jumpToPage(_currentIndex);
      });
    }
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
    const values = OverlayShape.values;
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

  List<Widget> _buildPerImageOverlayWidgets(app_models.MediaItem media) {
    final perText = _effectiveTextOverlays(media);
    final perStickers = _effectiveStickerOverlays(media);
    final widgets = <Widget>[];

    for (int i = 0; i < perText.length; i++) {
      final overlay = perText[i];
      widgets.add(
        Positioned(
          key: ValueKey('per_text_${media.id}_$i'),
          left: overlay.position.dx,
          top: overlay.position.dy,
          child: Transform.rotate(
            angle: overlay.rotation,
            child: Transform.scale(
              scale: overlay.scale,
              child: _buildOverlayVisual(overlay, false),
            ),
          ),
        ),
      );
    }

    for (int i = 0; i < perStickers.length; i++) {
      final s = perStickers[i];
      widgets.add(
        Positioned(
          key: ValueKey('per_sticker_${media.id}_${s.id}'),
          left: s.position.dx,
          top: s.position.dy,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..rotateZ(s.rotation)
              ..scaleByVector3(
                vector_math.Vector3.all(s.scale),
              ),
            child: OverlayStickerWidget(
              sticker: s,
              isActive: false,
              onDelete: () {},
            ),
          ),
        ),
      );
    }
    return widgets;
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
                        padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
                        child: Row(
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => Navigator.of(context).pop(),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2E2E2E),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(Icons.close, color: Colors.white, size: 22),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
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
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        if (_mediaList.length > 1)
                                          PageView.builder(
                                            controller: _postPageController,
                                            itemCount: _mediaList.length,
                                            onPageChanged: (i) {
                                              _setCurrentMedia(_mediaList[i], i);
                                            },
                                            itemBuilder: (context, i) {
                                              final item = _mediaList[i];
                                              final isActive = i == _currentIndex;
                                        if (_isVideoMedia(item)) {
                                          if (isActive) {
                                            return GestureDetector(
                                              onTap: () => _openPerVideoEditor(
                                                item,
                                                i,
                                              ),
                                              child: _buildVideoPreview(),
                                            );
                                          }
                                                if (item.filePath == null) {
                                                  return Container(color: Colors.black);
                                                }
                                                final thumb = _applySelectedFilter(
                                                  _buildVideoThumbnail(
                                                    item.filePath!,
                                                    coverPath: _coverPathFor(item),
                                                    fit: BoxFit.cover,
                                                  ),
                                                  filterIds: _effectiveFilterIds(item),
                                                );
                                                return GestureDetector(
                                                  onTap: () {
                                                    if (!isActive) {
                                                      _setCurrentMedia(item, i);
                                                    }
                                                    _openPerVideoEditor(item, i);
                                                  },
                                                  child: thumb,
                                                );
                                              }
                                                return GestureDetector(
                                                  onTap: () {
                                                    if (!isActive) {
                                                      _setCurrentMedia(item, i);
                                                    }
                                                    _openPerImageEditor(item);
                                                  },
                                                  child: LayoutBuilder(
                                                    builder: (context, viewport) {
                                                      return _buildPostZoomableImagePreviewFor(
                                                        item,
                                                        viewport,
                                                        enableGesture: isActive,
                                                      );
                                                    },
                                                  ),
                                                );
                                            },
                                          )
                                        else if (_isVideoMedia(_currentMedia))
                                          GestureDetector(
                                            onTap: _openVideoEditorForCurrent,
                                            child: _buildVideoPreview(),
                                          )
                                        else
                                          LayoutBuilder(
                                            builder: (context, viewport) {
                                              return _buildPostZoomableImagePreview(
                                                viewport,
                                                enableGesture: true,
                                              );
                                            },
                                          ),
                                        if (!_hideTextOverlaysForCapture)
                                          ..._buildPerImageOverlayWidgets(
                                              _currentMedia),
                                        if (!_hideTextOverlaysForCapture)
                                          ..._buildSortedLayers().map((layer) {
                                            if (layer['type'] == 'text') {
                                              final index =
                                                  layer['index'] as int;
                                              if (index >=
                                                  _textOverlays.length) {
                                                return const SizedBox.shrink();
                                              }
                                              final overlay =
                                                  _textOverlays[index];
                                              final isActive =
                                                  _activeTextIndex == index;
                                              return Positioned(
                                                key: ValueKey('text_$index'),
                                                left: overlay.position.dx,
                                                top: overlay.position.dy,
                                                child: GestureDetector(
                                                  onTapDown: (_) =>
                                                      _startTextHold(index),
                                                  onTapUp: (_) =>
                                                      _cancelTextHold(),
                                                  onTapCancel: _cancelTextHold,
                                                  onTap: () {
                                                    if (_suppressTextTap) {
                                                      _suppressTextTap = false;
                                                      return;
                                                    }
                                                    setState(() =>
                                                        _bringTextToFront(
                                                            index));
                                                    _openPreviewTextEditor(
                                                        index: index);
                                                  },
                                                  onScaleStart: (d) {
                                                    setState(() =>
                                                        _bringTextToFront(
                                                            index));
                                                    _cancelTextHold();
                                                    _handleTextScaleStart(d);
                                                  },
                                                  onScaleUpdate:
                                                      _handleTextScaleUpdate,
                                                  onScaleEnd: (_) =>
                                                      _handleTextScaleEnd(),
                                                  child: AnimatedOpacity(
                                                    duration: const Duration(
                                                        milliseconds: 180),
                                                    opacity:
                                                        _deletingTextIndexes
                                                                .contains(
                                                                    index)
                                                            ? 0.0
                                                            : 1.0,
                                                    child: AnimatedScale(
                                                      duration:
                                                          const Duration(
                                                              milliseconds:
                                                                  180),
                                                      scale:
                                                          _deletingTextIndexes
                                                                  .contains(
                                                                      index)
                                                              ? 0.0
                                                              : 1.0,
                                                      child: Transform.rotate(
                                                        angle: overlay.rotation,
                                                        child: Transform.scale(
                                                          scale: overlay.scale *
                                                              (_textDeleteScale[
                                                                      index] ??
                                                                  1.0),
                                                          child:
                                                              _buildOverlayVisual(
                                                                  overlay,
                                                                  isActive),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }
                                            final i = layer['index'] as int;
                                            if (i >= _stickerOverlays.length) {
                                              return const SizedBox.shrink();
                                            }
                                            final s = _stickerOverlays[i];
                                            final isActive =
                                                _activeStickerIndex == i;
                                            return Positioned(
                                              key: ValueKey('sticker_${s.id}'),
                                              left: s.position.dx,
                                              top: s.position.dy,
                                              child: GestureDetector(
                                                onTapDown: (_) =>
                                                    _startStickerHold(i),
                                                onTapUp: (_) =>
                                                    _cancelStickerHold(),
                                                onTapCancel: () =>
                                                    _cancelStickerHold(),
                                                onTap: () {
                                                  if (_suppressStickerTap) {
                                                    _suppressStickerTap = false;
                                                    return;
                                                  }
                                                  setState(() {
                                                    if (_activeStickerIndex ==
                                                        i) {
                                                      _stickerOverlays[i] =
                                                          s.copyWith(
                                                        shape:
                                                            _nextShape(s.shape),
                                                      );
                                                    }
                                                    _bringStickerToFront(i);
                                                  });
                                                },
                                                onScaleStart: (d) {
                                                  setState(() =>
                                                      _bringStickerToFront(i));
                                                  _cancelStickerHold();
                                                  _handleStickerScaleStart(d);
                                                },
                                                onScaleUpdate: (d) =>
                                                    _handleStickerScaleUpdate(
                                                        d, context),
                                                onScaleEnd: (_) =>
                                                    _handleStickerScaleEnd(
                                                        context),
                                                child: AnimatedOpacity(
                                                  duration: const Duration(
                                                      milliseconds: 180),
                                                  opacity:
                                                      _deletingStickerIds
                                                              .contains(s.id)
                                                          ? 0.0
                                                          : 1.0,
                                                  child: AnimatedScale(
                                                    duration: const Duration(
                                                        milliseconds: 180),
                                                    scale:
                                                        _deletingStickerIds
                                                                .contains(
                                                                    s.id)
                                                            ? 0.0
                                                            : 1.0,
                                                    child: Transform(
                                                      alignment:
                                                          Alignment.center,
                                                      transform:
                                                          Matrix4.identity()
                                                            ..rotateZ(
                                                                s.rotation)
                                                            ..scaleByVector3(
                                                              vector_math
                                                                  .Vector3.all(
                                                                s.scale *
                                                                    (_stickerDeleteScale[
                                                                            s.id] ??
                                                                        1.0),
                                                              ),
                                                            ),
                                                      child:
                                                          OverlayStickerWidget(
                                                        sticker: s,
                                                        isActive: isActive,
                                                        onDelete: () {},
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          }),
                                        if (_isStickerDeleteMode ||
                                            _isTextDeleteMode)
                                          Positioned.fill(
                                            child: GestureDetector(
                                              behavior: HitTestBehavior
                                                  .translucent,
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
                                              opacity: (_isStickerDeleteMode ||
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
                                    enabled: !_isCarouselVideo,
                                  ),
                                  const SizedBox(width: 10),
                                  _buildPostBottomPill(
                                    icon: Icons.layers_outlined,
                                    label: 'Overlay',
                                    onTap: _openOverlayPicker,
                                    enabled: !_isCarouselVideo,
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
                                    enabled: !_isCarouselVideo,
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
              if (_showInlineImageEditor)
                Positioned.fill(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _showInlineImageEditor = false;
                            });
                          },
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          width: double.infinity,
                          height:
                              MediaQuery.of(context).size.height * 0.72,
                          decoration: const BoxDecoration(
                            color: Color(0xFF0B0B0E),
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(20),
                            ),
                          ),
                          child: Column(
                            children: [
                              Align(
                                alignment: Alignment.topLeft,
                                child: Padding(
                                  padding:
                                      const EdgeInsets.only(left: 12, top: 8),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () {
                                      setState(() {
                                        _showInlineImageEditor = false;
                                      });
                                    },
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: Colors.white10,
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: const Icon(Icons.close,
                                          color: Colors.white, size: 18),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: LayoutBuilder(
                                    builder: (context, outerViewport) {
                                      final frameAspect = _postFrameAspect();
                                      return AspectRatio(
                                        aspectRatio: frameAspect,
                                        child: LayoutBuilder(
                                          builder: (context, viewport) {
                                            return _buildPostZoomableImagePreviewFor(
                                              _currentMedia,
                                              viewport,
                                              enableGesture: true,
                                            );
                                          },
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 8, 16, 16),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      _buildPostBottomPill(
                                        icon: Icons.text_fields,
                                        label: 'Text',
                                        onTap: _onTapText,
                                        enabled: !_isCarouselVideo,
                                      ),
                                      const SizedBox(width: 10),
                                      _buildPostBottomPill(
                                        icon: Icons.layers_outlined,
                                        label: 'Overlay',
                                        onTap: _openOverlayPicker,
                                        enabled: !_isCarouselVideo,
                                      ),
                                      const SizedBox(width: 10),
                                      _buildPostBottomPill(
                                        icon: Icons.filter_alt_outlined,
                                        label: 'Filter',
                                        onTap: _openFilterPicker,
                                        isActive:
                                            (_selectedFilter ?? 'none') !=
                                                'none',
                                      ),
                                      const SizedBox(width: 10),
                                      _buildPostBottomPill(
                                        icon: Icons.tune,
                                        label: 'Edit',
                                        onTap: _openImageAdjustmentsEditor,
                                        isActive: _imageAdjustments.values
                                            .any((v) => v != 0),
                                        enabled: !_isCarouselVideo,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 20),
                                child: Center(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      setState(() {
                                        _showInlineImageEditor = false;
                                      });
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 28, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                    ),
                                    child: const Text(
                                      'Done',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600),
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
                ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
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
                        borderRadius: _captureWithoutRadius
                            ? BorderRadius.zero
                            : BorderRadius.circular(24),
                        child: Builder(
                          builder: (context) {
                            final trimStart = _trimStartFor(_currentMedia);
                            final trimEnd = _trimEndFor(_currentMedia);
                            return GestureDetector(
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
                              onHorizontalDragEnd: (details) {
                                if (_isStickerDeleteMode || _isTextDeleteMode) return;
                                if (_mediaList.length > 1) return;
                                final v = details.primaryVelocity ?? 0;
                                if (v.abs() < 250) return;
                                _cycleReelFilter(v < 0 ? 1 : -1);
                              },
                              child: Stack(
                                fit: StackFit.expand,
                                alignment: Alignment.center,
                                children: [
                                  if (_mediaList.length > 1)
                                    PageView.builder(
                                      controller: _postPageController,
                                      itemCount: _mediaList.length,
                                      onPageChanged: (i) {
                                        _setCurrentMedia(_mediaList[i], i);
                                      },
                                      itemBuilder: (context, i) {
                                        final item = _mediaList[i];
                                        final isActive = i == _currentIndex;
                                        if (_isVideoMedia(item)) {
                                          if (isActive) {
                                            return GestureDetector(
                                              onTap: _openVideoEditorForCurrent,
                                              child: _buildVideoPreview(),
                                            );
                                          }
                                          if (item.filePath == null) {
                                            return Container(color: Colors.black);
                                          }
                                          return _buildVideoThumbnail(
                                            item.filePath!,
                                            coverPath: _coverPathFor(item),
                                            fit: BoxFit.cover,
                                          );
                                        }
                                        if (item.filePath == null) {
                                          return Container(color: Colors.black);
                                        }
                                        return Image.file(
                                          File(item.filePath!),
                                          fit: BoxFit.cover,
                                        );
                                      },
                                    )
                                  else if (_isVideoMedia(_currentMedia))
                                    GestureDetector(
                                      onTap: _openVideoEditorForCurrent,
                                      child: _buildVideoPreview(),
                                    )
                                  else
                                    _buildImagePreview(),
                                  if (_isVideoMedia(_currentMedia))
                                    Positioned(
                                      left: 12,
                                      right: 12,
                                      bottom: 2,
                                      child: _buildVideoProgressBar(),
                                    ),
                                  if (!_isStickerDeleteMode &&
                                      trimStart != null &&
                                      trimEnd != null)
                                    Positioned(
                                      top: 16,
                                      left: 16,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.content_cut,
                                                color: Colors.white, size: 12),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${_formatDuration(trimStart)} – ${_formatDuration(trimEnd)}',
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12),
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
                                        final isActive =
                                            _activeTextIndex == index;
                                        return Positioned(
                                          key: ValueKey('text_$index'),
                                          left: overlay.position.dx,
                                          top: overlay.position.dy,
                                          child: GestureDetector(
                                            onTapDown: (_) =>
                                                _startTextHold(index),
                                            onTapUp: (_) => _cancelTextHold(),
                                            onTapCancel: _cancelTextHold,
                                            onTap: () {
                                              if (_suppressTextTap) {
                                                _suppressTextTap = false;
                                                return;
                                              }
                                              setState(() =>
                                                  _bringTextToFront(index));
                                              _openPreviewTextEditor(
                                                  index: index);
                                            },
                                            onScaleStart: (d) {
                                              setState(() =>
                                                  _bringTextToFront(index));
                                              _cancelTextHold();
                                              _handleTextScaleStart(d);
                                            },
                                            onScaleUpdate:
                                                _handleTextScaleUpdate,
                                            onScaleEnd: (_) =>
                                                _handleTextScaleEnd(),
                                            child: AnimatedOpacity(
                                              duration: const Duration(
                                                  milliseconds: 180),
                                              opacity:
                                                  _deletingTextIndexes.contains(
                                                          index)
                                                      ? 0.0
                                                      : 1.0,
                                              child: AnimatedScale(
                                                duration: const Duration(
                                                    milliseconds: 180),
                                                scale: _deletingTextIndexes
                                                        .contains(index)
                                                    ? 0.0
                                                    : 1.0,
                                                child: Transform.rotate(
                                                  angle: overlay.rotation,
                                                  child: Transform.scale(
                                                    scale: overlay.scale *
                                                        (_textDeleteScale[
                                                                index] ??
                                                            1.0),
                                                    child: _buildOverlayVisual(
                                                        overlay, isActive),
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
                                        final isActive =
                                            _activeStickerIndex == i;
                                        return Positioned(
                                          key: ValueKey('sticker_${s.id}'),
                                          left: s.position.dx,
                                          top: s.position.dy,
                                          child: GestureDetector(
                                            onTapDown: (_) =>
                                                _startStickerHold(i),
                                            onTapUp: (_) =>
                                                _cancelStickerHold(),
                                            onTapCancel: () =>
                                                _cancelStickerHold(),
                                            onTap: () {
                                              if (_suppressStickerTap) {
                                                _suppressStickerTap = false;
                                                return;
                                              }
                                              setState(() {
                                                if (_activeStickerIndex ==
                                                    i) {
                                                  _stickerOverlays[i] =
                                                      s.copyWith(
                                                    shape: _nextShape(s.shape),
                                                  );
                                                }
                                                _bringStickerToFront(i);
                                              });
                                            },
                                            onScaleStart: (d) {
                                              setState(() =>
                                                  _bringStickerToFront(i));
                                              _cancelStickerHold();
                                              _handleStickerScaleStart(d);
                                            },
                                            onScaleUpdate: (d) =>
                                                _handleStickerScaleUpdate(
                                                    d, context),
                                            onScaleEnd: (_) =>
                                                _handleStickerScaleEnd(context),
                                            child: AnimatedOpacity(
                                              duration: const Duration(
                                                  milliseconds: 180),
                                              opacity:
                                                  _deletingStickerIds.contains(
                                                          s.id)
                                                      ? 0.0
                                                      : 1.0,
                                              child: AnimatedScale(
                                                duration: const Duration(
                                                    milliseconds: 180),
                                                scale: _deletingStickerIds
                                                        .contains(s.id)
                                                    ? 0.0
                                                    : 1.0,
                                                child: Transform(
                                                  alignment: Alignment.center,
                                                  transform: Matrix4.identity()
                                                    ..rotateZ(s.rotation)
                                                    ..scaleByVector3(
                                                      vector_math.Vector3.all(
                                                        s.scale *
                                                            (_stickerDeleteScale[
                                                                    s.id] ??
                                                                1.0),
                                                      ),
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
                                  if (_isStickerDeleteMode || _isTextDeleteMode)
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
                                        duration:
                                            const Duration(milliseconds: 160),
                                        curve: Curves.easeOut,
                                        opacity: (_isStickerDeleteMode ||
                                                _isTextDeleteMode)
                                            ? 1
                                            : 0,
                                        child: AnimatedScale(
                                          duration: const Duration(
                                              milliseconds: 160),
                                          curve: Curves.easeOut,
                                          scale: (_isStickerDeleteMode ||
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
                            );
                          },
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
                                  enabled: !_isCarouselVideo,
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
                                  if (_trimStartFor(_currentMedia) != null) ...[
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
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                children: [
                                  _buildEditOption(
                                    iconWidget: const Text(
                                      'Aa',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    label: 'Text',
                                    onTap: _onTapText,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildEditOption(
                                    icon: Icons.emoji_emotions_outlined,
                                    label: 'Sticker',
                                    onTap: _openOverlayPicker,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildEditOption(
                                    icon: Icons.graphic_eq,
                                    label: 'Audio',
                                    onTap: () {
                                      setState(() {
                                        _showMusicControls = !_showMusicControls;
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  _buildEditOption(
                                    icon: Icons.video_call_outlined,
                                    label: 'Add clips',
                                    onTap: _openAddClips,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildEditOption(
                                    icon: Icons.layers_outlined,
                                    label: 'Overlay',
                                    onTap: _openOverlayPicker,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildEditOption(
                                    icon: Icons.auto_awesome,
                                    label: 'Effects',
                                    onTap: () {},
                                  ),
                                  const SizedBox(width: 8),
                                  _buildEditOption(
                                    icon: Icons.tune,
                                    label: 'Edit',
                                    onTap: _openVideoEditor,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildEditOption(
                                    icon: Icons.volume_up_outlined,
                                    label: 'Volume',
                                    onTap: () {},
                                  ),
                                  const SizedBox(width: 8),
                                  _buildEditOption(
                                    icon: Icons.photo_outlined,
                                    label: 'Photo',
                                    onTap: () {},
                                  ),
                                  const SizedBox(width: 8),
                                  _buildEditOption(
                                    icon: Icons.closed_caption_outlined,
                                    label: 'Captions',
                                    onTap: () {},
                                  ),
                                  const SizedBox(width: 8),
                                  _buildEditOption(
                                    icon: Icons.mic_none,
                                    label: 'Voice',
                                    onTap: () {},
                                  ),
                                  const SizedBox(width: 8),
                                  _buildEditOption(
                                    icon: Icons.filter_alt_outlined,
                                    label: 'Filters',
                                    onTap: _openFilterPicker,
                                    isActive: (_selectedFilter ?? 'none') != 'none',
                                  ),
                                  const SizedBox(width: 8),
                                  _buildEditOption(
                                    icon: Icons.save_alt,
                                    label: 'Save',
                                    onTap: () {},
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
              top: 8,
              left: 8,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 160),
                opacity: (_isStickerDeleteMode || _isTextDeleteMode) ? 0 : 1,
                child: IgnorePointer(
                  ignoring: _isStickerDeleteMode || _isTextDeleteMode,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E2E2E),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 22),
                    ),
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
        _ensureVideoPlaying(controller);
        final frameAspect = _postFrameAspect();
        final videoAspect = controller.value.aspectRatio;
        final fit = widget.isReelFlow
            ? _videoPreviewFit(videoAspect, frameAspect)
            : BoxFit.cover;
        return _applyImageAdjustments(_applySelectedFilter(
          Stack(
            alignment: Alignment.center,
            children: [
              Container(color: Colors.black),
              SizedBox.expand(
                child: FittedBox(
                  fit: fit,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: controller.value.size.width,
                    height: controller.value.size.height,
                    child: VideoPlayer(controller),
                  ),
                ),
              ),
            ],
          ),
          filterIds: _effectiveFilterIds(_currentMedia),
        ));
      },
    );
  }

  void _ensureVideoPlaying(VideoPlayerController controller) {
    if (_autoPlayQueued) return;
    _autoPlayQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoPlayQueued = false;
      if (!mounted) return;
      if (!controller.value.isInitialized) return;
      if (!controller.value.isPlaying) {
        controller.play();
        setState(() => _isPlaying = true);
      }
    });
  }

  Widget _buildImagePreview() {
    if (_currentMedia.filePath != null) {
      if (_isVideoMedia(_currentMedia)) {
        return Container(
          color: Colors.black,
          child: Center(
            child: _buildVideoThumbnail(_currentMedia.filePath!, fit: BoxFit.contain),
          ),
        );
      }
      return Container(
        color: Colors.red,
        child: Center(
          child: RotatedBox(
            quarterTurns: 1,
            child: Image.file(
              File(_currentMedia.filePath!),
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
    bool enabled = true,
  }) {
    final canTap = enabled;
    final accent = const Color(0xFF0095F6);
    final fg = enabled ? Colors.white : Colors.white54;
    final activeColor = enabled ? accent : Colors.white54;
    return GestureDetector(
      onTap: canTap ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: enabled ? 0.08 : 0.04),
          borderRadius: BorderRadius.circular(16),
          border: isActive && enabled ? Border.all(color: accent) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? activeColor : fg,
              size: 16,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? activeColor : fg,
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
    IconData? icon,
    Widget? iconWidget,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    assert(icon != null || iconWidget != null);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF0095F6).withValues(alpha: 0.25)
                  : Colors.grey[800],
              borderRadius: BorderRadius.circular(10),
              border: isActive
                  ? Border.all(color: const Color(0xFF0095F6), width: 1.5)
                  : null,
            ),
            child: iconWidget ??
                Icon(
                  icon,
                  color: isActive ? const Color(0xFF0095F6) : Colors.white,
                  size: 20,
                ),
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

  Widget _buildVideoProgressBar() {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) {
      return Container(
        height: 3,
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(999),
        ),
      );
    }
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final durationMs = value.duration.inMilliseconds;
        final positionMs = value.position.inMilliseconds;
        final progress = durationMs > 0
            ? (positionMs / durationMs).clamp(0.0, 1.0)
            : 0.0;
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: progress),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          builder: (context, animated, __) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 3,
                value: animated,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            );
          },
        );
      },
    );
  }


}

class _ClipPickerSheet extends StatefulWidget {
  final AssetPathEntity assetsPath;
  final bool isLimited;
  const _ClipPickerSheet({
    required this.assetsPath,
    required this.isLimited,
  });

  @override
  State<_ClipPickerSheet> createState() => _ClipPickerSheetState();
}

class _ClipPickerSheetState extends State<_ClipPickerSheet> {
  final List<AssetEntity> _assets = [];
  final List<AssetEntity> _selected = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    final list = await widget.assetsPath.getAssetListPaged(page: 0, size: 120);
    if (mounted) {
      setState(() {
        _assets.addAll(list);
        _isLoading = false;
      });
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    if (minutes <= 0) return '${seconds}s';
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.75;
    return Container(
      height: height,
      color: Colors.black,
      child: Column(
        children: [
          AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Add clips',
              style: TextStyle(color: Colors.white),
            ),
            actions: [
              TextButton(
                onPressed: _selected.isEmpty
                    ? null
                    : () => Navigator.pop(
                          context,
                          List<AssetEntity>.from(_selected),
                        ),
                child: Text(
                  'Done',
                  style: TextStyle(
                    color: _selected.isEmpty ? Colors.white38 : Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (widget.isLimited)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.white70, size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Limited photo access. Some items may be hidden.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: PhotoManager.openSetting,
                    child: const Text(
                      'Settings',
                      style: TextStyle(color: Color(0xFF0095F6)),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 1,
                      mainAxisSpacing: 1,
                    ),
                    itemCount: _assets.length,
                    itemBuilder: (context, index) {
                      final asset = _assets[index];
                      final isSelected = _selected.any((a) => a.id == asset.id);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selected.removeWhere((a) => a.id == asset.id);
                            } else {
                              _selected.add(asset);
                            }
                          });
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            FutureBuilder<Uint8List?>(
                              future: asset.thumbnailDataWithSize(const ThumbnailSize(300, 300)),
                              builder: (context, snap) {
                                if (snap.connectionState != ConnectionState.done || snap.data == null) {
                                  return Container(color: Colors.grey[850]);
                                }
                                return Image.memory(snap.data!, fit: BoxFit.cover);
                              },
                            ),
                            if (asset.type == AssetType.video)
                              Positioned(
                                bottom: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _formatDuration(Duration(seconds: asset.duration)),
                                    style: const TextStyle(color: Colors.white, fontSize: 10),
                                  ),
                                ),
                              ),
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white.withValues(alpha: 0.9)
                                      : Colors.black.withValues(alpha: 0.35),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white70, width: 1),
                                ),
                                child: isSelected
                                    ? const Center(
                                        child: Icon(Icons.check, size: 12, color: Colors.black),
                                      )
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _PerImageEditResult {
  final String? filterId;
  final Map<String, int> adjustments;
  final List<_PreviewTextOverlay> textOverlays;
  final List<OverlaySticker> stickerOverlays;

  const _PerImageEditResult({
    required this.filterId,
    required this.adjustments,
    required this.textOverlays,
    required this.stickerOverlays,
  });
}

class _PerVideoEditResult {
  final String? filterId;
  final Duration? trimStart;
  final Duration? trimEnd;
  final String? outputPath;
  final String? coverPath;

  const _PerVideoEditResult({
    this.filterId,
    this.trimStart,
    this.trimEnd,
    this.outputPath,
    this.coverPath,
  });
}

class _PerVideoEditPage extends StatefulWidget {
  final app_models.MediaItem media;
  final double frameAspect;
  final String? initialFilter;
  final String? globalFilter;
  final Duration? initialTrimStart;
  final Duration? initialTrimEnd;
  final String? initialCoverPath;
  final List<app_models.Filter> filters;
  final List<double> Function(String id) filterMatrixFor;

  const _PerVideoEditPage({
    super.key,
    required this.media,
    required this.frameAspect,
    required this.initialFilter,
    required this.globalFilter,
    required this.initialTrimStart,
    required this.initialTrimEnd,
    required this.initialCoverPath,
    required this.filters,
    required this.filterMatrixFor,
  });

  @override
  State<_PerVideoEditPage> createState() => _PerVideoEditPageState();
}

class _PerVideoEditPageState extends State<_PerVideoEditPage> {
  late String? _selectedFilter;
  Duration? _trimStart;
  Duration? _trimEnd;
  String? _coverPath;
  String? _outputPath;
  List<Uint8List?> _thumbs = const [];
  bool _loadingThumbs = false;
  Duration _videoDuration = Duration.zero;

  String get _activePath => _outputPath ?? widget.media.filePath ?? '';

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter ?? 'none';
    _trimStart = widget.initialTrimStart;
    _trimEnd = widget.initialTrimEnd;
    _coverPath = widget.initialCoverPath;
    _loadThumbnails();
  }

  Future<void> _loadThumbnails() async {
    final path = _activePath;
    if (path.isEmpty) return;
    setState(() => _loadingThumbs = true);
    final controller = VideoPlayerController.file(File(path));
    await controller.initialize();
    _videoDuration = controller.value.duration;
    await controller.dispose();

    const count = 8;
    final durationMs = _videoDuration.inMilliseconds;
    final frames = <Uint8List?>[];
    for (int i = 0; i < count; i++) {
      final timeMs = durationMs == 0
          ? 0
          : (durationMs * i / (count - 1)).round();
      final bytes = await VideoThumbnail.thumbnailData(
        video: path,
        imageFormat: ImageFormat.JPEG,
        timeMs: timeMs,
        quality: 75,
      );
      frames.add(bytes);
    }
    if (!mounted) return;
    setState(() {
      _thumbs = frames;
      _loadingThumbs = false;
    });
  }

  Widget _applyFilterToPreview(Widget child, {String? filterId}) {
    final global = widget.globalFilter;
    final per = filterId;
    final ids = <String>[];
    if (global != null && global != 'none') ids.add(global);
    if (per != null && per != 'none') ids.add(per);
    Widget out = child;
    for (final id in ids) {
      final matrix = widget.filterMatrixFor(id);
      out = ColorFiltered(
        colorFilter: ColorFilter.matrix(matrix),
        child: out,
      );
    }
    return out;
  }

  Future<String?> _writeCoverBytes(Uint8List bytes) async {
    final filename =
        'bsmart_cover_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final outPath = '${Directory.systemTemp.path}/$filename';
    final outFile = File(outPath);
    await outFile.writeAsBytes(bytes, flush: true);
    return outPath;
  }

  Future<void> _openFilterPicker() async {
    final initialFilterId = _selectedFilter ?? 'none';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          top: false,
          child: SizedBox(
            height: 260,
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.filters.length,
                    itemBuilder: (context, i) {
                      final f = widget.filters[i];
                      final isActive = (_selectedFilter ?? 'none') == f.id;
                      final preview = _buildPreviewImage(
                        overrideFilterId: f.id,
                      );
                      return GestureDetector(
                        onTap: () => setState(() => _selectedFilter = f.id),
                        child: Container(
                          width: 90,
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          child: Column(
                            children: [
                              Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isActive
                                        ? Colors.white
                                        : Colors.white24,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: preview,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                f.name,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color:
                                      isActive ? Colors.white : Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() => _selectedFilter = initialFilterId);
                          Navigator.of(context).pop();
                        },
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        'Filter',
                        style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'Done',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openTrimEditor() async {
    final path = _activePath;
    if (path.isEmpty) return;
    final media = app_models.MediaItem(
      id: widget.media.id,
      type: widget.media.type,
      filePath: path,
      thumbnailPath: widget.media.thumbnailPath,
      duration: widget.media.duration,
      createdAt: widget.media.createdAt,
    );
    final result = await showModalBottomSheet<VideoEditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (context) {
        final height = MediaQuery.of(context).size.height * 0.9;
        return SizedBox(
          height: height,
          child: EditVideoScreen(media: media),
        );
      },
    );
    if (!mounted || result == null) return;
    setState(() {
      _trimStart = result.trimStart;
      _trimEnd = result.trimEnd;
      if (result.outputPath != null && result.outputPath!.isNotEmpty) {
        _outputPath = result.outputPath;
      }
    });
    if (result.outputPath != null && result.outputPath!.isNotEmpty) {
      await _loadThumbnails();
    }
  }

  Future<void> _openCoverPicker() async {
    if (_loadingThumbs) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          top: false,
          child: SizedBox(
            height: 220,
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    scrollDirection: Axis.horizontal,
                    itemCount: _thumbs.length,
                    itemBuilder: (context, i) {
                      final bytes = _thumbs[i];
                      final isActive = false;
                      return GestureDetector(
                        onTap: () async {
                          if (bytes == null) return;
                          final path = await _writeCoverBytes(bytes);
                          if (!mounted) return;
                          setState(() => _coverPath = path);
                          Navigator.of(context).pop();
                        },
                        child: Container(
                          width: 90,
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isActive
                                  ? Colors.white
                                  : Colors.white24,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: bytes != null
                              ? Image.memory(bytes, fit: BoxFit.cover)
                              : Container(color: const Color(0xFF2A2A2A)),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
                  child: Row(
                    children: const [
                      Spacer(),
                      Text(
                        'Cover',
                        style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w700),
                      ),
                      Spacer(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPreviewImage({String? overrideFilterId}) {
    if (_coverPath != null) {
      final coverFile = File(_coverPath!);
      if (coverFile.existsSync()) {
        return _applyFilterToPreview(
          Image.file(coverFile, fit: BoxFit.cover),
          filterId: overrideFilterId ?? _selectedFilter,
        );
      }
    }
    final bytes = _thumbs.isNotEmpty ? _thumbs.first : null;
    if (bytes != null) {
      return _applyFilterToPreview(
        Image.memory(bytes, fit: BoxFit.cover),
        filterId: overrideFilterId ?? _selectedFilter,
      );
    }
    return Container(color: Colors.black12);
  }

  Widget _buildBottomPill({
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07121E),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
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
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: widget.frameAspect,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: _buildPreviewImage(),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildBottomPill(
                      icon: Icons.filter_alt_outlined,
                      label: 'Filter',
                      onTap: _openFilterPicker,
                      isActive: (_selectedFilter ?? 'none') != 'none',
                    ),
                    const SizedBox(width: 10),
                    _buildBottomPill(
                      icon: Icons.content_cut,
                      label: 'Trim',
                      onTap: _openTrimEditor,
                      isActive: _trimStart != null && _trimEnd != null,
                    ),
                    const SizedBox(width: 10),
                    _buildBottomPill(
                      icon: Icons.photo,
                      label: 'Cover',
                      onTap: _openCoverPicker,
                      isActive: _coverPath != null,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(_PerVideoEditResult(
                      filterId: _selectedFilter,
                      trimStart: _trimStart,
                      trimEnd: _trimEnd,
                      outputPath: _outputPath,
                      coverPath: _coverPath,
                    ));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(fontWeight: FontWeight.w600),
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

class _PerImageEditPage extends StatefulWidget {
  final app_models.MediaItem media;
  final double frameAspect;
  final String? initialFilter;
  final Map<String, int> initialAdjustments;
  final String? globalFilter;
  final Map<String, int> globalAdjustments;
  final List<_PreviewTextOverlay> initialTextOverlays;
  final List<OverlaySticker> initialStickerOverlays;
  final List<app_models.Filter> filters;
  final List<double> Function(String id) filterMatrixFor;
  final List<double> Function({
    required double brightness,
    required double contrast,
    required double saturation,
  }) buildAdjustmentMatrix;
  final List<double> Function({
    required double amount,
    required double brightness,
    required double contrast,
    required double saturation,
  }) buildSepiaMatrix;

  const _PerImageEditPage({
    required this.media,
    required this.frameAspect,
    required this.initialFilter,
    required this.initialAdjustments,
    required this.globalFilter,
    required this.globalAdjustments,
    required this.initialTextOverlays,
    required this.initialStickerOverlays,
    required this.filters,
    required this.filterMatrixFor,
    required this.buildAdjustmentMatrix,
    required this.buildSepiaMatrix,
  });

  @override
  State<_PerImageEditPage> createState() => _PerImageEditPageState();
}

class _PerImageEditPageState extends State<_PerImageEditPage> {
  final GlobalKey<ExtendedImageGestureState> _gestureKey =
      GlobalKey<ExtendedImageGestureState>();
  final GlobalKey _previewKey = GlobalKey();
  ImageStream? _imageStream;
  ImageStreamListener? _imageStreamListener;
  double? _imageAspect;
  Key _imageKey = const ValueKey('img_0_0');
  late String? _selectedFilter;
  late Map<String, int> _adjustments;
  late List<_PreviewTextOverlay> _textOverlays;
  late List<OverlaySticker> _stickerOverlays;
  int? _activeTextIndex;
  int? _activeStickerIndex;
  Offset _textLastLocalFocalPoint = Offset.zero;
  double _textTransformBaseScale = 1.0;
  double _textTransformBaseRotation = 0.0;
  Offset _stickerLastLocalFocalPoint = Offset.zero;
  double _stickerBaseScale = 1.0;
  double _stickerBaseRotation = 0.0;

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter ?? 'none';
    _adjustments = Map<String, int>.from(widget.initialAdjustments);
    _textOverlays = List<_PreviewTextOverlay>.from(widget.initialTextOverlays);
    _stickerOverlays =
        List<OverlaySticker>.from(widget.initialStickerOverlays);
    final path = widget.media.filePath;
    if (path != null && path.isNotEmpty) {
      final provider = FileImage(File(path));
      final stream = provider.resolve(const ImageConfiguration());
      _imageStream = stream;
      _imageStreamListener = ImageStreamListener((info, _) {
        final w = info.image.width.toDouble();
        final h = info.image.height.toDouble();
        if (!mounted || h == 0) return;
        setState(() {
          _imageAspect = w / h;
          _imageKey = ValueKey('img_${w}_${h}');
        });
      });
      stream.addListener(_imageStreamListener!);
    }
  }

  @override
  void dispose() {
    final stream = _imageStream;
    final listener = _imageStreamListener;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    super.dispose();
  }

  Widget _applySelectedFilter(Widget child) {
    final ids = <String>[];
    final global = widget.globalFilter;
    if (global != null && global != 'none') {
      ids.add(global);
    }
    final per = _selectedFilter;
    if (per != null && per != 'none' && per != global) {
      ids.add(per);
    }
    if (ids.isEmpty) return child;
    Widget out = child;
    for (final id in ids) {
      final matrix = widget.filterMatrixFor(id);
      out = ColorFiltered(
        colorFilter: ColorFilter.matrix(matrix),
        child: out,
      );
    }
    return out;
  }

  Widget _applyAdjustments(Widget child) {
    final adj = _mergeAdjustments(widget.globalAdjustments, _adjustments);
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
        colorFilter: ColorFilter.matrix(
          widget.buildSepiaMatrix(
            amount: sepiaAmount,
            brightness: 1.0,
            contrast: 1.0,
            saturation: 1.0,
          ),
        ),
        child: out,
      );
    }
    out = ColorFiltered(
      colorFilter: ColorFilter.matrix(
        widget.buildAdjustmentMatrix(
          brightness: b,
          contrast: c,
          saturation: s,
        ),
      ),
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
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: vignette),
                ],
                stops: const [0.55, 1.0],
              ),
            ),
          ),
        ],
      );
    }
    return out;
  }

  Map<String, int> _mergeAdjustments(
    Map<String, int> base,
    Map<String, int> delta,
  ) {
    int clampValue(String key, int value) {
      if (key == 'lux' || key == 'opacity' || key == 'vignette') {
        return value.clamp(0, 100);
      }
      return value.clamp(-100, 100);
    }

    final out = <String, int>{};
    for (final entry in base.entries) {
      final next = entry.value + (delta[entry.key] ?? 0);
      out[entry.key] = clampValue(entry.key, next);
    }
    for (final entry in delta.entries) {
      out[entry.key] ??= clampValue(entry.key, entry.value);
    }
    return out;
  }

  bool _isVideoMedia(app_models.MediaItem media) {
    if (media.type == app_models.MediaType.video) return true;
    final path = media.filePath;
    if (path == null) return false;
    final lower = path.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m4v') ||
        lower.endsWith('.3gp') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.mkv');
  }

  Widget _buildVideoThumbnail(
    String filePath, {
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
  }) {
    return FutureBuilder<Uint8List?>(
      future: VideoThumbnail.thumbnailData(
        video: filePath,
        imageFormat: ImageFormat.JPEG,
        quality: 70,
      ),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done || snap.data == null) {
          return Container(
            width: width,
            height: height,
            color: Colors.black,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }
        return Image.memory(
          snap.data!,
          fit: fit,
          width: width,
          height: height,
        );
      },
    );
  }

  Future<ImageProvider<Object>> _baseTextEditorBackgroundFromMedia() async {
    final path = widget.media.filePath;
    if (path == null || path.isEmpty) {
      return const AssetImage('assets/images/dashboard_sample.png');
    }
    if (_isVideoMedia(widget.media)) {
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
      return Text(
        text,
        textAlign: overlay.alignment,
        style: baseStyle.copyWith(
          shadows: [
            Shadow(
              color: overlay.textColor.withValues(alpha: 0.8),
              blurRadius: 12,
            ),
          ],
        ),
      );
    }
    return Text(
      text,
      textAlign: overlay.alignment,
      style: baseStyle,
    );
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

  Size? _previewSize() {
    final render = _previewKey.currentContext?.findRenderObject();
    if (render is RenderBox) return render.size;
    return null;
  }

  Offset _overlayCenter() {
    final size = _previewSize();
    if (size == null) return const Offset(120, 200);
    return Offset((size.width - 120) / 2, (size.height - 120) / 2);
  }

  Offset _toPreviewLocal(Offset global) {
    final renderBox = _previewKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return global;
    return renderBox.globalToLocal(global);
  }

  Offset _normalizePosition(Offset position) {
    final size = _previewSize();
    if (size == null || size.width == 0 || size.height == 0) {
      return position;
    }
    final dx = (position.dx / size.width).clamp(0.0, 1.0);
    final dy = (position.dy / size.height).clamp(0.0, 1.0);
    return Offset(dx, dy);
  }

  Offset _denormalizePosition(Offset normalized) {
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
    final renderBox = _previewKey.currentContext?.findRenderObject() as RenderBox?;
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

  Future<void> _openTextEditor({int? index}) async {
    final existing = index != null && index >= 0 && index < _textOverlays.length
        ? _textOverlays[index]
        : null;
    final filePath = widget.media.filePath;
    final ImageProvider<Object> background = filePath != null
        ? (_isVideoMedia(widget.media)
            ? await _baseTextEditorBackgroundFromMedia()
            : FileImage(File(filePath)) as ImageProvider<Object>)
        : const AssetImage('assets/images/dashboard_sample.png');
    final normalizedInitialPosition =
        existing != null ? _normalizePosition(existing.position) : null;
    final result = await InstagramTextEditor.open(
      context,
      backgroundImage: background,
      initialText: existing?.text,
      initialColor: existing?.textColor ?? Colors.white,
      initialAlignment: existing?.alignment ?? TextAlign.center,
      initialBackgroundStyle: existing?.backgroundStyle ?? BackgroundStyle.none,
      initialScale: existing?.scale ?? 1.0,
      initialRotation: existing?.rotation ?? 0.0,
      initialPosition: normalizedInitialPosition,
      initialFont: existing?.fontName ?? 'Modern',
      initialFontSize: existing?.fontSize ?? 32.0,
    );
    if (result == null || result.text.trim().isEmpty) return;
    final resolvedPosition = _denormalizePosition(result.position);
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

  Future<void> _openOverlayPicker() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final file = File(picked.path);
    final center = _overlayCenter();
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

  Future<void> _openFilterPicker() async {
    if (widget.media.filePath == null) return;
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
                        itemCount: widget.filters.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, i) {
                          final f = widget.filters[i];
                          final isActive = (_selectedFilter ?? 'none') == f.id;
                          final base = _isVideoMedia(widget.media)
                              ? _buildVideoThumbnail(widget.media.filePath!, fit: BoxFit.cover)
                              : Image.file(File(widget.media.filePath!), fit: BoxFit.cover);
                          final preview = (f.id == 'none')
                              ? base
                              : ColorFiltered(
                                  colorFilter: ColorFilter.matrix(
                                    widget.filterMatrixFor(f.id),
                                  ),
                                  child: base,
                                );
                          final displayName =
                              f.id == 'none' ? 'Normal' : f.name;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedFilter = f.id;
                              });
                              setSheetState(() {});
                            },
                            child: SizedBox(
                              width: 88,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 76,
                                      height: 76,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isActive
                                              ? const Color(0xFF0095F6)
                                              : Colors.white24,
                                          width: isActive ? 2 : 1,
                                        ),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: preview,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      displayName,
                                      style: TextStyle(
                                        color: isActive
                                            ? const Color(0xFF0095F6)
                                            : Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
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

  void _openAdjustmentsEditor() {
    const tools = <_ImageToolSpec>[
      _ImageToolSpec(
          key: 'lux',
          label: 'Lux',
          icon: Icons.auto_fix_high,
          min: 0,
          max: 100),
      _ImageToolSpec(
          key: 'brightness',
          label: 'Brightness',
          icon: Icons.wb_sunny_outlined,
          min: -100,
          max: 100),
      _ImageToolSpec(
          key: 'contrast',
          label: 'Contrast',
          icon: Icons.contrast,
          min: -100,
          max: 100),
      _ImageToolSpec(
          key: 'saturate',
          label: 'Saturation',
          icon: Icons.palette_outlined,
          min: -100,
          max: 100),
      _ImageToolSpec(
          key: 'sepia',
          label: 'Temperature',
          icon: Icons.thermostat_outlined,
          min: -100,
          max: 100),
      _ImageToolSpec(
          key: 'opacity',
          label: 'Fade',
          icon: Icons.blur_on_outlined,
          min: 0,
          max: 100),
      _ImageToolSpec(
          key: 'vignette',
          label: 'Vignette',
          icon: Icons.vignette_outlined,
          min: 0,
          max: 100),
    ];
    String? selectedKey;
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
                final current = _adjustments[tool.key] ?? 0;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(child: SizedBox()),
                        Text(current.toString(),
                            style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                    Slider(
                      value: current.toDouble(),
                      min: tool.min.toDouble(),
                      max: tool.max.toDouble(),
                      onChanged: (v) {
                        final next = v.round();
                        setState(() {
                          _adjustments = {
                            ..._adjustments,
                            tool.key: next,
                          };
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
                  : tools.firstWhere((t) => t.key == selectedKey,
                      orElse: () => tools[0]);

              return SizedBox(
                height: MediaQuery.of(context).size.height * 0.46,
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(width: 64),
                        const Text('Edit',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Done',
                              style: TextStyle(color: Colors.white)),
                        ),
                        const Spacer(),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Column(
                        children: [
                          SizedBox(
                            height: 92,
                            child: ListView.separated(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              scrollDirection: Axis.horizontal,
                              itemCount: tools.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (context, i) {
                                final tool = tools[i];
                                final isActive = selectedKey == tool.key;
                                return GestureDetector(
                                  onTap: () {
                                    setSheetState(() {
                                      selectedKey = tool.key;
                                    });
                                  },
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 52,
                                        height: 52,
                                        decoration: BoxDecoration(
                                          color: isActive
                                              ? const Color(0xFF0095F6)
                                                  .withValues(alpha: 0.25)
                                              : Colors.white10,
                                          shape: BoxShape.circle,
                                          border: isActive
                                              ? Border.all(
                                                  color:
                                                      const Color(0xFF0095F6),
                                                  width: 1.2,
                                                )
                                              : null,
                                        ),
                                        child: Icon(tool.icon,
                                            color: isActive
                                                ? const Color(0xFF0095F6)
                                                : Colors.white,
                                            size: 22),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(tool.label,
                                          style: TextStyle(
                                              color: isActive
                                                  ? const Color(0xFF0095F6)
                                                  : Colors.white70,
                                              fontSize: 11)),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (selectedTool != null)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: sliderForTool(selectedTool),
                            ),
                        ],
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

  Widget _buildBottomPill({
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
          border: isActive
              ? Border.all(color: const Color(0xFF0095F6))
              : null,
        ),
        child: Column(
          children: [
            Icon(icon,
                color: isActive ? const Color(0xFF0095F6) : Colors.white,
                size: 20),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                    color: isActive
                        ? const Color(0xFF0095F6)
                        : Colors.white,
                    fontSize: 11)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filePath = widget.media.filePath;
    return Scaffold(
      backgroundColor: const Color(0xFF07121E),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
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
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: widget.frameAspect,
                    child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: LayoutBuilder(
                      builder: (context, viewport) {
                        if (filePath == null) {
                          return const Icon(Icons.image,
                              size: 100, color: Colors.white54);
                        }
                        if (_isVideoMedia(widget.media)) {
                          return _buildVideoThumbnail(
                            filePath,
                            fit: BoxFit.cover,
                            width: viewport.maxWidth,
                            height: viewport.maxHeight,
                          );
                        }
                        final preview = _applyAdjustments(_applySelectedFilter(
                          ExtendedImage.file(
                            key: _imageKey,
                            File(filePath),
                            width: viewport.maxWidth,
                            height: viewport.maxHeight,
                            fit: BoxFit.cover,
                            borderRadius: BorderRadius.circular(24),
                            clipBehavior: Clip.antiAlias,
                            mode: ExtendedImageMode.gesture,
                            extendedImageGestureKey: _gestureKey,
                            initGestureConfigHandler: (state) {
                              final imageAspect = _imageAspect ?? 1.0;
                              final viewportAspect = viewport.maxWidth / viewport.maxHeight;
                              final fillScale = (imageAspect / viewportAspect) > 1.0
                                  ? viewportAspect / imageAspect
                                  : imageAspect / viewportAspect;
                              final minFillScale = math.max(1.0, fillScale);
                              return GestureConfig(
                                minScale: minFillScale,
                                maxScale: math.max(4.0, minFillScale * 3.0),
                                initialScale: minFillScale,
                                speed: 1.0,
                                inertialSpeed: 100.0,
                                cacheGesture: true,
                                inPageView: false,
                              );
                            },
                          ),
                        ));
                        return SizedBox(
                          key: _previewKey,
                          width: viewport.maxWidth,
                          height: viewport.maxHeight,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRect(child: preview),
                              ..._textOverlays.asMap().entries.map((entry) {
                                final i = entry.key;
                                final overlay = entry.value;
                                final isActive = _activeTextIndex == i;
                                return Positioned(
                                  left: overlay.position.dx,
                                  top: overlay.position.dy,
                                  child: GestureDetector(
                                    onTap: () => _openTextEditor(index: i),
                                    onScaleStart: (d) {
                                      _activeTextIndex = i;
                                      _textLastLocalFocalPoint =
                                          _toPreviewLocal(d.focalPoint);
                                      _textTransformBaseScale = overlay.scale;
                                      _textTransformBaseRotation =
                                          overlay.rotation;
                                    },
                                    onScaleUpdate: (d) {
                                      final local =
                                          _toPreviewLocal(d.focalPoint);
                                      final delta =
                                          local - _textLastLocalFocalPoint;
                                      _textLastLocalFocalPoint = local;
                                      double newScale = overlay.scale;
                                      double newRotation = overlay.rotation;
                                      if (d.pointerCount > 1) {
                                        newScale =
                                            (_textTransformBaseScale *
                                                    d.scale)
                                                .clamp(0.2, 8.0);
                                        newRotation =
                                            _textTransformBaseRotation +
                                                d.rotation;
                                      }
                                      final nextPosition = _clampTextPosition(
                                        overlay,
                                        overlay.position + delta,
                                        newScale,
                                      );
                                      setState(() {
                                        _textOverlays[i] = overlay.copyWith(
                                          position: nextPosition,
                                          scale: newScale,
                                          rotation: newRotation,
                                        );
                                      });
                                    },
                                    child: Transform.rotate(
                                      angle: overlay.rotation,
                                      child: Transform.scale(
                                        scale: overlay.scale,
                                        child: _buildOverlayVisual(
                                            overlay, isActive),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                              ..._stickerOverlays.asMap().entries.map((entry) {
                                final i = entry.key;
                                final s = entry.value;
                                final isActive = _activeStickerIndex == i;
                                return Positioned(
                                  left: s.position.dx,
                                  top: s.position.dy,
                                  child: GestureDetector(
                                    onScaleStart: (d) {
                                      _activeStickerIndex = i;
                                      _stickerLastLocalFocalPoint =
                                          _toPreviewLocal(d.focalPoint);
                                      _stickerBaseScale = s.scale;
                                      _stickerBaseRotation = s.rotation;
                                    },
                                    onScaleUpdate: (d) {
                                      final local =
                                          _toPreviewLocal(d.focalPoint);
                                      final delta =
                                          local - _stickerLastLocalFocalPoint;
                                      _stickerLastLocalFocalPoint = local;
                                      double newScale = s.scale;
                                      double newRotation = s.rotation;
                                      if (d.pointerCount > 1) {
                                        newScale =
                                            (_stickerBaseScale * d.scale)
                                                .clamp(0.2, 8.0);
                                        newRotation =
                                            _stickerBaseRotation +
                                                d.rotation;
                                      }
                                      setState(() {
                                        _stickerOverlays[i] = s.copyWith(
                                          position: s.position + delta,
                                          scale: newScale,
                                          rotation: newRotation,
                                        );
                                      });
                                    },
                                    child: Transform(
                                      alignment: Alignment.center,
                                      transform: Matrix4.identity()
                                        ..rotateZ(s.rotation)
                                        ..scaleByVector3(
                                          vector_math.Vector3.all(s.scale),
                                        ),
                                      child: OverlayStickerWidget(
                                        sticker: s,
                                        isActive: isActive,
                                        onDelete: () {},
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildBottomPill(
                      icon: Icons.music_note,
                      label: 'Audio',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Audio is global only'),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 10),
                    _buildBottomPill(
                      icon: Icons.text_fields,
                      label: 'Text',
                      onTap: () => _openTextEditor(),
                    ),
                    const SizedBox(width: 10),
                    _buildBottomPill(
                      icon: Icons.layers_outlined,
                      label: 'Overlay',
                      onTap: _openOverlayPicker,
                    ),
                    const SizedBox(width: 10),
                    _buildBottomPill(
                      icon: Icons.filter_alt_outlined,
                      label: 'Filter',
                      onTap: _openFilterPicker,
                      isActive: (_selectedFilter ?? 'none') != 'none',
                    ),
                    const SizedBox(width: 10),
                    _buildBottomPill(
                      icon: Icons.tune,
                      label: 'Edit',
                      onTap: _openAdjustmentsEditor,
                      isActive: _adjustments.values.any((v) => v != 0),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(_PerImageEditResult(
                      filterId: _selectedFilter,
                      adjustments: _adjustments,
                      textOverlays: _textOverlays,
                      stickerOverlays: _stickerOverlays,
                    ));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(fontWeight: FontWeight.w600),
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
