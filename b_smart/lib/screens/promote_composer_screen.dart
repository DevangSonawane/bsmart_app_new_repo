import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../api/promote_reels_api.dart';
import '../api/upload_api.dart';
import '../models/location_place.dart';
import '../models/media_model.dart';
import '../services/create_service.dart';
import '../utils/url_helper.dart';
import 'edit_video_screen.dart';
import 'location_search_screen.dart';
import 'tag_people_screen.dart';

double? _tryParseAmount(String value) {
  final parsed = num.tryParse(value.trim());
  return parsed?.toDouble();
}

String _formatMoney(double amount) {
  final rounded = amount.roundToDouble();
  if ((amount - rounded).abs() < 0.0001) {
    return rounded.toStringAsFixed(0);
  }
  return amount.toStringAsFixed(2);
}

class _PromoteDraftMedia {
  final String path;
  final bool isVideo;
  final double aspectRatio;
  final Duration? trimStart;
  final Duration? trimEnd;
  final Duration? duration;

  const _PromoteDraftMedia({
    required this.path,
    required this.isVideo,
    required this.aspectRatio,
    this.trimStart,
    this.trimEnd,
    this.duration,
  });

  _PromoteDraftMedia copyWith({
    String? path,
    bool? isVideo,
    double? aspectRatio,
    Duration? trimStart,
    Duration? trimEnd,
    Duration? duration,
  }) {
    return _PromoteDraftMedia(
      path: path ?? this.path,
      isVideo: isVideo ?? this.isVideo,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      trimStart: trimStart ?? this.trimStart,
      trimEnd: trimEnd ?? this.trimEnd,
      duration: duration ?? this.duration,
    );
  }
}

class _PromoteDraftProduct {
  final String name;
  final String description;
  final String price;
  final String discountAmount;
  final String visitLink;
  final String? imagePath;

  const _PromoteDraftProduct({
    required this.name,
    required this.description,
    required this.price,
    required this.discountAmount,
    required this.visitLink,
    this.imagePath,
  });

  _PromoteDraftProduct copyWith({
    String? name,
    String? description,
    String? price,
    String? discountAmount,
    String? visitLink,
    String? imagePath,
  }) {
    return _PromoteDraftProduct(
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      discountAmount: discountAmount ?? this.discountAmount,
      visitLink: visitLink ?? this.visitLink,
      imagePath: imagePath ?? this.imagePath,
    );
  }
}

class PromoteComposerScreen extends StatefulWidget {
  const PromoteComposerScreen({super.key});

  @override
  State<PromoteComposerScreen> createState() => _PromoteComposerScreenState();
}

class _PromoteComposerScreenState extends State<PromoteComposerScreen> {
  final CreateService _createService = CreateService();
  final UploadApi _uploadApi = UploadApi();
  final PromoteReelsApi _promoteReelsApi = PromoteReelsApi();
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _captionCtl = TextEditingController();
  final TextEditingController _locationCtl = TextEditingController();

  final List<_PromoteDraftMedia> _media = [];
  final List<_PromoteDraftProduct> _products = [];
  final List<Map<String, dynamic>> _peopleTags = [];

  LocationPlace? _location;
  String? _coverImagePath;
  bool _hideLikes = false;
  bool _turnOffCommenting = false;
  bool _advancedSettingsOpen = false;
  bool _isSubmitting = false;
  int _step = 0;
  int _selectedCoverIndex = 0;
  Future<List<Uint8List?>>? _coverFramesFuture;

  static const _stepTitles = <String>[
    'Media',
    'Products',
    'Details',
  ];

  @override
  void dispose() {
    _captionCtl.dispose();
    _locationCtl.dispose();
    super.dispose();
  }

  String _pickString(dynamic value) {
    final s = (value ?? '').toString().trim();
    return s;
  }

  Future<_PromoteDraftMedia> _buildVideoDraft(XFile file) async {
    final controller = VideoPlayerController.file(File(file.path));
    Duration? duration;
    try {
      await controller.initialize();
      duration = controller.value.duration;
    } catch (_) {
      duration = null;
    } finally {
      await controller.dispose();
    }
    return _PromoteDraftMedia(
      path: file.path,
      isVideo: true,
      aspectRatio: 9 / 16,
      duration: duration,
    );
  }

