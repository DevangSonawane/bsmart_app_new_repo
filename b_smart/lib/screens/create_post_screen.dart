import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../services/supabase_service.dart';
import '../utils/current_user.dart';
import '../config/api_config.dart';
import '../api/upload_api.dart';
import '../api/posts_api.dart';
import '../api/users_api.dart';
import '../models/media_model.dart';

/// Single media item in the create-post flow (select → crop → edit → share).
class _CreatePostMediaItem {
  String sourcePath;
  String? croppedPath; // after crop step (images only)
  bool isVideo;
  double aspect;
  String filter;
  Map<String, int> adjustments;

  _CreatePostMediaItem({
    required this.sourcePath,
    this.croppedPath, // ignore: unused_element_parameter
    required this.isVideo,
    this.aspect = 1.0, // ignore: unused_element_parameter
    this.filter = 'Original', // ignore: unused_element_parameter
    Map<String, int>? adjustments,
  }) : adjustments = adjustments ?? {
    'brightness': 0, 'contrast': 0, 'saturate': 0,
    'sepia': 0, 'opacity': 0, 'vignette': 0,
  };

  String get displayPath => (isVideo ? sourcePath : (croppedPath ?? sourcePath));
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

// Adjustments matching React (property name, label, min, max)
const _adjustments = [
  ('brightness', 'Brightness', -100, 100),
  ('contrast', 'Contrast', -100, 100),
  ('saturate', 'Saturation', -100, 100),
  ('sepia', 'Temperature', -100, 100),
  ('opacity', 'Fade', 0, 100),
  ('vignette', 'Vignette', 0, 100),
];

const _popularEmojis = ['😂', '😮', '😍', '😢', '👏', '🔥', '🎉', '💯', '❤️', '🤣', '🥰', '😘', '😭', '😊'];

class CreatePostScreen extends StatefulWidget {
  final MediaItem? initialMedia;
  const CreatePostScreen({Key? key, this.initialMedia}) : super(key: key);

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final ImagePicker _picker = ImagePicker();
  final SupabaseService _svc = SupabaseService();
  final TextEditingController _captionCtl = TextEditingController();

  String _step = 'select'; // select | crop | edit | share
  List<_CreatePostMediaItem> _media = [];
  int _currentIndex = 0;

  // Share step
  String _location = '';
  bool _hideLikes = false;
  bool _turnOffCommenting = false;
  bool _advancedOpen = false;
  bool _showEmojiPicker = false;
  final List<_PostTag> _tags = [];
  bool _showTagSearch = false;
  double _tagX = 0, _tagY = 0;
  List<Map<String, dynamic>> _tagSearchResults = [];
  bool _isSearchingUsers = false;
  bool _isSubmitting = false;
  Map<String, dynamic>? _currentUserProfile;

  // Edit step tab
  String _editTab = 'filters';

  Future<void> _loadCurrentUserProfile() async {
    final uid = await CurrentUser.id;
    if (uid == null) return;
    final profile = await _svc.getUserById(uid);
    if (mounted) setState(() => _currentUserProfile = profile);
  }

  @override
  void initState() {
    super.initState();
    _loadCurrentUserProfile();
    final m = widget.initialMedia;
    if (m != null && m.filePath != null) {
      final item = _CreatePostMediaItem(
        sourcePath: m.filePath!,
        isVideo: m.type == MediaType.video,
      );
      _media = [item];
      _currentIndex = 0;
      _step = 'crop';
    }
  }

