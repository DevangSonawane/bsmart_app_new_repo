import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:camera/camera.dart';
import 'package:video_player/video_player.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import '../models/media_model.dart';
import 'create_post_screen.dart';
import 'create_upload_screen.dart';
import 'create_edit_preview_screen.dart';
import '../api/api.dart';
import '../services/supabase_service.dart';

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
    final overlayPaint = Paint()..color = maskColor;
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(Offset.zero & size, overlayPaint);
    if (!activeRect.isEmpty) {
      final rrect = RRect.fromRectAndRadius(activeRect, Radius.circular(borderRadius));
      final clearPaint = Paint()..blendMode = BlendMode.clear;
      canvas.drawRRect(rrect, clearPaint);
    }
    canvas.restore();

    final linePaint = Paint()
      ..color = Colors.white54
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final r in rects) {
      canvas.drawRect(r, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LayoutMaskPainter oldDelegate) {
    return oldDelegate.rects != rects || oldDelegate.activeRect != activeRect;
  }
}

enum _StoryElementType { text, sticker }

enum _ToolOverlayType { create, boomerang, layout, ai, draw }

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

class _StoryOverlayElement {
  final _StoryElementType type;
  final String? text;
  final String? style;
  final Color? color;
  final String? sticker;
  final Offset position;
  final double scale;
  final double rotation;
  final List<_StoryMention> mentions;

  _StoryOverlayElement._({
    required this.type,
    this.text,
    this.style,
    this.color,
    this.sticker,
    required this.position,
    required this.scale,
    required this.rotation,
    this.mentions = const [],
  });

  factory _StoryOverlayElement.text(
    String text, {
    String style = 'Classic',
    Color color = Colors.white,
    List<_StoryMention> mentions = const [],
  }) {
    return _StoryOverlayElement._(
      type: _StoryElementType.text,
      text: text,
      style: style,
      color: color,
      position: const Offset(100, 100),
      scale: 1.0,
      rotation: 0.0,
      mentions: mentions,
    );
  }

  factory _StoryOverlayElement.sticker(String label) {
    return _StoryOverlayElement._(
      type: _StoryElementType.sticker,
      sticker: label,
      position: const Offset(120, 120),
      scale: 1.0,
      rotation: 0.0,
    );
  }

  _StoryOverlayElement copyWith({
    String? text,
    String? style,
    Color? color,
    Offset? position,
    double? scale,
    double? rotation,
    List<_StoryMention>? mentions,
  }) {
    return _StoryOverlayElement._(
      type: type,
      text: text ?? this.text,
      style: style ?? this.style,
      color: color ?? this.color,
      sticker: sticker,
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

  const _StoryElementWidget({
    super.key,
    required this.element,
    this.isActive = false,
    this.onTap,
  });

  TextStyle _textStyleFor(String styleName, Color color) {
    switch (styleName) {
      case 'Modern':
        return TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w400);
      case 'Neon':
        return TextStyle(
          color: color,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          shadows: [
            Shadow(
              color: color.withAlpha(160),
              blurRadius: 12,
            ),
          ],
        );
      case 'Typewriter':
        return TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w500, letterSpacing: 2.0);
      case 'Strong':
        return TextStyle(color: color, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 0.8);
      case 'Classic':
      default:
        return TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: 0.5);
    }
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
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: e.type == _StoryElementType.text
                    ? (isActive ? Colors.white24 : Colors.black26)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: e.type == _StoryElementType.text
                  ? Text(
                      e.text ?? '',
                      style: _textStyleFor(e.style ?? 'Classic', e.color ?? Colors.white),
                    )
                  : Text(
                      e.sticker ?? '',
                      style: const TextStyle(fontSize: 32),
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
  final List<Offset> points;

  _StoryStroke({
    required this.color,
    required this.size,
    required this.points,
  });
}

class _StoryDrawingPainter extends CustomPainter {
  final List<_StoryStroke> strokes;

