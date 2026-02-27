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
import '../config/api_config.dart';

// --- Models ---

enum _StoryElementType { text, sticker }

class _StoryOverlayElement {
  final _StoryElementType type;
  final String? text;
  final String? style;
  final Color? color;
  final String? sticker;
  Offset position;
  double scale;
  double rotation;

  _StoryOverlayElement({
    required this.type,
    this.text,
    this.style,
    this.color,
    this.sticker,
    required this.position,
    required this.scale,
    required this.rotation,
  });

  factory _StoryOverlayElement.text(String text, {String style = 'Classic', Color color = Colors.white}) {
    return _StoryOverlayElement(
      type: _StoryElementType.text,
      text: text,
      style: style,
      color: color,
      position: const Offset(150, 300),
      scale: 1.0,
      rotation: 0.0,
    );
  }

  factory _StoryOverlayElement.sticker(String label) {
    return _StoryOverlayElement(
      type: _StoryElementType.sticker,
      sticker: label,
      position: const Offset(150, 300),
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
  }) {
    return _StoryOverlayElement(
      type: type,
      text: text ?? this.text,
      style: style ?? this.style,
      color: color ?? this.color,
      sticker: sticker,
      position: position ?? this.position,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
    );
  }
}

// --- Interaction Widget ---

class _StoryElementWidget extends StatefulWidget {
  final _StoryOverlayElement element;
  final VoidCallback onStartDrag;
  final void Function(Offset endPosition) onEndDrag;
  final VoidCallback onTap;
  final VoidCallback onUpdate;

  const _StoryElementWidget({
    super.key,
    required this.element,
    required this.onStartDrag,
    required this.onEndDrag,
    required this.onTap,
    required this.onUpdate,
  });

  @override
  State<_StoryElementWidget> createState() => _StoryElementWidgetState();
}

class _StoryElementWidgetState extends State<_StoryElementWidget> {
  late Offset _basePosition;
  late double _baseScale;
  late double _baseRotation;

  @override
  Widget build(BuildContext context) {
    final e = widget.element;

    return Positioned(
      left: e.position.dx,
      top: e.position.dy,
      child: GestureDetector(
        onTap: widget.onTap,
        onScaleStart: (details) {
          widget.onStartDrag();
          _basePosition = e.position;
          _baseScale = e.scale;
          _baseRotation = e.rotation;
        },
        onScaleUpdate: (details) {
          setState(() {
            // 1. Handle Translation (Movement)
            // We use the focalPointDelta to move the element relative to where it started
            e.position = _basePosition + details.localFocalPoint - details.localFocalPoint; 
            // Better approach for smooth dragging:
            e.position = Offset(
              _basePosition.dx + (details.focalPointDelta.dx * 1.0),
              _basePosition.dy + (details.focalPointDelta.dy * 1.0),
            );
            _basePosition = e.position;

            // 2. Handle Scaling (Pinch)
            if (details.scale != 1.0) {
              e.scale = _baseScale * details.scale;
            }

            // 3. Handle Rotation
            if (details.rotation != 0.0) {
              e.rotation = _baseRotation + details.rotation;
            }
          });
          widget.onUpdate();
        },
        onScaleEnd: (details) {
          widget.onEndDrag(e.position);
        },
        child: Transform.rotate(
          angle: e.rotation,
          child: Transform.scale(
            scale: e.scale,
            child: _buildContent(e),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(_StoryOverlayElement e) {
    if (e.type == _StoryElementType.sticker) {
      return Text(e.sticker ?? '', style: const TextStyle(fontSize: 60));
    }

    final color = e.color ?? Colors.white;
    final styleName = e.style ?? 'Classic';
    
    TextStyle textStyle;
    BoxDecoration decoration = const BoxDecoration();

    switch (styleName) {
      case 'Modern':
        textStyle = TextStyle(color: color, fontSize: 32, fontWeight: FontWeight.bold);
        break;
      case 'Neon':
        textStyle = TextStyle(
          color: color,
          fontSize: 32,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: color, blurRadius: 15)],
        );
        break;
      case 'Typewriter':
        textStyle = TextStyle(color: Colors.black, fontSize: 28, fontFamily: 'Courier');
        decoration = BoxDecoration(color: color, borderRadius: BorderRadius.circular(4));
        break;
      case 'Strong':
        textStyle = const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic);
        decoration = BoxDecoration(color: color);
        break;
      default:
        textStyle = TextStyle(color: color, fontSize: 32, fontWeight: FontWeight.bold);
        decoration = BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(12),
        );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: decoration,
      child: Text(e.text ?? '', style: textStyle, textAlign: TextAlign.center),
    );
  }
}

// --- Main Screen ---

class StoryCameraScreen extends StatefulWidget {
  const StoryCameraScreen({super.key});

