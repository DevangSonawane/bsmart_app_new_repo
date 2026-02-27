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
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/media_model.dart';
import 'create_post_screen.dart';
import 'create_upload_screen.dart';
import '../api/api.dart';
import '../services/supabase_service.dart';
import '../config/api_config.dart';

class StoryCameraScreen extends StatefulWidget {
  const StoryCameraScreen({super.key});

  @override
  State<StoryCameraScreen> createState() => _StoryCameraScreenState();
}

enum _StoryElementType { text, sticker }

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
  Offset _storyLastFocalPoint = Offset.zero;
  double _storyTransformBaseScale = 1.0;
  double _storyTransformBaseRotation = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    _loadRecentMedia();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _controller = null;
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

  void _toggleFlash() {
    setState(() {
      if (_flashMode == FlashMode.off) {
        _flashMode = FlashMode.auto;
      } else if (_flashMode == FlashMode.auto) {
        _flashMode = FlashMode.always;
      } else {
        _flashMode = FlashMode.off;
      }
    });
    _applyFlashMode();
  }

  void _applyFlashMode() {
    if (_controller == null) return;
    _controller!.setFlashMode(_flashMode).catchError((_) {});
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
    try {
      final xfile = await _controller!.stopVideoRecording();
      setState(() {
        _recording = false;
      });
      await _navigateToEditor(File(xfile.path), MediaType.video);
    } catch (e) {
      debugPrint('Error stopping video recording: $e');
      setState(() {
        _recording = false;
      });
    }
  }

  Future<void> _onThumbnailTap(AssetEntity asset) async {
    final file = await asset.originFile;
    if (file == null) return;
    final type = asset.type == AssetType.video ? MediaType.video : MediaType.image;
    await _navigateToEditor(file, type);
  }

  Future<void> _navigateToEditor(File file, MediaType type) async {
    if (!mounted) return;
    
    if (_mode == UploadMode.story && type == MediaType.image) {
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
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreatePostScreen(
          initialMedia: MediaItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            type: type,
            filePath: file.path,
            createdAt: DateTime.now(),
          ),
        ),
      ),
    );
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
      return const SizedBox(height: 80);
    }
    return Container(
      height: 80,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withOpacity(0),
            Colors.transparent,
          ],
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _recentAssets.length,
        itemBuilder: (context, index) {
          final asset = _recentAssets[index];
          return Padding(
            padding: EdgeInsets.only(right: index < _recentAssets.length - 1 ? 8 : 0),
            child: GestureDetector(
              onTap: () => _onThumbnailTap(asset),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: FutureBuilder<Uint8List?>(
                  future: asset.thumbnailDataWithSize(const ThumbnailSize(200, 200)),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done || snapshot.data == null) {
                      return Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey[900],
                      );
                    }
                    return Image.memory(
                      snapshot.data!,
                      width: 60,
                      height: 60,
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
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 4,
          ),
        ),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: _recording ? 32 : 68,
            height: _recording ? 32 : 68,
            decoration: BoxDecoration(
              color: _recording ? const Color(0xFFED4956) : Colors.white,
              borderRadius: BorderRadius.circular(_recording ? 8 : 34),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeTabs() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () async {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const CreateUploadScreen(),
                  ),
                );
              },
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                style: TextStyle(
                  color: _mode == UploadMode.post ? Colors.white : Colors.white54,
                  fontWeight: _mode == UploadMode.post ? FontWeight.bold : FontWeight.w500,
                  letterSpacing: 1.2,
                ),
                child: const Text('POST'),
              ),
            ),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: () {
                setState(() {
                  _mode = UploadMode.story;
                });
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
            const SizedBox(width: 16),
            GestureDetector(
              onTap: () {
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
              },
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                style: TextStyle(
                  color: _mode == UploadMode.reel ? Colors.white : Colors.white54,
                  fontWeight: _mode == UploadMode.reel ? FontWeight.bold : FontWeight.w500,
                  letterSpacing: 1.2,
                ),
                child: const Text('REEL'),
              ),
            ),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: () {
                setState(() {
                  _mode = UploadMode.live;
                });
              },
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                style: TextStyle(
                  color: _mode == UploadMode.live ? Colors.white : Colors.white54,
                  fontWeight: _mode == UploadMode.live ? FontWeight.bold : FontWeight.w500,
                  letterSpacing: 1.2,
                ),
                child: const Text('LIVE'),
              ),
            ),
          ],
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

    if (imageBytes == null) {
      debugPrint('⚠️ Image bytes are null in build');
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text('Loading image...', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
    }

    debugPrint('✅ Building story editor UI with ${imageBytes.length} bytes');

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
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                              onPressed: _exitStoryEditing,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 16,
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
                      if (!_storyStickerMode)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 10,
                          child: SizedBox(
                            height: 100,
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: SizedBox(
                                height: 100,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  itemCount: _storyFilterNames.length,
                                  itemBuilder: (context, index) {
                                    final name = _storyFilterNames[index];
                                    final selected = name == _storyCurrentFilter;
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _storyCurrentFilter = name;
                                        });
                                      },
                                      child: SizedBox(
                                        width: 80,
                                        height: 100,
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            Container(
                                              height: 60,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(18),
                                                border: Border.all(
                                                  color: selected ? Colors.white : Colors.white24,
                                                  width: selected ? 2 : 1,
                                                ),
                                                boxShadow: selected
                                                    ? [
                                                        BoxShadow(
                                                          color: Colors.black.withAlpha(100),
                                                          blurRadius: 8,
                                                          offset: const Offset(0, 4),
                                                        ),
                                                      ]
                                                    : null,
                                              ),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(16),
                                                child: ColorFiltered(
                                                  colorFilter: ColorFilter.matrix(_storyFilterMatrixFor(name)),
                                                  child: Image.memory(
                                                    imageBytes,
                                                    fit: BoxFit.cover,
                                                    gaplessPlayback: true,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              name,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                      right: 12,
                      top: 80,
                      bottom: 80,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            children: [
                              _StoryToolButton(icon: LucideIcons.type, label: 'Aa', onTap: _storyAddText),
                              const SizedBox(height: 12),
                              _StoryToolButton(
                                icon: LucideIcons.pencil,
                                label: 'Pen',
                                onTap: () {
                                  setState(() {
                                    _storyDrawingMode = true;
                                    _storyStickerMode = false;
                                  });
                                },
                              ),
                              const SizedBox(height: 12),
                              _StoryToolButton(
                                icon: LucideIcons.sticker,
                                label: 'Sticker',
                                onTap: () {
                                  setState(() {
                                    _storyStickerMode = true;
                                    _storyDrawingMode = false;
                                  });
                                },
                              ),
                            ],
                          ),
                          if (_storyDrawingMode)
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      IconButton(onPressed: _storyUndo, icon: const Icon(Icons.undo, color: Colors.white)),
                                      IconButton(onPressed: _storyRedoStroke, icon: const Icon(Icons.redo, color: Colors.white)),
                                    ],
                                  ),
                                  Slider(
                                    value: _storyBrushSize,
                                    min: 2,
                                    max: 24,
                                    divisions: 22,
                                    onChanged: (v) => setState(() => _storyBrushSize = v),
                                  ),
                                  SizedBox(
                                    height: 24,
                                    child: ListView(
                                      scrollDirection: Axis.horizontal,
                                      children: [
                                        for (final c in [Colors.white, Colors.black, Colors.red, Colors.yellow, Colors.green, Colors.blue, Colors.purple])
                                          GestureDetector(
                                            onTap: () => setState(() => _storyCurrentColor = c),
                                            child: Container(
                                              width: 24,
                                              height: 24,
                                              margin: const EdgeInsets.symmetric(horizontal: 4),
                                              decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: Colors.white)),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_storyStickerMode)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 120,
                        child: Container(
                          height: 160,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.black.withAlpha(140)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Stickers', style: TextStyle(color: Colors.white70)),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 100,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: [
                                    for (final s in ['🔥', '😊', '🎉', '⭐', '💥', '💖', '😂'])
                                      GestureDetector(
                                        onTap: () => _storyAddSticker(s),
                                        child: Container(
                                          width: 80,
                                          margin: const EdgeInsets.symmetric(horizontal: 6),
                                          decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white24)),
                                          child: Center(child: Text(s, style: const TextStyle(fontSize: 28))),
                                        ),
                                      ),
                                  ],
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
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _storyPostYourStory,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const CircleAvatar(radius: 10, backgroundColor: Colors.white, child: Icon(Icons.person, size: 12, color: Colors.blue)),
                    label: const Text('Your Story'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _storyPostCloseFriends,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF22C55E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.star),
                    label: const Text('Close Friends'),
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

  void _exitStoryEditing() {
    setState(() {
      _isStoryEditing = false;
      _editingImageFile = null;
      _editingImageBytes = null;
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
      debugPrint('\n════════════════════════════════════════');
      debugPrint('🚀 Starting Story Post');
      debugPrint('════════════════════════════════════════');
      debugPrint('Close Friends: $isCloseFriends');

      await Future.delayed(const Duration(milliseconds: 300));

      final boundary = _storyRepaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        debugPrint('❌ RepaintBoundary is null');
        debugPrint('Context: ${_storyRepaintKey.currentContext}');
        _storyShowError('Unable to capture story. Please try again.');
        return;
      }

      debugPrint('✅ RepaintBoundary found');

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

      debugPrint('\n════════════════════════════════════════');
      debugPrint('📤 STEP 1: Uploading to /api/stories/upload');
      debugPrint('════════════════════════════════════════');

      final uploadResponse = await _storyUploadWithRetry(jpg);

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
          'type': 'image',
          'width': image.width,
          'height': image.height,
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

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: _buildCameraPreview(),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.6),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(LucideIcons.x, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    IconButton(
                      icon: Icon(
                        _flashMode == FlashMode.off ? LucideIcons.zapOff : LucideIcons.zap,
                        color: Colors.white,
                      ),
                      onPressed: _toggleFlash,
                    ),
                    Row(
                      children: [
                        if (_cameras.length > 1)
                          IconButton(
                            icon: _isSwitchingCamera
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(LucideIcons.refreshCw, color: Colors.white),
                            onPressed: _isSwitchingCamera ? null : _switchCamera,
                          ),
                        IconButton(
                          icon: const Icon(LucideIcons.settings, color: Colors.white),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMediaCarousel(),
                  const SizedBox(height: 20),
                  _buildCaptureControls(),
                  const SizedBox(height: 20),
                  _buildModeTabs(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