  _StoryDrawingPainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strokes) {
      final paint = Paint()
        ..color = s.color
        ..strokeWidth = s.size
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < s.points.length - 1; i++) {
        canvas.drawLine(s.points[i], s.points[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StoryDrawingPainter oldDelegate) => oldDelegate.strokes != strokes;
}

class _StoryToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _StoryToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

const _storyFilterNames = [
  'Original',
  'Clarendon',
  'Gingham',
  'Moon',
  'Lark',
  'Reyes',
  'Juno',
];

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
  File? _editingImageFile;
  Uint8List? _editingImageBytes;
  File? _editingVideoFile;
  VideoPlayerController? _editingVideoController;
  final GlobalKey _storyRepaintKey = GlobalKey();
  final List<_StoryOverlayElement> _storyElements = [];
  int? _storyActiveElementIndex;
  bool _storyShowTrash = false;
  bool _storyDrawingMode = false;
  bool _storyStickerMode = false;
  final List<_StoryStroke> _storyStrokes = [];
  final List<_StoryStroke> _storyRedo = [];
  double _storyBrushSize = 8.0;
  Color _storyCurrentColor = Colors.white;
  String _storyCurrentFilter = 'Original';
  bool _recordAsReel = false;
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
  int _layoutActiveIndex = 0;

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
    if (_controller!.value.isTakingPicture || _controller!.value.isRecordingVideo) return;
    if (_boomerangEnabled) {
      await _captureBoomerang();
      return;
    }
    if (_activeToolOverlay == _ToolOverlayType.layout && _selectedLayout != null) {
      await _captureLayoutFrame();
      return;
    }
    try {
      final xfile = await _controller!.takePicture();
      await _navigateToEditor(File(xfile.path), MediaType.image);
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
      if (_mode == UploadMode.post) {
        _recordAsReel = true;
      }
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
      final asReel = _recordAsReel || _mode == UploadMode.reel;
      _recordAsReel = false;
      await _navigateToEditor(File(xfile.path), MediaType.video, asReel: asReel);
    } catch (e) {
      debugPrint('Error stopping video recording: $e');
      setState(() {
        _recording = false;
      });
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
        await _navigateToEditor(File(xfile.path), MediaType.video);
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
        await _navigateToEditor(File(xfile.path), MediaType.video);
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
      await _navigateToEditor(File(outputPath), MediaType.video);
      return true;
    }
    debugPrint('Boomerang ffmpeg failed: $returnCode');
    return false;
  }

  Future<void> _onThumbnailTap(AssetEntity asset) async {
    final file = await asset.originFile;
    if (file == null) return;
    final type = asset.type == AssetType.video ? MediaType.video : MediaType.image;
    await _navigateToEditor(file, type);
  }

  void _openToolOverlay(_ToolOverlayType type, {Widget? icon}) {
    setState(() {
      _activeToolOverlay = type;
      if (type != _ToolOverlayType.layout) {
        _layoutMenuOpen = false;
        _selectedLayout = null;
        _layoutSlotImages.clear();
        _layoutActiveIndex = 0;
      }
    });
  }

  void _closeToolOverlay() {
    setState(() {
      _activeToolOverlay = null;
      _layoutMenuOpen = false;
      _selectedLayout = null;
      _layoutSlotImages.clear();
      _layoutActiveIndex = 0;
    });
  }

