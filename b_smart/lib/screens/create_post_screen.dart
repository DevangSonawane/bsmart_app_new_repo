import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../utils/current_user.dart';
import '../config/api_config.dart';
import '../api/upload_api.dart';
import '../api/posts_api.dart';
import '../models/media_model.dart';
import 'tag_people_screen.dart';

/// Single media item in the create-post flow (select → crop → edit → share).
class _CreatePostMediaItem {
  String sourcePath;
  String? croppedPath; // after crop step (images only)
  bool isVideo;
  bool alreadyCropped;
  bool alreadyProcessed;
  double aspect;
  String filter;
  Map<String, int> adjustments;

  _CreatePostMediaItem({
    required this.sourcePath,
    this.croppedPath, // ignore: unused_element_parameter
    required this.isVideo,
    this.alreadyCropped = false,
    this.alreadyProcessed = false,
    this.aspect = 1.0, // ignore: unused_element_parameter
    this.filter = 'Original', // ignore: unused_element_parameter
    Map<String, int>? adjustments,
  }) : adjustments = adjustments ?? {
    'brightness': 0, 'contrast': 0, 'saturate': 0, 'lux': 0,
    'sepia': 0, 'opacity': 0, 'vignette': 0,
  };

  String get displayPath => (isVideo ? sourcePath : (croppedPath ?? sourcePath));
}

class _MoreOptionsScreen extends StatefulWidget {
  final bool turnOffCommenting;
  final bool hideLikes;
  final bool hideShares;
  final void Function(bool turnOffCommenting, bool hideLikes, bool hideShares)
      onChanged;

  const _MoreOptionsScreen({
    required this.turnOffCommenting,
    required this.hideLikes,
    required this.hideShares,
    required this.onChanged,
  });

  @override
  State<_MoreOptionsScreen> createState() => _MoreOptionsScreenState();
}

class _MoreOptionsScreenState extends State<_MoreOptionsScreen> {
  late bool _turnOffCommenting;
  late bool _hideLikes;
  late bool _hideShares;

  @override
  void initState() {
    super.initState();
    _turnOffCommenting = widget.turnOffCommenting;
    _hideLikes = widget.hideLikes;
    _hideShares = widget.hideShares;
  }