  Future<List<Uint8List?>> _buildCoverFrames(
    String path, {
    Duration? duration,
  }) async {
    final totalMs = duration?.inMilliseconds ?? 0;
    const frameCount = 8;
    final frames = <Uint8List?>[];
    for (var i = 0; i < frameCount; i++) {
      final timeMs =
          totalMs > 0 ? ((totalMs * i) / (frameCount - 1)).round() : (i * 750);
      final bytes = await VideoThumbnail.thumbnailData(
        video: path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 360,
        quality: 78,
        timeMs: timeMs,
      );
      frames.add(bytes);
    }
    return frames;
  }

  Future<void> _pickMedia() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final file = await _picker.pickVideo(source: ImageSource.gallery);
      if (file == null) return;
      final media = await _buildVideoDraft(file);
      final trimmed = await navigator.push<VideoEditResult>(
        MaterialPageRoute(
          builder: (_) => EditVideoScreen(
            media: MediaItem(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              type: MediaType.video,
              filePath: file.path,
              createdAt: DateTime.now(),
            ),
          ),
        ),
      );
      if (trimmed == null || !mounted) return;
      setState(() {
        _media
          ..clear()
          ..add(
            media.copyWith(
              trimStart: trimmed.trimStart,
              trimEnd: trimmed.trimEnd,
            ),
          );
        _selectedCoverIndex = 0;
        _coverImagePath = null;
        _coverFramesFuture = _buildCoverFrames(
          file.path,
          duration: media.duration,
        );
      });
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to pick media')),
      );
    }
  }

  Future<void> _pickCoverFromDevice() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) return;
    setState(() {
      _coverImagePath = file.path;
    });
  }

  Future<void> _editVideoAt(int index) async {
    if (index < 0 || index >= _media.length) return;
    final item = _media[index];
    if (!item.isVideo) return;

    final trimmed = await Navigator.of(context).push<VideoEditResult>(
      MaterialPageRoute(
        builder: (_) => EditVideoScreen(
          media: MediaItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            type: MediaType.video,
            filePath: item.path,
            createdAt: DateTime.now(),
          ),
        ),
      ),
    );
    if (trimmed == null || !mounted) return;
    setState(() {
      _media[index] = item.copyWith(
        trimStart: trimmed.trimStart,
        trimEnd: trimmed.trimEnd,
      );
    });
  }

  Future<void> _tagPeople() async {
    if (_media.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add media before tagging people')),
      );
      return;
    }

    final mediaPaths = _media.map((item) => item.path).toList(growable: false);
    final isVideos = _media.map((item) => item.isVideo).toList(growable: false);
    final aspectRatios =
        _media.map((item) => item.aspectRatio).toList(growable: false);
    final adjustments =
        List<Map<String, int>>.generate(_media.length, (_) => const {});
    final result = await Navigator.of(context).push<List<dynamic>>(
      MaterialPageRoute(
        builder: (_) => TagPeopleScreen(
          mediaPaths: mediaPaths,
          isVideos: isVideos,
          coverPaths: null,
          filterNames: List<String>.filled(_media.length, 'Original'),
          adjustments: adjustments,
          alreadyProcessed: List<bool>.filled(_media.length, false),
          aspectRatios: aspectRatios,
          initialTagsByIndex: const {},
          initialIndex: 0,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _peopleTags
        ..clear()
        ..addAll(result.cast<Map<String, dynamic>>());
    });
  }

  Future<void> _pickLocation() async {
    final selected = await Navigator.of(context).push<LocationPlace>(
      MaterialPageRoute(builder: (_) => const LocationSearchScreen()),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _location = selected;
      _locationCtl.text = selected.searchText;
    });
  }

  Future<void> _openProductEditor({int? index}) async {
    final existing = index != null && index >= 0 && index < _products.length
        ? _products[index]
        : null;
    final result = await Navigator.of(context).push<_PromoteDraftProduct>(
      MaterialPageRoute(
        builder: (_) => _PromoteProductEditorScreen(initial: existing),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (index != null && index >= 0 && index < _products.length) {
        _products[index] = result;
      } else {
        _products.add(result);
      }
    });
  }

  Future<Map<String, dynamic>> _uploadProductImage(String path) async {
    final uploaded = await _uploadApi.uploadPromoteProductFile(path);
    final fileName = _pickString(uploaded['fileName'] ?? uploaded['filename']);
    final fileUrl = _pickString(
      uploaded['promote_img'] ??
          uploaded['fileUrl'] ??
          uploaded['file_url'] ??
          uploaded['url'],
    );
    final normalizedUrl = UrlHelper.normalizeUrl(fileUrl);
    return {
      if (fileName.isNotEmpty) 'fileName': fileName,
      if (normalizedUrl.isNotEmpty) 'promote_img': normalizedUrl,
      if (normalizedUrl.isNotEmpty) 'fileUrl': normalizedUrl,
      if (normalizedUrl.isNotEmpty) 'url': normalizedUrl,
    };
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (_media.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add media for the promote')),
      );
      return;
    }

    final caption = _captionCtl.text.trim();
    final tags = RegExp(r'#[a-zA-Z0-9_]+')
        .allMatches(caption)
        .map((m) => m.group(0)!)
        .toList();

    setState(() {
      _isSubmitting = true;
    });

    try {
      List<Uint8List?>? coverFrames;
      if (_coverFramesFuture != null) {
        try {
          coverFrames = await _coverFramesFuture;
        } catch (_) {
          coverFrames = null;
        }
      }

      final mediaPayload = <Map<String, dynamic>>[];
      for (var index = 0; index < _media.length; index++) {
        final item = _media[index];
        final path = item.isVideo
            ? await _createService.trimVideoForUpload(
                  inputPath: item.path,
                  trimStart: item.trimStart,
                  trimEnd: item.trimEnd,
                  videoDuration: item.duration,
                ) ??
                item.path
            : item.path;
        final uploaded = item.isVideo
            ? await _uploadApi.uploadPromoteFile(path)
            : await _uploadApi.uploadPromoteFile(path);
        final fileName =
            _pickString(uploaded['fileName'] ?? uploaded['filename']);
        final fileUrl = _pickString(
          uploaded['fileUrl'] ?? uploaded['file_url'] ?? uploaded['url'],
        );
        final normalizedUrl = UrlHelper.normalizeUrl(fileUrl);
        Map<String, dynamic>? coverPayload;
        if (item.isVideo &&
            coverFrames != null &&
            coverFrames.isNotEmpty &&
            _selectedCoverIndex >= 0 &&
            _selectedCoverIndex < coverFrames.length &&
            coverFrames[_selectedCoverIndex] != null) {
          final coverBytes = coverFrames[_selectedCoverIndex]!;
          final coverUpload = await _uploadApi.uploadThumbnailBytes(
            bytes: coverBytes,
            filename: 'promote_cover.jpg',
          );
          final coverUrl = _pickString(
            coverUpload['fileUrl'] ??
                coverUpload['file_url'] ??
                coverUpload['url'],
          );
          final normalizedCoverUrl = UrlHelper.normalizeUrl(coverUrl);
          if (normalizedCoverUrl.isNotEmpty) {
            coverPayload = {
              'coverUrl': normalizedCoverUrl,
              'uploadedCoverUrl': normalizedCoverUrl,
              'thumbnails': [normalizedCoverUrl],
            };
          }
        }
        mediaPayload.add({
          if (fileName.isNotEmpty) 'fileName': fileName,
          if (normalizedUrl.isNotEmpty) 'fileUrl': normalizedUrl,
          if (normalizedUrl.isNotEmpty) 'url': normalizedUrl,
          'ratio': item.aspectRatio,
          'filter': 'none',
          'media_type': item.isVideo ? 'video' : 'image',
          if (item.trimStart != null)
            'trimStartMs': item.trimStart!.inMilliseconds,
          if (item.trimEnd != null) 'trimEndMs': item.trimEnd!.inMilliseconds,
          if (coverPayload != null) ...coverPayload,
        });
      }

      final productsPayload = <Map<String, dynamic>>[];
      for (final product in _products) {
        final payload = <String, dynamic>{
          'product_name': product.name.trim(),
          'product_description': product.description.trim(),
          'product_price': num.tryParse(product.price.trim())?.toDouble() ?? 0,
          'discount_amount':
              num.tryParse(product.discountAmount.trim())?.toDouble() ?? 0,
          'visit_link': product.visitLink.trim(),
        };
        if (product.imagePath != null && product.imagePath!.isNotEmpty) {
          payload.addAll(await _uploadProductImage(product.imagePath!));
        }
        productsPayload.add(payload);
      }

      final peopleTags = _peopleTags.map((tag) {
        final user = tag['user'];
        final userMap = user is Map ? Map<String, dynamic>.from(user) : null;
        return <String, dynamic>{
          'user_id': userMap?['id'] ?? userMap?['_id'] ?? tag['user_id'],
          'username': userMap?['username'] ?? userMap?['name'],
          'x': tag['x'],
          'y': tag['y'],
          if (tag['mediaIndex'] != null) 'mediaIndex': tag['mediaIndex'],
        };
      }).toList();

      await _promoteReelsApi.createPromoteReel({
        'caption': caption,
        'location': _location?.fullText ?? _locationCtl.text.trim(),
        'location_data': _location?.toJson(),
        'media': mediaPayload,
        'tags': tags,
        'people_tags': peopleTags,
        'hide_likes_count': _hideLikes,
        'turn_off_commenting': _turnOffCommenting,
        'products': productsPayload,
      });

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create promote: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _goNext() {
    if (_step >= _stepTitles.length - 1) {
      _submit();
      return;
    }
    setState(() {
      _step++;
    });
  }

  void _goBack() {
    if (_step <= 0) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _step--;
    });
  }

  Widget _buildMediaStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'Choose your media',
          subtitle: 'Pick one video for the promote. Vertical clips work best.',
        ),
        const SizedBox(height: 16),
        _buildHeroCard(
          child: Column(
            children: [
              if (_media.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.play_circle_fill_rounded,
                        size: 46,
                        color: Color(0xFFFFD77A),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No media selected yet',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Add a video from your gallery to start the promote.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )
              else
                SizedBox(
                  height: 220,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _media.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final item = _media[index];
                      return _MediaPreviewCard(
                        media: item,
                        onEditVideo:
                            item.isVideo ? () => _editVideoAt(index) : null,
                        onRemove: () {
                          setState(() => _media.removeAt(index));
                        },
                      );
                    },
                  ),
                ),
              const SizedBox(height: 14),
              _ActionPill(
                label: _media.isEmpty ? 'Add video' : 'Replace video',
                icon: LucideIcons.video,
                onTap: _pickMedia,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_media.isNotEmpty) _buildCoverSection(),
      ],
    );
  }

  Widget _buildCoverSection() {
    return _buildHeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose cover photo',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pick the frame that will represent the promote.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 14),
          if (_media.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Select a frame below or upload a cover from your device.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: _pickCoverFromDevice,
                  icon: const Icon(
                    LucideIcons.imagePlus,
                    size: 16,
                    color: Color(0xFFFFD77A),
                  ),
                  label: const Text(
                    'From device',
                    style: TextStyle(
                      color: Color(0xFFFFD77A),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          if (_media.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    LucideIcons.imagePlus,
                    color: Colors.white.withValues(alpha: 0.7),
                    size: 28,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Add a video first to generate cover frames.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            )
          else
            FutureBuilder<List<Uint8List?>>(
              future: _coverFramesFuture,
              builder: (context, snapshot) {
                final frames = snapshot.data ?? const <Uint8List?>[];
                final customCover = _coverImagePath != null &&
                        _coverImagePath!.isNotEmpty &&
                        File(_coverImagePath!).existsSync()
                    ? File(_coverImagePath!)
                    : null;
                final selectedBytes = customCover == null &&
                        frames.isNotEmpty &&
                        _selectedCoverIndex >= 0 &&
                        _selectedCoverIndex < frames.length
                    ? frames[_selectedCoverIndex]
                    : null;
                final selectedMedia = customCover != null
                    ? Image.file(
                        customCover,
                        fit: BoxFit.cover,
                      )
                    : selectedBytes != null
                        ? Image.memory(
                            selectedBytes,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                          )
                        : _VideoThumb(path: _media.first.path);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 190,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          selectedMedia,
                          Positioned(
                            left: 12,
                            bottom: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Selected cover',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.95),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (customCover != null) ...[
                      Text(
                        'Cover selected from your device',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _coverImagePath = null;
                            });
                          },
                          icon: const Icon(
                            LucideIcons.refreshCcw,
                            size: 16,
                            color: Color(0xFFFFD77A),
                          ),
                          label: const Text(
                            'Use video frame instead',
                            style: TextStyle(
                              color: Color(0xFFFFD77A),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      Text(
                        snapshot.connectionState == ConnectionState.waiting
                            ? 'Generating cover frames...'
                            : 'Tap a frame below to choose the cover',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    SizedBox(
                      height: 82,
                      child: customCover != null
                          ? const SizedBox.shrink()
                          : snapshot.connectionState == ConnectionState.waiting
                              ? const Center(
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Color(0xFFFFD77A),
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: frames.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 10),
                                  itemBuilder: (context, index) {
                                    final bytes = frames[index];
                                    final selected =
                                        index == _selectedCoverIndex;
                                    return GestureDetector(
                                      onTap: bytes == null
                                          ? null
                                          : () => setState(() {
                                                _selectedCoverIndex = index;
                                              }),
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 180),
                                        width: 58,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                            color: selected
                                                ? const Color(0xFFFFD77A)
                                                : Colors.white
                                                    .withValues(alpha: 0.08),
                                            width: selected ? 2 : 1,
                                          ),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: bytes == null
                                            ? Container(
                                                color: Colors.white
                                                    .withValues(alpha: 0.05),
                                                child: const Icon(
                                                  Icons.image_outlined,
                                                  color: Colors.white54,
                                                ),
                                              )
                                            : Stack(
                                                fit: StackFit.expand,
                                                children: [
                                                  Image.memory(
                                                    bytes,
                                                    fit: BoxFit.cover,
                                                    gaplessPlayback: true,
                                                  ),
                                                  if (selected)
                                                    Container(
                                                      color: Colors.black
                                                          .withValues(
                                                              alpha: 0.18),
                                                      child: const Center(
                                                        child: Icon(
                                                          LucideIcons.check,
                                                          color:
                                                              Color(0xFFFFD77A),
                                                          size: 18,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildProductsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'Add products',
          subtitle: 'Create premium product cards with title, price and link.',
        ),
        const SizedBox(height: 16),
        if (_products.isEmpty)
          _buildHeroCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Column(
                children: [
                  Icon(
                    Icons.shopping_bag_rounded,
                    size: 42,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No products added yet',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Add items that can be shown under the promote reel.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ..._products.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ProductPreviewCard(
                product: item,
                onEdit: () => _openProductEditor(index: index),
                onRemove: () => setState(() => _products.removeAt(index)),
              ),
            );
          }),
        const SizedBox(height: 14),
        _ActionPill(
          label: 'Add product',
          icon: LucideIcons.squarePen,
          onTap: () => _openProductEditor(),
        ),
      ],
    );
  }

  Widget _buildDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'Caption and details',
          subtitle: 'Caption, tags and advanced settings live here.',
        ),
        const SizedBox(height: 16),
        _buildHeroCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _captionCtl,
                maxLines: 5,
                minLines: 3,
                style: const TextStyle(color: Colors.white),
                cursorColor: const Color(0xFFFFD77A),
                decoration: _fieldDecoration(
                  label: 'Caption',
                  hint: 'Write a short, compelling promote caption...',
                  icon: LucideIcons.penLine,
                ),
              ),
              const SizedBox(height: 14),
              _ActionRowCard(
                icon: LucideIcons.userRoundPlus,
                title: 'Tag people',
                subtitle: _peopleTags.isEmpty
                    ? 'No people tagged yet'
                    : '${_peopleTags.length} tagged',
                onTap: _tagPeople,
              ),
              const SizedBox(height: 12),
              _LocationCard(
                title: 'Location',
                subtitle: _location?.searchText ?? _locationCtl.text.trim(),
                onTap: _pickLocation,
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    InkWell(
                      onTap: () {
                        setState(() {
                          _advancedSettingsOpen = !_advancedSettingsOpen;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            const Icon(
                              LucideIcons.settings2,
                              color: Colors.white70,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Advanced settings',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Hide likes and comments control',
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.66),
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              _advancedSettingsOpen
                                  ? LucideIcons.chevronUp
                                  : LucideIcons.chevronDown,
                              color: Colors.white70,
                            ),
                          ],
                        ),
                      ),
                    ),
                    AnimatedCrossFade(
                      firstChild: const SizedBox.shrink(),
                      secondChild: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                        child: Column(
                          children: [
                            _ToggleCard(
                              title: 'Hide likes count',
                              subtitle:
                                  'Only you can see the like count on this promote.',
                              value: _hideLikes,
                              onChanged: (value) =>
                                  setState(() => _hideLikes = value),
                            ),
                            const SizedBox(height: 12),
                            _ToggleCard(
                              title: 'Turn off commenting',
                              subtitle:
                                  'Stop comments on this promote once it is live.',
                              value: _turnOffCommenting,
                              onChanged: (value) =>
                                  setState(() => _turnOffCommenting = value),
                            ),
                          ],
                        ),
                      ),
                      crossFadeState: _advancedSettingsOpen
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 180),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: 13.5,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF18110B), Color(0xFF0D0D0D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: Colors.white70, size: 18),
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        borderSide: BorderSide(color: Color(0xFFFFD77A)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canPublish = _media.isNotEmpty && !_isSubmitting;
    final isFinalStep = _step == _stepTitles.length - 1;
    return Scaffold(
      backgroundColor: const Color(0xFF090909),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _goBack,
                    icon: const Icon(LucideIcons.arrowLeft),
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create Promote',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _stepTitles[_step],
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isFinalStep)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: canPublish ? _submit : null,
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFFFD77A),
                                Color(0xFFB57B17),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.rocket, size: 16),
                              SizedBox(width: 8),
                              Text(
                                'Publish',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    TextButton(
                      onPressed: canPublish ? _goNext : null,
                      child: const Text(
                        'Next',
                        style: TextStyle(
                          color: Color(0xFFFFD77A),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: List.generate(_stepTitles.length, (index) {
                  final active = index == _step;
                  final done = index < _step;
                  return Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: EdgeInsets.only(
                          right: index == _stepTitles.length - 1 ? 0 : 6),
                      height: 4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: active
                            ? const Color(0xFFFFD77A)
                            : done
                                ? const Color(0xFFB57B17)
                                : Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Stack(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    child: SingleChildScrollView(
                      key: ValueKey<int>(_step),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      child: switch (_step) {
                        0 => _buildMediaStep(),
                        1 => _buildProductsStep(),
                        2 => _buildDetailsStep(),
                        _ => _buildDetailsStep(),
                      },
                    ),
                  ),
                  if (_isSubmitting)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.45),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFFFD77A),
                          ),
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
}

class _PromoteProductEditorScreen extends StatefulWidget {
  final _PromoteDraftProduct? initial;

  const _PromoteProductEditorScreen({this.initial});

  @override
  State<_PromoteProductEditorScreen> createState() =>
      _PromoteProductEditorScreenState();
}

class _PromoteProductEditorScreenState
    extends State<_PromoteProductEditorScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _nameCtl = TextEditingController();
  final TextEditingController _descCtl = TextEditingController();
  final TextEditingController _priceCtl = TextEditingController();
  final TextEditingController _discountCtl = TextEditingController();
  final TextEditingController _linkCtl = TextEditingController();
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _nameCtl.text = initial.name;
      _descCtl.text = initial.description;
      _priceCtl.text = initial.price;
      _discountCtl.text = initial.discountAmount;
      _linkCtl.text = initial.visitLink;
      _imagePath = initial.imagePath;
    }
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _descCtl.dispose();
    _priceCtl.dispose();
    _discountCtl.dispose();
    _linkCtl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) return;
    setState(() => _imagePath = file.path);
  }

  void _save() {
    final name = _nameCtl.text.trim();
    final price = _priceCtl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a product name')),
      );
      return;
    }
    if (price.isEmpty || num.tryParse(price) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a valid product price')),
      );
      return;
    }
    Navigator.of(context).pop(
      _PromoteDraftProduct(
        name: name,
        description: _descCtl.text.trim(),
        price: price,
        discountAmount: _discountCtl.text.trim(),
        visitLink: _linkCtl.text.trim(),
        imagePath: _imagePath,
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white),
      cursorColor: const Color(0xFFFFD77A),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.white70, size: 18),
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
          borderSide: BorderSide(color: Color(0xFFFFD77A)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _imagePath != null && _imagePath!.isNotEmpty;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        foregroundColor: Colors.white,
        title: const Text('Product editor'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text(
              'Save',
              style: TextStyle(
                color: Color(0xFFFFD77A),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Design a product card that feels premium and clickable.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: double.infinity,
                  height: 180,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF181818), Color(0xFF101010)],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: hasImage
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(26),
                          child: Image.file(
                            File(_imagePath!),
                            fit: BoxFit.cover,
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              LucideIcons.imagePlus,
                              size: 42,
                              color: Color(0xFFFFD77A),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Add product image',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Square or portrait images work best',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),
              _field(
                controller: _nameCtl,
                label: 'Product name *',
                hint: 'Luxury tote bag',
                icon: LucideIcons.tag,
              ),
              const SizedBox(height: 12),
              _field(
                controller: _descCtl,
                label: 'Description',
                hint: 'Tell people why they need it',
                icon: LucideIcons.fileText,
                maxLines: 4,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      controller: _priceCtl,
                      label: 'Price *',
                      hint: '2499',
                      icon: LucideIcons.indianRupee,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(
                      controller: _discountCtl,
                      label: 'Discount',
                      hint: '300',
                      icon: LucideIcons.badgePercent,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  final price = _tryParseAmount(_priceCtl.text) ?? 0;
                  final discount = _tryParseAmount(_discountCtl.text) ?? 0;
                  if (price <= 0) {
                    return const SizedBox.shrink();
                  }
                  final finalPrice =
                      (price - discount).clamp(0, double.infinity).toDouble();
                  final discountPct = discount > 0 && price > 0
                      ? ((discount / price) * 100).round()
                      : 0;
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFFFD77A).withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            LucideIcons.badgePercent,
                            color: Color(0xFFFFD77A),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Final price',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.68),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '₹${_formatMoney(finalPrice)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (discountPct > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD77A)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '$discountPct% off',
                              style: const TextStyle(
                                color: Color(0xFFFFD77A),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _field(
                controller: _linkCtl,
                label: 'Visit link',
                hint: 'https://example.com/product',
                icon: LucideIcons.link,
                keyboardType: TextInputType.url,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaPreviewCard extends StatelessWidget {
  final _PromoteDraftMedia media;
  final VoidCallback? onEditVideo;
  final VoidCallback onRemove;

  const _MediaPreviewCard({
    required this.media,
    required this.onEditVideo,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isVideo = media.isVideo;
    return Container(
      width: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: isVideo
                ? _VideoThumb(path: media.path)
                : Image.file(
                    File(media.path),
                    fit: BoxFit.cover,
                  ),
          ),
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                isVideo ? 'Video' : 'Image',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: Row(
              children: [
                if (isVideo && onEditVideo != null)
                  _miniIconButton(
                    icon: LucideIcons.scissors,
                    onTap: onEditVideo!,
                  ),
                const SizedBox(width: 6),
                _miniIconButton(
                  icon: LucideIcons.trash2,
                  onTap: onRemove,
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.74),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Text(
                media.isVideo ? 'Video ready' : 'Ready for upload',
                maxLines: 2,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.black.withValues(alpha: 0.48),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 14),
        ),
      ),
    );
  }
}

class _VideoThumb extends StatelessWidget {
  final String path;

  const _VideoThumb({required this.path});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          color: Colors.white.withValues(alpha: 0.06),
        ),
        const Center(
          child: Icon(
            Icons.play_circle_fill_rounded,
            color: Colors.white70,
            size: 42,
          ),
        ),
      ],
    );
  }
}

class _LocationCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _LocationCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(LucideIcons.mapPinned, color: Colors.white70),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle.isEmpty ? 'Add location' : subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.68),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(LucideIcons.chevronRight, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionRowCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionRowCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const SizedBox(width: 2),
              Icon(icon, color: Colors.white70, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.68),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(LucideIcons.chevronRight, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.68),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: const Color(0xFFFFD77A),
              activeTrackColor: const Color(0xFFFFD77A).withValues(alpha: 0.38),
              inactiveThumbColor: const Color(0xFFB8B8B8),
              inactiveTrackColor: Colors.white.withValues(alpha: 0.16),
              trackOutlineColor: WidgetStatePropertyAll(
                Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _ActionPill({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductPreviewCard extends StatelessWidget {
  final _PromoteDraftProduct product;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _ProductPreviewCard({
    required this.product,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 88,
              height: 88,
              child: product.imagePath == null
                  ? Container(
                      color: Colors.white.withValues(alpha: 0.06),
                      child: const Icon(
                        LucideIcons.imagePlus,
                        color: Colors.white54,
                      ),
                    )
                  : Image.file(File(product.imagePath!), fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  product.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Price: ${product.price}  Discount: ${product.discountAmount}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                onPressed: onEdit,
                icon: const Icon(LucideIcons.squarePen),
                color: Colors.white,
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(LucideIcons.trash2),
                color: Colors.redAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}