  Future<void> _navigateToEditor(File file, MediaType type,
      {bool asReel = false}) async {
    if (!mounted) return;
    
    if (_mode == UploadMode.story && type == MediaType.image && !asReel) {
      debugPrint('Loading image for story editor: ${file.path}');
      
      try {
        final bytes = await file.readAsBytes();
        debugPrint('Image bytes loaded: ${bytes.length} bytes');
        
        if (!mounted) return;
        
        setState(() {
          _editingImageFile = file;
          _editingImageBytes = bytes;
          _isStoryEditing = true;
          _storyElements.clear();
          _storyStrokes.clear();
          _storyRedo.clear();
          _storyShowTrash = false;
          _storyDrawingMode = false;
          _storyStickerMode = false;
          _storyBrushSize = 8.0;
          _storyCurrentColor = Colors.white;
          _storyCurrentFilter = 'Original';
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
        await _editingVideoController!.setLooping(true);
        await _editingVideoController!.play();

        if (!mounted) return;
        setState(() {
          _editingVideoFile = file;
          _editingImageFile = null;
          _editingImageBytes = null;
          _isStoryEditing = true;
          _storyElements.clear();
          _storyStrokes.clear();
          _storyRedo.clear();
          _storyShowTrash = false;
          _storyDrawingMode = false;
          _storyStickerMode = false;
          _storyBrushSize = 8.0;
          _storyCurrentColor = Colors.white;
          _storyCurrentFilter = 'Original';
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
          _layoutRects(const Size(1080, 1920), _selectedLayout!, 8).length,
          null,
        ),
      );
    }
    try {
      final xfile = await _controller!.takePicture();
      final bytes = await File(xfile.path).readAsBytes();
      if (_layoutActiveIndex < _layoutSlotImages.length) {
        _layoutSlotImages[_layoutActiveIndex] = bytes;
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
    final targetSize = const Size(1080, 1920);
    final rects = _layoutRects(targetSize, _selectedLayout!, 8);
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
      canvas.drawImageRect(image, src, dst, Paint());
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
      _editingImageFile = null;
      _editingVideoFile = null;
      _editingVideoController?.dispose();
      _editingVideoController = null;
      _isStoryEditing = true;
      _storyElements.clear();
      _storyStrokes.clear();
      _storyRedo.clear();
      _storyShowTrash = false;
      _storyDrawingMode = false;
      _storyStickerMode = false;
      _storyBrushSize = 8.0;
      _storyCurrentColor = Colors.white;
      _storyCurrentFilter = 'Original';
      _layoutMenuOpen = false;
      _activeToolOverlay = null;
    });
  }

  Widget _buildToolButton({IconData? icon, Widget? child, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: child ??
              Icon(
                icon,
                color: Colors.white,
                size: 28,
              ),
        ),
      ),
    );
  }

  Widget _buildMediaCarousel() {
    if (_recentAssets.isEmpty) {
      return const SizedBox(height: 56);
    }
    return Container(
      height: 56,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: _recentAssets.length,
        itemBuilder: (context, index) {
          final asset = _recentAssets[index];
          return Padding(
            padding: EdgeInsets.only(right: index < _recentAssets.length - 1 ? 10 : 0),
            child: GestureDetector(
              onTap: () => _onThumbnailTap(asset),
              child: ClipOval(
                child: FutureBuilder<Uint8List?>(
                  future: asset.thumbnailDataWithSize(const ThumbnailSize(200, 200)),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done || snapshot.data == null) {
                      return Container(
                        width: 48,
                        height: 48,
                        color: Colors.grey[900],
                      );
                    }
                    return Image.memory(
                      snapshot.data!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCaptureControls() {
    return GestureDetector(
      onTap: _onCapturePressed,
      onLongPressStart: (_) => _onRecordStart(),
      onLongPressEnd: (_) => _onRecordEnd(),
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
                          _layoutRects(const Size(1080, 1920), _StoryLayoutType.grid2x2, 8).length,
                          null,
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
                  child: const Padding(
                    padding: EdgeInsets.only(bottom: 18),
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: Center(
                        child: Icon(Icons.grid_on_rounded, color: Colors.white, size: 18),
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
                        ..addAll(List<Uint8List?>.filled(_layoutRects(const Size(1080, 1920), type, 8).length, null));
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
          8,
        );
        final activeRect = rects.isNotEmpty && _layoutActiveIndex < rects.length
            ? rects[_layoutActiveIndex]
            : Rect.zero;

        return Stack(
          children: [
            ...rects.asMap().entries.map((entry) {
              final i = entry.key;
              final r = entry.value;
              final imageBytes = i < _layoutSlotImages.length ? _layoutSlotImages[i] : null;
              if (imageBytes == null) return const SizedBox.shrink();
              return Positioned(
                left: r.left,
                top: r.top,
                width: r.width,
                height: r.height,
                child: Image.memory(
                  imageBytes,
                  fit: BoxFit.cover,
                ),
              );
            }),
            Positioned.fill(
              child: CustomPaint(
                painter: _LayoutMaskPainter(
                  rects: rects,
                  activeRect: activeRect,
                  borderRadius: 0,
                  maskColor: const Color(0xFF5A5A5A),
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

  Widget _buildSwitchCameraButton() {
    return GestureDetector(
      onTap: _isSwitchingCamera ? null : _switchCamera,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white10,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: _isSwitchingCamera
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.cameraswitch_rounded, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_controller == null || !_controller!.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
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
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  debugPrint('📐 Layout constraints: ${constraints.maxWidth}x${constraints.maxHeight}');

                  return GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onScaleStart: (details) {
                      if (_storyDrawingMode || _storyElements.isEmpty) return;
                      final activeIndex = _storyActiveElementIndex ?? (_storyElements.length - 1);
                      _storyActiveElementIndex = activeIndex;
                      _storyLastFocalPoint = details.focalPoint;
                      final element = _storyElements[activeIndex];
                      _storyTransformBaseScale = element.scale;
                      _storyTransformBaseRotation = element.rotation;
                    },
                    onScaleUpdate: (details) {
                      if (_storyDrawingMode || _storyElements.isEmpty) return;
                      final activeIndex = _storyActiveElementIndex ?? (_storyElements.length - 1);
                      final element = _storyElements[activeIndex];
                      final delta = details.focalPoint - _storyLastFocalPoint;
                      _storyLastFocalPoint = details.focalPoint;

                      double newScale = element.scale;
                      double newRotation = element.rotation;

                      if (details.pointerCount > 1) {
                        newScale = (_storyTransformBaseScale * details.scale).clamp(0.2, 8.0);
                        newRotation = _storyTransformBaseRotation + details.rotation;
                      }

                      setState(() {
                        _storyElements[activeIndex] = element.copyWith(
                          position: element.position + delta,
                          scale: newScale,
                          rotation: newRotation,
                        );
                      });
                    },
                    child: Stack(
                      children: [
                        RepaintBoundary(
                          key: _storyRepaintKey,
                          child: SizedBox(
                            width: constraints.maxWidth,
                            height: constraints.maxHeight,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (imageBytes != null)
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
                                  )
                                else if (videoController != null)
                                  ColorFiltered(
                                    colorFilter: ColorFilter.matrix(_storyFilterMatrixFor(_storyCurrentFilter)),
                                    child: FittedBox(
                                      fit: BoxFit.cover,
                                      child: SizedBox(
                                        width: videoController.value.size.width,
                                        height: videoController.value.size.height,
                                        child: VideoPlayer(videoController),
                                      ),
                                    ),
                                  ),
                                CustomPaint(painter: _StoryDrawingPainter(_storyStrokes)),
                                ..._storyElements.asMap().entries.map(
                                  (entry) {
                                    final index = entry.key;
                                    final e = entry.value;
                                    final isActive = _storyActiveElementIndex == null
                                        ? index == _storyElements.length - 1
                                        : index == _storyActiveElementIndex;
                                    return _StoryElementWidget(
                                      key: ValueKey(e.hashCode),
                                      element: e,
                                      isActive: isActive,
                                      onTap: () {
                                        if (e.type == _StoryElementType.text) {
                                          setState(() {
                                            _storyActiveElementIndex = index;
                                          });
                                          _storyEditText(e);
                                        }
                                      },
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
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
                                onTap: () {},
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
                                              onTap: () {},
                                              showLabel: true,
                                              icon: const Icon(Icons.alternate_email, color: Colors.white, size: 22),
                                            ),
                                            const SizedBox(height: 10),
                                            _buildEditActionRow(
                                              label: 'Draw',
                                              onTap: () {
                                                setState(() {
                                                  _storyDrawingMode = true;
                                                  _storyStickerMode = false;
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
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        children: const [
                                          Icon(LucideIcons.tag, color: Colors.white, size: 18),
                                          SizedBox(width: 10),
                                          Text('Label AI', style: TextStyle(color: Colors.white, fontSize: 14)),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: const [
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
                          left: 24,
                          right: 24,
                          bottom: 9,
                          child: const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Add a caption...',
                              style: TextStyle(color: Colors.white70, fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
                      child: Row(
                        children: const [
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
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: const [
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
      _editingImageFile = null;
      _editingImageBytes = null;
      _editingVideoFile = null;
      _editingVideoController?.dispose();
      _editingVideoController = null;
      _selectedLayout = null;
      _layoutMenuOpen = false;
      _layoutSlotImages.clear();
      _layoutActiveIndex = 0;
      _storyElements.clear();
      _storyStrokes.clear();
      _storyRedo.clear();
      _storyShowTrash = false;
      _storyDrawingMode = false;
      _storyStickerMode = false;
    });
  }

  void _startStoryStroke(Offset pos) {
    if (!_storyDrawingMode) return;
    setState(() {
      _storyStrokes.add(_StoryStroke(color: _storyCurrentColor, size: _storyBrushSize, points: [pos]));
      _storyRedo.clear();
    });
  }

  void _appendStoryStroke(Offset pos) {
    if (!_storyDrawingMode || _storyStrokes.isEmpty) return;
    setState(() {
      _storyStrokes.last.points.add(pos);
    });
  }

  void _storyUndo() {
    if (_storyStrokes.isEmpty) return;
    setState(() {
      _storyRedo.add(_storyStrokes.removeLast());
    });
  }

  void _storyRedoStroke() {
    if (_storyRedo.isEmpty) return;
    setState(() {
      _storyStrokes.add(_storyRedo.removeLast());
    });
  }

  void _storyAddSticker(String label) {
    setState(() {
      _storyElements.add(_StoryOverlayElement.sticker(label));
      _storyStickerMode = false;
      _storyActiveElementIndex = _storyElements.length - 1;
    });
  }

  Future<_StoryOverlayElement?> _showStoryTextEditor({
    String initialText = '',
    String initialStyle = 'Classic',
    Color? initialColor,
    List<_StoryMention> initialMentions = const [],
  }) {
    final controller = TextEditingController(text: initialText);
    String style = initialStyle;
    Color color = initialColor ?? _storyCurrentColor;
    List<_StoryMention> selectedMentions = List.of(initialMentions);
    List<Map<String, dynamic>> mentionResults = [];
    bool showMentionList = false;
    bool mentionLoading = false;
    String currentMentionQuery = '';
    return showModalBottomSheet<_StoryOverlayElement>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final media = MediaQuery.of(ctx);
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            TextStyle textStyleFor(String name, Color c) {
              switch (name) {
                case 'Modern':
                  return TextStyle(
                    color: c,
                    fontSize: 28,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.0,
                  );
                case 'Neon':
                  return TextStyle(
                    color: c,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    shadows: [
                      Shadow(
                        color: c.withAlpha(160),
                        blurRadius: 14,
                      ),
                    ],
                  );
                case 'Typewriter':
                  return TextStyle(
                    color: c,
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 2.0,
                  );
                case 'Strong':
                  return TextStyle(
                    color: c,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  );
                case 'Classic':
                default:
                  return TextStyle(
                    color: c,
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  );
              }
            }

            return Container(
              color: Colors.black.withAlpha(230),
              padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
              child: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              final text = controller.text.trim().isEmpty ? 'Tap to edit' : controller.text.trim();
                              Navigator.pop(
                                ctx,
                                _StoryOverlayElement.text(
                                  text,
                                  style: style,
                                  color: color,
                                  mentions: selectedMentions,
                                ),
                              );
                            },
                            child: const Text(
                              'Done',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: TextField(
                            controller: controller,
                            autofocus: true,
                            textAlign: TextAlign.center,
                            maxLines: null,
                            style: textStyleFor(style, color),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Type something...',
                              hintStyle: TextStyle(color: Colors.white54),
                            ),
                            onChanged: (value) async {
                              final selection = controller.selection;
                              int cursor = selection.baseOffset;
                              if (cursor < 0 || cursor > value.length) {
                                cursor = value.length;
                              }
                              final prefix = value.substring(0, cursor);
                              final atIndex = prefix.lastIndexOf('@');
                              if (atIndex == -1) {
                                setModalState(() {
                                  showMentionList = false;
                                  mentionResults = [];
                                  currentMentionQuery = '';
                                });
                                return;
                              }
                              // Allow @ mentions anywhere in the text; we only
                              // restrict by the characters that follow it.
                              final afterAt = prefix.substring(atIndex + 1);
                              if (afterAt.contains(' ')) {
                                setModalState(() {
                                  showMentionList = false;
                                  mentionResults = [];
                                  currentMentionQuery = '';
                                });
                                return;
                              }

                              currentMentionQuery = afterAt;

                              setModalState(() {
                                mentionLoading = true;
                                showMentionList = true;
                              });

                              try {
                                List<Map<String, dynamic>> results;
                                if (currentMentionQuery.isEmpty) {
                                  // No query yet – show a default list of users.
                                  results = await SupabaseService().fetchUsers(limit: 20);
                                } else {
                                  results = await UsersApi().search(currentMentionQuery);
                                  if (results.isEmpty) {
                                    // Fallback to local samples so UI still shows something.
                                    results = await SupabaseService().fetchUsers(limit: 20);
                                  }
                                }
                                setModalState(() {
                                  mentionLoading = false;
                                  mentionResults = results;
                                  showMentionList = results.isNotEmpty;
                                });
                              } catch (_) {
                                try {
                                  final fallback = await SupabaseService().fetchUsers(limit: 20);
                                  setModalState(() {
                                    mentionLoading = false;
                                    mentionResults = fallback;
                                    showMentionList = fallback.isNotEmpty;
                                  });
                                } catch (_) {
                                  setModalState(() {
                                    mentionLoading = false;
                                    mentionResults = [];
                                    showMentionList = false;
                                  });
                                }
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    if (showMentionList)
                      SizedBox(
                        height: 160,
                        child: Container(
                          color: Colors.black.withAlpha(230),
                          child: mentionLoading
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
                              : ListView.builder(
                                  itemCount: mentionResults.length,
                                  itemBuilder: (context, index) {
                                    final user = mentionResults[index];
                                    final username = (user['username'] as String?) ?? '';
                                    final fullName = user['full_name'] as String?;
                                    final avatarUrl = user['avatar_url'] as String?;
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
                                        username,
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                      subtitle: fullName != null
                                          ? Text(
                                              fullName,
                                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                                            )
                                          : null,
                                      onTap: () {
                                        final value = controller.text;
                                        final selection = controller.selection;
                                        int cursor = selection.baseOffset;
                                        if (cursor < 0 || cursor > value.length) {
                                          cursor = value.length;
                                        }
                                        final prefix = value.substring(0, cursor);
                                        final suffix = value.substring(cursor);
                                        final atIndex = prefix.lastIndexOf('@');
                                        if (atIndex == -1) {
                                          return;
                                        }
                                        final before = value.substring(0, atIndex);
                                        final mentionText = '@$username ';
                                        final newText = before + mentionText + suffix;
                                        controller.value = controller.value.copyWith(
                                          text: newText,
                                          selection: TextSelection.collapsed(
                                            offset: (before + mentionText).length,
                                          ),
                                        );
                                        final userId = (user['id'] as String?) ?? (user['_id'] as String?) ?? '';
                                        if (userId.isNotEmpty &&
                                            !selectedMentions.any((m) => m.userId == userId)) {
                                          selectedMentions.add(
                                            _StoryMention(userId: userId, username: username),
                                          );
                                        }
                                        setModalState(() {
                                          showMentionList = false;
                                          mentionResults = [];
                                        });
                                      },
                                    );
                                  },
                                ),
                        ),
                      ),
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          for (final s in ['Classic', 'Modern', 'Neon', 'Typewriter', 'Strong'])
                            GestureDetector(
                              onTap: () {
                                setModalState(() {
                                  style = s;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: s == style ? Colors.white.withAlpha(80) : Colors.white.withAlpha(30),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  s,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: s == style ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 32,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          for (final c in [Colors.white, Colors.black, Colors.red, Colors.yellow, Colors.green, Colors.blue, Colors.purple])
                            GestureDetector(
                              onTap: () {
                                setModalState(() {
                                  color = c;
                                });
                              },
                              child: Container(
                                width: 26,
                                height: 26,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: c,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: c == color ? Colors.white : Colors.white54,
                                    width: c == color ? 2 : 1,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _storyAddText() {
    _showStoryTextEditor().then((value) {
      if (value != null && mounted) {
        setState(() {
          _storyCurrentColor = value.color ?? _storyCurrentColor;
          _storyElements.add(value);
          _storyActiveElementIndex = _storyElements.length - 1;
        });
      }
    });
  }

  Future<void> _storyEditText(_StoryOverlayElement e) async {
    final updated = await _showStoryTextEditor(
      initialText: e.text ?? '',
      initialStyle: e.style ?? 'Classic',
      initialColor: e.color ?? Colors.white,
      initialMentions: e.mentions,
    );
    if (updated != null && mounted) {
      setState(() {
        final idx = _storyElements.indexOf(e);
        if (idx != -1) {
          _storyElements[idx] = e.copyWith(
            text: updated.text,
            style: updated.style,
            color: updated.color,
            mentions: updated.mentions,
          );
          _storyCurrentColor = updated.color ?? _storyCurrentColor;
        }
      });
    }
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

      final screenSize = MediaQuery.of(context).size;

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
                  'fontSize': 24.0,
                  'fontFamily': (e.style ?? 'classic').toLowerCase(),
                  'color': '#${(e.color ?? Colors.white).value.toRadixString(16).substring(2, 8).toUpperCase()}',
                  'align': 'center',
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
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 12,
                      child: Padding(
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
                    ),
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
        ],
      ),
    );
  }
}