  void _update(void Function() fn) {
    setState(fn);
    widget.onChanged(_turnOffCommenting, _hideLikes, _hideShares);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final appBarBg =
        theme.appBarTheme.backgroundColor ?? theme.scaffoldBackgroundColor;
    final appBarFg =
        theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: appBarBg,
        elevation: 0,
        iconTheme: IconThemeData(color: appBarFg),
        title: Text(
          'More options',
          style: TextStyle(color: appBarFg, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How others can interact with your post',
                style: TextStyle(
                  color: muted,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              _buildMoreOptionToggle(
                context,
                icon: Icons.comments_disabled_outlined,
                title: 'Turn off commenting',
                value: _turnOffCommenting,
                onChanged: (v) => _update(() => _turnOffCommenting = v),
              ),
              const SizedBox(height: 12),
              _buildMoreOptionToggle(
                context,
                icon: Icons.favorite_border,
                title: 'Hide like count on this post',
                subtitle:
                    'Only you will see the total number of likes and views on this post.',
                value: _hideLikes,
                onChanged: (v) => _update(() => _hideLikes = v),
              ),
              const SizedBox(height: 12),
              _buildMoreOptionToggle(
                context,
                icon: Icons.ios_share,
                title: 'Hide share count on this post',
                subtitle:
                    'Only you will see the number of likes and shares on this post.',
                value: _hideShares,
                onChanged: (v) => _update(() => _hideShares = v),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

  Widget _buildMoreOptionToggle(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface;
    final muted = theme.colorScheme.onSurfaceVariant;
    final primary = _shareBlue;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Icon(icon, color: fg, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: fg,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: muted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 10),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: Colors.black,
          activeTrackColor: Colors.black.withValues(alpha: 0.25),
          inactiveThumbColor: fg.withValues(alpha: 0.7),
          inactiveTrackColor: fg.withValues(alpha: 0.12),
        ),
      ],
    );
  }

/// Tag on the post (x, y as percentage; user map from Supabase).
class _PostTag {
  final String id;
  double x, y;
  final Map<String, dynamic> user;

  _PostTag({required this.id, required this.x, required this.y, required this.user});
}

// Filter names matching React CreatePostModal
const _filterNames = [
  'Original', 'Clarendon', 'Gingham', 'Moon', 'Lark', 'Reyes', 'Juno',
  'Slumber', 'Crema', 'Ludwig', 'Aden', 'Perpetua',
];

// Top-level 4x5 color matrix. When brightness=1, contrast=1, saturation=1 returns IDENTITY (no change).
// Saturation: s=1 = full color (identity), s=0 = grayscale. Uses luminance weights.
List<double> _buildFilterMatrixBase({double brightness = 1, double contrast = 1, double saturation = 1}) {
  final b = brightness;
  final c = contrast;
  final s = saturation;
  final invSat = 1 - s;
  const lr = 0.2126, lg = 0.7152, lb = 0.0722;
  final scale = c * b;
  // Saturation matrix: (1-s)*luminance + s*channel → identity when s=1
  return [
    (invSat * lr + s) * scale, invSat * lg * scale, invSat * lb * scale, 0, 0,
    invSat * lr * scale, (invSat * lg + s) * scale, invSat * lb * scale, 0, 0,
    invSat * lr * scale, invSat * lg * scale, (invSat * lb + s) * scale, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

// Filter preset matrices (approximate React CSS: contrast, saturate, brightness, grayscale, sepia).
List<double> _filterMatrixFor(String name) {
  switch (name) {
    case 'Clarendon':
      return _buildFilterMatrixBase(brightness: 1.0, contrast: 1.2, saturation: 1.25);
    case 'Gingham':
      return _buildFilterMatrixBase(brightness: 1.05, contrast: 1.0, saturation: 1.0);
    case 'Moon':
      return _buildGrayscaleMatrix(contrast: 1.1, brightness: 1.1);
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

class CreatePostScreen extends StatefulWidget {
  final MediaItem? initialMedia;
  final List<MediaItem>? initialMediaList;
  final double? initialAspect;
  final String? initialFilterName;
  final Map<String, int>? initialAdjustments;
  const CreatePostScreen({
    super.key,
    this.initialMedia,
    this.initialMediaList,
    this.initialAspect,
    this.initialFilterName,
    this.initialAdjustments,
  });

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

const _shareBlue = Color(0xFF4F6EF7);

class _CreatePostScreenState extends State<CreatePostScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _captionCtl = TextEditingController();

  String _step = 'select'; // select | crop | edit | share
  List<_CreatePostMediaItem> _media = [];
  int _currentIndex = 0;
  PageController? _previewPageController;
  PageController? _overlayPageController;

  // Share step
  final String _location = '';
  bool _hideLikes = false;
  bool _turnOffCommenting = false;
  bool _hideShares = false;
  final Map<int, List<_PostTag>> _tagsByIndex = {};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final list = widget.initialMediaList;
    if (list != null && list.isNotEmpty) {
      _media = list
          .where((m) => m.filePath != null)
          .map((m) {
            final baseName = m.filePath!.split('/').last;
            final alreadyCropped = baseName.startsWith('bsmart_crop_') || baseName.startsWith('bsmart_post_');
            final alreadyProcessed = baseName.startsWith('bsmart_post_');
            return _CreatePostMediaItem(
              sourcePath: m.filePath!,
              isVideo: m.type == MediaType.video,
              alreadyCropped: alreadyCropped,
              alreadyProcessed: alreadyProcessed,
              aspect: widget.initialAspect ?? 1.0,
              adjustments: widget.initialAdjustments,
            );
          })
          .toList();
      _currentIndex = 0;
      _ensurePreviewControllers();
      _step = 'share';
      return;
    }

    final m = widget.initialMedia;
    if (m != null && m.filePath != null) {
      final baseName = m.filePath!.split('/').last;
      final alreadyCropped = baseName.startsWith('bsmart_crop_') || baseName.startsWith('bsmart_post_');
      final alreadyProcessed = baseName.startsWith('bsmart_post_');
      final item = _CreatePostMediaItem(
        sourcePath: m.filePath!,
        isVideo: m.type == MediaType.video,
        alreadyCropped: alreadyCropped,
        alreadyProcessed: alreadyProcessed,
        aspect: widget.initialAspect ?? 1.0,
        adjustments: widget.initialAdjustments,
      );
      if (widget.initialFilterName != null && widget.initialFilterName!.isNotEmpty) {
        // Only apply if our filter list recognizes the name, otherwise keep Original
        final name = widget.initialFilterName!;
        item.filter = _filterNames.contains(name) ? name : 'Original';
      }
      _media = [item];
      _currentIndex = 0;
      _ensurePreviewControllers();
      _step = 'share';
    }
  }

  @override
  void dispose() {
    _captionCtl.dispose();
    _previewPageController?.dispose();
    _overlayPageController?.dispose();
    super.dispose();
  }

  void _ensurePreviewControllers() {
    if (_media.length > 1) {
      _previewPageController ??= PageController(initialPage: _currentIndex);
      _overlayPageController ??= PageController(initialPage: _currentIndex);
    }
  }

  _CreatePostMediaItem? get _currentMedia =>
      _media.isEmpty ? null : _media[_currentIndex.clamp(0, _media.length - 1)];

  Future<void> _pickMedia() async {
    try {
      final files = await _picker.pickMultipleMedia();
      if (files.isEmpty) return;
      final newItems = <_CreatePostMediaItem>[];
      for (final x in files) {
        final path = x.path;
        final isVideo = path.toLowerCase().contains('.mp4') ||
            path.toLowerCase().contains('.mov') ||
            (x.mimeType?.startsWith('video/') ?? false);
        newItems.add(_CreatePostMediaItem(sourcePath: path, isVideo: isVideo));
      }
      if (mounted) {
        setState(() {
          if (_step == 'select') {
            _media = newItems;
            _currentIndex = 0;
            _ensurePreviewControllers();
            _step = 'share';
          } else {
            _media.addAll(newItems);
            _currentIndex = _media.length - 1;
            _ensurePreviewControllers();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick media: $e')),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      final x = await _picker.pickImage(source: ImageSource.camera);
      if (x == null) return;
      final item = _CreatePostMediaItem(sourcePath: x.path, isVideo: false);
      if (mounted) {
        setState(() {
          if (_step == 'select') {
            _media = [item];
            _currentIndex = 0;
            _ensurePreviewControllers();
            _step = 'share';
          } else {
            _media.add(item);
            _currentIndex = _media.length - 1;
            _ensurePreviewControllers();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not capture photo: $e')),
        );
      }
    }
  }

  Future<void> _recordVideo() async {
    try {
      final x = await _picker.pickVideo(source: ImageSource.camera, maxDuration: const Duration(seconds: 60));
      if (x == null) return;
      final item = _CreatePostMediaItem(sourcePath: x.path, isVideo: true);
      if (mounted) {
        setState(() {
          if (_step == 'select') {
            _media = [item];
            _currentIndex = 0;
            _ensurePreviewControllers();
            _step = 'share';
          } else {
            _media.add(item);
            _currentIndex = _media.length - 1;
            _ensurePreviewControllers();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not record video: $e')),
        );
      }
    }
  }

  void _back() {
    Navigator.of(context).maybePop();
  }

  void _next() {
    try {
      if (_step == 'share') {
        _submit();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Something went wrong: $e')),
        );
      }
    }
  }

  String _cssFrom(String name, Map<String, int> adj) {
    final presets = {
      'Original': '',
      'Clarendon': 'contrast(1.2) saturate(1.25)',
      'Gingham': 'brightness(1.05) hue-rotate(-10deg)',
      'Moon': 'grayscale(1) contrast(1.1) brightness(1.1)',
      'Lark': 'contrast(0.9)',
      'Reyes': 'sepia(0.22) brightness(1.1) contrast(0.85) saturate(0.75)',
      'Juno': 'contrast(1.2) brightness(1.1) saturate(1.4) sepia(0.2)',
      'Slumber': 'brightness(1.05) saturate(0.66) sepia(0.20)',
      'Crema': 'contrast(0.9) saturate(0.9) sepia(0.2)',
      'Ludwig': 'contrast(0.9) saturate(0.9) brightness(1.1)',
      'Aden': 'contrast(0.9) saturate(0.85) brightness(1.2) hue-rotate(-20deg)',
      'Perpetua': 'contrast(1.1) brightness(1.1) saturate(1.1)',
    };
    final base = presets[name] ?? '';
    final brightness = 'brightness(${100 + (adj['brightness'] ?? 0)}%)';
    final contrast = 'contrast(${100 + (adj['contrast'] ?? 0)}%)';
    final saturate = 'saturate(${100 + (adj['saturate'] ?? 0)}%)';
    final sepia = ((adj['sepia'] ?? 0) != 0) ? 'sepia(${(adj['sepia'] ?? 0).abs()}%)' : '';
    String hue = '';
    final s = adj['sepia'] ?? 0;
    if (s < 0) {
      hue = 'hue-rotate(${s.abs()}deg)';
    } else if (s > 0) {
      hue = 'hue-rotate(${s}deg)';
    }
    final parts = [base, brightness, contrast, saturate, sepia, hue].where((e) => e.isNotEmpty).toList();
    return parts.join(' ');
  }

  String _aspectRatioLabel(double? aspect) {
    final a = aspect ?? 0.0;
    if (a <= 0) return 'original';
    if ((a - 1).abs() < 0.001) return '1:1';
    if ((a - (4 / 5)).abs() < 0.001) return '4:5';
    if ((a - (16 / 9)).abs() < 0.001) return '16:9';
    if ((a - (9 / 16)).abs() < 0.001) return '9:16';
    return 'custom';
  }

  bool _showPreviewOverlay = false;

  Future<void> _openTagPeople() async {
    if (_media.isEmpty) return;
    final initialByIndex = <int, List<Map<String, dynamic>>>{};
    for (final entry in _tagsByIndex.entries) {
      if (entry.value.isEmpty) continue;
      initialByIndex[entry.key] = entry.value
          .map((t) => {
                'id': t.id,
                'x': t.x,
                'y': t.y,
                'user': t.user,
                'mediaIndex': entry.key,
              })
          .toList();
    }
    final result = await Navigator.of(context).push<List<Map<String, dynamic>>>(
      MaterialPageRoute(
        builder: (_) => TagPeopleScreen(
          mediaPaths: _media.map((m) => m.displayPath).toList(),
          isVideos: _media.map((m) => m.isVideo).toList(),
          filterNames: _media.map((m) => m.filter).toList(),
          adjustments: _media.map((m) => m.adjustments).toList(),
          alreadyProcessed: _media.map((m) => m.alreadyProcessed).toList(),
          initialTagsByIndex: initialByIndex,
          initialIndex: _currentIndex,
        ),
      ),
    );
    if (!mounted) return;
    if (result == null) return;
    setState(() {
      _tagsByIndex.clear();
      for (final m in result) {
        final mediaIndex = (m['mediaIndex'] as num?)?.toInt() ?? _currentIndex;
        final list = _tagsByIndex.putIfAbsent(mediaIndex, () => []);
        list.add(
          _PostTag(
            id: (m['id'] ?? '').toString(),
            x: (m['x'] as num?)?.toDouble() ?? 0.5,
            y: (m['y'] as num?)?.toDouble() ?? 0.5,
            user: Map<String, dynamic>.from(m['user'] as Map),
          ),
        );
      }
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting || _media.isEmpty) return;
    final userId = await CurrentUser.id;
    if (!mounted) return;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to share.')));
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final processedMedia = <Map<String, dynamic>>[];
      for (final item in _media) {
        final path = item.isVideo ? item.sourcePath : (item.croppedPath ?? item.sourcePath);
        final file = File(path);
        if (!await file.exists()) continue;
        final bytes = await file.readAsBytes();
        final isImage = !item.isVideo;
        Uint8List toUpload;
        String ext;
        if (isImage) {
          if (item.alreadyProcessed) {
            toUpload = Uint8List.fromList(bytes);
            ext = path.split('.').last;
          } else {
            final processed = await _processImageBytes(Uint8List.fromList(bytes), item);
            var jpg = await FlutterImageCompress.compressWithList(
              processed,
              quality: 85,
              format: CompressFormat.jpeg,
            );
            if (jpg.length > 4 * 1024 * 1024) {
              jpg = await FlutterImageCompress.compressWithList(
                jpg,
                quality: 70,
                format: CompressFormat.jpeg,
              );
            }
            toUpload = Uint8List.fromList(jpg);
            ext = 'jpg';
          }
        } else {
          toUpload = Uint8List.fromList(bytes);
          ext = path.split('.').last;
        }
        final filename = '$userId/${DateTime.now().millisecondsSinceEpoch}_${item.hashCode % 100000}.$ext';
        final uploaded = await UploadApi().uploadFileBytes(bytes: toUpload, filename: filename);
        final serverFileName = (uploaded['fileName'] ?? uploaded['filename'] ?? filename).toString();
        String? fileUrl = uploaded['fileUrl']?.toString();
        if (fileUrl != null && fileUrl.isNotEmpty) {
          fileUrl = fileUrl.replaceAll('\\', '/');
          final isAbs = fileUrl.startsWith('http://') || fileUrl.startsWith('https://');
          if (!isAbs) {
            final base = ApiConfig.baseUrl;
            final baseUri = Uri.parse(base);
            final origin = '${baseUri.scheme}://${baseUri.host}${baseUri.hasPort ? ':${baseUri.port}' : ''}';
            if (!fileUrl.startsWith('/')) {
              if (fileUrl.startsWith('uploads/') || fileUrl.contains('/')) {
                fileUrl = '/$fileUrl';
              } else {
                fileUrl = '/uploads/$fileUrl';
              }
            }
            fileUrl = '$origin$fileUrl';
          } else if (fileUrl.startsWith('http://')) {
            try {
              final parsed = Uri.parse(fileUrl);
              fileUrl = Uri(
                scheme: 'https',
                host: parsed.host,
                port: parsed.hasPort ? parsed.port : null,
                path: parsed.path,
                query: parsed.query,
              ).toString();
            } catch (_) {}
          }
        }
        final adj = item.adjustments;
        final css = _cssFrom(item.filter, adj);
        final aspectLabel = _aspectRatioLabel(item.aspect);
        processedMedia.add({
          'fileName': serverFileName,
          'fileUrl': fileUrl,
          'type': item.isVideo ? 'video' : 'image',
          'crop': {
            'mode': 'original',
            'zoom': 1,
            'x': 0,
            'y': 0,
            'aspect_ratio': aspectLabel,
          },
          'aspect_ratio': aspectLabel,
          'filter': {
            'name': item.filter,
            'css': css,
          },
          'adjustments': {
            'brightness': adj['brightness'],
            'contrast': adj['contrast'],
            'saturation': adj['saturate'],
            'temperature': adj['sepia'],
            'fade': adj['opacity'],
            'vignette': adj['vignette'],
          },
        });
      }
      if (processedMedia.isEmpty) throw Exception('No media to upload');

      final peopleTags = _tagsByIndex.values.expand((list) => list).map((t) => {
            'user_id': t.user['id'] ?? t.user['_id'],
            'username': t.user['username'],
            'x': t.x,
            'y': t.y,
          }).toList();

      final hashtagMatches = RegExp(r'#[a-zA-Z0-9_]+').allMatches(_captionCtl.text.trim()).map((m) => m.group(0)!).toList();

      final created = await PostsApi().createPost(
        media: processedMedia.cast<Map<String, dynamic>>(),
        caption: _captionCtl.text.trim(),
        location: _location.isEmpty ? null : _location,
        tags: hashtagMatches,
        hideLikesCount: _hideLikes,
        turnOffCommenting: _turnOffCommenting,
        hideShareCount: _hideShares,
        peopleTags: peopleTags.cast<Map<String, dynamic>>(),
        type: 'post',
      );
      if (created.isNotEmpty && mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post shared successfully!')));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to create post.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface;
    final appBarBg =
        theme.appBarTheme.backgroundColor ?? theme.scaffoldBackgroundColor;
    final appBarFg =
        theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface;
    final isSelect = _step == 'select';
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: appBarBg,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: appBarFg),
          onPressed: _back,
        ),
        title: Text(
          isSelect ? 'Create new post' : 'New post',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: fg,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: isSelect ? _buildSelect() : _buildShare(),
      ),
    );
  }

  Widget _buildSelect() {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    const primary = Color(0xFF0095F6);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.image, size: 56, color: muted),
                const SizedBox(width: 8),
                Icon(LucideIcons.video, size: 56, color: muted),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Drag photos and videos here',
              style: TextStyle(fontSize: 20, color: muted, fontWeight: FontWeight.w300),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _takePhoto,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Take Photo'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _recordVideo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Record Video'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _pickMedia,
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Select From Gallery'),
            ),
          ],
        ),
      ),
    );
  }

  /// Applies named filter preset + adjustments (matches React getFilterStyle).
  Widget _applyFilterToImage(File file, _CreatePostMediaItem item) {
    if (item.alreadyProcessed) {
      return Image.file(file, fit: BoxFit.cover);
    }
    final adj = item.adjustments;
    final lux = ((adj['lux'] ?? 0).clamp(0, 100) / 100.0);
    final luxBC = 1.0 + (lux * 0.35);
    final luxS = 1.0 + (lux * 0.2);
    final b = ((adj['brightness'] ?? 0) / 100.0 + 1.0) * luxBC;
    final c = ((adj['contrast'] ?? 0) / 100.0 + 1.0) * luxBC;
    final s = ((adj['saturate'] ?? 0) / 100.0 + 1.0) * luxS;
    final opacity = 1.0 - (adj['opacity'] ?? 0) / 100.0;
    final presetMatrix = _filterMatrixFor(item.filter);
    final adjustmentMatrix = _buildFilterMatrix(brightness: b, contrast: c, saturation: s);
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: ColorFiltered(
        colorFilter: ColorFilter.matrix(presetMatrix),
        child: ColorFiltered(
          colorFilter: ColorFilter.matrix(adjustmentMatrix),
          child: item.alreadyCropped
              ? Image.file(file, fit: BoxFit.cover)
              : item.aspect == 0.0
                  ? Image.file(file, fit: BoxFit.contain)
                  : AspectRatio(
                      aspectRatio: item.aspect,
                      child: Image.file(file, fit: BoxFit.cover),
                    ),
        ),
      ),
    );
  }

  /// Adjustment matrix (brightness/contrast/saturation). Identity when b=1, c=1, s=1.
  List<double> _buildFilterMatrix({double brightness = 1, double contrast = 1, double saturation = 1}) {
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


  Future<Uint8List> _processImageBytes(Uint8List srcBytes, _CreatePostMediaItem item) async {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(srcBytes, (img) => completer.complete(img));
    final srcImage = await completer.future;
    final srcW = srcImage.width.toDouble();
    final srcH = srcImage.height.toDouble();
    Rect srcRect;
    if (item.alreadyCropped || item.aspect == 0.0 || item.aspect <= 0) {
      srcRect = Rect.fromLTWH(0, 0, srcW, srcH);
    } else {
      final target = item.aspect;
      final current = srcW / srcH;
      if (current > target) {
        final newW = srcH * target;
        final left = (srcW - newW) / 2.0;
        srcRect = Rect.fromLTWH(left, 0, newW, srcH);
      } else {
        final newH = srcW / target;
        final top = (srcH - newH) / 2.0;
        srcRect = Rect.fromLTWH(0, top, srcW, newH);
      }
    }
    final dstW = srcRect.width.round();
    final dstH = srcRect.height.round();
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, dstW.toDouble(), dstH.toDouble()));
    final adj = item.adjustments;
    final lux = ((adj['lux'] ?? 0).clamp(0, 100) / 100.0);
    final luxBC = 1.0 + (lux * 0.35);
    final luxS = 1.0 + (lux * 0.2);
    final b = ((adj['brightness'] ?? 0) / 100.0 + 1.0) * luxBC;
    final c = ((adj['contrast'] ?? 0) / 100.0 + 1.0) * luxBC;
    final s = ((adj['saturate'] ?? 0) / 100.0 + 1.0) * luxS;
    final opacity = 1.0 - (adj['opacity'] ?? 0) / 100.0;
    final preset = _filterMatrixFor(item.filter);
    final adjust = _buildFilterMatrix(brightness: b, contrast: c, saturation: s);
    final combined = _combineColorMatrices(adjust, preset);
    combined[18] = combined[18] * opacity;
    final paint = Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high
      ..colorFilter = ui.ColorFilter.matrix(combined);
    final src = ui.Rect.fromLTWH(srcRect.left, srcRect.top, srcRect.width, srcRect.height);
    final dst = ui.Rect.fromLTWH(0, 0, dstW.toDouble(), dstH.toDouble());
    canvas.drawImageRect(srcImage, src, dst, paint);
    final picture = recorder.endRecording();
    final outImage = await picture.toImage(dstW, dstH);
    final byteData = await outImage.toByteData(format: ui.ImageByteFormat.png);
    return Uint8List.view(byteData!.buffer);
  }

  List<double> _combineColorMatrices(List<double> a, List<double> b) {
    final out = List<double>.filled(20, 0.0);
    for (var row = 0; row < 4; row++) {
      for (var col = 0; col < 4; col++) {
        double sum = 0.0;
        for (var k = 0; k < 4; k++) {
          sum += b[row * 5 + k] * a[k * 5 + col];
        }
        out[row * 5 + col] = sum;
      }
      double t = b[row * 5 + 4];
      for (var k = 0; k < 4; k++) {
        t += b[row * 5 + k] * a[k * 5 + 4];
      }
      out[row * 5 + 4] = t;
    }
    return out;
  }

  Future<void> _openMoreOptions() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 340),
        pageBuilder: (_, __, ___) => _MoreOptionsScreen(
          turnOffCommenting: _turnOffCommenting,
          hideLikes: _hideLikes,
          hideShares: _hideShares,
          onChanged: (nextTurnOff, nextHideLikes, nextHideShares) {
            setState(() {
              _turnOffCommenting = nextTurnOff;
              _hideLikes = nextHideLikes;
              _hideShares = nextHideShares;
            });
          },
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: const Interval(0.05, 1.0, curve: Curves.easeOut),
                reverseCurve:
                    const Interval(0.0, 0.95, curve: Curves.easeIn),
              ),
            ),
            child: child,
          );
        },
      ),
    );
  }

  Widget _buildShare() {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface;
    final muted = theme.colorScheme.onSurfaceVariant;
    final divider = theme.dividerColor;
    final item = _currentMedia;
    if (item == null) return const SizedBox();
    final aspect = item.aspect == 0.0 ? 1.0 : item.aspect;

    Widget optionRow({
      required IconData icon,
      required String label,
      String? subtitle,
      VoidCallback? onTap,
    }) {
      return InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: fg, size: 20),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(color: fg, fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    if (subtitle != null && subtitle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          subtitle,
                          style: TextStyle(color: muted, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                  ],
                ),
              ),
              Icon(LucideIcons.chevronRight, color: muted, size: 18),
            ],
          ),
        ),
      );
    }

    Widget pillButton({
      required IconData icon,
      required String label,
      VoidCallback? onTap,
    }) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.6)
                : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: fg, size: 18),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: fg, fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    }

    // Audio suggestion chips removed per request

    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 96),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          _overlayPageController?.jumpToPage(_currentIndex);
                          setState(() => _showPreviewOverlay = true);
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            color: theme.colorScheme.surface,
                            child: SizedBox(
                              width: 160,
                              child: _media.length <= 1
                                  ? AspectRatio(
                                      aspectRatio: aspect,
                                      child: item.isVideo
                                          ? Icon(LucideIcons.video,
                                              size: 64, color: muted)
                                          : _applyFilterToImage(
                                              File(item.displayPath), item),
                                    )
                                  : AspectRatio(
                                      aspectRatio: (_media[_currentIndex].aspect == 0.0)
                                          ? 1.0
                                          : _media[_currentIndex].aspect,
                                      child: PageView.builder(
                                        controller: _previewPageController,
                                        itemCount: _media.length,
                                        onPageChanged: (i) {
                                          setState(() {
                                            _currentIndex = i;
                                          });
                                          _overlayPageController?.jumpToPage(i);
                                        },
                                        itemBuilder: (context, i) {
                                          final m = _media[i];
                                          final a = (m.aspect == 0.0) ? 1.0 : m.aspect;
                                          return AspectRatio(
                                            aspectRatio: a,
                                            child: m.isVideo
                                                ? Icon(LucideIcons.video,
                                                    size: 64, color: muted)
                                                : _applyFilterToImage(
                                                    File(m.displayPath), m),
                                          );
                                        },
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    TextField(
                      controller: _captionCtl,
                      maxLines: 4,
                      style: TextStyle(color: fg, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'Add a caption...',
                        hintStyle: TextStyle(color: muted, fontSize: 16),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        pillButton(icon: LucideIcons.listOrdered, label: 'Poll'),
                        const SizedBox(width: 12),
                        pillButton(icon: LucideIcons.search, label: 'Prompt'),
                      ],
                    ),
                    const SizedBox(height: 22),
                    optionRow(icon: LucideIcons.music2, label: 'Add audio'),
                    const SizedBox(height: 8),
                    optionRow(
                      icon: LucideIcons.userPlus,
                      label: 'Tag people',
                      subtitle: (() {
                        final usernames = _tagsByIndex.values
                            .expand((list) => list)
                            .map((t) => (t.user['username'] ?? '').toString())
                            .where((u) => u.isNotEmpty)
                            .toList();
                        if (usernames.isEmpty) return '';
                        if (usernames.length <= 2) {
                          return usernames.join(', ');
                        }
                        return '${usernames.take(2).join(', ')} +${usernames.length - 2} more';
                      })(),
                      onTap: _openTagPeople,
                    ),
                    optionRow(icon: LucideIcons.mapPin, label: 'Add location'),
                    const SizedBox(height: 8),
                    Divider(
                      color: theme.brightness == Brightness.dark
                          ? divider.withValues(alpha: 0.35)
                          : Colors.grey.shade300,
                      height: 1,
                    ),
                    optionRow(
                      icon: LucideIcons.ellipsis,
                      label: 'More options',
                      onTap: _openMoreOptions,
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _next,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _shareBlue,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          _shareBlue.withValues(alpha: 0.6),
                      disabledForegroundColor: Colors.white70,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      _isSubmitting ? 'Sharing...' : 'Share',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_showPreviewOverlay) _buildPreviewOverlay(),
        
      ],
    );
  }

  Widget _buildPreviewOverlay() {
    final item = _currentMedia;
    if (item == null) return const SizedBox.shrink();
    final aspect = (item.aspect == 0.0) ? 1.0 : item.aspect;
    return Positioned.fill(
      child: Stack(
        children: [
          GestureDetector(
            onTap: () => setState(() => _showPreviewOverlay = false),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(color: Colors.black.withValues(alpha: 0.25)),
            ),
          ),
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.96, end: 1.0),
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              builder: (context, scale, child) {
                return Transform.scale(scale: scale, child: child);
              },
              child: Material(
                elevation: 16,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.9,
                    child: _media.length <= 1
                        ? AspectRatio(
                            aspectRatio: aspect,
                            child: item.isVideo
                                ? Icon(LucideIcons.video,
                                    size: 100, color: Colors.grey[600])
                                : _applyFilterToImage(
                                    File(item.displayPath), item),
                          )
                        : AspectRatio(
                            aspectRatio: (_media[_currentIndex].aspect == 0.0)
                                ? 1.0
                                : _media[_currentIndex].aspect,
                            child: PageView.builder(
                              controller: _overlayPageController,
                              itemCount: _media.length,
                              onPageChanged: (i) {
                                setState(() {
                                  _currentIndex = i;
                                });
                                _previewPageController?.jumpToPage(i);
                              },
                              itemBuilder: (context, i) {
                                final m = _media[i];
                                final a = (m.aspect == 0.0) ? 1.0 : m.aspect;
                                return AspectRatio(
                                  aspectRatio: a,
                                  child: m.isVideo
                                      ? Icon(LucideIcons.video,
                                          size: 100,
                                          color: Colors.grey[600])
                                      : _applyFilterToImage(
                                          File(m.displayPath), m),
                                );
                              },
                            ),
                          ),
                  ),
              ),
            ),
          ),
          Positioned(
            top: 24,
            right: 24,
            child: IconButton(
              icon: const Icon(LucideIcons.x, color: Colors.white, size: 24),
              onPressed: () => setState(() => _showPreviewOverlay = false),
            ),
          ),
        ],
      ),
    );
  }
}
