import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/ads_api.dart';
import '../api/auth_api.dart';
import '../api/upload_api.dart';
import '../config/api_config.dart';
import '../theme/design_tokens.dart';

enum _ComposerStep { select, crop, edit, share }

List<double> _buildFilterMatrixBase({
  double brightness = 1,
  double contrast = 1,
  double saturation = 1,
}) {
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

List<double> _buildGrayscaleMatrix({
  double contrast = 1.0,
  double brightness = 1.0,
}) {
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

List<double> _buildSepiaMatrix({
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

List<double> _filterMatrixFor(String name) {
  switch (name) {
    case 'Clarendon':
      return _buildFilterMatrixBase(
        brightness: 1.0,
        contrast: 1.2,
        saturation: 1.25,
      );
    case 'Gingham':
      return _buildFilterMatrixBase(
        brightness: 1.05,
        contrast: 1.0,
        saturation: 1.0,
      );
    case 'Moon':
      return _buildGrayscaleMatrix(contrast: 1.1, brightness: 1.1);
    case 'Lark':
      return _buildFilterMatrixBase(
        brightness: 1.0,
        contrast: 0.9,
        saturation: 1.0,
      );
    case 'Reyes':
      return _buildSepiaMatrix(
        amount: 0.22,
        brightness: 1.1,
        contrast: 0.85,
        saturation: 0.75,
      );
    case 'Juno':
      return _buildSepiaMatrix(
        amount: 0.2,
        brightness: 1.1,
        contrast: 1.2,
        saturation: 1.4,
      );
    case 'Slumber':
      return _buildSepiaMatrix(
        amount: 0.2,
        brightness: 1.05,
        contrast: 1.0,
        saturation: 0.66,
      );
    case 'Crema':
      return _buildSepiaMatrix(
        amount: 0.2,
        brightness: 1.0,
        contrast: 0.9,
        saturation: 0.9,
      );
    case 'Ludwig':
      return _buildFilterMatrixBase(
        brightness: 1.1,
        contrast: 0.9,
        saturation: 0.9,
      );
    case 'Aden':
      return _buildFilterMatrixBase(
        brightness: 1.2,
        contrast: 0.9,
        saturation: 0.85,
      );
    case 'Perpetua':
      return _buildFilterMatrixBase(
        brightness: 1.1,
        contrast: 1.1,
        saturation: 1.1,
      );
    case 'Original':
    default:
      return _buildFilterMatrixBase(brightness: 1.0, contrast: 1.0, saturation: 1.0);
  }
}

class _AdComposerMedia {
  String path;
  final bool isVideo;
  double aspect = 1.0;
  String filter = 'Original';
  final Map<String, int> adjustments;

  _AdComposerMedia({
    required this.path,
    required this.isVideo,
  }) : adjustments =
            {
              'brightness': 0,
              'contrast': 0,
              'saturate': 0,
              'sepia': 0,
              'opacity': 0,
              'vignette': 0,
            };
}

class AdvertiserCreateAdScreen extends StatefulWidget {
  final String initialContentType;
  final String? initialMediaPath;
  final bool? initialMediaIsVideo;

  const AdvertiserCreateAdScreen({
    super.key,
    this.initialContentType = 'post',
    this.initialMediaPath,
    this.initialMediaIsVideo,
  });

  @override
  State<AdvertiserCreateAdScreen> createState() => _AdvertiserCreateAdScreenState();
}

class _AdvertiserCreateAdScreenState extends State<AdvertiserCreateAdScreen> {
  final ImagePicker _picker = ImagePicker();
  final UploadApi _uploadApi = UploadApi();
  final AdsApi _adsApi = AdsApi();

  _ComposerStep _step = _ComposerStep.select;
  final List<_AdComposerMedia> _media = [];
  int _currentIndex = 0;

  Map<String, dynamic>? _me;
  final TextEditingController _captionCtl = TextEditingController();
  final TextEditingController _locationCtl = TextEditingController();
  final TextEditingController _budgetCtl = TextEditingController();

  bool _hideLikes = false;
  bool _turnOffCommenting = false;
  bool _advancedOpen = false;
  String _editTab = 'filters';
  String _contentType = 'post';
  bool _isSubmitting = false;
  int _uploadProgress = 0;
  String _uploadStage = '';

  List<String> _categories = const [];
  bool _loadingCategories = false;
  String? _selectedCategory;
  final Set<String> _selectedLanguages = <String>{};
  final Set<String> _selectedCountries = <String>{};

  final List<String> _filters = const [
    'Original',
    'Clarendon',
    'Gingham',
    'Moon',
    'Lark',
    'Reyes',
    'Juno',
    'Slumber',
    'Crema',
    'Ludwig',
    'Aden',
    'Perpetua',
  ];
  static const double _editPanelMinWidth = 300;

  final List<String> _languages = const [
    'Arabic',
    'Chinese',
    'English',
    'French',
    'German',
    'Hindi',
    'Italian',
    'Japanese',
    'Korean',
    'Portuguese',
    'Russian',
    'Spanish',
    'Turkish',
  ];

  final List<String> _countries = const [
    'Argentina',
    'Australia',
    'Austria',
    'Bangladesh',
    'Belgium',
    'Brazil',
    'Canada',
    'Chile',
    'China',
    'Colombia',
    'Czech Republic',
    'Denmark',
    'Egypt',
    'Finland',
    'France',
    'Germany',
    'Greece',
    'India',
    'Indonesia',
    'Ireland',
    'Italy',
    'Japan',
    'Malaysia',
    'Mexico',
    'Netherlands',
    'New Zealand',
    'Nigeria',
    'Norway',
    'Pakistan',
    'Peru',
    'Philippines',
    'Poland',
    'Portugal',
    'Romania',
    'Russia',
    'Saudi Arabia',
    'Singapore',
    'South Africa',
    'South Korea',
    'Spain',
    'Sweden',
    'Switzerland',
    'Thailand',
    'Turkey',
    'UAE',
    'UK',
    'USA',
    'Ukraine',
    'Vietnam',
  ];

  @override
  void initState() {
    super.initState();
    final t = widget.initialContentType.toLowerCase().trim();
    _contentType = t == 'reel' ? 'reel' : 'post';
    final mediaPath = widget.initialMediaPath?.trim();
    if (mediaPath != null && mediaPath.isNotEmpty) {
      final isVideo = widget.initialMediaIsVideo ?? _isVideoPath(mediaPath);
      _media
        ..clear()
        ..add(_AdComposerMedia(path: mediaPath, isVideo: isVideo));
      _currentIndex = 0;
      _step = _ComposerStep.crop;
    }
    _loadMe();
    _loadCategories();
  }

  @override
  void dispose() {
    _captionCtl.dispose();
    _locationCtl.dispose();
    _budgetCtl.dispose();
    super.dispose();
  }

  _AdComposerMedia? get _currentMedia =>
      _media.isEmpty ? null : _media[_currentIndex.clamp(0, _media.length - 1)];

  bool _isVideoPath(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m4v') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.webm');
  }

  Future<void> _loadMe() async {
    try {
      final raw = await AuthApi().me();
      final me = raw['user'] is Map<String, dynamic>
          ? raw['user'] as Map<String, dynamic>
          : raw;
      if (!mounted) return;
      setState(() => _me = me);
    } catch (_) {}
  }

  Future<void> _loadCategories() async {
    setState(() => _loadingCategories = true);
    try {
      final categories = await _adsApi.getCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories.isNotEmpty
            ? categories
            : const [
                'Fashion',
                'Electronics',
                'Food & Dining',
                'Beauty & Personal Care',
                'Travel',
                'Education',
                'Technology',
                'Other',
              ];
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _categories = const [
          'Fashion',
          'Electronics',
          'Food & Dining',
          'Beauty & Personal Care',
          'Travel',
          'Education',
          'Technology',
          'Other',
        ];
      });
    } finally {
      if (mounted) setState(() => _loadingCategories = false);
    }
  }

  Future<void> _showAddCategoryDialog() async {
    final controller = TextEditingController();
    final categoryName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            hintText: 'Enter category name',
          ),
          onSubmitted: (_) => Navigator.of(context).pop(controller.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    final name = categoryName?.trim() ?? '';
    if (name.isEmpty) return;

    try {
      await _adsApi.addCategory(name);
      await _loadCategories();
      if (!mounted) return;

      final matched = _categories
          .where((c) => c.toLowerCase() == name.toLowerCase())
          .cast<String?>()
          .firstWhere((c) => c != null, orElse: () => null);

      setState(() {
        _selectedCategory = matched ?? name;
      });
      _showSnack('Category added successfully.');
    } catch (e) {
      _showSnack('Could not add category: $e');
    }
  }

  Future<void> _pickMedia() async {
    try {
      final items = await _picker.pickMultipleMedia();
      if (items.isEmpty) return;
      final picked = <_AdComposerMedia>[];
      for (final x in items) {
        final path = x.path;
        final lower = path.toLowerCase();
        final isVideo = lower.endsWith('.mp4') ||
            lower.endsWith('.mov') ||
            lower.endsWith('.m4v') ||
            (x.mimeType?.startsWith('video/') ?? false);
        if (_contentType == 'reel' && !isVideo) {
          continue;
        }
        picked.add(_AdComposerMedia(path: path, isVideo: isVideo));
      }
      if (picked.isEmpty) {
        _showSnack(
          _contentType == 'reel'
              ? 'Reel supports video files only.'
              : 'No supported media selected.',
        );
        return;
      }
      if (!mounted) return;
      setState(() {
        _media
          ..clear()
          ..addAll(picked);
        _currentIndex = 0;
        _step = _ComposerStep.crop;
      });
    } catch (e) {
      _showSnack('Could not pick media: $e');
    }
  }

  Future<void> _takePhoto() async {
    if (_contentType == 'reel') {
      _showSnack('Reel supports video only.');
      return;
    }
    try {
      final x = await _picker.pickImage(source: ImageSource.camera);
      if (x == null) return;
      if (!mounted) return;
      setState(() {
        _media
          ..clear()
          ..add(_AdComposerMedia(path: x.path, isVideo: false));
        _currentIndex = 0;
        _step = _ComposerStep.crop;
      });
    } catch (e) {
      _showSnack('Could not open camera: $e');
    }
  }

  Future<void> _recordVideo() async {
    try {
      final x = await _picker.pickVideo(source: ImageSource.camera);
      if (x == null) return;
      if (!mounted) return;
      setState(() {
        _media
          ..clear()
          ..add(_AdComposerMedia(path: x.path, isVideo: true));
        _currentIndex = 0;
        _step = _ComposerStep.crop;
      });
    } catch (e) {
      _showSnack('Could not open video recorder: $e');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _back() {
    if (_isSubmitting) return;
    if (_step == _ComposerStep.share) {
      setState(() => _step = _ComposerStep.edit);
      return;
    }
    if (_step == _ComposerStep.edit) {
      setState(() => _step = _ComposerStep.crop);
      return;
    }
    if (_step == _ComposerStep.crop) {
      setState(() {
        _step = _ComposerStep.select;
        _media.clear();
        _currentIndex = 0;
      });
      return;
    }
    Navigator.of(context).maybePop();
  }

  void _next() {
    if (_step == _ComposerStep.select) return;
    if (_step == _ComposerStep.crop) {
      setState(() => _step = _ComposerStep.edit);
      return;
    }
    if (_step == _ComposerStep.edit) {
      setState(() => _step = _ComposerStep.share);
      return;
    }
    _submitAd();
  }

  String _titleForStep() {
    final base = _contentType == 'reel' ? 'reel' : 'post';
    switch (_step) {
      case _ComposerStep.select:
        return 'Create new $base';
      case _ComposerStep.crop:
        return 'Crop';
      case _ComposerStep.edit:
        return 'Edit';
      case _ComposerStep.share:
        return 'Create new $base';
    }
  }

  String _aspectRatioLabel(double aspect) {
    if ((aspect - 1).abs() < 0.001) return '1:1';
    if ((aspect - (4 / 5)).abs() < 0.001) return '4:5';
    if ((aspect - (16 / 9)).abs() < 0.001) return '16:9';
    if ((aspect - (9 / 16)).abs() < 0.001) return '9:16';
    return 'custom';
  }

  Future<Map<String, dynamic>> _uploadMedia(_AdComposerMedia item, int index, int total) async {
    final file = File(item.path);
    if (!await file.exists()) {
      throw Exception('Missing media file at ${item.path}');
    }

    setState(() {
      _uploadStage = 'Uploading media ${index + 1}/$total';
      _uploadProgress = 5 + ((index * 85) ~/ total);
    });

    final bytes = await file.readAsBytes();
    final ext = item.path.split('.').last.toLowerCase();
    final userId = (_me?['id'] ?? _me?['_id'] ?? 'user').toString();
    final filename =
        '$userId/${DateTime.now().millisecondsSinceEpoch}_${item.hashCode.abs()}.${ext.isEmpty ? (item.isVideo ? 'mp4' : 'jpg') : ext}';
    final uploaded = await _uploadApi.uploadFileBytes(bytes: bytes, filename: filename);
    final serverFileName =
        (uploaded['fileName'] ?? uploaded['filename'] ?? filename).toString();
    final fileUrl = _normalizeFileUrl(uploaded['fileUrl']?.toString());

    final media = <String, dynamic>{
      'fileName': serverFileName,
      'fileUrl': fileUrl,
      'url': fileUrl,
      'media_type': item.isVideo ? 'video' : 'image',
      'crop_settings': {
        'mode': 'original',
        'aspect_ratio': _aspectRatioLabel(item.aspect),
        'zoom': 1,
        'x': 0,
        'y': 0,
      },
      'timing_window': {
        'start': 0,
        'end': 0,
      },
      'thumbnails': const <Map<String, dynamic>>[],
    };

    if (!item.isVideo) {
      media['image_editing'] = {
        'filter': {
          'name': item.filter,
          'css': item.filter == 'Original' ? '' : item.filter.toLowerCase(),
        },
        'adjustments': {
          'brightness': item.adjustments['brightness'],
          'contrast': item.adjustments['contrast'],
          'saturation': item.adjustments['saturate'],
          'temperature': item.adjustments['sepia'],
          'fade': item.adjustments['opacity'],
          'vignette': item.adjustments['vignette'],
        },
      };
    } else {
      media['video_meta'] = {
        'original_length_seconds': 0,
        'selected_start': 0,
        'selected_end': 0,
        'final_duration': 0,
        'thumbnail_time': 0,
      };
    }

    return media;
  }

  String _normalizeFileUrl(String? raw) {
    var fileUrl = (raw ?? '').trim();
    if (fileUrl.isEmpty) return '';

    fileUrl = fileUrl.replaceAll('\\', '/');
    final isAbs = fileUrl.startsWith('http://') || fileUrl.startsWith('https://');
    if (!isAbs) {
      final base = ApiConfig.baseUrl;
      final baseUri = Uri.parse(base);
      final origin =
          '${baseUri.scheme}://${baseUri.host}${baseUri.hasPort ? ':${baseUri.port}' : ''}';
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
    return fileUrl;
  }

  Future<void> _submitAd() async {
    if (_isSubmitting) return;
    if (_media.isEmpty) {
      _showSnack('Please select at least one image or video.');
      return;
    }
    if (_selectedCategory == null || _selectedCategory!.isEmpty) {
      _showSnack('Please select an ad category.');
      return;
    }
    final budgetCoinsInput = num.tryParse(_budgetCtl.text.trim());
    final budgetCoins = budgetCoinsInput?.round();
    if (budgetCoins == null || budgetCoins <= 0) {
      _showSnack('Please enter total budget in coins.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _uploadProgress = 0;
      _uploadStage = 'Preparing';
    });

    try {
      final uploadedMedia = <Map<String, dynamic>>[];
      for (int i = 0; i < _media.length; i++) {
        final media = await _uploadMedia(_media[i], i, _media.length);
        uploadedMedia.add(media);
      }

      final caption = _captionCtl.text.trim();
      final hashtags = RegExp(r'#[a-zA-Z0-9_]+')
          .allMatches(caption)
          .map((m) => m.group(0)!)
          .toList();

      setState(() {
        _uploadStage = 'Publishing ad';
        _uploadProgress = 96;
      });

      final payload = <String, dynamic>{
        'type': 'ads',
        'caption': caption,
        'location': _locationCtl.text.trim(),
        'media': uploadedMedia,
        'hashtags': hashtags,
        'tagged_users': const [],
        'engagement_controls': {
          'hide_likes_count': _hideLikes,
          'disable_comments': _turnOffCommenting,
        },
        'content_type': _contentType,
        'category': _selectedCategory,
        'tags': hashtags,
        'target_language': _selectedLanguages.toList(),
        'target_location': _selectedCountries.toList(),
        'total_budget_coins': budgetCoins,
      };

      await _adsApi.createAd(payload);

      if (!mounted) return;
      setState(() {
        _uploadProgress = 100;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ad created successfully.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      _showSnack('Failed to create ad: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _uploadStage = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSelect = _step == _ComposerStep.select;
    final canShare = _step == _ComposerStep.share &&
        !_isSubmitting &&
        _media.isNotEmpty &&
        (_selectedCategory?.isNotEmpty ?? false) &&
        ((double.tryParse(_budgetCtl.text.trim()) ?? 0) > 0);

    return Scaffold(
      backgroundColor: isSelect ? Colors.white : const Color(0xFFF0F0F0),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.black87),
          onPressed: _back,
        ),
        title: Text(_titleForStep()),
        actions: [
          if (_step != _ComposerStep.select)
            TextButton(
              onPressed: _step == _ComposerStep.share
                  ? (canShare ? _next : null)
                  : (_isSubmitting ? null : _next),
              child: Text(
                _step == _ComposerStep.share ? 'Share' : 'Next',
                style: const TextStyle(
                  color: Color(0xFF0095F6),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          switch (_step) {
            _ComposerStep.select => _buildSelect(),
            _ComposerStep.crop => _buildCrop(),
            _ComposerStep.edit => _buildEdit(),
            _ComposerStep.share => _buildShare(),
          },
          if (_isSubmitting) _buildUploadOverlay(),
        ],
      ),
    );
  }

  Widget _buildSelect() {
    final isReel = _contentType == 'reel';
    return Stack(
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: DesignTokens.instaGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    isReel ? LucideIcons.video : LucideIcons.images,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isReel ? 'Select reel media' : 'Select post media',
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _pickMedia,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DesignTokens.instaPink,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Select From Gallery'),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: isReel ? null : _takePhoto,
                      child: const Text(
                        'Take Photo',
                        style: TextStyle(
                          color: DesignTokens.instaPurple,
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 32),
                    TextButton(
                      onPressed: _recordVideo,
                      child: const Text(
                        'Record Video',
                        style: TextStyle(
                          color: DesignTokens.instaPurple,
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 360),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black12),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _typePill(
                    label: 'POST',
                    icon: LucideIcons.image,
                    selected: _contentType == 'post',
                    onTap: () => setState(() => _contentType = 'post'),
                  ),
                  _typePill(
                    label: 'REEL',
                    icon: LucideIcons.video,
                    selected: _contentType == 'reel',
                    onTap: () => setState(() => _contentType = 'reel'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _typePill({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected ? DesignTokens.instaPink.withValues(alpha: 0.16) : Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
            icon,
            size: 16,
            color: selected ? DesignTokens.instaPink : Colors.black87,
          ),
          const SizedBox(width: 6),
          Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? DesignTokens.instaPink : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCrop() {
    final item = _currentMedia;
    if (item == null) return const SizedBox.shrink();
    return Stack(
      children: [
        Positioned.fill(
          child: _buildAspectPreview(item),
        ),
        Positioned(
          left: 16,
          bottom: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _aspectButton('1:1', 1.0, item),
              _aspectButton('4:5', 4 / 5, item),
              _aspectButton('16:9', 16 / 9, item),
              _aspectButton('9:16', 9 / 16, item),
            ],
          ),
        ),
        if (_media.length > 1) ...[
          if (_currentIndex > 0)
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton.filledTonal(
                  onPressed: () => setState(() => _currentIndex--),
                  icon: const Icon(LucideIcons.chevronLeft),
                ),
              ),
            ),
          if (_currentIndex < _media.length - 1)
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton.filledTonal(
                  onPressed: () => setState(() => _currentIndex++),
                  icon: const Icon(LucideIcons.chevronRight),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _aspectButton(String label, double value, _AdComposerMedia item) {
    final selected = (item.aspect - value).abs() < 0.001;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? Colors.white : Colors.black54,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => setState(() => item.aspect = value),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.black : Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEdit() {
    final item = _currentMedia;
    if (item == null) return const SizedBox.shrink();
    final file = File(item.path);
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
                    icon: const Icon(LucideIcons.chevronLeft, color: Colors.black87),
                    style: IconButton.styleFrom(backgroundColor: Colors.white70),
                    onPressed: () => setState(() => _currentIndex--),
                  ),
                ),
              if (_currentIndex < _media.length - 1)
                Positioned(
                  right: 8,
                  child: IconButton(
                    icon: const Icon(LucideIcons.chevronRight, color: Colors.black87),
                    style: IconButton.styleFrom(backgroundColor: Colors.white70),
                    onPressed: () => setState(() => _currentIndex++),
                  ),
                ),
            ],
          ],
        );
        final toolsSection = Container(
          width: useColumn ? null : _editPanelMinWidth,
          constraints: useColumn ? null : const BoxConstraints(minWidth: _editPanelMinWidth),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              left: useColumn
                  ? BorderSide.none
                  : BorderSide(color: Theme.of(context).dividerColor),
              top: useColumn
                  ? BorderSide(color: Theme.of(context).dividerColor)
                  : BorderSide.none,
            ),
          ),
          child: Column(
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
                                  children: _filters.map((name) {
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
                                                  color: selected
                                                      ? const Color(0xFF0095F6)
                                                      : Colors.grey.shade300,
                                                  width: 2,
                                                ),
                                              ),
                                              clipBehavior: Clip.antiAlias,
                                              child: item.isVideo
                                                  ? const Icon(LucideIcons.video, size: 32)
                                                  : _filterThumbnail(file, name),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              name,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: selected
                                                    ? FontWeight.w600
                                                    : FontWeight.normal,
                                                color: selected
                                                    ? const Color(0xFF0095F6)
                                                    : Colors.grey,
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
                          children: [
                            _slider('Brightness', 'brightness', item, -100, 100),
                            _slider('Contrast', 'contrast', item, -100, 100),
                            _slider('Saturation', 'saturate', item, -100, 100),
                            _slider('Temperature', 'sepia', item, -100, 100),
                            _slider('Fade', 'opacity', item, 0, 100),
                            _slider('Vignette', 'vignette', item, 0, 100),
                          ],
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
              SizedBox(height: 280, child: toolsSection),
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

  void _applyFilter(String name) {
    final item = _currentMedia;
    if (item == null) return;
    setState(() => item.filter = name);
  }

  Widget _slider(String label, String key, _AdComposerMedia item, int min, int max) {
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
            onChanged: (v) => setState(() => item.adjustments[key] = v.round()),
          ),
        ],
      ),
    );
  }

  Widget _applyFilterToImage(
    File file,
    _AdComposerMedia item, {
    bool includeAspect = true,
  }) {
    final adj = item.adjustments;
    final b = (adj['brightness'] ?? 0) / 100.0 + 1.0;
    final c = (adj['contrast'] ?? 0) / 100.0 + 1.0;
    final s = (adj['saturate'] ?? 0) / 100.0 + 1.0;
    final opacity = 1.0 - (adj['opacity'] ?? 0) / 100.0;
    final presetMatrix = _filterMatrixFor(item.filter);
    final adjustmentMatrix =
        _buildFilterMatrix(brightness: b, contrast: c, saturation: s);
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: ColorFiltered(
        colorFilter: ColorFilter.matrix(presetMatrix),
        child: ColorFiltered(
          colorFilter: ColorFilter.matrix(adjustmentMatrix),
          child: includeAspect
              ? (item.aspect <= 0
                  ? Image.file(file, fit: BoxFit.contain)
                  : AspectRatio(
                      aspectRatio: item.aspect,
                      child: Image.file(file, fit: BoxFit.cover),
                    ))
              : Image.file(file, fit: BoxFit.cover),
        ),
      ),
    );
  }

  List<double> _buildFilterMatrix({
    double brightness = 1,
    double contrast = 1,
    double saturation = 1,
  }) {
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

  Widget _filterThumbnail(File file, String filterName) {
    final matrix = _filterMatrixFor(filterName);
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(matrix),
      child: Image.file(file, fit: BoxFit.cover),
    );
  }

  Widget _buildShare() {
    final avatar = _me?['avatar_url']?.toString();
    final username = (_me?['username']?.toString() ?? 'User');
    return Row(
      children: [
        Expanded(
          child: _currentMedia == null
              ? const SizedBox.shrink()
              : _buildAspectPreview(_currentMedia!),
        ),
        SizedBox(
          width: 360,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundImage: avatar != null && avatar.isNotEmpty
                        ? NetworkImage(avatar)
                        : null,
                    child: avatar == null || avatar.isEmpty
                        ? Text(username.substring(0, 1).toUpperCase())
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Text(username, style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
                const SizedBox(height: 12),
                TextField(
                  controller: _captionCtl,
                  maxLines: 5,
                  maxLength: 2200,
                  decoration: InputDecoration(
                    hintText: 'Write a caption...',
                    border: const OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: DesignTokens.instaPink, width: 1.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _locationCtl,
                decoration: const InputDecoration(
                  hintText: 'Add location',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              _categorySection(),
              const SizedBox(height: 12),
              _multiSection(
                title: 'Target Language',
                values: _languages,
                selected: _selectedLanguages,
              ),
              const SizedBox(height: 12),
              _multiSection(
                title: 'Target Country',
                values: _countries,
                selected: _selectedCountries,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _budgetCtl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Total Budget (Coins) *',
                  hintText: 'e.g. 1000',
                  border: const OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: DesignTokens.instaPink, width: 1.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () => setState(() => _advancedOpen = !_advancedOpen),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Advanced Settings',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    Icon(
                      _advancedOpen ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                    ),
                  ],
                ),
              ),
              if (_advancedOpen) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Hide like and view counts'),
                  value: _hideLikes,
                  onChanged: (v) => setState(() => _hideLikes = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Turn off commenting'),
                  value: _turnOffCommenting,
                  onChanged: (v) => setState(() => _turnOffCommenting = v),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _categorySection() {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(
        'Category ${(_selectedCategory != null && _selectedCategory!.isNotEmpty) ? '($_selectedCategory)' : ''}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      children: [
        if (_loadingCategories)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: LinearProgressIndicator(),
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _categories.map((c) {
              final selected = _selectedCategory == c;
              return ChoiceChip(
                label: Text(c),
                selected: selected,
                selectedColor: DesignTokens.instaPink.withValues(alpha: 0.18),
                labelStyle: TextStyle(
                  color: selected ? DesignTokens.instaPink : null,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
                onSelected: (_) => setState(() => _selectedCategory = c),
              );
            }).toList(),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _loadingCategories ? null : _showAddCategoryDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add category'),
          ),
        ),
      ],
    );
  }

  Widget _multiSection({
    required String title,
    required List<String> values,
    required Set<String> selected,
  }) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(
        '$title ${selected.isNotEmpty ? '(${selected.length})' : ''}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: values.map((v) {
              final isSelected = selected.contains(v);
              return FilterChip(
                label: Text(v),
                selected: isSelected,
                selectedColor: DesignTokens.instaPink.withValues(alpha: 0.18),
                labelStyle: TextStyle(
                  color: isSelected ? DesignTokens.instaPink : null,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
                onSelected: (on) {
                  setState(() {
                    if (on) {
                      selected.add(v);
                    } else {
                      selected.remove(v);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadOverlay() {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.6),
        child: Center(
          child: Container(
            width: 320,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: DesignTokens.instaPink),
                const SizedBox(height: 12),
                Text(_uploadStage.isEmpty ? 'Uploading...' : _uploadStage),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _uploadProgress / 100,
                  color: DesignTokens.instaPink,
                ),
                const SizedBox(height: 6),
                Text('$_uploadProgress%'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAspectPreview(_AdComposerMedia item) {
    final surface = Theme.of(context).colorScheme.surfaceContainerHighest;
    final iconColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final aspect = item.aspect <= 0 ? 1.0 : item.aspect;
    return Container(
      color: surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth;
          final maxH = constraints.maxHeight;
          double w = maxW;
          double h = w / aspect;
          if (h > maxH) {
            h = maxH;
            w = h * aspect;
          }
          return Center(
            child: SizedBox(
              width: w,
              height: h,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: item.isVideo
                    ? DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.82),
                        ),
                        child: Center(
                          child: Icon(
                            LucideIcons.video,
                            size: 72,
                            color: iconColor,
                          ),
                        ),
                      )
                    : _applyFilterToImage(
                        File(item.path),
                        item,
                        includeAspect: false,
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}
