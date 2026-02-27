import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../models/media_model.dart';
import '../services/supabase_service.dart';
import '../api/upload_api.dart';
import '../api/reels_api.dart';
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
    Key? key,
    required this.media,
    this.selectedFilter,
    this.selectedMusic,
    this.musicVolume = 0.5,
    this.trimStart,
    this.trimEnd,
  }) : super(key: key);

  @override
  State<CreateReelDetailsScreen> createState() => _CreateReelDetailsScreenState();
}

class _CreateReelDetailsScreenState extends State<CreateReelDetailsScreen> {
  final SupabaseService _svc = SupabaseService();
  final TextEditingController _captionCtl = TextEditingController();

  String _location = '';
  bool _hideLikes = false;
  bool _turnOffCommenting = false;
  bool _advancedOpen = false;
  bool _showEmojiPicker = false;
  bool _isSubmitting = false;
  bool _soundOn = true;
  Map<String, dynamic>? _currentUserProfile;
  final List<Map<String, dynamic>> _peopleTags = [];
  String? _draggingTagId;

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
        controller.play();
        setState(() {});
      });
    }
  }

  Future<Map<String, dynamic>?> _uploadThumbnailForVideo({
    required String videoPath,
    required int startMs,
    required int endMs,
  }) async {
    try {
      final durationMs = endMs > startMs ? endMs - startMs : (endMs > 0 ? endMs : startMs);
      final midOffset = durationMs > 0 ? durationMs ~/ 2 : 0;
      final captureMs = startMs + midOffset;
      final bytes = await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        timeMs: captureMs,
        quality: 85,
      );
      if (bytes == null || bytes.isEmpty) return null;
      final filename = 'thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final res = await UploadApi().uploadThumbnailBytes(bytes: bytes, filename: filename);
      final rawThumbs = res['thumbnails'];
      if (rawThumbs == null) return null;
      List<Map<String, dynamic>>? thumbs;
      if (rawThumbs is List) {
        thumbs = rawThumbs.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } else if (rawThumbs is Map) {
        thumbs = [Map<String, dynamic>.from(rawThumbs as Map)];
      }
      if (thumbs == null || thumbs.isEmpty) return null;
      return {
        'thumbs': thumbs,
        'timeMs': captureMs,
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
      final filename = '$userId/${DateTime.now().millisecondsSinceEpoch}_reel.$ext';
      final uploaded = await UploadApi().uploadFileBytes(bytes: bytes, filename: filename);
      final serverFileName = (uploaded['fileName'] ?? uploaded['filename'] ?? filename).toString();
      String? fileUrl = uploaded['fileUrl']?.toString();
      if (fileUrl != null && fileUrl.isNotEmpty) {
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
      }

      // Build media payload matching web client's reel structure as closely as possible.
      final Duration videoDuration =
          widget.media.duration ?? widget.trimEnd ?? const Duration(seconds: 0);
      final Duration start = widget.trimStart ?? Duration.zero;
      final Duration end =
          widget.trimEnd != null && widget.trimEnd! > start ? widget.trimEnd! : videoDuration;
      final int startMs = start.inMilliseconds;
      final int endMs = end.inMilliseconds;
      final int totalMs = videoDuration.inMilliseconds;
      final int finalLenMs = endMs > startMs ? (endMs - startMs) : totalMs;

      final thumbMeta = await _uploadThumbnailForVideo(
        videoPath: filePath,
        startMs: startMs,
        endMs: endMs,
      );

      final mediaItem = <String, dynamic>{
        'fileName': serverFileName,
        'type': 'video',
        if (fileUrl != null && fileUrl.isNotEmpty) 'fileUrl': fileUrl,
        // Timing information (ms, mirroring JS payload which uses numeric values)
        'timing': {
          'start': startMs,
          'end': endMs,
        },
        'videoLength': totalMs,
        'totalLenght': totalMs,
        'finalLength-start': startMs,
        'finallength-end': endMs,
        'finalLength': finalLenMs,
        'finallength': finalLenMs,
        if (thumbMeta != null && thumbMeta['thumbs'] != null) 'thumbnail': thumbMeta['thumbs'],
        if (thumbMeta != null && thumbMeta['timeMs'] != null) 'thumbail-time': thumbMeta['timeMs'],
        'soundOn': _soundOn,
        'isMuted': !_soundOn,
        'volume': 1.0,
        if (widget.selectedMusic != null) 'musicId': widget.selectedMusic,
        if (widget.selectedMusic != null) 'musicVolume': widget.musicVolume,
      };

      // Extract hashtags
      final captionText = _captionCtl.text.trim();
      final tags = RegExp(r'#(\w+)').allMatches(captionText).map((m) => m.group(0)!).toList();

      final created = await ReelsApi().createReel(
        media: [mediaItem],
        caption: captionText.isEmpty ? null : captionText,
        location: _location.isEmpty ? null : _location,
        tags: tags,
        peopleTags: _peopleTags.map((t) => {
          'user_id': t['user_id'],
          'username': t['username'],
          'x': (t['x'] as double) * 100, // API expects 0-100 range? React sends 0-100.
          'y': (t['y'] as double) * 100,
        }).toList(),
        hideLikesCount: _hideLikes,
        turnOffCommenting: _turnOffCommenting,
      );

      if (created.isNotEmpty && mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reel shared successfully!')),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create reel.')),
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

  @override
  Widget build(BuildContext context) {
    final media = widget.media;
    final isVideo = media.type == MediaType.video;

    Widget previewChild;
    if (media.filePath != null && isVideo) {
      final controller = _videoController;
      if (controller == null) {
        previewChild =
            Icon(LucideIcons.video, size: 100, color: Colors.grey[600]);
      } else {
        previewChild = FutureBuilder<void>(
          future: _videoInit,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done ||
                !controller.value.isInitialized) {
              return const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              );
            }
            return FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            );
          },
        );
      }
    } else if (media.filePath != null && !isVideo) {
      previewChild = Image.file(
        File(media.filePath!),
        fit: BoxFit.cover,
      );
    } else {
      previewChild = Icon(
        isVideo ? LucideIcons.video : LucideIcons.image,
        size: 100,
        color: Colors.grey[600],
      );
    }

    final previewSection = Container(
      color: Colors.black,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(child: previewChild),
          // Interactive layer for tagging
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                if (_peopleTags.isEmpty) {
                   _showTagSearch();
                }
              },
              child: Container(color: Colors.transparent),
            ),
          ),
          if (_peopleTags.isEmpty)
             const Positioned(
                bottom: 20,
                child: Text(
                  'Tap to tag people',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    shadows: [Shadow(blurRadius: 2, color: Colors.black)],
                  ),
                ),
             ),
          // Render tags
           ..._peopleTags.map((tag) {
              final x = (tag['x'] as double);
              final y = (tag['y'] as double);
              return Align(
                alignment: Alignment(x * 2 - 1, y * 2 - 1),
                child: GestureDetector(
                  onPanUpdate: (details) {
                    // Drag logic requires container size context, skipping complex drag for now
                    // just allow tap to remove
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tag['username'],
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _peopleTags.remove(tag);
                            });
                          },
                          child: const Icon(LucideIcons.x, size: 14, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              );
           }).toList(),
        ],
      ),
    );

    final sharePanel = Container(
      color: Theme.of(context).colorScheme.surface,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.transparent,
                  child: CircleAvatar(
                    radius: 15,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: _currentUserProfile != null &&
                            _currentUserProfile!['avatar_url'] != null &&
                            (_currentUserProfile!['avatar_url'] as String)
                                .isNotEmpty
                        ? NetworkImage(
                            _currentUserProfile!['avatar_url'] as String)
                        : null,
                    child: _currentUserProfile == null ||
                            _currentUserProfile!['avatar_url'] == null ||
                            (_currentUserProfile!['avatar_url'] as String)
                                .isEmpty
                        ? Text(
                            _currentUserProfile != null
                                ? ((_currentUserProfile!['username'] ??
                                            _currentUserProfile!['full_name'] ??
                                            'U') as String)
                                        .isNotEmpty
                                    ? ((_currentUserProfile!['username'] ??
                                                _currentUserProfile![
                                                    'full_name'] ??
                                                'U') as String)
                                            .substring(0, 1)
                                            .toUpperCase()
                                    : 'U'
                                : 'U',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  (_currentUserProfile?['username'] as String?) ?? 'User',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
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
                      icon: Icon(LucideIcons.smile,
                          color: Colors.grey[600], size: 22),
                      onPressed: () =>
                          setState(() => _showEmojiPicker = !_showEmojiPicker),
                    ),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _captionCtl,
                      builder: (_, value, __) => Text(
                        '${value.text.length}/2,200',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[600]),
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
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _popularEmojis
                              .map(
                                (e) => InkWell(
                                  onTap: () {
                                    _captionCtl.text = _captionCtl.text + e;
                                    setState(() {});
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Text(e,
                                        style:
                                            const TextStyle(fontSize: 22)),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          InkWell(
            onTap: _showTagSearch,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tag People', style: TextStyle(fontSize: 14)),
                  const Text('Add Tag', style: TextStyle(fontSize: 14, color: Colors.blue, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          if (_peopleTags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _peopleTags.map((tag) => Chip(
                  avatar: CircleAvatar(
                    backgroundImage: tag['avatar_url'] != null ? NetworkImage(tag['avatar_url']) : null,
                    child: tag['avatar_url'] == null ? Text(tag['username'][0].toUpperCase()) : null,
                  ),
                  label: Text(tag['username']),
                  onDeleted: () {
                    setState(() {
                      _peopleTags.remove(tag);
                    });
                  },
                )).toList(),
              ),
            ),
          const Divider(height: 1),
          InkWell(
            onTap: () => setState(() => _soundOn = !_soundOn),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Sound', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  Switch(
                    value: _soundOn,
                    onChanged: (v) => setState(() => _soundOn = v),
                    activeColor: Colors.blue,
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          InkWell(
            onTap: () => setState(() => _advancedOpen = !_advancedOpen),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          if (_advancedOpen) ...[
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Hide like and view counts on this reel',
                              style: TextStyle(fontSize: 14),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Only you will see the total number of likes and views. You can change this later in the ... menu.',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _hideLikes,
                        onChanged: (v) =>
                            setState(() => _hideLikes = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Turn off commenting',
                                style: TextStyle(fontSize: 14)),
                            SizedBox(height: 4),
                            Text(
                              'You can change this later in the ... menu at the top of your reel.',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
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
          const SizedBox(height: 24),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('New Reel', style: TextStyle(color: Colors.black)),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Share',
                    style: TextStyle(
                      color: Color(0xFF0095F6),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final useColumn = constraints.maxWidth < 600;
          final borderedPanel = Container(
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
            child: sharePanel,
          );
          if (useColumn) {
            return Column(
              children: [
                Expanded(flex: 2, child: previewSection),
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
              Expanded(flex: 2, child: previewSection),
              SizedBox(
                width: 420,
                child: borderedPanel,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TagSearchSheet extends StatefulWidget {
  final Function(Map<String, dynamic>) onSelect;
  const _TagSearchSheet({Key? key, required this.onSelect}) : super(key: key);

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
                          final username = (user['username'] as String?) ?? 'User';
                          final fullName = (user['full_name'] as String?) ?? '';
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.grey[200],
                              backgroundImage: avatar != null && avatar.isNotEmpty
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
                            subtitle: fullName.isNotEmpty ? Text(fullName) : null,
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
