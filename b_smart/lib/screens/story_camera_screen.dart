import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:camera/camera.dart';
import 'package:video_player/video_player.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import '../instagram_text_editor/instagram_text_editor.dart';
import '../instagram_text_editor/instagram_text_result.dart';
import '../models/media_model.dart';
import 'create_post_screen.dart';
import 'create_upload_screen.dart';
import 'create_edit_preview_screen.dart';
import '../api/api.dart';

class StoryCameraScreen extends StatefulWidget {
  final UploadMode initialMode;
  final bool lockMode;

  const StoryCameraScreen({
    super.key,
    this.initialMode = UploadMode.story,
    this.lockMode = false,
  });

  @override
  State<StoryCameraScreen> createState() => _StoryCameraScreenState();
}

class _LayoutMaskPainter extends CustomPainter {
  final List<Rect> rects;
  final Rect activeRect;
  final double borderRadius;
  final Color maskColor;

  _LayoutMaskPainter({
    required this.rects,
    required this.activeRect,
    required this.borderRadius,
    required this.maskColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw thin white dividing lines between slots (internal edges only)
    final lineShadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    const eps = 0.5;
    final seen = <String>{};
    for (var i = 0; i < rects.length; i++) {
      final a = rects[i];
      for (var j = i + 1; j < rects.length; j++) {
        final b = rects[j];
        final vGap1 = b.left - a.right;
        final vGap2 = a.left - b.right;
        if (vGap1 > eps || vGap2 > eps || (a.right - b.left).abs() < eps || (b.right - a.left).abs() < eps) {
          final x = vGap1 > eps ? a.right : (vGap2 > eps ? b.right : ((a.right - b.left).abs() < eps ? a.right : b.right));
          final y1 = math.max(a.top, b.top);
          final y2 = math.min(a.bottom, b.bottom);
          if (y2 > y1 + eps) {
            final key = 'v:${x.toStringAsFixed(1)}:${y1.toStringAsFixed(1)}:${y2.toStringAsFixed(1)}';
            if (seen.add(key)) {
              canvas.drawLine(Offset(x, y1), Offset(x, y2), lineShadowPaint);
              canvas.drawLine(Offset(x, y1), Offset(x, y2), linePaint);
            }
          }
        }
        final hGap1 = b.top - a.bottom;
        final hGap2 = a.top - b.bottom;
        if (hGap1 > eps || hGap2 > eps || (a.bottom - b.top).abs() < eps || (b.bottom - a.top).abs() < eps) {
          final y = hGap1 > eps ? a.bottom : (hGap2 > eps ? b.bottom : ((a.bottom - b.top).abs() < eps ? a.bottom : b.bottom));
          final x1 = math.max(a.left, b.left);
          final x2 = math.min(a.right, b.right);
          if (x2 > x1 + eps) {
            final key = 'h:${y.toStringAsFixed(1)}:${x1.toStringAsFixed(1)}:${x2.toStringAsFixed(1)}';
            if (seen.add(key)) {
              canvas.drawLine(Offset(x1, y), Offset(x2, y), lineShadowPaint);
              canvas.drawLine(Offset(x1, y), Offset(x2, y), linePaint);
            }
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LayoutMaskPainter oldDelegate) {
    return oldDelegate.rects != rects ||
        oldDelegate.activeRect != activeRect ||
        oldDelegate.maskColor != maskColor;
  }
}

enum _StoryElementType { text }

enum _ToolOverlayType { create, boomerang, layout, ai, draw }

enum _StoryBrushType { pen, marker, neon, eraser }

enum _StoryLayoutType {
  grid2x2,
  twoVertical,
  twoHorizontal,
  threeVertical,
  onePlusTwo,
  twoPlusOne,
}

class _StoryMention {
  final String userId;
  final String username;

  const _StoryMention({
    required this.userId,
    required this.username,
  });
}

enum _StoryStickerType { like, wow, fire, music, travel, coffee }

class _StorySticker {
  final String id;
  final _StoryStickerType type;
  final Offset position;
  final double scale;
  final double rotation;

  _StorySticker({
    required this.id,
    required this.type,
    required this.position,
    required this.scale,
    required this.rotation,
  });

  _StorySticker copyWith({
    Offset? position,
    double? scale,
    double? rotation,
  }) {
    return _StorySticker(
      id: id,
      type: type,
      position: position ?? this.position,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
    );
  }
}

class _StoryOverlayElement {
  final _StoryElementType type;
  final String? text;
  final TextStyle? style;
  final TextAlign alignment;
  final BackgroundStyle backgroundStyle;
  final String fontName;
  final double fontSize;
  final Color textColor;
  final Offset position;
  final double scale;
  final double rotation;
  final List<_StoryMention> mentions;

  _StoryOverlayElement._({
    required this.type,
    this.text,
    this.style,
    this.alignment = TextAlign.center,
    this.backgroundStyle = BackgroundStyle.none,
    this.fontName = 'Modern',
    this.fontSize = 32.0,
    this.textColor = Colors.white,
    required this.position,
    required this.scale,
    required this.rotation,
    this.mentions = const [],
  });

  factory _StoryOverlayElement.text(
    String text, {
    TextStyle? style,
    TextAlign alignment = TextAlign.center,
    BackgroundStyle backgroundStyle = BackgroundStyle.none,
    String fontName = 'Modern',
    double fontSize = 32.0,
    Color textColor = Colors.white,
    List<_StoryMention> mentions = const [],
    Offset position = const Offset(100, 100),
    double scale = 1.0,
    double rotation = 0.0,
  }) {
    return _StoryOverlayElement._(
      type: _StoryElementType.text,
      text: text,
      style: style,
      alignment: alignment,
      backgroundStyle: backgroundStyle,
      fontName: fontName,
      fontSize: fontSize,
      textColor: textColor,
      position: position,
      scale: scale,
      rotation: rotation,
      mentions: mentions,
    );
  }

  _StoryOverlayElement copyWith({
    String? text,
    TextStyle? style,
    TextAlign? alignment,
    BackgroundStyle? backgroundStyle,
    String? fontName,
    double? fontSize,
    Color? textColor,
    Offset? position,
    double? scale,
    double? rotation,
    List<_StoryMention>? mentions,
  }) {
    return _StoryOverlayElement._(
      type: type,
      text: text ?? this.text,
      style: style ?? this.style,
      alignment: alignment ?? this.alignment,
      backgroundStyle: backgroundStyle ?? this.backgroundStyle,
      fontName: fontName ?? this.fontName,
      fontSize: fontSize ?? this.fontSize,
      textColor: textColor ?? this.textColor,
      position: position ?? this.position,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      mentions: mentions ?? this.mentions,
    );
  }
}

class _StoryElementWidget extends StatelessWidget {
  final _StoryOverlayElement element;
  final bool isActive;
  final VoidCallback? onTap;
  final GestureTapDownCallback? onTapDown;
  final GestureTapUpCallback? onTapUp;
  final VoidCallback? onTapCancel;
  final double deleteScale;
  final bool showDeleteFade;

  const _StoryElementWidget({
    super.key,
    required this.element,
    this.isActive = false,
    this.onTap,
    this.onTapDown,
    this.onTapUp,
    this.onTapCancel,
    this.deleteScale = 1.0,
    this.showDeleteFade = false,
  });

  Widget _buildOverlayStyledText(_StoryOverlayElement overlay) {
    final text = overlay.text ?? '';
    final baseStyle = (overlay.style ?? const TextStyle())
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
                  blurRadius: 24,
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Text(text, textAlign: overlay.alignment, style: baseStyle);
  }

  Widget _buildOverlayVisual(_StoryOverlayElement overlay) {
    final text = overlay.text ?? '';
    final baseStyle = (overlay.style ?? const TextStyle())
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
      content = Text.rich(TextSpan(children: spans), textAlign: overlay.alignment);
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

  @override
  Widget build(BuildContext context) {
    final e = element;
    return Positioned(
      left: e.position.dx,
      top: e.position.dy,
      child: Transform.rotate(
        angle: e.rotation,
        child: Transform.scale(
          scale: e.scale,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: onTapDown,
            onTapUp: onTapUp,
            onTapCancel: onTapCancel,
            onTap: onTap,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 160),
              opacity: showDeleteFade ? 0.2 : 1.0,
              child: AnimatedScale(
                duration: const Duration(milliseconds: 160),
                scale: deleteScale,
                child: _buildOverlayVisual(e),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StoryStroke {
  final Color color;
  final double size;
  final double opacity;
  final double blurSigma;
  final bool isEraser;
  final List<Offset> points;

  _StoryStroke({
    required this.color,
    required this.size,
    this.opacity = 1.0,
    this.blurSigma = 0.0,
    this.isEraser = false,
    required this.points,
  });
}

class _StoryDrawingPainter extends CustomPainter {
  final List<_StoryStroke> strokes;

  _StoryDrawingPainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Offset.zero & size, Paint());
    for (final s in strokes) {
      final paint = Paint()
        ..color = s.color.withValues(alpha: s.opacity)
        ..strokeWidth = s.size
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..blendMode = s.isEraser ? BlendMode.clear : BlendMode.srcOver;
      if (s.blurSigma > 0) {
        paint.maskFilter = MaskFilter.blur(BlurStyle.normal, s.blurSigma);
      }
      for (var i = 0; i < s.points.length - 1; i++) {
        canvas.drawLine(s.points[i], s.points[i + 1], paint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StoryDrawingPainter oldDelegate) => oldDelegate.strokes != strokes;
}

List<double> _storyFilterMatrixBase({double brightness = 1, double contrast = 1, double saturation = 1}) {
  final b = brightness;
  final c = contrast;
  final s = saturation;
  final invSat = 1 - s;
  const lr = 0.2126, lg = 0.7152, lb = 0.0722;
  final scale = c * b;
  return [
    (invSat * lr + s) * scale,
    invSat * lg * scale,
    invSat * lb * scale,
    0,
    0,
    invSat * lr * scale,
    (invSat * lg + s) * scale,
    invSat * lb * scale,
    0,
    0,
    invSat * lr * scale,
    invSat * lg * scale,
    (invSat * lb + s) * scale,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];
}

List<double> _storyGrayscaleMatrix({double contrast = 1.0, double brightness = 1.0}) {
  const r = 0.2126, g = 0.7152, b = 0.0722;
  return [
    r * contrast * brightness,
    g * contrast * brightness,
    b * contrast * brightness,
    0,
    0,
    r * contrast * brightness,
    g * contrast * brightness,
    b * contrast * brightness,
    0,
    0,
    r * contrast * brightness,
    g * contrast * brightness,
    b * contrast * brightness,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];
}

List<double> _storySepiaMatrix({
  double amount = 0.2,
  double brightness = 1.0,
  double contrast = 1.0,
  double saturation = 1.0,
}) {
  final t = 1 - amount;
  final r = 0.393 + 0.607 * t;
  final g = 0.769 - 0.769 * amount;
  final b = 0.189 - 0.189 * amount;
  final invSat = 1 - saturation;
  const lr = 0.2126, lg = 0.7152, lb = 0.0722;
  final c = contrast * brightness;
  return [
    (r * saturation + lr * invSat) * c,
    (g * saturation + lg * invSat) * c,
    (b * saturation + lb * invSat) * c,
    0,
    0,
    (0.349 * t + 0.349 * amount) * saturation * c + lr * invSat * c,
    (0.686 + 0.314 * t) * saturation * c + lg * invSat * c,
    (0.168 * t) * saturation * c + lb * invSat * c,
    0,
    0,
    (0.272 * t) * saturation * c + lr * invSat * c,
    (0.534 * t - 0.534 * amount) * saturation * c + lg * invSat * c,
    (0.131 + 0.869 * t) * saturation * c + lb * invSat * c,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];
}

List<double> _storyFilterMatrixFor(String name) {
  switch (name) {
    case 'Clarendon':
      return _storyFilterMatrixBase(brightness: 1.0, contrast: 1.2, saturation: 1.25);
    case 'Gingham':
      return _storyFilterMatrixBase(brightness: 1.05, contrast: 1.0, saturation: 1.0);
    case 'Moon':
      return _storyGrayscaleMatrix(contrast: 1.1, brightness: 1.1);
    case 'Lark':
      return _storyFilterMatrixBase(brightness: 1.0, contrast: 0.9, saturation: 1.0);
    case 'Reyes':
      return _storySepiaMatrix(amount: 0.22, brightness: 1.1, contrast: 0.85, saturation: 0.75);
    case 'Juno':
      return _storySepiaMatrix(amount: 0.2, brightness: 1.1, contrast: 1.2, saturation: 1.4);
    case 'Original':
    default:
      return _storyFilterMatrixBase(brightness: 1.0, contrast: 1.0, saturation: 1.0);
  }
}

class _StoryCameraScreenState extends State<StoryCameraScreen> with WidgetsBindingObserver {
  FlashMode _flashMode = FlashMode.off;
  bool _recording = false;
  UploadMode _mode = UploadMode.story;
  CameraController? _controller;
  bool _initializing = true;
  bool _permissionDenied = false;
  List<CameraDescription> _cameras = [];
  int _currentCameraIndex = 0;
  bool _isSwitchingCamera = false;
  final List<AssetEntity> _recentAssets = [];

  bool _isStoryEditing = false;
  Uint8List? _editingImageBytes;
  File? _editingVideoFile;
  VideoPlayerController? _editingVideoController;
  final GlobalKey _storyRepaintKey = GlobalKey();
  final List<_StoryOverlayElement> _storyElements = [];
  int? _storyActiveElementIndex;
  bool _storyDrawingMode = false;
  final List<_StoryStroke> _storyStrokes = [];
  final List<_StoryStroke> _storyRedo = [];
  double _storyBrushSize = 8.0;
  _StoryBrushType _storyBrushType = _StoryBrushType.pen;
  Color _storyCurrentColor = Colors.white;
  String _storyCurrentFilter = 'Original';
  Offset _storyLastFocalPoint = Offset.zero;
  double _storyTransformBaseScale = 1.0;
  double _storyTransformBaseRotation = 0.0;
  bool _storyToolsExpanded = false;
  bool _showMoreMenu = false;
  _ToolOverlayType? _activeToolOverlay;
  bool _boomerangEnabled = false;
  bool _boomerangProcessing = false;
  bool _boomerangStarting = false;
  bool _layoutMenuOpen = false;
  _StoryLayoutType? _selectedLayout;
  final List<Uint8List?> _layoutSlotImages = [];
  final List<bool> _layoutSlotFlips = [];
  int _layoutActiveIndex = 0;
  bool _storyFlipX = false;
  bool _hideStoryTextOverlaysForCapture = false;
  bool _isStoryTextDeleteMode = false;
  Timer? _storyTextHoldTimer;
  bool _storySuppressTextTap = false;
  final Map<int, double> _storyTextDeleteScale = {};
  Offset _storyLastLocalFocalPoint = Offset.zero;
  bool _storyTrashArmed = false;
  final List<_StorySticker> _storyStickers = [];
  int? _storyActiveStickerIndex;
  bool _isStoryStickerDeleteMode = false;
  Timer? _storyStickerHoldTimer;
  bool _storySuppressStickerTap = false;
  final Map<String, double> _storyStickerDeleteScale = {};
  Offset _storyStickerLastLocalFocalPoint = Offset.zero;
  double _storyStickerBaseScale = 1.0;
  double _storyStickerBaseRotation = 0.0;
  bool _handlingStickerGesture = false;
  static const double _storyStickerBaseSize = 72.0;
  final List<_StoryMention> _storyHiddenMentions = [];

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    _loadRecentMedia();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _storyTextHoldTimer?.cancel();
    _storyStickerHoldTimer?.cancel();
    _controller?.dispose();
    _controller = null;
    _editingVideoController?.dispose();
    _editingVideoController = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _initializeCameraController(_currentCameraIndex);
    }
  }

  Future<void> _initCamera() async {
    try {
      final camStatus = await Permission.camera.request();
      if (!camStatus.isGranted) {
        if (mounted) {
          setState(() {
            _permissionDenied = true;
            _initializing = false;
          });
        }
        return;
      }

      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        if (mounted) {
          setState(() {
            _permissionDenied = true;
            _initializing = false;
          });
        }
        return;
      }

      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _initializing = false;
          });
        }
        return;
      }

      await _initializeCameraController(_currentCameraIndex);

      if (mounted) {
        setState(() {
          _initializing = false;
        });
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _permissionDenied = true;
      });
    }
  }

  Future<void> _initializeCameraController(int cameraIndex) async {
    if (_controller != null) {
      await _controller!.dispose();
      _controller = null;
    }

    if (cameraIndex >= _cameras.length) {
      return;
    }

    final controller = CameraController(
      _cameras[cameraIndex],
      ResolutionPreset.high,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await controller.initialize();
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      await controller.setFlashMode(_flashMode);
      if (mounted) {
        setState(() {
          _controller = controller;
        });
      } else {
        await controller.dispose();
      }
    } catch (e) {
      debugPrint('Error initializing camera controller: $e');
      await controller.dispose();
    }
  }

  Future<void> _toggleFlash() async {
    FlashMode next;
    if (_flashMode == FlashMode.off) {
      next = FlashMode.auto;
    } else if (_flashMode == FlashMode.auto) {
      next = FlashMode.always;
    } else {
      next = FlashMode.off;
    }

    if (_controller == null) {
      setState(() {
        _flashMode = next;
      });
      return;
    }

    try {
      await _controller!.setFlashMode(next);
      if (mounted) {
        setState(() {
          _flashMode = next;
        });
      }
    } catch (_) {
      // Ignore failures for devices without flash support.
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) {
      return;
    }
    if (_isSwitchingCamera) {
      return;
    }

    setState(() {
      _isSwitchingCamera = true;
    });

    try {
      _currentCameraIndex = (_currentCameraIndex + 1) % _cameras.length;
      await _initializeCameraController(_currentCameraIndex);
    } finally {
      if (mounted) {
        setState(() {
          _isSwitchingCamera = false;
        });
      }
    }
  }

  Future<void> _loadRecentMedia() async {
    try {
      final PermissionState ps = await PhotoManager.requestPermissionExtend();
      if (!ps.isAuth) {
        return;
      }

      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.common,
        filterOption: FilterOptionGroup(
          orders: [const OrderOption(type: OrderOptionType.createDate, asc: false)],
        ),
      );

      if (albums.isEmpty) {
        return;
      }

      final recentAlbum = albums.first;
      final List<AssetEntity> media = await recentAlbum.getAssetListPaged(
        page: 0,
        size: 15,
      );

      if (!mounted) return;

      setState(() {
        _recentAssets
          ..clear()
          ..addAll(media);
      });
    } catch (e) {
      debugPrint('Error loading recent media: $e');
    }
  }

  Future<void> _onCapturePressed() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_controller!.value.isTakingPicture) return;
    if (_boomerangEnabled) {
      await _captureBoomerang();
      return;
    }
    if (_activeToolOverlay == _ToolOverlayType.draw) {
      if (_recording) {
        await _stopVideoAndNavigate();
      } else {
        await _onRecordStart();
      }
      return;
    }
    if (_controller!.value.isRecordingVideo) return;
    if (_activeToolOverlay == _ToolOverlayType.layout && _selectedLayout != null) {
      await _captureLayoutFrame();
      return;
    }
    try {
      final xfile = await _controller!.takePicture();
      await _navigateToEditor(
        File(xfile.path),
        MediaType.image,
        flipHorizontal: _isFrontCamera,
      );
    } catch (e) {
      debugPrint('Error capturing photo: $e');
    }
  }

  Future<void> _onRecordStart() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_controller!.value.isRecordingVideo) return;
    if (_boomerangEnabled) {
      await _startBoomerangRecording();
      return;
    }
    try {
      await _controller!.startVideoRecording();
      setState(() {
        _recording = true;
      });
    } catch (e) {
      debugPrint('Error starting video recording: $e');
    }
  }

  Future<void> _onRecordEnd() async {
    if (_controller == null || !_controller!.value.isRecordingVideo) {
      if (_recording) {
        setState(() {
          _recording = false;
        });
      }
      return;
    }
    if (_boomerangEnabled) {
      await _endBoomerangRecording();
      return;
    }
    try {
      final xfile = await _controller!.stopVideoRecording();
      setState(() {
        _recording = false;
      });
      _mode = UploadMode.story;
      File videoFile = File(xfile.path);
      try {
        await Future.delayed(const Duration(milliseconds: 200));
        final outputDir = await Directory.systemTemp.createTemp('story_video_');
        final outputPath = '${outputDir.path}/story_${DateTime.now().millisecondsSinceEpoch}.mp4';
        final cmd = '-y -i "${xfile.path}" -vf "transpose=cclock" -c:a copy -movflags +faststart "$outputPath"';
        final session = await FFmpegKit.execute(cmd);
        final returnCode = await session.getReturnCode();
        if (ReturnCode.isSuccess(returnCode)) {
          videoFile = File(outputPath);
          debugPrint('✅ Video transposed successfully');
        } else {
          debugPrint('⚠️ FFmpeg transpose failed, using original');
        }
      } catch (e) {
        debugPrint('FFmpeg error: $e');
      }
      await _navigateToEditor(
        videoFile,
        MediaType.video,
        flipHorizontal: _isFrontCamera,
        loopPreview: true,
      );
    } catch (e) {
      debugPrint('Error stopping video recording: $e');
      setState(() {
        _recording = false;
      });
    }
  }

  Future<void> _stopVideoAndNavigate() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (!_controller!.value.isRecordingVideo) {
      if (_recording) {
        setState(() {
          _recording = false;
        });
      }
      return;
    }
    try {
      final xfile = await _controller!.stopVideoRecording();
      if (mounted) {
        setState(() {
          _recording = false;
          _mode = UploadMode.story;
          _activeToolOverlay = null;
          _layoutMenuOpen = false;
          _selectedLayout = null;
          _layoutSlotImages.clear();
          _layoutActiveIndex = 0;
        });
      }
      File videoFile = File(xfile.path);
      try {
        await Future.delayed(const Duration(milliseconds: 200));
        final outputDir = await Directory.systemTemp.createTemp('story_video_');
        final outputPath = '${outputDir.path}/story_${DateTime.now().millisecondsSinceEpoch}.mp4';
        final cmd = '-y -i "${xfile.path}" -vf "transpose=cclock" -c:a copy -movflags +faststart "$outputPath"';
        final session = await FFmpegKit.execute(cmd);
        final returnCode = await session.getReturnCode();
        if (ReturnCode.isSuccess(returnCode)) {
          videoFile = File(outputPath);
          debugPrint('✅ Video transposed successfully');
        } else {
          debugPrint('⚠️ FFmpeg transpose failed, using original');
        }
      } catch (e) {
        debugPrint('FFmpeg error: $e');
      }
      await _navigateToEditor(
        videoFile,
        MediaType.video,
        flipHorizontal: _isFrontCamera,
        loopPreview: true,
      );
    } catch (e) {
      debugPrint('Error stopping video recording: $e');
      if (mounted) {
        setState(() {
          _recording = false;
        });
      }
    }
  }

  Future<void> _captureBoomerang() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_controller!.value.isRecordingVideo || _boomerangProcessing) return;
    _boomerangProcessing = true;
    try {
      await _controller!.startVideoRecording();
      setState(() {
        _recording = true;
      });
      await Future.delayed(const Duration(milliseconds: 900));
      if (!_controller!.value.isRecordingVideo) {
        _boomerangProcessing = false;
        return;
      }
      final xfile = await _controller!.stopVideoRecording();
      setState(() {
        _recording = false;
      });
      final ok = await _processBoomerang(File(xfile.path));
      if (!ok) {
        await _navigateToEditor(
          File(xfile.path),
          MediaType.video,
          flipHorizontal: _isFrontCamera,
          loopPreview: false,
        );
      }
    } catch (e) {
      debugPrint('Error capturing boomerang: $e');
      if (mounted) {
        setState(() {
          _recording = false;
        });
      }
    } finally {
      _boomerangProcessing = false;
    }
  }

  Future<void> _startBoomerangRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_controller!.value.isRecordingVideo || _boomerangProcessing) return;
    _boomerangProcessing = true;
    _boomerangStarting = true;
    try {
      await _controller!.startVideoRecording();
      setState(() {
        _recording = true;
      });
      _boomerangStarting = false;
    } catch (e) {
      debugPrint('Error starting boomerang recording: $e');
      _boomerangStarting = false;
      _boomerangProcessing = false;
    }
  }

  Future<void> _endBoomerangRecording() async {
    if (_controller == null || !_controller!.value.isRecordingVideo) {
      _boomerangProcessing = false;
      if (_recording) {
        setState(() {
          _recording = false;
        });
      }
      return;
    }
    if (_boomerangStarting) {
      await Future.delayed(const Duration(milliseconds: 120));
      if (_controller == null || !_controller!.value.isRecordingVideo) {
        _boomerangProcessing = false;
        _boomerangStarting = false;
        return;
      }
    }
    try {
      final xfile = await _controller!.stopVideoRecording();
      setState(() {
        _recording = false;
      });
      final ok = await _processBoomerang(File(xfile.path));
      if (!ok) {
        await _navigateToEditor(
          File(xfile.path),
          MediaType.video,
          flipHorizontal: _isFrontCamera,
          loopPreview: false,
        );
      }
    } catch (e) {
      debugPrint('Error stopping boomerang recording: $e');
      setState(() {
        _recording = false;
      });
    } finally {
      _boomerangProcessing = false;
    }
  }

  Future<bool> _processBoomerang(File input) async {
    // Give the recorder a moment to finalize the file before ffmpeg reads it.
    await Future.delayed(const Duration(milliseconds: 200));
    final outputDir = await Directory.systemTemp.createTemp('boomerang_');
    final outputPath =
        '${outputDir.path}/boomerang_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final cmd =
        '-y -i "${input.path}" -filter_complex "[0:v]reverse,setpts=PTS-STARTPTS[rev];[0:v][rev]concat=n=2:v=1:a=0,format=yuv420p" -an -movflags +faststart "$outputPath"';
    final session = await FFmpegKit.execute(cmd);
    final returnCode = await session.getReturnCode();
    if (ReturnCode.isSuccess(returnCode)) {
      await _navigateToEditor(
        File(outputPath),
        MediaType.video,
        flipHorizontal: _isFrontCamera,
        loopPreview: true,
      );
      return true;
    }
    debugPrint('Boomerang ffmpeg failed: $returnCode');
    return false;
  }

  Future<void> _onThumbnailTap(AssetEntity asset) async {
    final file = await asset.originFile;
    if (file == null) return;
    final type = asset.type == AssetType.video ? MediaType.video : MediaType.image;
    await _navigateToEditor(file, type, flipHorizontal: false, loopPreview: false);
  }

  void _openToolOverlay(_ToolOverlayType type, {Widget? icon}) {
    setState(() {
      _activeToolOverlay = type;
      _boomerangEnabled = type == _ToolOverlayType.boomerang;
      if (type != _ToolOverlayType.layout) {
        _layoutMenuOpen = false;
        _selectedLayout = null;
        _layoutSlotImages.clear();
        _layoutSlotFlips.clear();
        _layoutActiveIndex = 0;
      }
    });
  }

  void _closeToolOverlay() {
    setState(() {
      _activeToolOverlay = null;
      _boomerangEnabled = false;
      _layoutMenuOpen = false;
      _selectedLayout = null;
      _layoutSlotImages.clear();
      _layoutSlotFlips.clear();
      _layoutActiveIndex = 0;
    });
  }

  bool get _isFrontCamera {
    if (_cameras.isEmpty || _currentCameraIndex >= _cameras.length) {
      return false;
    }
    return _cameras[_currentCameraIndex].lensDirection == CameraLensDirection.front;
  }

  Future<void> _navigateToEditor(
    File file,
    MediaType type, {
    bool asReel = false,
    bool flipHorizontal = false,
    bool loopPreview = false,
  }) async {
    if (!mounted) return;
    
    if (_mode == UploadMode.story && type == MediaType.image && !asReel) {
      debugPrint('Loading image for story editor: ${file.path}');
      
      try {
        final bytes = await file.readAsBytes();
        debugPrint('Image bytes loaded: ${bytes.length} bytes');
        
        if (!mounted) return;
        
        setState(() {
          _editingImageBytes = bytes;
          _isStoryEditing = true;
          _storyElements.clear();
          _storyStrokes.clear();
          _storyRedo.clear();
          _storyDrawingMode = false;
          _storyBrushSize = 8.0;
          _storyCurrentColor = Colors.white;
          _storyCurrentFilter = 'Original';
          _storyFlipX = flipHorizontal;
        });
        
        debugPrint('Story editor state updated');
      } catch (e) {
        debugPrint('Error loading image: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load image: $e')),
          );
        }
      }
      return;
    }

    if (_mode == UploadMode.story && type == MediaType.video && !asReel) {
      try {
        _editingVideoController?.dispose();
        _editingVideoController = VideoPlayerController.file(file);
        await _editingVideoController!.initialize();
        debugPrint(
          '🎬 video size=${_editingVideoController!.value.size} ar=${_editingVideoController!.value.aspectRatio} rot=${_editingVideoController!.value.rotationCorrection}',
        );
        await _editingVideoController!.setLooping(loopPreview);
        await _editingVideoController!.play();

        if (!mounted) return;
        setState(() {
          _editingVideoFile = file;
          _editingImageBytes = null;
          _isStoryEditing = true;
          _storyElements.clear();
          _storyStrokes.clear();
          _storyRedo.clear();
          _storyDrawingMode = false;
          _storyBrushSize = 8.0;
          _storyCurrentColor = Colors.white;
          _storyCurrentFilter = 'Original';
          _storyFlipX = flipHorizontal;
        });
      } catch (e) {
        debugPrint('Error loading video for story editor: $e');
      }
      return;
    }
    
    final media = MediaItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      filePath: file.path,
      createdAt: DateTime.now(),
    );

    if (asReel) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => CreateEditPreviewScreen(
            media: media,
            selectedFilter: _storyCurrentFilter,
            isPostFlow: false,
          ),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreatePostScreen(
          initialMedia: media,
        ),
      ),
    );
  }

  Future<void> _captureLayoutFrame() async {
    if (_selectedLayout == null) return;
    if (_layoutSlotImages.isEmpty) {
      _layoutSlotImages.addAll(
        List<Uint8List?>.filled(
          _layoutRects(const Size(1080, 1920), _selectedLayout!, 0).length,
          null,
        ),
      );
      _layoutSlotFlips.addAll(
        List<bool>.filled(
          _layoutRects(const Size(1080, 1920), _selectedLayout!, 0).length,
          false,
        ),
      );
    }
    try {
      final xfile = await _controller!.takePicture();
      final bytes = await File(xfile.path).readAsBytes();
      if (_layoutActiveIndex < _layoutSlotImages.length) {
        _layoutSlotImages[_layoutActiveIndex] = bytes;
        _layoutSlotFlips[_layoutActiveIndex] = _isFrontCamera;
      }
      final next = _layoutSlotImages.indexWhere((e) => e == null);
      if (next == -1) {
        await _composeLayoutAndOpenEditor();
      } else {
        setState(() {
          _layoutActiveIndex = next;
        });
      }
    } catch (e) {
      debugPrint('Error capturing layout frame: $e');
    }
  }

  Future<void> _composeLayoutAndOpenEditor() async {
    if (_selectedLayout == null) return;
    const targetSize = Size(1080, 1920);
    final rects = _layoutRects(targetSize, _selectedLayout!, 0);
    if (rects.isEmpty) return;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Offset.zero & targetSize);
    canvas.drawRect(Offset.zero & targetSize, Paint()..color = Colors.black);

    for (var i = 0; i < rects.length; i++) {
      final bytes = i < _layoutSlotImages.length ? _layoutSlotImages[i] : null;
      if (bytes == null) continue;
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final srcSize = Size(image.width.toDouble(), image.height.toDouble());
      final dst = rects[i];
      final srcAspect = srcSize.width / srcSize.height;
      final dstAspect = dst.width / dst.height;
      Rect src;
      if (srcAspect > dstAspect) {
        final newW = srcSize.height * dstAspect;
        final x = (srcSize.width - newW) / 2;
        src = Rect.fromLTWH(x, 0, newW, srcSize.height);
      } else {
        final newH = srcSize.width / dstAspect;
        final y = (srcSize.height - newH) / 2;
        src = Rect.fromLTWH(0, y, srcSize.width, newH);
      }
      final flip = i < _layoutSlotFlips.length && _layoutSlotFlips[i];
      if (flip) {
        canvas.save();
        canvas.translate(dst.left + dst.width, dst.top);
        canvas.scale(-1, 1);
        final flippedDst = Rect.fromLTWH(0, 0, dst.width, dst.height);
        canvas.drawImageRect(image, src, flippedDst, Paint());
        canvas.restore();
      } else {
        canvas.drawImageRect(image, src, dst, Paint());
      }
    }

    final picture = recorder.endRecording();
    final outImage = await picture.toImage(
      targetSize.width.toInt(),
      targetSize.height.toInt(),
    );
    final byteData = await outImage.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return;

    if (!mounted) return;
    setState(() {
      _editingImageBytes = byteData.buffer.asUint8List();
      _editingVideoFile = null;
      _editingVideoController?.dispose();
      _editingVideoController = null;
      _isStoryEditing = true;
      _storyElements.clear();
      _storyStrokes.clear();
      _storyRedo.clear();
      _storyDrawingMode = false;
      _storyBrushSize = 8.0;
      _storyCurrentColor = Colors.white;
      _storyCurrentFilter = 'Original';
      _storyFlipX = false;
      _layoutMenuOpen = false;
      _activeToolOverlay = null;
    });
  }

  Widget _buildCaptureControls() {
    final handsFreeActive = _activeToolOverlay == _ToolOverlayType.draw;
    return GestureDetector(
      onTap: _onCapturePressed,
      onLongPressStart: handsFreeActive ? null : (_) => _onRecordStart(),
      onLongPressEnd: handsFreeActive ? null : (_) => _onRecordEnd(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 3,
          ),
        ),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: _recording ? 28 : 56,
            height: _recording ? 28 : 56,
            decoration: BoxDecoration(
              color: _recording ? const Color(0xFFED4956) : const Color(0xFFE6E6E6),
              borderRadius: BorderRadius.circular(_recording ? 8 : 34),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeTabs() {
    final allowSwitch = !widget.lockMode;
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: allowSwitch
                ? () async {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const CreateUploadScreen(),
                      ),
                    );
                  }
                : null,
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: TextStyle(
                color:
                    _mode == UploadMode.post ? Colors.white : (allowSwitch ? Colors.white54 : Colors.white38),
                fontWeight: _mode == UploadMode.post ? FontWeight.bold : FontWeight.w500,
                letterSpacing: 1.2,
              ),
              child: const Text('POST'),
            ),
          ),
          const SizedBox(width: 14),
          GestureDetector(
            onTap: allowSwitch
                ? () {
                    setState(() {
                      _mode = UploadMode.story;
                    });
                  }
                : () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => const StoryCameraScreen(
                          initialMode: UploadMode.story,
                        ),
                      ),
                    );
                  },
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: TextStyle(
                color: _mode == UploadMode.story ? Colors.white : Colors.white54,
                fontWeight: _mode == UploadMode.story ? FontWeight.bold : FontWeight.w500,
                letterSpacing: 1.2,
              ),
              child: const Text('STORY'),
            ),
          ),
          const SizedBox(width: 14),
          GestureDetector(
            onTap: allowSwitch
                ? () {
                    setState(() {
                      _mode = UploadMode.reel;
                    });
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const CreateUploadScreen(
                          initialMode: UploadMode.reel,
                        ),
                      ),
                    );
                  }
                : null,
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: TextStyle(
                color:
                    _mode == UploadMode.reel ? Colors.white : (allowSwitch ? Colors.white54 : Colors.white38),
                fontWeight: _mode == UploadMode.reel ? FontWeight.bold : FontWeight.w500,
                letterSpacing: 1.2,
              ),
              child: const Text('REEL'),
            ),
          ),
          const SizedBox(width: 14),
          GestureDetector(
            onTap: allowSwitch
                ? () {
                    setState(() {
                      _mode = UploadMode.live;
                    });
                  }
                : null,
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: TextStyle(
                color:
                    _mode == UploadMode.live ? Colors.white : (allowSwitch ? Colors.white54 : Colors.white38),
                fontWeight: _mode == UploadMode.live ? FontWeight.bold : FontWeight.w500,
                letterSpacing: 1.2,
              ),
              child: const Text('LIVE'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryToolItem({
    Key? key,
    required Widget icon,
    required String label,
    Widget? badge,
    Widget? iconOverlay,
    required bool showLabel,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        key: key,
        padding: const EdgeInsets.only(bottom: 22),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(child: icon),
                  if (iconOverlay != null) iconOverlay,
                ],
              ),
            ),
            const SizedBox(width: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              layoutBuilder: (currentChild, previousChildren) {
                return Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                );
              },
              child: showLabel
                  ? Column(
                      key: const ValueKey('label_on'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (badge != null) ...[
                          badge,
                          const SizedBox(height: 4),
                        ],
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  : const SizedBox(
                      key: ValueKey('label_off'),
                      width: 0,
                      height: 0,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryTools() {
    final hasActive = _activeToolOverlay != null;
    final active = _activeToolOverlay;
    Widget wrap(_ToolOverlayType type, Widget Function(bool isActive) builder) {
      final dim = hasActive && active != type;
      final isActive = active == type;
      return Opacity(
        opacity: dim ? 0.25 : 1.0,
        child: IgnorePointer(
          ignoring: dim,
          child: builder(isActive),
        ),
      );
    }

    Widget buildCloseOverlay() {
      return Positioned(
        right: -10,
        bottom: -10,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _closeToolOverlay,
          child: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close, color: Colors.white, size: 14),
          ),
        ),
      );
    }

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        wrap(
          _ToolOverlayType.create,
          (isActive) => _buildStoryToolItem(
            icon: const Text(
              'Aa',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
            iconOverlay: isActive ? buildCloseOverlay() : null,
            label: 'Create',
            showLabel: _storyToolsExpanded,
            onTap: () {
              _boomerangEnabled = false;
              _openToolOverlay(
                _ToolOverlayType.create,
                icon: const Text('Aa', style: TextStyle(color: Colors.black, fontSize: 34, fontWeight: FontWeight.w700)),
              );
            },
          ),
        ),
        wrap(
          _ToolOverlayType.boomerang,
          (isActive) => _buildStoryToolItem(
            icon: const Icon(Icons.all_inclusive, color: Colors.white, size: 26),
            iconOverlay: isActive ? buildCloseOverlay() : null,
            label: 'Boomerang',
            showLabel: _storyToolsExpanded,
            onTap: () {
              _boomerangEnabled = true;
              _openToolOverlay(
                _ToolOverlayType.boomerang,
                icon: const Icon(Icons.all_inclusive, color: Colors.black, size: 36),
              );
            },
          ),
        ),
        wrap(
          _ToolOverlayType.layout,
          (isActive) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStoryToolItem(
                icon: const Icon(Icons.grid_view_rounded, color: Colors.white, size: 24),
                iconOverlay: isActive ? buildCloseOverlay() : null,
                label: 'Layout',
                showLabel: _storyToolsExpanded,
                onTap: () {
                  _boomerangEnabled = false;
                  _openToolOverlay(
                    _ToolOverlayType.layout,
                    icon: const Icon(Icons.grid_view_rounded, color: Colors.black, size: 34),
                  );
                  if (_selectedLayout == null) {
                    setState(() {
                      _selectedLayout = _StoryLayoutType.grid2x2;
                      _layoutSlotImages
                        ..clear()
                        ..addAll(List<Uint8List?>.filled(
                          _layoutRects(const Size(1080, 1920), _StoryLayoutType.grid2x2, 0).length,
                          null,
                        ));
                      _layoutSlotFlips
                        ..clear()
                        ..addAll(List<bool>.filled(
                          _layoutRects(const Size(1080, 1920), _StoryLayoutType.grid2x2, 0).length,
                          false,
                        ));
                      _layoutActiveIndex = 0;
                    });
                  }
                },
              ),
              if (isActive)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() {
                      _layoutMenuOpen = !_layoutMenuOpen;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white54, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.grid_on_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        wrap(
          _ToolOverlayType.ai,
          (isActive) => _buildStoryToolItem(
            icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.white, size: 24),
            iconOverlay: isActive ? buildCloseOverlay() : null,
            badge: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'NEW',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            label: 'AI images',
            showLabel: _storyToolsExpanded,
            onTap: () {
              _boomerangEnabled = false;
              _openToolOverlay(
                _ToolOverlayType.ai,
                icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.black, size: 34),
              );
            },
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: _storyToolsExpanded
              ? wrap(
                  _ToolOverlayType.draw,
                  (isActive) => _buildStoryToolItem(
                    key: const ValueKey('handsfree'),
                    icon: const Icon(Icons.pan_tool_alt_outlined, color: Colors.white, size: 22),
                    iconOverlay: isActive ? buildCloseOverlay() : null,
                    label: 'Hands-free',
                    showLabel: true,
                    onTap: () => _openToolOverlay(
                      _ToolOverlayType.draw,
                      icon: const Icon(Icons.pan_tool_alt_outlined, color: Colors.black, size: 34),
                    ),
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('handsfree_empty')),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            setState(() {
              if (hasActive) {
                _closeToolOverlay();
              } else {
                _storyToolsExpanded = !_storyToolsExpanded;
              }
            });
          },
          child: SizedBox(
            width: 40,
            height: 40,
            child: Center(
              child: AnimatedRotation(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                turns: _storyToolsExpanded ? 0.5 : 0.0,
                child: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 28),
              ),
            ),
          ),
        ),
      ],
    );

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      alignment: Alignment.topLeft,
      child: content,
    );
  }

  List<Rect> _layoutRects(Size size, _StoryLayoutType type, double gap) {
    final w = size.width;
    final h = size.height;
    switch (type) {
      case _StoryLayoutType.grid2x2:
        final cw = (w - gap) / 2;
        final ch = (h - gap) / 2;
        return [
          Rect.fromLTWH(0, 0, cw, ch),
          Rect.fromLTWH(cw + gap, 0, cw, ch),
          Rect.fromLTWH(0, ch + gap, cw, ch),
          Rect.fromLTWH(cw + gap, ch + gap, cw, ch),
        ];
      case _StoryLayoutType.twoVertical:
        final ch = (h - gap) / 2;
        return [
          Rect.fromLTWH(0, 0, w, ch),
          Rect.fromLTWH(0, ch + gap, w, ch),
        ];
      case _StoryLayoutType.twoHorizontal:
        final cw = (w - gap) / 2;
        return [
          Rect.fromLTWH(0, 0, cw, h),
          Rect.fromLTWH(cw + gap, 0, cw, h),
        ];
      case _StoryLayoutType.threeVertical:
        final ch = (h - gap * 2) / 3;
        return [
          Rect.fromLTWH(0, 0, w, ch),
          Rect.fromLTWH(0, ch + gap, w, ch),
          Rect.fromLTWH(0, (ch + gap) * 2, w, ch),
        ];
      case _StoryLayoutType.onePlusTwo:
        final leftW = (w - gap) * 0.55;
        final rightW = w - gap - leftW;
        final ch = (h - gap) / 2;
        return [
          Rect.fromLTWH(0, 0, leftW, h),
          Rect.fromLTWH(leftW + gap, 0, rightW, ch),
          Rect.fromLTWH(leftW + gap, ch + gap, rightW, ch),
        ];
      case _StoryLayoutType.twoPlusOne:
        final cw = (w - gap) / 2;
        final topH = (h - gap) * 0.55;
        final bottomH = h - gap - topH;
        return [
          Rect.fromLTWH(0, 0, cw, topH),
          Rect.fromLTWH(cw + gap, 0, cw, topH),
          Rect.fromLTWH(0, topH + gap, w, bottomH),
        ];
    }
  }

  Widget _buildLayoutThumb(_StoryLayoutType type) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final rects = _layoutRects(Size(constraints.maxWidth, constraints.maxHeight), type, 4);
        return Stack(
          children: rects
              .map(
                (r) => Positioned(
                  left: r.left,
                  top: r.top,
                  width: r.width,
                  height: r.height,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white70, width: 1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildLayoutMenu() {
    if (!_layoutMenuOpen || _activeToolOverlay != _ToolOverlayType.layout) {
      return const SizedBox.shrink();
    }

    final items = [
      _StoryLayoutType.grid2x2,
      _StoryLayoutType.twoVertical,
      _StoryLayoutType.twoHorizontal,
      _StoryLayoutType.threeVertical,
      _StoryLayoutType.onePlusTwo,
      _StoryLayoutType.twoPlusOne,
    ];

    return Positioned(
      left: 70,
      top: 300,
      child: AnimatedOpacity(
        opacity: _layoutMenuOpen ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF4A4A4A),
            borderRadius: BorderRadius.circular(16),
          ),
          child: SizedBox(
            width: 190,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: items.map((type) {
                final selected = _selectedLayout == type;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedLayout = type;
                      _layoutMenuOpen = false;
                      _layoutSlotImages
                        ..clear()
                        ..addAll(List<Uint8List?>.filled(_layoutRects(const Size(1080, 1920), type, 0).length, null));
                      _layoutSlotFlips
                        ..clear()
                        ..addAll(List<bool>.filled(_layoutRects(const Size(1080, 1920), type, 0).length, false));
                      _layoutActiveIndex = 0;
                    });
                  },
                  child: Container(
                    width: 54,
                    height: 54,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: selected ? Colors.white24 : Colors.white10,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? Colors.white : Colors.white30,
                        width: 1,
                      ),
                    ),
                    child: _buildLayoutThumb(type),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLayoutOverlay() {
    if (_selectedLayout == null) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final rects = _layoutRects(
          Size(constraints.maxWidth, constraints.maxHeight),
          _selectedLayout!,
          0,
        );
        final activeRect = rects.isNotEmpty && _layoutActiveIndex < rects.length
            ? rects[_layoutActiveIndex]
            : Rect.zero;

        return Stack(
          children: [
            Positioned.fill(
              child: ClipRect(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    color: const Color(0x730B0F14),
                  ),
                ),
              ),
            ),
            ...rects.asMap().entries.map((entry) {
              final i = entry.key;
              final r = entry.value;
              final imageBytes = i < _layoutSlotImages.length ? _layoutSlotImages[i] : null;
              if (i == _layoutActiveIndex) return const SizedBox.shrink();
              if (imageBytes == null) return const SizedBox.shrink();
              return Positioned(
                left: r.left,
                top: r.top,
                width: r.width,
                height: r.height,
                child: ClipRect(
                  child: SizedBox(
                    width: r.width,
                    height: r.height,
                    child: Image.memory(
                      imageBytes,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              );
            }),
            if (activeRect != Rect.zero)
              Positioned(
                left: activeRect.left,
                top: activeRect.top,
                width: activeRect.width,
                height: activeRect.height,
                child: ClipRect(
                  child: SizedBox(
                    width: activeRect.width,
                    height: activeRect.height,
                    child: _buildCameraPreview(),
                  ),
                ),
              ),
            Positioned.fill(
              child: CustomPaint(
                painter: _LayoutMaskPainter(
                  rects: rects,
                  activeRect: activeRect,
                  borderRadius: 0,
                  maskColor: const Color(0xCC000000),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGalleryShortcut() {
    if (_recentAssets.isEmpty) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white10,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 2),
        ),
        child: const Icon(Icons.photo_library_outlined, color: Colors.white, size: 20),
      );
    }
    final asset = _recentAssets.first;
    return GestureDetector(
      onTap: () => _onThumbnailTap(asset),
      child: ClipOval(
        child: FutureBuilder<Uint8List?>(
          future: asset.thumbnailDataWithSize(const ThumbnailSize(200, 200)),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done || snapshot.data == null) {
              return Container(
                width: 44,
                height: 44,
                color: Colors.grey[900],
              );
            }
            return Image.memory(
              snapshot.data!,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
            );
          },
        ),
      ),
    );
  }

  Widget _buildReverseIcon() {
    return GestureDetector(
      onTap: _isSwitchingCamera ? null : _switchCamera,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white10,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 2),
        ),
        child: Center(
          child: _isSwitchingCamera
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.cached_rounded, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  Widget _buildEditIconButton({
    required Widget child,
    required VoidCallback onTap,
    double size = 44,
    Color bg = const Color(0xFF3A3A3A),
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
        ),
        child: Center(child: child),
      ),
    );
  }

  Widget _buildEditActionRow({
    required String label,
    required Widget icon,
    required VoidCallback onTap,
    required bool showLabel,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: showLabel
              ? Text(
                  label,
                  key: const ValueKey('edit_label_on'),
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                )
              : const SizedBox(
                  key: ValueKey('edit_label_off'),
                  width: 0,
                  height: 0,
                ),
        ),
        if (showLabel) const SizedBox(width: 10),
        _buildEditIconButton(onTap: onTap, child: icon),
      ],
    );
  }

  Widget _buildCameraPreview() {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _controller!.value.previewSize!.height,
          height: _controller!.value.previewSize!.width,
          child: CameraPreview(_controller!),
        ),
      ),
    );
  }

  Widget _buildStoryEditingUi(BuildContext context) {
    final imageBytes = _editingImageBytes;
    final videoController = _editingVideoController;
    const double storyPreviewBottomInset = 70; // 42 height + 16 bottom spacing + 12 gap
    const double storyPreviewCornerRadius = 24;

    if (imageBytes == null && (videoController == null || !videoController.value.isInitialized)) {
      debugPrint('⚠️ Media not ready in story editor build');
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text('Loading...', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
    }

    if (imageBytes != null) {
      debugPrint('✅ Building story editor UI with ${imageBytes.length} bytes');
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  debugPrint('📐 Layout constraints: ${constraints.maxWidth}x${constraints.maxHeight}');

                  return GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onScaleStart: (details) {
                      if (_handlingStickerGesture) return;
                      if (_storyDrawingMode || _storyElements.isEmpty) return;
                      final activeIndex = _storyActiveElementIndex ?? (_storyElements.length - 1);
                      _storyActiveElementIndex = activeIndex;
                      _storyLastFocalPoint = details.focalPoint;
                      _storyLastLocalFocalPoint = _toStoryLocal(details.focalPoint);
                      final element = _storyElements[activeIndex];
                      _storyTransformBaseScale = element.scale;
                      _storyTransformBaseRotation = element.rotation;
                    },
                    onScaleUpdate: (details) {
                      if (_handlingStickerGesture) return;
                      if (_storyDrawingMode || _storyElements.isEmpty) return;
                      final activeIndex = _storyActiveElementIndex ?? (_storyElements.length - 1);
                      final element = _storyElements[activeIndex];
                      final delta = details.focalPoint - _storyLastFocalPoint;
                      _storyLastFocalPoint = details.focalPoint;
                      _storyLastLocalFocalPoint = _toStoryLocal(details.focalPoint);

                      double newScale = element.scale;
                      double newRotation = element.rotation;

                      if (details.pointerCount > 1) {
                        newScale = (_storyTransformBaseScale * details.scale).clamp(0.2, 8.0);
                        newRotation = _storyTransformBaseRotation + details.rotation;
                      }

                      setState(() {
                        if (_isStoryTextDeleteMode) {
                          _updateStoryTextDeleteScale(activeIndex);
                        }
                        final nextPosition = _clampStoryTextPosition(
                          element,
                          element.position + delta,
                          newScale,
                        );
                        _storyElements[activeIndex] = element.copyWith(
                          position: nextPosition,
                          scale: newScale,
                          rotation: newRotation,
                        );
                      });
                    },
                    onScaleEnd: (_) {
                      if (_handlingStickerGesture) return;
                      if (_isStoryTextDeleteMode) {
                        final activeIndex = _storyActiveElementIndex ?? (_storyElements.length - 1);
                        _handleStoryTextDeleteEnd(activeIndex);
                      }
                    },
                    child: Stack(
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final availableW = constraints.maxWidth;
                            final availableH = constraints.maxHeight - storyPreviewBottomInset;

                            return Align(
                              alignment: Alignment.topCenter,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: availableW,
                                  maxHeight: availableH,
                                ),
                                child: AspectRatio(
                                  aspectRatio: 9 / 16,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(storyPreviewCornerRadius),
                                    child: RepaintBoundary(
                                      key: _storyRepaintKey,
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          if (imageBytes != null)
                                            _maybeFlipStoryMedia(
                                              ColorFiltered(
                                                colorFilter: ColorFilter.matrix(_storyFilterMatrixFor(_storyCurrentFilter)),
                                                child: Image.memory(
                                                  imageBytes,
                                                  fit: BoxFit.cover,
                                                  gaplessPlayback: true,
                                                  errorBuilder: (context, error, stackTrace) {
                                                    debugPrint('❌ Error displaying image: $error');
                                                    return Container(
                                                      color: Colors.grey[900],
                                                      child: Column(
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        children: [
                                                          const Icon(Icons.error, color: Colors.white, size: 48),
                                                          const SizedBox(height: 8),
                                                          Padding(
                                                            padding: const EdgeInsets.all(16.0),
                                                            child: Text(
                                                              'Error: $error',
                                                              style: const TextStyle(color: Colors.white),
                                                              textAlign: TextAlign.center,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            )
                                          else if (videoController != null)
                                            Positioned.fill(
                                              child: Transform(
                                                alignment: Alignment.center,
                                                transform: Matrix4.diagonal3Values(
                                                  _storyFlipX ? -1.0 : 1.0,
                                                  1.0,
                                                  1.0,
                                                ),
                                                child: Builder(
                                                  builder: (context) {
                                                    final double w = videoController.value.size.width;
                                                    final double h = videoController.value.size.height;
                                                    return FittedBox(
                                                      fit: BoxFit.cover,
                                                      clipBehavior: Clip.hardEdge,
                                                      child: SizedBox(
                                                        width: w,
                                                        height: h,
                                                        child: VideoPlayer(videoController),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                          CustomPaint(painter: _StoryDrawingPainter(_storyStrokes)),
                                          ..._storyStickers.asMap().entries.map((entry) {
                                            final index = entry.key;
                                            final s = entry.value;
                                            final isActive = _storyActiveStickerIndex == index;
                                            final deleteScale =
                                                _storyStickerDeleteScale[s.id] ?? 1.0;
                                            final isDeleting =
                                                _isStoryStickerDeleteMode && isActive;
                                            return Positioned(
                                              key: ValueKey('sticker_${s.id}'),
                                              left: s.position.dx,
                                              top: s.position.dy,
                                              child: Transform.rotate(
                                                angle: s.rotation,
                                                child: Transform.scale(
                                                  scale: s.scale,
                                                  child: GestureDetector(
                                                    onTapDown: (d) {
                                                      _storyStickerLastLocalFocalPoint =
                                                          _toStoryLocal(d.globalPosition);
                                                      _startStoryStickerHold(index);
                                                    },
                                                    onTapUp: (_) =>
                                                        _handleStoryStickerDeleteEnd(index),
                                                    onTapCancel: _cancelStoryStickerHold,
                                                    onTap: () {
                                                      if (_storySuppressStickerTap) {
                                                        setState(() => _storySuppressStickerTap = false);
                                                        return;
                                                      }
                                                      if (_isStoryStickerDeleteMode) {
                                                        _exitStoryStickerDeleteMode();
                                                        return;
                                                      }
                                                      setState(() {
                                                        _storyActiveStickerIndex = index;
                                                        _storyActiveElementIndex = null;
                                                      });
                                                    },
                                                    onScaleStart: (d) {
                                                      _handlingStickerGesture = true;
                                                      setState(() {
                                                        _storyActiveStickerIndex = index;
                                                        _storyActiveElementIndex = null;
                                                      });
                                                      _storyStickerLastLocalFocalPoint =
                                                          _toStoryLocal(d.focalPoint);
                                                      _storyStickerBaseScale = _storyStickers[index].scale;
                                                      _storyStickerBaseRotation = _storyStickers[index].rotation;
                                                      _cancelStoryStickerHold();
                                                    },
                                                    onScaleUpdate: (d) {
                                                      final current = _storyStickers[index];
                                                      final local =
                                                          _toStoryLocal(d.focalPoint);
                                                      final delta =
                                                          local - _storyStickerLastLocalFocalPoint;
                                                      _storyStickerLastLocalFocalPoint = local;
                                                      double newScale = current.scale;
                                                      double newRotation = current.rotation;
                                                      if (d.pointerCount > 1) {
                                                        newScale = (_storyStickerBaseScale * d.scale)
                                                            .clamp(0.4, 6.0);
                                                        newRotation = _storyStickerBaseRotation + d.rotation;
                                                      }
                                                      final nextPos = _clampStoryStickerPosition(
                                                        current.position + delta,
                                                        newScale,
                                                      );
                                                      setState(() {
                                                        if (_isStoryStickerDeleteMode) {
                                                          _updateStoryStickerDeleteScale(index);
                                                        }
                                                        _storyStickers[index] = current.copyWith(
                                                          position: nextPos,
                                                          scale: newScale,
                                                          rotation: newRotation,
                                                        );
                                                      });
                                                    },
                                                    onScaleEnd: (_) {
                                                      _handlingStickerGesture = false;
                                                      if (_isStoryStickerDeleteMode) {
                                                        _handleStoryStickerDeleteEnd(index);
                                                      }
                                                    },
                                                    child: AnimatedOpacity(
                                                      duration: const Duration(milliseconds: 160),
                                                      opacity:
                                                          isDeleting && _storyTrashArmed ? 0.2 : 1.0,
                                                      child: AnimatedScale(
                                                        duration: const Duration(milliseconds: 160),
                                                        scale: isDeleting ? deleteScale : 1.0,
                                                        child: _buildStoryStickerWidget(
                                                          s.type,
                                                          size: _storyStickerBaseSize,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          }),
                                          if (!_hideStoryTextOverlaysForCapture)
                                            ..._storyElements.asMap().entries.map(
                                              (entry) {
                                                final index = entry.key;
                                                final e = entry.value;
                                                final isActive = _storyActiveElementIndex == null
                                                    ? index == _storyElements.length - 1
                                                    : index == _storyActiveElementIndex;
                                                final deleteScale = _storyTextDeleteScale[index] ?? 1.0;
                                                final isDeleting = _isStoryTextDeleteMode &&
                                                    _storyActiveElementIndex == index;
                                                return _StoryElementWidget(
                                                  key: ValueKey(e.hashCode),
                                                  element: e,
                                                  isActive: isActive,
                                                  deleteScale: isDeleting ? deleteScale : 1.0,
                                                  showDeleteFade: isDeleting && _storyTrashArmed,
                                                  onTap: () {
                                                    if (e.type == _StoryElementType.text) {
                                                      if (_storySuppressTextTap) {
                                                        setState(() => _storySuppressTextTap = false);
                                                        return;
                                                      }
                                                      if (_isStoryTextDeleteMode) {
                                                        _exitStoryTextDeleteMode();
                                                        return;
                                                      }
                                                      setState(() {
                                                        _storyActiveElementIndex = index;
                                                      });
                                                      _storyEditText(e);
                                                    }
                                                  },
                                                  onTapDown: (d) {
                                                    _storyLastLocalFocalPoint =
                                                        _toStoryLocal(d.globalPosition);
                                                    _startStoryTextHold(index);
                                                  },
                                                  onTapUp: (_) => _handleStoryTextDeleteEnd(index),
                                                  onTapCancel: _cancelStoryTextHold,
                                                );
                                              },
                                            ),
                                          const Positioned(
                                            left: 16,
                                            right: 16,
                                            bottom: 12,
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                'Add a caption...',
                                                style: TextStyle(color: Colors.white70, fontSize: 16),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        if (_storyDrawingMode)
                          Positioned.fill(
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onPanStart: (d) => _startStoryStroke(d.localPosition),
                              onPanUpdate: (d) => _appendStoryStroke(d.localPosition),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        if (!_storyDrawingMode)
                          Positioned(
                            left: 16,
                            top: 16,
                            child: ClipOval(
                              child: Material(
                                color: Colors.black.withAlpha(140),
                                child: IconButton(
                                  icon: const Icon(Icons.close, color: Colors.white),
                                  onPressed: _exitStoryEditing,
                                ),
                              ),
                            ),
                          ),
                        if (!_storyDrawingMode)
                          Positioned(
                            right: 16,
                            top: 16,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _buildEditActionRow(
                                  label: 'Text',
                                  onTap: _storyAddText,
                                  showLabel: _storyToolsExpanded,
                                  icon: const Text(
                                    'Aa',
                                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _buildEditActionRow(
                                  label: 'Stickers',
                                  onTap: _openStoryStickerPicker,
                                  showLabel: _storyToolsExpanded,
                                  icon: const Icon(LucideIcons.sticker, color: Colors.white, size: 22),
                                ),
                                const SizedBox(height: 10),
                                _buildEditActionRow(
                                  label: 'Audio',
                                  onTap: () {},
                                  showLabel: _storyToolsExpanded,
                                  icon: const Icon(LucideIcons.music, color: Colors.white, size: 22),
                                ),
                                const SizedBox(height: 10),
                                _buildEditActionRow(
                                  label: 'Effects',
                                  onTap: () {},
                                  showLabel: _storyToolsExpanded,
                                  icon: const Icon(LucideIcons.sparkles, color: Colors.white, size: 22),
                                ),
                                const SizedBox(height: 10),
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeInOut,
                                  alignment: Alignment.topRight,
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 180),
                                    switchInCurve: Curves.easeOut,
                                    switchOutCurve: Curves.easeIn,
                                    child: _storyToolsExpanded
                                        ? Column(
                                            key: const ValueKey('edit_more_menu'),
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              const SizedBox(height: 10),
                                              _buildEditActionRow(
                                                label: 'Mention',
                                                onTap: _openStoryMentionSheet,
                                                showLabel: true,
                                                icon: const Icon(Icons.alternate_email, color: Colors.white, size: 22),
                                              ),
                                              const SizedBox(height: 10),
                                              _buildEditActionRow(
                                                label: 'Draw',
                                                onTap: () {
                                                  setState(() {
                                                    _storyDrawingMode = true;
                                                    _storyBrushType = _StoryBrushType.pen;
                                                  });
                                                },
                                                showLabel: true,
                                                icon: const Icon(LucideIcons.pencil, color: Colors.white, size: 22),
                                              ),
                                              const SizedBox(height: 10),
                                              _buildEditActionRow(
                                                label: 'Download',
                                                onTap: () {},
                                                showLabel: true,
                                                icon: const Icon(Icons.download_rounded, color: Colors.white, size: 22),
                                              ),
                                              const SizedBox(height: 10),
                                              _buildEditActionRow(
                                                label: 'More',
                                                onTap: () {
                                                  setState(() {
                                                    _showMoreMenu = !_showMoreMenu;
                                                  });
                                                },
                                                showLabel: true,
                                                icon: const Icon(Icons.more_horiz, color: Colors.white, size: 22),
                                              ),
                                            ],
                                          )
                                        : const SizedBox.shrink(key: ValueKey('edit_more_menu_empty')),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _storyToolsExpanded = !_storyToolsExpanded;
                                      if (!_storyToolsExpanded) {
                                        _showMoreMenu = false;
                                      }
                                    });
                                  },
                                  child: AnimatedRotation(
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeInOut,
                                    turns: _storyToolsExpanded ? 0.5 : 0.0,
                                    child: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 28),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_storyDrawingMode)
                          Positioned(
                            left: 16,
                            right: 16,
                            top: 16,
                            child: _buildStoryDrawTopBar(),
                          ),
                        if (_storyDrawingMode)
                          Positioned(
                            left: 16,
                            top: 120,
                            bottom: 120,
                            child: SizedBox(
                              width: 28,
                              child: _buildStoryBrushSizeBar(),
                            ),
                          ),
                        Positioned(
                          right: 96,
                          bottom: 180,
                          child: IgnorePointer(
                            ignoring: !_showMoreMenu,
                            child: AnimatedOpacity(
                              opacity: _showMoreMenu ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeInOut,
                              child: AnimatedScale(
                                scale: _showMoreMenu ? 1.0 : 0.96,
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeInOut,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4A4A4A),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(LucideIcons.tag, color: Colors.white, size: 18),
                                          SizedBox(width: 10),
                                          Text('Label AI', style: TextStyle(color: Colors.white, fontSize: 14)),
                                        ],
                                      ),
                                      SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Icon(LucideIcons.eyeOff, color: Colors.white, size: 18),
                                          SizedBox(width: 10),
                                          Text('Turn off commenting', style: TextStyle(color: Colors.white, fontSize: 14)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 92,
                          child: IgnorePointer(
                            ignoring: !(_isStoryTextDeleteMode || _isStoryStickerDeleteMode),
                            child: AnimatedOpacity(
                              opacity: (_isStoryTextDeleteMode || _isStoryStickerDeleteMode) ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 160),
                              curve: Curves.easeInOut,
                              child: Center(
                                child: AnimatedScale(
                                  duration: const Duration(milliseconds: 140),
                                  scale: _storyTrashArmed ? 1.12 : 1.0,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 140),
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: _storyTrashArmed
                                          ? const Color(0xFFEF4444).withAlpha(220)
                                          : Colors.black.withAlpha(170),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: _storyTrashArmed ? Colors.white70 : Colors.white24,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(Icons.delete_outline, color: Colors.white, size: 26),
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
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _storyPostYourStory,
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: const Row(
                          children: [
                            CircleAvatar(radius: 12, backgroundColor: Colors.white24, child: Icon(Icons.person, size: 14, color: Colors.white)),
                            SizedBox(width: 10),
                            Text('Your story', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _storyPostCloseFriends,
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: const Row(
                          children: [
                            CircleAvatar(radius: 12, backgroundColor: Color(0xFF22C55E), child: Icon(Icons.star, size: 14, color: Colors.white)),
                            SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                'Close Friends',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: Color(0xFF536DFE),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _exitStoryEditing() {
    setState(() {
      _isStoryEditing = false;
      _editingImageBytes = null;
      _editingVideoFile = null;
      _editingVideoController?.dispose();
      _editingVideoController = null;
      _selectedLayout = null;
      _layoutMenuOpen = false;
      _layoutSlotImages.clear();
      _layoutSlotFlips.clear();
      _layoutActiveIndex = 0;
      _storyElements.clear();
      _storyStrokes.clear();
      _storyRedo.clear();
      _storyDrawingMode = false;
      _storyFlipX = false;
      _isStoryTextDeleteMode = false;
      _storySuppressTextTap = false;
      _storyStickers.clear();
      _storyActiveStickerIndex = null;
      _isStoryStickerDeleteMode = false;
      _storySuppressStickerTap = false;
      _storyStickerDeleteScale.clear();
      _storyHiddenMentions.clear();
    });
    _storyTextHoldTimer?.cancel();
    _storyStickerHoldTimer?.cancel();
  }

  Widget _maybeFlipStoryMedia(Widget child) {
    if (!_storyFlipX) return child;
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..scaleByDouble(-1.0, 1.0, 1.0, 1.0),
      child: child,
    );
  }

  Widget _buildStoryStickerWidget(_StoryStickerType type, {double size = 72}) {
    BoxDecoration baseDecoration({required List<Color> colors}) {
      return BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      );
    }

    Widget glossyHighlight() {
      return Positioned(
        top: 6,
        left: 6,
        right: 6,
        child: Container(
          height: size * 0.28,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.65),
                Colors.white.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      );
    }

    switch (type) {
      case _StoryStickerType.like:
        return Container(
          width: size,
          height: size,
          decoration: baseDecoration(colors: const [Color(0xFF7C3AED), Color(0xFF4F46E5)]),
          child: Stack(
            children: [
              glossyHighlight(),
              const Center(
                child: Icon(Icons.thumb_up_alt_rounded, color: Colors.white, size: 34),
              ),
            ],
          ),
        );
      case _StoryStickerType.wow:
        return Container(
          width: size,
          height: size,
          decoration: baseDecoration(colors: const [Color(0xFFFFB703), Color(0xFFFB8500)]),
          child: Stack(
            children: [
              glossyHighlight(),
              const Center(
                child: Text('WOW', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        );
      case _StoryStickerType.fire:
        return Container(
          width: size,
          height: size,
          decoration: baseDecoration(colors: const [Color(0xFFEF4444), Color(0xFFF97316)]),
          child: Stack(
            children: [
              glossyHighlight(),
              const Center(
                child: Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 34),
              ),
            ],
          ),
        );
      case _StoryStickerType.music:
        return Container(
          width: size,
          height: size,
          decoration: baseDecoration(colors: const [Color(0xFF06B6D4), Color(0xFF3B82F6)]),
          child: Stack(
            children: [
              glossyHighlight(),
              const Center(
                child: Icon(Icons.music_note_rounded, color: Colors.white, size: 34),
              ),
            ],
          ),
        );
      case _StoryStickerType.travel:
        return Container(
          width: size,
          height: size,
          decoration: baseDecoration(colors: const [Color(0xFF22C55E), Color(0xFF16A34A)]),
          child: Stack(
            children: [
              glossyHighlight(),
              const Center(
                child: Icon(Icons.flight_takeoff_rounded, color: Colors.white, size: 34),
              ),
            ],
          ),
        );
      case _StoryStickerType.coffee:
        return Container(
          width: size,
          height: size,
          decoration: baseDecoration(colors: const [Color(0xFF9A3412), Color(0xFFB45309)]),
          child: Stack(
            children: [
              glossyHighlight(),
              const Center(
                child: Icon(Icons.coffee_rounded, color: Colors.white, size: 34),
              ),
            ],
          ),
        );
    }
  }

  String _textAlignToApi(TextAlign align) {
    switch (align) {
      case TextAlign.left:
      case TextAlign.start:
        return 'left';
      case TextAlign.right:
      case TextAlign.end:
        return 'right';
      case TextAlign.justify:
        return 'justify';
      case TextAlign.center:
        return 'center';
    }
  }

  Size? _storyPreviewSize() {
    final renderBox = _storyRepaintKey.currentContext?.findRenderObject() as RenderBox?;
    return renderBox?.size;
  }

  Offset _normalizeStoryPosition(Offset position) {
    final size = _storyPreviewSize();
    if (size == null || size.width == 0 || size.height == 0) {
      return position;
    }
    final dx = (position.dx / size.width).clamp(0.0, 1.0);
    final dy = (position.dy / size.height).clamp(0.0, 1.0);
    return Offset(dx, dy);
  }

  Offset _denormalizeStoryPosition(Offset normalized) {
    final size = _storyPreviewSize();
    if (size == null || size.width == 0 || size.height == 0) {
      return normalized;
    }
    return Offset(
      normalized.dx * size.width,
      normalized.dy * size.height,
    );
  }

  Size _measureStoryTextSize(_StoryOverlayElement overlay, double maxWidth) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: overlay.text ?? '',
        style: (overlay.style ?? const TextStyle()).copyWith(
          color: overlay.textColor,
          fontSize: overlay.fontSize,
        ),
      ),
      textAlign: overlay.alignment,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    return textPainter.size;
  }

  Offset _clampStoryTextPosition(
    _StoryOverlayElement overlay,
    Offset position,
    double scale,
  ) {
    final renderBox = _storyRepaintKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return position;
    final bounds = renderBox.size;
    final textSize = _measureStoryTextSize(overlay, bounds.width);
    final scaled = Size(textSize.width * scale, textSize.height * scale);
    final maxX = (bounds.width - scaled.width).clamp(0.0, bounds.width);
    final maxY = (bounds.height - scaled.height).clamp(0.0, bounds.height);
    final clampedX = position.dx.clamp(0.0, maxX);
    final clampedY = position.dy.clamp(0.0, maxY);
    return Offset(clampedX, clampedY);
  }

  Offset _storyTrashCenterLocal() {
    final renderBox = _storyRepaintKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return const Offset(0, 0);
    final size = renderBox.size;
    return Offset(size.width / 2, size.height - 24 - 28);
  }

  Offset _toStoryLocal(Offset global) {
    final renderBox = _storyRepaintKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return global;
    return renderBox.globalToLocal(global);
  }

  void _updateStoryTextDeleteScale(int index) {
    if (!_isStoryTextDeleteMode) return;
    final center = _storyTrashCenterLocal();
    final distance = (center - _storyLastLocalFocalPoint).distance;
    const threshold = 120.0;
    final t = (distance / threshold).clamp(0.0, 1.0);
    final scale = 0.2 + (0.8 * t);
    _storyTextDeleteScale[index] = scale;
    _storyTrashArmed = distance <= 44;
  }

  Offset _storyStickerCenter() {
    final size = _storyPreviewSize();
    if (size == null) return const Offset(120, 220);
    return Offset(
      (size.width - _storyStickerBaseSize) / 2,
      (size.height - _storyStickerBaseSize) / 2,
    );
  }

  Offset _clampStoryStickerPosition(Offset position, double scale) {
    final renderBox = _storyRepaintKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return position;
    final bounds = renderBox.size;
    final scaledSize = _storyStickerBaseSize * scale;
    final maxX = (bounds.width - scaledSize).clamp(0.0, bounds.width);
    final maxY = (bounds.height - scaledSize).clamp(0.0, bounds.height);
    final clampedX = position.dx.clamp(0.0, maxX);
    final clampedY = position.dy.clamp(0.0, maxY);
    return Offset(clampedX, clampedY);
  }

  void _startStoryStickerHold(int index) {
    _storyStickerHoldTimer?.cancel();
    _storyStickerHoldTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _storySuppressStickerTap = true;
        _isStoryStickerDeleteMode = true;
        _storyActiveStickerIndex = index;
        _storyStickerDeleteScale[_storyStickers[index].id] = 1.0;
        _storyTrashArmed = false;
      });
    });
  }

  void _cancelStoryStickerHold() {
    _storyStickerHoldTimer?.cancel();
    _storyStickerHoldTimer = null;
  }

  void _exitStoryStickerDeleteMode() {
    if (!mounted) return;
    setState(() {
      _isStoryStickerDeleteMode = false;
      _storySuppressStickerTap = false;
      _storyTrashArmed = false;
      _storyStickerDeleteScale.clear();
    });
  }

  void _deleteStoryStickerAt(int index) {
    if (!mounted) return;
    setState(() {
      if (index >= 0 && index < _storyStickers.length) {
        _storyStickers.removeAt(index);
      }
      _storyActiveStickerIndex =
          _storyStickers.isEmpty ? null : (_storyStickers.length - 1);
      _isStoryStickerDeleteMode = false;
      _storySuppressStickerTap = false;
      _storyTrashArmed = false;
      _storyStickerDeleteScale.clear();
    });
  }

  void _updateStoryStickerDeleteScale(int index) {
    if (!_isStoryStickerDeleteMode) return;
    final center = _storyTrashCenterLocal();
    final distance = (center - _storyStickerLastLocalFocalPoint).distance;
    const threshold = 120.0;
    final t = (distance / threshold).clamp(0.0, 1.0);
    final scale = 0.2 + (0.8 * t);
    _storyStickerDeleteScale[_storyStickers[index].id] = scale;
    _storyTrashArmed = distance <= 44;
  }

  void _handleStoryStickerDeleteEnd(int index) {
    _cancelStoryStickerHold();
    if (!_isStoryStickerDeleteMode) return;
    if (index < 0 || index >= _storyStickers.length) {
      _exitStoryStickerDeleteMode();
      return;
    }
    final trashCenter = _storyTrashCenterLocal();
    if ((_storyStickerLastLocalFocalPoint - trashCenter).distance <= 44) {
      _deleteStoryStickerAt(index);
    } else {
      _exitStoryStickerDeleteMode();
    }
  }

  void _startStoryTextHold(int index) {
    _storyTextHoldTimer?.cancel();
    _storyTextHoldTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _storySuppressTextTap = true;
        _isStoryTextDeleteMode = true;
        _storyActiveElementIndex = index;
        _storyTextDeleteScale[index] = 1.0;
        _storyTrashArmed = false;
      });
    });
  }

  void _cancelStoryTextHold() {
    _storyTextHoldTimer?.cancel();
    _storyTextHoldTimer = null;
  }

  void _exitStoryTextDeleteMode() {
    if (!mounted) return;
    setState(() {
      _isStoryTextDeleteMode = false;
      _storySuppressTextTap = false;
      _storyTrashArmed = false;
      _storyTextDeleteScale.clear();
    });
  }

  void _deleteStoryTextAt(int index) {
    if (!mounted) return;
    setState(() {
      if (index >= 0 && index < _storyElements.length) {
        _storyElements.removeAt(index);
      }
      _storyActiveElementIndex =
          _storyElements.isEmpty ? null : (_storyElements.length - 1);
      _isStoryTextDeleteMode = false;
      _storySuppressTextTap = false;
      _storyTrashArmed = false;
      _storyTextDeleteScale.clear();
    });
  }

  void _handleStoryTextDeleteEnd(int index) {
    _cancelStoryTextHold();
    if (!_isStoryTextDeleteMode) return;
    if (index < 0 || index >= _storyElements.length) {
      _exitStoryTextDeleteMode();
      return;
    }
    final trashCenter = _storyTrashCenterLocal();
    if ((_storyLastLocalFocalPoint - trashCenter).distance <= 44) {
      _deleteStoryTextAt(index);
    } else {
      _exitStoryTextDeleteMode();
    }
  }

  Future<ImageProvider> _buildStoryTextEditorBackground() async {
    final devicePixelRatio = View.of(context).devicePixelRatio;
    if (mounted) {
      setState(() => _hideStoryTextOverlaysForCapture = true);
      await WidgetsBinding.instance.endOfFrame;
    }
    if (!mounted) {
      if (_editingImageBytes != null) {
        return MemoryImage(_editingImageBytes!);
      }
      return const AssetImage('assets/images/dashboard_sample.png');
    }
    final boundary = _storyRepaintKey.currentContext?.findRenderObject();
    try {
      if (boundary is RenderRepaintBoundary) {
        final pixelRatio = math.min(2.0, devicePixelRatio);
        final image = await boundary.toImage(pixelRatio: pixelRatio);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data != null) {
          return MemoryImage(data.buffer.asUint8List());
        }
      }
    } catch (_) {
      // Fallback below.
    } finally {
      if (mounted) {
        setState(() => _hideStoryTextOverlaysForCapture = false);
      }
    }
    if (_editingImageBytes != null) {
      return MemoryImage(_editingImageBytes!);
    }
    return const AssetImage('assets/images/dashboard_sample.png');
  }

  Future<void> _openStoryTextEditor({int? index}) async {
    final existing =
        index != null && index >= 0 && index < _storyElements.length ? _storyElements[index] : null;
    final background = await _buildStoryTextEditorBackground();
    if (!mounted) return;
    final normalizedInitialPosition =
        existing != null ? _normalizeStoryPosition(existing.position) : null;
    final result = await InstagramTextEditor.open(
      context,
      backgroundImage: background,
      initialText: existing?.text,
      initialColor: existing?.textColor ?? _storyCurrentColor,
      initialAlignment: existing?.alignment ?? TextAlign.center,
      initialBackgroundStyle: existing?.backgroundStyle ?? BackgroundStyle.none,
      initialScale: existing?.scale ?? 1.0,
      initialRotation: existing?.rotation ?? 0.0,
      initialPosition: normalizedInitialPosition,
      initialFont: existing?.fontName ?? 'Modern',
      initialFontSize: existing?.fontSize ?? 32.0,
    );

    if (result == null || !mounted) return;
    if (result.text.trim().isEmpty) return;

    final resolvedPosition = _denormalizeStoryPosition(result.position);
    final overlay = _StoryOverlayElement.text(
      result.text,
      style: result.style,
      alignment: result.alignment,
      backgroundStyle: result.backgroundStyle,
      fontName: result.fontName,
      fontSize: result.fontSize,
      textColor: result.textColor,
      position: resolvedPosition,
      scale: result.scale,
      rotation: result.rotation,
      mentions: existing?.mentions ?? const [],
    );
    final clamped = overlay.copyWith(
      position: _clampStoryTextPosition(overlay, overlay.position, overlay.scale),
    );

    setState(() {
      final targetIndex = index ?? _storyActiveElementIndex;
      if (targetIndex != null &&
          targetIndex >= 0 &&
          targetIndex < _storyElements.length) {
        _storyElements[targetIndex] = clamped;
        _storyActiveElementIndex = targetIndex;
      } else {
        _storyElements.add(clamped);
        _storyActiveElementIndex = _storyElements.length - 1;
      }
      _storyCurrentColor = clamped.textColor;
    });
  }

  void _openStoryStickerPicker() {
    final stickers = [
      _StoryStickerType.like,
      _StoryStickerType.wow,
      _StoryStickerType.fire,
      _StoryStickerType.music,
      _StoryStickerType.travel,
      _StoryStickerType.coffee,
    ];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemCount: stickers.length,
            itemBuilder: (context, index) {
              final sticker = stickers[index];
              return GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  final center = _storyStickerCenter();
                  setState(() {
                    _storyStickers.add(
                      _StorySticker(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        type: sticker,
                        position: center,
                        scale: 1.0,
                        rotation: 0.0,
                      ),
                    );
                    _storyActiveStickerIndex = _storyStickers.length - 1;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24, width: 1),
                  ),
                  child: Center(
                    child: _buildStoryStickerWidget(sticker, size: 60),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
  Future<void> _openStoryMentionSheet() async {
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    List<Map<String, dynamic>> results = [];
    bool loading = true;
    Future<void> loadResults(StateSetter setModalState) async {
      setModalState(() {
        loading = true;
      });
      try {
        final fetched = await UsersApi().search('');
        if (!mounted) return;
        setModalState(() {
          results = fetched;
          loading = false;
        });
      } catch (_) {
        if (!mounted) return;
        setModalState(() {
          results = [];
          loading = false;
        });
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) {
        final media = MediaQuery.of(ctx);
        final height = media.size.height * 0.55;
        return StatefulBuilder(
          builder: (context, setModalState) {
            if (loading && results.isEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!loading) return;
                loadResults(setModalState);
              });
            }
            return SafeArea(
              top: false,
              child: Container(
                height: height,
                decoration: const BoxDecoration(
                  color: Color(0xFF0F1115),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 46,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Mention',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () async {
                          Navigator.of(ctx).pop();
                          if (!mounted) return;
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (screenCtx) => _StoryMentionPickerScreen(
                                initialSelected: List.of(_storyHiddenMentions),
                                onDone: (selected) {
                                  setState(() {
                                    _storyHiddenMentions
                                      ..clear()
                                      ..addAll(selected);
                                  });
                                },
                              ),
                            ),
                          );
                        },
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF232833),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              SizedBox(width: 12),
                              Icon(Icons.search, color: Colors.white54, size: 20),
                              SizedBox(width: 8),
                              Text('Search', style: TextStyle(color: Colors.white54)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "People added here will be mentioned in your story but their username won't be visible.",
                          style: TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: loading
                          ? const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                            )
                          : results.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No suggestions right now',
                                    style: TextStyle(color: Colors.white38),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: results.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white12),
                                  itemBuilder: (context, index) {
                                    final user = results[index];
                                    final username = (user['username'] as String?) ?? '';
                                    final fullName = user['full_name'] as String?;
                                    final avatarUrl = user['avatar_url'] as String?;
                                    final userId = (user['id'] as String?) ?? (user['_id'] as String?) ?? '';
                                    final selected = userId.isNotEmpty &&
                                        _storyHiddenMentions.any((m) => m.userId == userId);
                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: Colors.white24,
                                        backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                                            ? NetworkImage(avatarUrl)
                                            : null,
                                        child: avatarUrl == null || avatarUrl.isEmpty
                                            ? Text(
                                                username.isNotEmpty ? username[0].toUpperCase() : '?',
                                                style: const TextStyle(color: Colors.white),
                                              )
                                            : null,
                                      ),
                                      title: Text(
                                        fullName?.isNotEmpty == true ? fullName! : username,
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                      subtitle: Text(
                                        username,
                                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                                      ),
                                      trailing: Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                          color: selected ? Colors.white : Colors.transparent,
                                        ),
                                        child: selected
                                            ? const Icon(Icons.check, color: Colors.black, size: 14)
                                            : null,
                                      ),
                                      onTap: () {
                                        if (userId.isEmpty) return;
                                        setState(() {
                                          final idx = _storyHiddenMentions.indexWhere((m) => m.userId == userId);
                                          if (idx == -1) {
                                            _storyHiddenMentions.add(
                                              _StoryMention(userId: userId, username: username),
                                            );
                                          } else {
                                            _storyHiddenMentions.removeAt(idx);
                                          }
                                        });
                                        setModalState(() {});
                                      },
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _startStoryStroke(Offset pos) {
    if (!_storyDrawingMode) return;
    final bool isEraser = _storyBrushType == _StoryBrushType.eraser;
    double opacity = 1.0;
    double blurSigma = 0.0;
    switch (_storyBrushType) {
      case _StoryBrushType.marker:
        opacity = 0.65;
        break;
      case _StoryBrushType.neon:
        opacity = 0.9;
        blurSigma = 6.0;
        break;
      case _StoryBrushType.eraser:
      case _StoryBrushType.pen:
        break;
    }
    setState(() {
      _storyStrokes.add(
        _StoryStroke(
          color: _storyCurrentColor,
          size: _storyBrushSize,
          opacity: opacity,
          blurSigma: blurSigma,
          isEraser: isEraser,
          points: [pos],
        ),
      );
      _storyRedo.clear();
    });
  }

  void _appendStoryStroke(Offset pos) {
    if (!_storyDrawingMode || _storyStrokes.isEmpty) return;
    setState(() {
      _storyStrokes.last.points.add(pos);
    });
  }

  void _storyUndoStroke() {
    if (_storyStrokes.isEmpty) return;
    setState(() {
      _storyRedo.add(_storyStrokes.removeLast());
    });
  }

  void _storyExitDrawMode() {
    setState(() {
      _storyDrawingMode = false;
    });
  }

  Widget _buildStoryBrushButton({
    required _StoryBrushType type,
    required IconData icon,
  }) {
    final bool isActive = _storyBrushType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _storyBrushType = type;
        });
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? Colors.white : Colors.transparent,
          border: Border.all(color: Colors.white, width: 1.6),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isActive ? Colors.black : Colors.white,
        ),
      ),
    );
  }

  Widget _buildStoryBrushSizeBar() {
    const double minSize = 2.0;
    const double maxSize = 28.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final t = (_storyBrushSize - minSize) / (maxSize - minSize);
        final thumbY = (1 - t).clamp(0.0, 1.0) * height;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            final local = d.localPosition.dy.clamp(0.0, height);
            final newT = 1 - local / height;
            setState(() {
              _storyBrushSize = minSize + newT * (maxSize - minSize);
            });
          },
          onVerticalDragUpdate: (d) {
            final local = d.localPosition.dy.clamp(0.0, height);
            final newT = 1 - local / height;
            setState(() {
              _storyBrushSize = minSize + newT * (maxSize - minSize);
            });
          },
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Align(
                alignment: Alignment.center,
                child: Container(
                  width: 4,
                  height: height,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Positioned(
                top: thumbY - 10,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStoryDrawTopBar() {
    return Row(
      children: [
        GestureDetector(
          onTap: _storyUndoStroke,
          child: Text(
            'Undo',
            style: TextStyle(
              color: _storyStrokes.isEmpty ? Colors.white38 : Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Spacer(),
        _buildStoryBrushButton(type: _StoryBrushType.pen, icon: Icons.edit),
        const SizedBox(width: 12),
        _buildStoryBrushButton(type: _StoryBrushType.marker, icon: Icons.brush),
        const SizedBox(width: 12),
        _buildStoryBrushButton(type: _StoryBrushType.neon, icon: Icons.auto_awesome),
        const SizedBox(width: 12),
        _buildStoryBrushButton(type: _StoryBrushType.eraser, icon: Icons.cleaning_services),
        const Spacer(),
        GestureDetector(
          onTap: _storyExitDrawMode,
          child: const Text(
            'Done',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  void _storyAddText() {
    _openStoryTextEditor();
  }

  Future<void> _storyEditText(_StoryOverlayElement e) async {
    final idx = _storyElements.indexOf(e);
    if (idx == -1) return;
    _openStoryTextEditor(index: idx);
  }

  Future<void> _storyPostYourStory() async {
    await _storyPostToApi(isCloseFriends: false);
  }

  Future<void> _storyPostCloseFriends() async {
    await _storyPostToApi(isCloseFriends: true);
  }

  Future<void> _storyPostToApi({bool isCloseFriends = false}) async {
    try {
      final isVideoStory = _editingVideoFile != null;
      final screenSize = MediaQuery.of(context).size;
      debugPrint('\n════════════════════════════════════════');
      debugPrint('🚀 Starting Story Post');
      debugPrint('════════════════════════════════════════');
      debugPrint('Close Friends: $isCloseFriends');
      debugPrint('Media type: ${isVideoStory ? 'video' : 'image'}');

      await Future.delayed(const Duration(milliseconds: 300));

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                SizedBox(width: 16),
                Text('Posting story...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      debugPrint('\n════════════════════════════════════════');
      debugPrint('📤 STEP 1: Uploading to /api/stories/upload');
      debugPrint('════════════════════════════════════════');

      Map<String, dynamic> uploadResponse;
      int? mediaWidth;
      int? mediaHeight;

      if (isVideoStory) {
        final videoFile = _editingVideoFile!;
        debugPrint('🎞 Uploading video file: ${videoFile.path}');
        uploadResponse = await _storyUploadVideoWithRetry(videoFile);
        final size = _editingVideoController?.value.size;
        if (size != null) {
          mediaWidth = size.width.round();
          mediaHeight = size.height.round();
        }
      } else {
        final boundary = _storyRepaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary == null) {
          debugPrint('❌ RepaintBoundary is null');
          debugPrint('Context: ${_storyRepaintKey.currentContext}');
          _storyShowError('Unable to capture story. Please try again.');
          return;
        }

        debugPrint('✅ RepaintBoundary found');
        debugPrint('\n📸 Capturing image from RepaintBoundary...');
        final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
        debugPrint('✅ Image captured: ${image.width}x${image.height}');

        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) {
          debugPrint('❌ ByteData is null');
          _storyShowError('Failed to capture image');
          return;
        }

        final bytes = byteData.buffer.asUint8List();
        debugPrint('✅ PNG bytes: ${bytes.length} (${(bytes.length / 1024 / 1024).toStringAsFixed(2)} MB)');

        var jpg = await FlutterImageCompress.compressWithList(
          bytes,
          quality: 85,
          format: CompressFormat.jpeg,
        );
        debugPrint('✅ JPEG compressed: ${jpg.length} bytes (${(jpg.length / 1024 / 1024).toStringAsFixed(2)} MB)');

        if (jpg.length > 4 * 1024 * 1024) {
          debugPrint('⚠️ File too large, re-compressing...');
          jpg = await FlutterImageCompress.compressWithList(
            jpg,
            quality: 70,
            format: CompressFormat.jpeg,
          );
          debugPrint('✅ JPEG re-compressed: ${jpg.length} bytes (${(jpg.length / 1024 / 1024).toStringAsFixed(2)} MB)');
        }

        uploadResponse = await _storyUploadWithRetry(jpg);
        mediaWidth = image.width;
        mediaHeight = image.height;
      }

      debugPrint('📦 Upload response type: ${uploadResponse.runtimeType}');
      debugPrint('📦 Upload response keys: ${uploadResponse.keys.toList()}');
      debugPrint('📦 Upload response: $uploadResponse');

      Map<String, dynamic>? mediaPayload;

      if (uploadResponse.containsKey('media')) {
        mediaPayload = uploadResponse['media'] as Map<String, dynamic>?;
        debugPrint('✅ Found media in response["media"]');
      } else if (uploadResponse.containsKey('url') && uploadResponse.containsKey('type')) {
        mediaPayload = uploadResponse;
        debugPrint('✅ Using full response as media payload');
      } else if (uploadResponse.containsKey('data')) {
        final data = uploadResponse['data'];
        if (data is Map) {
          mediaPayload = data as Map<String, dynamic>;
          debugPrint('✅ Found media in response["data"]');
        }
      } else if (uploadResponse.containsKey('fileUrl') || uploadResponse.containsKey('file_url')) {
        final url = uploadResponse['fileUrl'] ?? uploadResponse['file_url'];
        mediaPayload = {
          'url': url,
          'type': isVideoStory ? 'video' : 'image',
          if (mediaWidth != null) 'width': mediaWidth,
          if (mediaHeight != null) 'height': mediaHeight,
        };
        debugPrint('✅ Constructed media payload from fileUrl');
      }

      if (mediaPayload == null) {
        debugPrint('❌ Could not extract media payload from response');
        debugPrint('Response structure: $uploadResponse');
        _storyShowError('Upload failed: Invalid response format. Check console.');
        return;
      }

      debugPrint('✅ Media payload: $mediaPayload');
      if (isVideoStory) {
        mediaPayload['type'] = 'video';
        if (mediaWidth != null) mediaPayload['width'] = mediaWidth;
        if (mediaHeight != null) mediaPayload['height'] = mediaHeight;
      }

      debugPrint('\n════════════════════════════════════════');
      debugPrint('📝 STEP 2: Creating story via /api/stories');
      debugPrint('════════════════════════════════════════');

      final mentionsPayload = <Map<String, dynamic>>[];
      for (final e in _storyElements.where((e) => e.type == _StoryElementType.text)) {
        for (final m in e.mentions) {
          if ((e.text ?? '').contains('@${m.username}')) {
            mentionsPayload.add({
              'user_id': m.userId,
              'username': m.username,
              'x': e.position.dx / screenSize.width,
              'y': e.position.dy / screenSize.height,
            });
          }
        }
      }
      for (final m in _storyHiddenMentions) {
        if (mentionsPayload.any((item) => item['user_id'] == m.userId)) {
          continue;
        }
        mentionsPayload.add({
          'user_id': m.userId,
          'username': m.username,
          'x': 0.5,
          'y': 0.9,
        });
      }

      final storyItem = <String, dynamic>{
        'media': mediaPayload,
        'filter': {
          'name': _storyCurrentFilter.toLowerCase(),
          'intensity': 1.0,
        },
        'texts': _storyElements
            .where((e) => e.type == _StoryElementType.text)
            .map((e) => {
                  'content': e.text ?? '',
                  'fontSize': e.fontSize,
                  'fontFamily': e.fontName.toLowerCase(),
                  'color':
                      '#${e.textColor.toARGB32().toRadixString(16).substring(2, 8).toUpperCase()}',
                  'align': _textAlignToApi(e.alignment),
                  'x': e.position.dx / screenSize.width,
                  'y': e.position.dy / screenSize.height,
                })
            .toList(),
        'mentions': mentionsPayload,
      };

      if (isCloseFriends) {
        storyItem['isCloseFriends'] = true;
      }

      debugPrint('📋 Story item payload:');
      debugPrint(jsonEncode(storyItem));

      final createResponse = await StoriesApi().create([storyItem]).timeout(const Duration(seconds: 15));

      debugPrint('✅ Create response: $createResponse');
      debugPrint('\n════════════════════════════════════════');
      debugPrint('🎉 Story posted successfully!');
      debugPrint('════════════════════════════════════════\n');

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isCloseFriends ? 'Posted to Close Friends ✓' : 'Posted to Your Story ✓'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        _exitStoryEditing();
      }
    } on SocketException catch (e) {
      debugPrint('\n❌ SocketException: $e');
      _storyShowError('No internet connection');
    } on TimeoutException catch (e) {
      debugPrint('\n❌ TimeoutException: $e');
      _storyShowError('Request timed out. Please try again.');
    } catch (e, stackTrace) {
      debugPrint('\n❌❌❌ ERROR ❌❌❌');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('Error message: $e');
      debugPrint('Stack trace:');
      debugPrint(stackTrace.toString());
      debugPrint('════════════════════════════════════════\n');

      String errorMessage = 'Failed to post story';

      if (e.toString().contains('ApiException') || e.toString().contains('Exception')) {
        final match = RegExp(r'Exception: (.+)').firstMatch(e.toString());
        if (match != null) {
          errorMessage = match.group(1) ?? errorMessage;
        }
      }

      _storyShowError('$errorMessage\n\nCheck console for details');
    }
  }

  Future<Map<String, dynamic>> _storyUploadWithRetry(List<int> bytes, {int maxRetries = 3}) async {
    int attempts = 0;
    Exception? lastException;
    
    while (attempts < maxRetries) {
      try {
        attempts++;
        debugPrint('Upload attempt $attempts of $maxRetries');
        
        // Call the /api/stories/upload endpoint
        final response = await StoriesApi().upload(bytes).timeout(const Duration(seconds: 20));
        
        debugPrint('✓ Upload successful on attempt $attempts');
        return response;
      } catch (e) {
        lastException = e as Exception;
        debugPrint('✗ Upload attempt $attempts failed: $e');
        
        if (attempts < maxRetries) {
          final delay = Duration(seconds: attempts * 2);
          debugPrint('Retrying in ${delay.inSeconds} seconds...');
          await Future.delayed(delay);
        }
      }
    }
    
    throw lastException ?? Exception('Upload failed after $maxRetries attempts');
  }

  Future<Map<String, dynamic>> _storyUploadVideoWithRetry(File file, {int maxRetries = 3}) async {
    int attempts = 0;
    Exception? lastException;

    while (attempts < maxRetries) {
      try {
        attempts++;
        debugPrint('Upload attempt $attempts of $maxRetries');

        final response = await StoriesApi().uploadFile(file.path).timeout(const Duration(seconds: 60));

        debugPrint('✓ Upload successful on attempt $attempts');
        return response;
      } catch (e) {
        lastException = e as Exception;
        debugPrint('✗ Upload attempt $attempts failed: $e');

        if (attempts < maxRetries) {
          final delay = Duration(seconds: attempts * 2);
          debugPrint('Retrying in ${delay.inSeconds} seconds...');
          await Future.delayed(delay);
        }
      }
    }

    throw lastException ?? Exception('Upload failed after $maxRetries attempts');
  }

  void _storyShowError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: () => _storyPostToApi(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isStoryEditing) {
      return _buildStoryEditingUi(context);
    }

    if (_initializing) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (_permissionDenied) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off, color: Colors.white70, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Camera permission required',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  await openAppSettings();
                },
                child: const Text(
                  'Open Settings',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final mediaPadding = MediaQuery.of(context).padding;
    final previewPadding = EdgeInsets.fromLTRB(
      0,
      mediaPadding.top + 8,
      0,
      mediaPadding.bottom + 90,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F14),
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: previewPadding,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: _buildCameraPreview(),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: previewPadding,
              child: Stack(
                children: [
                  if (_selectedLayout != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: _buildLayoutOverlay(),
                      ),
                    ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: _storyToolsExpanded ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeInOut,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: 200,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Colors.black.withValues(alpha: 0.65),
                                  Colors.black.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    right: 8,
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(LucideIcons.x, color: Colors.white),
                          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                        ),
                        Expanded(
                          child: Center(
                            child: GestureDetector(
                              onTap: _toggleFlash,
                              child: Icon(
                                _flashMode == FlashMode.off
                                    ? Icons.flash_off_rounded
                                    : (_flashMode == FlashMode.auto
                                        ? Icons.flash_auto_rounded
                                        : Icons.flash_on_rounded),
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.settings, color: Colors.white),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 16,
                    top: 140,
                    child: _buildStoryTools(),
                  ),
                  _buildLayoutMenu(),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Container(
                color: const Color(0xFF0B0F14),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: Row(
                  children: [
                    _buildGalleryShortcut(),
                    const Spacer(),
                    _buildModeTabs(),
                    const Spacer(),
                    _buildReverseIcon(),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: mediaPadding.bottom + 112,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      const SizedBox(width: 44),
                      Expanded(
                        child: Center(
                          child: _buildCaptureControls(),
                        ),
                      ),
                      const SizedBox(width: 44),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryMentionPickerScreen extends StatefulWidget {
  final List<_StoryMention> initialSelected;
  final ValueChanged<List<_StoryMention>> onDone;

  const _StoryMentionPickerScreen({
    required this.initialSelected,
    required this.onDone,
  });

  @override
  State<_StoryMentionPickerScreen> createState() => _StoryMentionPickerScreenState();
}

class _StoryMentionPickerScreenState extends State<_StoryMentionPickerScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = true;
  final List<_StoryMention> _selected = [];

  @override
  void initState() {
    super.initState();
    _selected.addAll(widget.initialSelected);
    _loadResults('');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FocusScope.of(context).unfocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadResults(String query) async {
    setState(() => _loading = true);
    try {
      final fetched = await UsersApi().search(query);
      if (!mounted) return;
      setState(() {
        _results = fetched;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _results = [];
        _loading = false;
      });
    }
  }

  void _toggleUser(String userId, String username) {
    final idx = _selected.indexWhere((m) => m.userId == userId);
    if (idx == -1) {
      _selected.add(_StoryMention(userId: userId, username: username));
    } else {
      _selected.removeAt(idx);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1115),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Mention',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: () {
              widget.onDone(List.of(_selected));
              Navigator.pop(context);
            },
            child: const Text('Done', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF232833),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Icon(Icons.search, color: Colors.white54, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) => _loadResults(value.trim()),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Search',
                        hintStyle: TextStyle(color: Colors.white54),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "People added here will be mentioned in your story but their username won't be visible.",
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white12),
                    itemBuilder: (context, index) {
                      final user = _results[index];
                      final username = (user['username'] as String?) ?? '';
                      final fullName = user['full_name'] as String?;
                      final avatarUrl = user['avatar_url'] as String?;
                      final userId = (user['id'] as String?) ?? (user['_id'] as String?) ?? '';
                      final selected = userId.isNotEmpty &&
                          _selected.any((m) => m.userId == userId);
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.white24,
                          backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                              ? NetworkImage(avatarUrl)
                              : null,
                          child: avatarUrl == null || avatarUrl.isEmpty
                              ? Text(
                                  username.isNotEmpty ? username[0].toUpperCase() : '?',
                                  style: const TextStyle(color: Colors.white),
                                )
                              : null,
                        ),
                        title: Text(
                          fullName?.isNotEmpty == true ? fullName! : username,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          username,
                          style: const TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                        trailing: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                            color: selected ? Colors.white : Colors.transparent,
                          ),
                          child: selected
                              ? const Icon(Icons.check, color: Colors.black, size: 14)
                              : null,
                        ),
                        onTap: () {
                          if (userId.isEmpty) return;
                          _toggleUser(userId, username);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