  @override
  State<StoryCameraScreen> createState() => _StoryCameraScreenState();
}

class _StoryCameraScreenState extends State<StoryCameraScreen> with WidgetsBindingObserver {
  // ... (Keep all your existing variables: _controller, _isStoryEditing, etc.)
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
  bool _storyShowTrash = false;
  bool _storyDrawingMode = false;
  bool _storyStickerMode = false;
  final List<_StoryStroke> _storyStrokes = [];
  final List<_StoryStroke> _storyRedo = [];
  double _storyBrushSize = 8.0;
  Color _storyCurrentColor = Colors.white;
  String _storyCurrentFilter = 'Original';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    _loadRecentMedia();
  }

  // ... (Keep existing _initCamera, _initializeCameraController, _toggleFlash, _switchCamera, _loadRecentMedia, _onCapturePressed, _onRecordStart, _onRecordEnd, _onThumbnailTap, _navigateToEditor methods)

  // ... [PLACEHOLDER FOR PREVIOUS CAMERA METHODS - KEEP AS PER YOUR CODE] ...

  @override
  Widget build(BuildContext context) {
    if (_isStoryEditing) {
      return _buildStoryEditingUi(context);
    }
    // ... (Keep existing camera build logic)
    return _buildCameraUI(); 
  }

  Widget _buildStoryEditingUi(BuildContext context) {
    final imageBytes = _editingImageBytes;
    if (imageBytes == null) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. The Main Content (Repaint Boundary)
          RepaintBoundary(
            key: _storyRepaintKey,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColorFiltered(
                  colorFilter: ColorFilter.matrix(_storyFilterMatrixFor(_storyCurrentFilter)),
                  child: Image.memory(imageBytes, fit: BoxFit.cover),
                ),
                CustomPaint(painter: _StoryDrawingPainter(_storyStrokes)),
                // The Interaction Layer
                for (var element in _storyElements)
                  _StoryElementWidget(
                    element: element,
                    onUpdate: () => setState(() {}),
                    onStartDrag: () => setState(() => _storyShowTrash = true),
                    onTap: () {
                       if (element.type == _StoryElementType.text) _storyEditText(element);
                    },
                    onEndDrag: (pos) {
                      setState(() => _storyShowTrash = false);
                      // Instagram-style Trash logic
                      if (pos.dy > MediaQuery.of(context).size.height - 150) {
                        setState(() => _storyElements.remove(element));
                      }
                    },
                  ),
              ],
            ),
          ),

          // 2. Editing Toolbar
          Positioned(
            top: 40,
            right: 10,
            child: Column(
              children: [
                _StoryToolButton(icon: LucideIcons.type, label: 'Text', onTap: _storyAddText),
                const SizedBox(height: 15),
                _StoryToolButton(icon: LucideIcons.sticker, label: 'Stickers', onTap: () => setState(() => _storyStickerMode = true)),
              ],
            ),
          ),

          // 3. Trash Can
          if (_storyShowTrash)
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Icon(LucideIcons.trash2, color: Colors.white, size: 40),
            ),

          // 4. Footer Buttons (Your Story / Close Friends)
          _buildStoryFooter(),
          
          if (_storyStickerMode) _buildStickerPicker(),
        ],
      ),
    );
  }

  // ... (Keep _storyAddText, _storyEditText, _storyPostToApi, and Filter logic)

  Widget _buildStoryFooter() {
    return Positioned(
      bottom: 20,
      left: 15,
      right: 15,
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => _storyPostToApi(isCloseFriends: false),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
              child: const Text("Your Story"),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton(
              onPressed: () => _storyPostToApi(isCloseFriends: true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text("Close Friends"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickerPicker() {
    return Container(
      color: Colors.black87,
      child: GridView.count(
        crossAxisCount: 4,
        children: ['🔥', '😂', '❤️', '📍', '✅', '✨'].map((s) {
          return GestureDetector(
            onTap: () {
              setState(() {
                _storyElements.add(_StoryOverlayElement.sticker(s));
                _storyStickerMode = false;
              });
            },
            child: Center(child: Text(s, style: const TextStyle(fontSize: 40))),
          );
        }).toList(),
      ),
    );
  }
  
  // Note: Integrate the above into your existing class structure.
  // The most important fix is the _StoryElementWidget logic.
}

// ... (Keep your _StoryStroke, _StoryDrawingPainter, and FilterMatrix helper functions)