  @override
  void dispose() {
    _captionCtl.dispose();
    super.dispose();
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
            _step = 'crop';
          } else {
            _media.addAll(newItems);
            _currentIndex = _media.length - 1;
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
            _step = 'crop';
          } else {
            _media.add(item);
            _currentIndex = _media.length - 1;
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
            _step = 'crop';
          } else {
            _media.add(item);
            _currentIndex = _media.length - 1;
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

  Future<void> _cropCurrent() async {
    final item = _currentMedia;
    if (item == null) return;
    // Advance to next item or edit step. Native ImageCropper is skipped to avoid
    // app crashes on some platforms (path/activity issues); use source image as-is.
    if (item.isVideo) {
      if (mounted) {
        setState(() {
          _advanceFromCrop((nextIndex, nextStep) {
            _currentIndex = nextIndex;
            if (nextStep != null) _step = nextStep;
          });
        });
      }
      return;
    }
    // For images: use source path as display/upload path (no native crop) so flow never crashes
    if (mounted) {
      setState(() {
        _media[_currentIndex].croppedPath = item.sourcePath;
        _advanceFromCrop((nextIndex, nextStep) {
          _currentIndex = nextIndex;
          if (nextStep != null) _step = nextStep;
        });
      });
    }
  }

  /// Returns (nextIndex, nextStep). If nextStep is non-null, transition to that step with index 0.
  void _advanceFromCrop(void Function(int index, String? step) apply) {
    if (_currentIndex < _media.length - 1) {
      apply(_currentIndex + 1, null);
    } else {
      apply(0, 'edit');
    }
  }

  void _back() {
    if (_step == 'share') {
      setState(() => _step = 'edit');
    } else if (_step == 'edit') {
      setState(() => _step = 'crop');
    } else if (_step == 'crop') {
      setState(() {
        _step = 'select';
        _media = [];
        _currentIndex = 0;
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  void _next() {
    try {
      if (_step == 'crop') {
        _cropCurrent();
      } else if (_step == 'edit') {
        if (mounted) setState(() => _step = 'share');
      } else if (_step == 'share') {
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

  void _setAspect(double a) {
    final item = _currentMedia;
    if (item != null) setState(() => item.aspect = a);
  }

  void _applyFilter(String name) {
    final item = _currentMedia;
    if (item != null) setState(() => item.filter = name);
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

  void _updateAdjustment(String key, int value) {
    final item = _currentMedia;
    if (item != null) setState(() => item.adjustments[key] = value);
  }

  String? _draggingTagId;

  void _onImageTapForTag(TapDownDetails details, Size size) {
    if (_draggingTagId != null) return;
    setState(() {
      _tagX = (details.localPosition.dx / size.width).clamp(0.0, 1.0) * 100;
      _tagY = (details.localPosition.dy / size.height).clamp(0.0, 1.0) * 100;
      _showTagSearch = true;
      _searchTagUsers('');
    });
  }

  Timer? _searchDebounce;
  String _lastSearchQuery = '';

  Future<void> _searchTagUsers(String query) async {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    
    // Clear results if query is empty
    if (query.isEmpty) {
      if (mounted) setState(() {
        _tagSearchResults = [];
        _isSearchingUsers = false;
        _lastSearchQuery = '';
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      setState(() {
        _isSearchingUsers = true;
        _lastSearchQuery = query;
      });
      try {
        final list = await UsersApi().search(query);
        if (mounted) setState(() {
          _tagSearchResults = list;
          _isSearchingUsers = false;
        });
      } catch (e) {
        if (mounted) setState(() {
          _tagSearchResults = [];
          _isSearchingUsers = false;
        });
      }
    });
  }

  void _addTag(Map<String, dynamic> user) {
    setState(() {
      _tags.add(_PostTag(
        id: '${DateTime.now().millisecondsSinceEpoch}_${user['id']}',
        x: _tagX,
        y: _tagY,
        user: user,
      ));
      _showTagSearch = false;
    });
  }

  void _removeTag(String id) {
    setState(() => _tags.removeWhere((t) => t.id == id));
  }

  Future<void> _submit() async {
    if (_isSubmitting || _media.isEmpty) return;
    final userId = await CurrentUser.id;
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
        processedMedia.add({
          'fileName': serverFileName,
          'fileUrl': fileUrl,
          'type': item.isVideo ? 'video' : 'image',
          'crop': {
            'mode': 'original',
            'zoom': 1.0,
            'x': 0,
            'y': 0,
          },
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

      final peopleTags = _tags.map((t) => {
        'user_id': t.user['id'] ?? t.user['_id'],
        'username': t.user['username'],
        'x': t.x,
        'y': t.y,
      }).toList();

      final hashtagMatches = RegExp(r'#[a-zA-Z0-9_]+').allMatches(_captionCtl.text.trim()).map((m) => m.group(0)!).toList();

      final postData = {
        'caption': _captionCtl.text.trim(),
        'location': _location.isEmpty ? null : _location,
        'media': processedMedia,
        'tags': hashtagMatches,
        'people_tags': peopleTags,
        'hide_likes_count': _hideLikes,
        'turn_off_commenting': _turnOffCommenting,
        'type': 'post',
      };
      final created = await PostsApi().createPost(
        media: processedMedia.cast<Map<String, dynamic>>(),
        caption: _captionCtl.text.trim(),
        location: _location.isEmpty ? null : _location,
        tags: hashtagMatches,
        hideLikesCount: _hideLikes,
        turnOffCommenting: _turnOffCommenting,
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
    final isSelect = _step == 'select';
    return Scaffold(
      backgroundColor: isSelect ? Colors.white : const Color(0xFFF0F0F0),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: Colors.black87),
          onPressed: _back,
        ),
        title: Text(
          isSelect ? 'Create new post' : _step == 'crop' ? 'Crop' : _step == 'edit' ? 'Edit' : 'Create new post',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.black87),
        ),
        centerTitle: true,
        actions: [
          if (!isSelect)
            TextButton(
              onPressed: (_step == 'share' && _isSubmitting) ? null : _next,
              child: Text(
                _step == 'share' ? (_isSubmitting ? 'Sharing...' : 'Share') : 'Next',
                style: TextStyle(
                  color: (_step == 'share' && _isSubmitting) ? Colors.grey : const Color(0xFF0095F6),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: isSelect ? _buildSelect() : _step == 'crop' ? _buildCrop() : _step == 'edit' ? _buildEdit() : _buildShare(),
      ),
    );
  }

  Widget _buildSelect() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.image, size: 56, color: Colors.grey[700]),
                const SizedBox(width: 8),
                Icon(LucideIcons.video, size: 56, color: Colors.grey[700]),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Drag photos and videos here',
              style: TextStyle(fontSize: 20, color: Colors.grey[800], fontWeight: FontWeight.w300),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _takePhoto,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0095F6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Take Photo'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _recordVideo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0095F6),
                    foregroundColor: Colors.white,
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
                backgroundColor: const Color(0xFF0095F6),
                foregroundColor: Colors.white,
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

  Widget _buildCrop() {
    final item = _currentMedia;
    if (item == null) return const SizedBox();
    return Stack(
      children: [
        Center(
          child: item.isVideo
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.video, size: 80, color: Colors.grey[600]),
                    const SizedBox(height: 8),
                    Text('Video (no crop)', style: TextStyle(color: Colors.grey[600])),
                  ],
                )
              : item.aspect == 0.0
                  ? Image.file(File(item.sourcePath), fit: BoxFit.contain)
                  : AspectRatio(
                      aspectRatio: item.aspect,
                      child: Image.file(File(item.sourcePath), fit: BoxFit.cover),
                    ),
        ),
        // Aspect ratio buttons
        Positioned(
          left: 16,
          bottom: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _aspectButton('Original', 0.0, () => _setAspect(0)),
              _aspectButton('1:1', 1.0, () => _setAspect(1)),
              _aspectButton('4:5', 4/5, () => _setAspect(4/5)),
              _aspectButton('16:9', 16/9, () => _setAspect(16/9)),
            ],
          ),
        ),
        if (_media.length > 1) ...[
          if (_currentIndex > 0)
            Positioned(
              left: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: Icon(LucideIcons.chevronLeft, color: Colors.white, size: 32),
                  style: IconButton.styleFrom(backgroundColor: Colors.black54),
                  onPressed: () => setState(() => _currentIndex--),
                ),
              ),
            ),
          if (_currentIndex < _media.length - 1)
            Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: Icon(LucideIcons.chevronRight, color: Colors.white, size: 32),
                  style: IconButton.styleFrom(backgroundColor: Colors.black54),
                  onPressed: () => setState(() => _currentIndex++),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _aspectButton(String label, double current, VoidCallback onTap) {
    final isSelected = (_currentMedia?.aspect ?? -1) == current;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isSelected ? Colors.white : Colors.black54,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(label, style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontWeight: FontWeight.w500)),
          ),
        ),
      ),
    );
  }

  static const double _editPanelMinWidth = 300;
  static const double _sharePanelMinWidth = 340;

  Widget _buildEdit() {
    final item = _currentMedia;
    if (item == null) return const SizedBox();
    final file = File(item.displayPath);
    return LayoutBuilder(
      builder: (context, constraints) {
        final useColumn = constraints.maxWidth < 600;
        final imageSection = Stack(
          alignment: Alignment.center,
          children: [
            item.isVideo
                ? Icon(LucideIcons.video, size: 100, color: Colors.grey[600])
                : _applyFilterToImage(file, item),
            if (_media.length > 1) ...[
              if (_currentIndex > 0)
                Positioned(
                  left: 8,
                  child: IconButton(
                    icon: Icon(LucideIcons.chevronLeft, color: Colors.black87),
                    style: IconButton.styleFrom(backgroundColor: Colors.white70),
                    onPressed: () => setState(() => _currentIndex--),
                  ),
                ),
              if (_currentIndex < _media.length - 1)
                Positioned(
                  right: 8,
                  child: IconButton(
                    icon: Icon(LucideIcons.chevronRight, color: Colors.black87),
                    style: IconButton.styleFrom(backgroundColor: Colors.white70),
                    onPressed: () => setState(() => _currentIndex++),
                  ),
                ),
            ],
          ],
        );
        final toolsSection = Container(
          width: useColumn ? null : _editPanelMinWidth,
          constraints: useColumn ? null : BoxConstraints(minWidth: _editPanelMinWidth),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              left: useColumn ? BorderSide.none : BorderSide(color: Theme.of(context).dividerColor),
              top: useColumn ? BorderSide(color: Theme.of(context).dividerColor) : BorderSide.none,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _editTab = 'filters'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: _editTab == 'filters' ? Colors.black : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                        child: Text(
                          'Filters',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: _editTab == 'filters' ? Colors.black : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _editTab = 'adjustments'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: _editTab == 'adjustments' ? Colors.black : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                        child: Text(
                          'Adjustments',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: _editTab == 'adjustments' ? Colors.black : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _editTab == 'filters'
                      ? Row(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: _filterNames.map((name) {
                                    final selected = item.filter == name;
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 16),
                                      child: InkWell(
                                        onTap: () => _applyFilter(name),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 72,
                                              height: 72,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: selected ? const Color(0xFF0095F6) : Colors.grey.shade300,
                                                  width: 2,
                                                ),
                                              ),
                                              clipBehavior: Clip.antiAlias,
                                              child: item.isVideo
                                                  ? Icon(LucideIcons.video, size: 32)
                                                  : _filterThumbnail(file, name, selected),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              name,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                                                color: selected ? const Color(0xFF0095F6) : Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _adjustments.map((adj) {
                            final key = adj.$1;
                            final label = adj.$2;
                            final min = adj.$3;
                            final max = adj.$4;
                            final value = item.adjustments[key] ?? 0;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                      Text('$value', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                    ],
                                  ),
                                  Slider(
                                    value: value.toDouble(),
                                    min: min.toDouble(),
                                    max: max.toDouble(),
                                    onChanged: (v) => _updateAdjustment(key, v.round()),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                ),
              ),
            ],
          ),
        );
        if (useColumn) {
          return Column(
            children: [
              Expanded(flex: 2, child: imageSection),
              SizedBox(
                height: 280,
                child: toolsSection,
              ),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 2, child: imageSection),
            toolsSection,
          ],
        );
      },
    );
  }

  /// Applies named filter preset + adjustments (matches React getFilterStyle).
  Widget _applyFilterToImage(File file, _CreatePostMediaItem item) {
    final adj = item.adjustments;
    final b = (adj['brightness'] ?? 0) / 100.0 + 1.0;
    final c = (adj['contrast'] ?? 0) / 100.0 + 1.0;
    final s = (adj['saturate'] ?? 0) / 100.0 + 1.0;
    final opacity = 1.0 - (adj['opacity'] ?? 0) / 100.0;
    final presetMatrix = _filterMatrixFor(item.filter);
    final adjustmentMatrix = _buildFilterMatrix(brightness: b, contrast: c, saturation: s);
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: ColorFiltered(
        colorFilter: ColorFilter.matrix(presetMatrix),
        child: ColorFiltered(
          colorFilter: ColorFilter.matrix(adjustmentMatrix),
          child: item.aspect == 0.0
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

  /// Thumbnail with a single filter preset (for Filters tab).
  Widget _filterThumbnail(File file, String filterName, bool isSelected) {
    final matrix = _filterMatrixFor(filterName);
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(matrix),
      child: Image.file(file, fit: BoxFit.cover),
    );
  }

  Future<Uint8List> _processImageBytes(Uint8List srcBytes, _CreatePostMediaItem item) async {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(srcBytes, (img) => completer.complete(img));
    final srcImage = await completer.future;
    final srcW = srcImage.width.toDouble();
    final srcH = srcImage.height.toDouble();
    Rect srcRect;
    if (item.aspect == 0.0 || item.aspect <= 0) {
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
    final b = (adj['brightness'] ?? 0) / 100.0 + 1.0;
    final c = (adj['contrast'] ?? 0) / 100.0 + 1.0;
    final s = (adj['saturate'] ?? 0) / 100.0 + 1.0;
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

  Widget _buildShare() {
    final item = _currentMedia;
    if (item == null) return const SizedBox();
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final useColumn = constraints.maxWidth < 600;

        final imageSection = LayoutBuilder(
          builder: (context, imageConstraints) {
            final w = imageConstraints.maxWidth;
            final h = imageConstraints.maxHeight;
            return Stack(
              alignment: Alignment.center,
              children: [
                GestureDetector(
                  onTapDown: (details) => _onImageTapForTag(details, Size(w, h)),
                  child: Container(
                    width: w,
                    height: h,
                    color: Colors.black,
                    child: Center(
                      child: item.isVideo
                          ? Icon(LucideIcons.video, size: 100, color: Colors.grey[600])
                          : _applyFilterToImage(File(item.displayPath), item),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 16,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                      child: const Text('Tap photo to tag people', style: TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  ),
                ),
                ..._tags.map((t) {
                  final x = (t.x / 100) * w;
                  final y = (t.y / 100) * h;
                  return Positioned(
                    left: x,
                    top: y,
                    child: GestureDetector(
                      onPanStart: (_) => setState(() => _draggingTagId = t.id),
                      onPanEnd: (_) => setState(() => _draggingTagId = null),
                      onPanUpdate: (details) {
                        setState(() {
                          t.x += (details.delta.dx / w) * 100;
                          t.y += (details.delta.dy / h) * 100;
                          t.x = t.x.clamp(0.0, 100.0);
                          t.y = t.y.clamp(0.0, 100.0);
                        });
                      },
                      child: Transform.translate(
                        offset: const Offset(-20, -15),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 8,
                                backgroundColor: Colors.grey[800],
                                backgroundImage: t.user['avatar_url'] != null && (t.user['avatar_url'] as String).isNotEmpty
                                    ? NetworkImage(t.user['avatar_url'] as String)
                                    : null,
                                child: t.user['avatar_url'] == null || (t.user['avatar_url'] as String).isEmpty
                                    ? Text(((t.user['username'] as String?) ?? 'U')[0].toUpperCase(),
                                        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold))
                                    : null,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                (t.user['username'] as String?) ?? '',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () => _removeTag(t.id),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(LucideIcons.x, size: 10, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                if (_showTagSearch) _buildTagSearchOverlay(),
                if (_media.length > 1) ...[
                  if (_currentIndex > 0)
                    Positioned(
                      left: 8,
                      child: IconButton(
                        icon: Icon(LucideIcons.chevronLeft, color: Colors.black87),
                        style: IconButton.styleFrom(backgroundColor: Colors.white70),
                        onPressed: () => setState(() => _currentIndex--),
                      ),
                    ),
                  if (_currentIndex < _media.length - 1)
                    Positioned(
                      right: 8,
                      child: IconButton(
                        icon: Icon(LucideIcons.chevronRight, color: Colors.black87),
                        style: IconButton.styleFrom(backgroundColor: Colors.white70),
                        onPressed: () => setState(() => _currentIndex++),
                      ),
                    ),
                ],
              ],
            );
          }
        );

        final sharePanel = Container(
          color: Theme.of(context).colorScheme.surface,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              // User row (React: user avatar + username)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: _currentUserProfile?['avatar_url'] != null &&
                              (_currentUserProfile!['avatar_url'] as String).isNotEmpty
                          ? NetworkImage(_currentUserProfile!['avatar_url'] as String)
                          : null,
                      child: _currentUserProfile?['avatar_url'] == null ||
                              (_currentUserProfile!['avatar_url'] as String).isEmpty
                          ? Text(
                              ((_currentUserProfile?['username'] as String?) ?? 'U').toUpperCase().substring(0, 1),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      (_currentUserProfile?['username'] as String?) ?? 'User',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              // Caption section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _captionCtl,
                      maxLines: 6,
                      maxLength: 2200,
                      decoration: const InputDecoration(
                        hintText: 'Write a caption...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        counterText: '',
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(LucideIcons.smile, color: Colors.grey[600], size: 22),
                          onPressed: () => setState(() => _showEmojiPicker = !_showEmojiPicker),
                        ),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _captionCtl,
                          builder: (_, value, __) => Text(
                            '${value.text.length}/2,200',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ),
                      ],
                    ),
                    if (_showEmojiPicker)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Most popular',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: _popularEmojis.map((e) => InkWell(
                                onTap: () {
                                  _captionCtl.text = _captionCtl.text + e;
                                  setState(() {});
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: Text(e, style: const TextStyle(fontSize: 22)),
                                ),
                              )).toList(),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Add Tag row (React parity)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Icon(LucideIcons.userPlus, size: 22, color: Colors.grey[700]),
                title: const Text('Add Tag', style: TextStyle(fontSize: 14)),
              ),
              // Advanced Settings accordion (React: Hide likes, Turn off commenting + description)
              InkWell(
                onTap: () => setState(() => _advancedOpen = !_advancedOpen),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Advanced Settings', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      Icon(_advancedOpen ? LucideIcons.chevronUp : LucideIcons.chevronDown, color: Colors.grey[600], size: 20),
                    ],
                  ),
                ),
              ),
              if (_advancedOpen) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Hide like and view counts on this post',
                                  style: TextStyle(fontSize: 14),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Only you will see the total number of likes and views. You can change this later in the ... menu.',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                          Switch(value: _hideLikes, onChanged: (v) => setState(() => _hideLikes = v)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Turn off commenting', style: TextStyle(fontSize: 14)),
                                const SizedBox(height: 4),
                                Text(
                                  'You can change this later in the ... menu at the top of your post.',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                          Switch(value: _turnOffCommenting, onChanged: (v) => setState(() => _turnOffCommenting = v)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        );

        final borderedPanel = Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              left: useColumn ? BorderSide.none : BorderSide(color: Theme.of(context).dividerColor),
              top: useColumn ? BorderSide(color: Theme.of(context).dividerColor) : BorderSide.none,
            ),
          ),
          child: sharePanel,
        );

        if (useColumn) {
          return Column(
            children: [
              Expanded(flex: 2, child: imageSection),
              if (!_showTagSearch)
                SizedBox(
                  height: 320,
                  child: borderedPanel,
                ),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 2, child: imageSection),
            SizedBox(
              width: _sharePanelMinWidth,
              child: borderedPanel,
            ),
          ],
        );
      },
    );
  }

  Widget _buildTagSearchOverlay() {
    return Positioned(
      left: 24,
      right: 24,
      top: 24,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.4, // Reduced slightly to ensure it fits well
          ),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tag People', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 20),
                    onPressed: () {
                      setState(() {
                        _showTagSearch = false;
                      });
                    },
                  ),
                ],
              ),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Search user',
                  prefixIcon: Icon(LucideIcons.search, size: 20),
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onChanged: (v) => _searchTagUsers(v),
              ),
              const SizedBox(height: 8),
              Flexible(
                fit: FlexFit.loose,
                child: _isSearchingUsers
                    ? const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : _tagSearchResults.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Center(
                              child: Text(
                                _lastSearchQuery.isEmpty 
                                  ? 'Type a name to search...' 
                                  : 'No users found',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: _tagSearchResults.length,
                            itemBuilder: (_, i) {
                              final u = _tagSearchResults[i];
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundImage: u['avatar_url'] != null && (u['avatar_url'] as String).isNotEmpty
                                      ? NetworkImage(u['avatar_url'] as String)
                                      : null,
                                  child: u['avatar_url'] == null || (u['avatar_url'] as String).isEmpty
                                      ? const Icon(LucideIcons.user, size: 16)
                                      : null,
                                ),
                                title: Text((u['username'] as String?) ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                subtitle: Text((u['full_name'] as String?) ?? '', style: const TextStyle(fontSize: 12)),
                                onTap: () => _addTag(u),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
