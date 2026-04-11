import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/media_model.dart';
import '../services/supabase_service.dart';
import '../api/upload_api.dart';
import '../api/reels_api.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../api/users_api.dart';
import '../config/api_config.dart';
import '../utils/current_user.dart';

class CreateReelDetailsScreen extends StatefulWidget {
  final MediaItem media;
  final String? selectedFilter;
  final String? selectedMusic;
  final double musicVolume;
  final Duration? trimStart;
  final Duration? trimEnd;

  const CreateReelDetailsScreen({
    super.key,
    required this.media,
    this.selectedFilter,
    this.selectedMusic,
    this.musicVolume = 0.5,
    this.trimStart,
    this.trimEnd,
  });

  @override
  State<CreateReelDetailsScreen> createState() =>
      _CreateReelDetailsScreenState();
}

class _CreateReelDetailsScreenState extends State<CreateReelDetailsScreen> {
  final SupabaseService _svc = SupabaseService();
  final TextEditingController _captionCtl = TextEditingController();

  final String _location = '';
  bool _hideLikes = false;
  bool _turnOffCommenting = false;
  bool _advancedOpen = false;
  bool _showEmojiPicker = false;
  bool _isSubmitting = false;
  bool _soundOn = true;
  Map<String, dynamic>? _currentUserProfile;
  final List<Map<String, dynamic>> _peopleTags = [];
  String? _draggingTagId;
  String? _selectedThumbnailPath; // User-selected thumbnail (gallery)
  Uint8List?
      _selectedThumbnailBytes; // User-selected or frame-picked thumbnail (bytes)
  double?
      _selectedThumbnailTimeSec; // For API parity with React (video_meta.thumbnail_time)

  VideoPlayerController? _videoController;
  Future<void>? _videoInit;

  static const _popularEmojis = [
    '😂',
    '😮',
    '😍',
    '😢',
    '👏',
    '🔥',
    '🎉',
    '💯',
    '❤️',
    '🤣',
    '🥰',
    '😘',
    '😭',
    '😊'
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentUserProfile();
    final media = widget.media;
    if (media.type == MediaType.video && media.filePath != null) {
      final controller = VideoPlayerController.file(File(media.filePath!));
      _videoController = controller;
      _videoInit = controller.initialize().then((_) {
        if (!mounted) return;
        controller.setLooping(true);
        controller.setVolume(_soundOn ? 1.0 : 0.0);
        controller.play();
        setState(() {});
      });
    }
  }

  @override
  void deactivate() {
    if (_videoController?.value.isInitialized == true) {
      _videoController?.pause();
    }
    super.deactivate();
  }

  Future<void> _pickCustomThumbnail() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth) return;

    final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      filterOption: FilterOptionGroup(
        orders: [
          const OrderOption(type: OrderOptionType.createDate, asc: false)
        ],
      ),
    );
    if (paths.isEmpty) return;

    // Simple picker using modal bottom sheet
    if (!mounted) return;
    final AssetEntity? selected = await showModalBottomSheet<AssetEntity>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (ctx) => _ThumbnailPickerSheet(assetsPath: paths.first),
    );

    if (selected != null) {
      final file = await selected.file;
      if (file != null) {
        Uint8List? bytes;
        try {
          bytes = await file.readAsBytes();
        } catch (_) {
          bytes = null;
        }
        setState(() {
          _selectedThumbnailPath = file.path;
          _selectedThumbnailBytes = bytes;
          _selectedThumbnailTimeSec = 0;
        });
      }
    }
  }

  Future<void> _pickThumbnailFromVideoFrame() async {
    final videoPath = widget.media.filePath;
    final controller = _videoController;
    if (widget.media.type != MediaType.video ||
        videoPath == null ||
        controller == null) return;

    if (controller.value.isInitialized != true) {
      try {
        await _videoInit;
      } catch (_) {}
    }
    if (controller.value.isInitialized != true) return;

    final picked = await showModalBottomSheet<_PickedVideoFrame>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (ctx) => _VideoFramePickerSheet(
        controller: controller,
        videoPath: videoPath,
        initialMs: controller.value.position.inMilliseconds,
      ),
    );

    if (!mounted || picked == null) return;
    setState(() {
      _selectedThumbnailBytes = picked.bytes;
      _selectedThumbnailTimeSec = picked.timeSec;
      _selectedThumbnailPath = null;
    });
  }

  Future<Map<String, dynamic>?> _uploadThumbnailForVideo({
    required String videoPath,
    required int startMs,
    required int endMs,
  }) async {
    try {
      Uint8List? bytes = _selectedThumbnailBytes;
      double thumbnailTimeSec = (_selectedThumbnailTimeSec ?? 0).toDouble();

      // 1) Try gallery-selected thumbnail file if bytes are missing.
      if ((bytes == null || bytes.isEmpty) && _selectedThumbnailPath != null) {
        final file = File(_selectedThumbnailPath!);
        if (await file.exists()) {
          bytes = await file.readAsBytes();
          thumbnailTimeSec = 0;
        }
      }

      // 2) Fallback: generate from video mid-point of selected window (React parity: a deterministic frame).
      if (bytes == null || bytes.isEmpty) {
        final windowMs = endMs > startMs ? (endMs - startMs) : 0;
        final captureMs = startMs + (windowMs > 0 ? (windowMs ~/ 2) : 0);
        bytes = await VideoThumbnail.thumbnailData(
          video: videoPath,
          imageFormat: ImageFormat.JPEG,
          timeMs: captureMs,
          quality: 85,
        );
        thumbnailTimeSec = captureMs / 1000.0;
      }

      if (bytes == null || bytes.isEmpty) return null;

      final filename = 'thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final res = await UploadApi()
          .uploadThumbnailBytes(bytes: bytes, filename: filename);
      final rawThumbs = res['thumbnails'];
      if (rawThumbs == null) return null;
      List<Map<String, dynamic>>? thumbs;
      if (rawThumbs is List) {
        thumbs =
            rawThumbs.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } else if (rawThumbs is Map) {
        thumbs = [Map<String, dynamic>.from(rawThumbs)];
      }
      if (thumbs == null || thumbs.isEmpty) return null;
      return {
        // React web uses `thumbnails` on the media object and `video_meta.thumbnail_time`.
        'thumbnails': thumbs,
        'thumbnailTimeSec': thumbnailTimeSec,
      };
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _captionCtl.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUserProfile() async {
    final uid = await CurrentUser.id;
    if (uid == null) return;
    final profile = await _svc.getUserById(uid);
    if (mounted) setState(() => _currentUserProfile = profile);
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final userId = await CurrentUser.id;
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to share.')),
        );
      }
      return;
    }
    final filePath = widget.media.filePath;
    if (filePath == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Missing media file')),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File not found');
      }
      final bytes = await file.readAsBytes();
      final ext = filePath.split('.').last;
      final filename =
          '$userId/${DateTime.now().millisecondsSinceEpoch}_reel.$ext';
      final uploaded =
          await UploadApi().uploadFileBytes(bytes: bytes, filename: filename);
      final serverFileName =
          (uploaded['fileName'] ?? uploaded['filename'] ?? filename).toString();
      String? fileUrl = (uploaded['url'] ?? uploaded['fileUrl'])?.toString();

      if (fileUrl != null && fileUrl.isNotEmpty) {
        fileUrl = fileUrl.replaceAll('\\', '/');
        final isAbs =
            fileUrl.startsWith('http://') || fileUrl.startsWith('https://');
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
      }

      // React web creates reels via `POST /api/posts/reels` and uses a specific media schema.
      final Duration videoDuration = widget.media.duration ??
          _videoController?.value.duration ??
          widget.trimEnd ??
          Duration.zero;
      final Duration start = widget.trimStart ?? Duration.zero;
      final Duration end = widget.trimEnd != null && widget.trimEnd! > start
          ? widget.trimEnd!
          : videoDuration;

      final int startMs = start.inMilliseconds;
      final int endMs = end.inMilliseconds;
      final double durationSec = videoDuration.inMilliseconds / 1000.0;
      final double startSec = startMs / 1000.0;
      final double endSec = endMs / 1000.0;
      final double finalDurationSec =
          (endMs > startMs) ? ((endMs - startMs) / 1000.0) : durationSec;

      final thumbMeta = await _uploadThumbnailForVideo(
        videoPath: filePath,
        startMs: startMs,
        endMs: endMs,
      );

      final uploadedThumbs = thumbMeta?['thumbnails'];
      final double thumbnailTimeSec = (thumbMeta?['thumbnailTimeSec'] is num)
          ? (thumbMeta?['thumbnailTimeSec'] as num).toDouble()
          : 0.0;

      final mediaItem = <String, dynamic>{
        'fileName': serverFileName,
        if (fileUrl != null && fileUrl.isNotEmpty) 'fileUrl': fileUrl,
        if (fileUrl != null && fileUrl.isNotEmpty) 'url': fileUrl,
        'media_type': 'video',
        'video_meta': <String, dynamic>{
          'original_length_seconds': durationSec,
          'selected_start': startSec,
          'selected_end': endSec,
          'final_duration': finalDurationSec,
          'thumbnail_time': thumbnailTimeSec,
        },
        'timing_window': <String, dynamic>{
          'start': startSec,
          'end': endSec,
        },
        if (uploadedThumbs != null) 'thumbnails': uploadedThumbs,
        'crop_settings': <String, dynamic>{
          'mode': 'original',
          'aspect_ratio': 'original',
          'zoom': 1,
          'x': 0,
          'y': 0,
        },
      };

      // Extract hashtags
      final captionText = _captionCtl.text.trim();
      final tags = RegExp(r'#(\w+)')
          .allMatches(captionText)
          .map((m) => m.group(0)!)
          .toList();

      final peopleTags = _peopleTags
          .map((t) => <String, dynamic>{
                'user_id': t['user_id'],
                'username': t['username'],
                'x': t['x'],
                'y': t['y'],
              })
          .toList();

      final created = await ReelsApi().createReel(
        media: [mediaItem],
        caption: captionText.isEmpty ? null : captionText,
        location: _location.isEmpty ? null : _location,
        tags: tags,
        peopleTags: peopleTags,
        hideLikesCount: _hideLikes,
        turnOffCommenting: _turnOffCommenting,
      );

      String? pickId(dynamic v) {
        if (v == null) return null;
        if (v is Map) return pickId(v['id'] ?? v['_id'] ?? v['reel_id']);
        final s = v.toString().trim();
        return s.isEmpty ? null : s;
      }

      final createdId =
          pickId(created['id'] ?? created['_id'] ?? created['reel'] ?? created['data']);
      NotificationService().addNotification(
        NotificationItem(
          id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
          typeKey: 'reel_posted',
          title: 'Reel shared',
          message: 'Your reel is now live',
          timestamp: DateTime.now(),
          isRead: false,
          relatedId: createdId,
        ),
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reel shared successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showTagSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _TagSearchSheet(onSelect: (user) {
        setState(() {
          _peopleTags.add({
            'user_id': user['id'],
            'username': user['username'],
            'avatar_url': user['avatar_url'],
            'x': 0.5,
            'y': 0.5,
          });
        });
        Navigator.pop(ctx);
      }),
    );
  }

  Widget _buildThumbnailSection() {
    final hasCustomThumb = _selectedThumbnailBytes != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('Cover',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        SizedBox(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              // Current selection preview (tap to pick a frame if video, else upload)
              GestureDetector(
                onTap: widget.media.type == MediaType.video
                    ? _pickThumbnailFromVideoFrame
                    : _pickCustomThumbnail,
                child: Container(
                  width: 80,
                  height: 120,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                    image: hasCustomThumb
                        ? DecorationImage(
                            image: MemoryImage(_selectedThumbnailBytes!),
                            fit: BoxFit.cover)
                        : (_selectedThumbnailPath != null
                            ? DecorationImage(
                                image: FileImage(File(_selectedThumbnailPath!)),
                                fit: BoxFit.cover)
                            : null),
                  ),
                  child: (!hasCustomThumb && _selectedThumbnailPath == null)
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            if (_videoController != null &&
                                _videoController!.value.isInitialized)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(7),
                                child: FittedBox(
                                  fit: BoxFit.cover,
                                  child: SizedBox(
                                    width: _videoController!.value.size.width,
                                    height: _videoController!.value.size.height,
                                    child: VideoPlayer(_videoController!),
                                  ),
                                ),
                              )
                            else
                              const Center(
                                  child: Icon(LucideIcons.image,
                                      color: Colors.grey)),
                            Container(
                              color: Colors.black26,
                              child: const Center(
                                child: Icon(Icons.edit, color: Colors.white),
                              ),
                            ),
                          ],
                        )
                      : null,
                ),
              ),
              // Option to pick a frame from the video
              if (widget.media.type == MediaType.video)
                GestureDetector(
                  onTap: _pickThumbnailFromVideoFrame,
                  child: Container(
                    width: 80,
                    height: 120,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.movie_filter_outlined,
                            color: Colors.black54),
                        SizedBox(height: 4),
                        Text('Frames',
                            style:
                                TextStyle(fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                  ),
                ),
              // Option to pick from gallery
              GestureDetector(
                onTap: _pickCustomThumbnail,
                child: Container(
                  width: 80,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined,
                          color: Colors.black54),
                      SizedBox(height: 4),
                      Text('Upload',
                          style:
                              TextStyle(fontSize: 12, color: Colors.black54)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Reel'),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Share',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.blue)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Video Preview (Mini)
                  Container(
                    width: 80,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _videoController != null &&
                            _videoController!.value.isInitialized
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: _videoController!.value.size.width,
                                height: _videoController!.value.size.height,
                                child: VideoPlayer(_videoController!),
                              ),
                            ),
                          )
                        : const Center(
                            child:
                                CircularProgressIndicator(color: Colors.white)),
                  ),
                  const SizedBox(width: 16),
                  // Caption Input
                  Expanded(
                    child: TextField(
                      controller: _captionCtl,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText: 'Write a caption...',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            _buildThumbnailSection(),
            const Divider(height: 32),

            // ... (rest of the settings: Tag People, Location, etc.)
            ListTile(
              leading: const Icon(LucideIcons.userPlus),
              title: const Text('Tag people'),
              trailing: _peopleTags.isNotEmpty
                  ? Text('${_peopleTags.length} people')
                  : const Icon(LucideIcons.chevronRight),
              onTap: _showTagSearch,
            ),
            ListTile(
              leading: const Icon(LucideIcons.mapPin),
              title: const Text('Add location'),
              trailing: const Icon(LucideIcons.chevronRight),
              onTap: () {
                // TODO: Location picker
              },
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: InkWell(
                onTap: () => setState(() => _advancedOpen = !_advancedOpen),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Advanced Settings',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500)),
                      Icon(
                        _advancedOpen
                            ? LucideIcons.chevronUp
                            : LucideIcons.chevronDown,
                        color: Colors.grey[600],
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_advancedOpen) ...[
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Hide like count on this reel'),
                        ),
                        Switch(
                          value: _hideLikes,
                          onChanged: (v) => setState(() => _hideLikes = v),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Turn off commenting'),
                        ),
                        Switch(
                          value: _turnOffCommenting,
                          onChanged: (v) =>
                              setState(() => _turnOffCommenting = v),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}

class _ThumbnailPickerSheet extends StatefulWidget {
  final AssetPathEntity assetsPath;
  const _ThumbnailPickerSheet({required this.assetsPath});

  @override
  State<_ThumbnailPickerSheet> createState() => _ThumbnailPickerSheetState();
}

class _ThumbnailPickerSheetState extends State<_ThumbnailPickerSheet> {
  final List<AssetEntity> _assets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    final list = await widget.assetsPath.getAssetListPaged(page: 0, size: 60);
    if (mounted) {
      setState(() {
        _assets.addAll(list);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      color: Colors.white,
      child: Column(
        children: [
          AppBar(
            title: const Text('Select Cover',
                style: TextStyle(color: Colors.black)),
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 1,
                      mainAxisSpacing: 1,
                    ),
                    itemCount: _assets.length,
                    itemBuilder: (context, index) {
                      final asset = _assets[index];
                      return GestureDetector(
                        onTap: () => Navigator.pop(context, asset),
                        child: FutureBuilder<Uint8List?>(
                          future: asset.thumbnailDataWithSize(
                              const ThumbnailSize(200, 200)),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              return Image.memory(snapshot.data!,
                                  fit: BoxFit.cover);
                            }
                            return Container(color: Colors.grey[300]);
                          },
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

class _PickedVideoFrame {
  final Uint8List bytes;
  final double timeSec;
  const _PickedVideoFrame({required this.bytes, required this.timeSec});
}

class _VideoFramePickerSheet extends StatefulWidget {
  final VideoPlayerController controller;
  final String videoPath;
  final int initialMs;

  const _VideoFramePickerSheet({
    required this.controller,
    required this.videoPath,
    required this.initialMs,
  });

  @override
  State<_VideoFramePickerSheet> createState() => _VideoFramePickerSheetState();
}

class _VideoFramePickerSheetState extends State<_VideoFramePickerSheet> {
  late double _posMs;
  bool _seeking = false;

  int get _durationMs {
    final d = widget.controller.value.duration.inMilliseconds;
    return d <= 0 ? 1 : d;
  }

  @override
  void initState() {
    super.initState();
    _posMs = widget.initialMs.clamp(0, _durationMs).toDouble();
    try {
      widget.controller.pause();
    } catch (_) {}
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await widget.controller.seekTo(Duration(milliseconds: _posMs.toInt()));
      } catch (_) {}
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    try {
      widget.controller.play();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _seekTo(double ms) async {
    if (_seeking) return;
    setState(() => _seeking = true);
    try {
      await widget.controller.seekTo(Duration(milliseconds: ms.toInt()));
    } catch (_) {}
    if (mounted) setState(() => _seeking = false);
  }

  Future<void> _useThisFrame() async {
    final ms = _posMs.toInt();
    final bytes = await VideoThumbnail.thumbnailData(
      video: widget.videoPath,
      imageFormat: ImageFormat.JPEG,
      timeMs: ms,
      quality: 85,
    );
    if (!mounted) return;
    if (bytes == null || bytes.isEmpty) {
      Navigator.pop(context);
      return;
    }
    Navigator.pop(
      context,
      _PickedVideoFrame(bytes: bytes, timeSec: ms / 1000.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.8,
        color: Colors.black,
        child: Column(
          children: [
            AppBar(
              title: const Text('Select Frame',
                  style: TextStyle(color: Colors.white)),
              backgroundColor: Colors.black,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                TextButton(
                  onPressed: _useThisFrame,
                  child: const Text('Use',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            Expanded(
              child: Center(
                child: c.value.isInitialized
                    ? AspectRatio(
                        aspectRatio: c.value.aspectRatio == 0
                            ? (9 / 16)
                            : c.value.aspectRatio,
                        child: VideoPlayer(c),
                      )
                    : const CircularProgressIndicator(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Frame',
                          style: TextStyle(color: Colors.white70)),
                      const Spacer(),
                      Text(
                        '${(_posMs / 1000.0).toStringAsFixed(2)}s',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                  Slider(
                    min: 0,
                    max: _durationMs.toDouble(),
                    value: _posMs.clamp(0, _durationMs.toDouble()),
                    onChanged: (v) => setState(() => _posMs = v),
                    onChangeEnd: (v) => _seekTo(v),
                  ),
                  if (_seeking)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text('Seeking…',
                          style:
                              TextStyle(color: Colors.white54, fontSize: 12)),
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

class _TagSearchSheet extends StatefulWidget {
  final Function(Map<String, dynamic>) onSelect;
  const _TagSearchSheet({required this.onSelect});

  @override
  State<_TagSearchSheet> createState() => _TagSearchSheetState();
}

class _TagSearchSheetState extends State<_TagSearchSheet> {
  final TextEditingController _searchCtl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchCtl.addListener(() => _onSearchChanged(_searchCtl.text));
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.trim().isEmpty) {
        if (mounted) setState(() => _results = []);
        return;
      }
      if (mounted) setState(() => _loading = true);
      try {
        final res = await UsersApi().search(query);
        if (mounted) setState(() => _results = res);
      } catch (_) {
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            'Tag People',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchCtl,
            decoration: InputDecoration(
              hintText: 'Search user',
              prefixIcon: const Icon(LucideIcons.search, size: 20),
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? Center(
                        child: Text(
                          _searchCtl.text.isEmpty
                              ? 'Search for users to tag'
                              : 'No users found',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final user = _results[index];
                          final avatar = user['avatar_url'] as String?;
                          final username =
                              (user['username'] as String?) ?? 'User';
                          final fullName = (user['full_name'] as String?) ?? '';
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.grey[200],
                              backgroundImage:
                                  avatar != null && avatar.isNotEmpty
                                      ? NetworkImage(avatar)
                                      : null,
                              child: (avatar == null || avatar.isEmpty)
                                  ? Text(
                                      username.substring(0, 1).toUpperCase(),
                                      style: const TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.bold),
                                    )
                                  : null,
                            ),
                            title: Text(username),
                            subtitle:
                                fullName.isNotEmpty ? Text(fullName) : null,
                            onTap: () => widget.onSelect(user),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
