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
import '../api/posts_api.dart';
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
  State<CreateReelDetailsScreen> createState() => _CreateReelDetailsScreenState();
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
  String? _selectedThumbnailPath; // User-selected thumbnail

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

  Future<void> _pickCustomThumbnail() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth) return;
    
    final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      filterOption: FilterOptionGroup(
        orders: [const OrderOption(type: OrderOptionType.createDate, asc: false)],
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
        setState(() {
          _selectedThumbnailPath = file.path;
        });
      }
    }
  }

  Future<Map<String, dynamic>?> _uploadThumbnailForVideo({
    required String videoPath,
    required int startMs,
    required int endMs,
  }) async {
    try {
      Uint8List? bytes;
      
      // 1. Use user-selected thumbnail if available
      if (_selectedThumbnailPath != null) {
        final file = File(_selectedThumbnailPath!);
        if (await file.exists()) {
          bytes = await file.readAsBytes();
        }
      }
      
      // 2. Fallback to generating from video
      if (bytes == null) {
        final durationMs = endMs > startMs ? endMs - startMs : (endMs > 0 ? endMs : startMs);
        final midOffset = durationMs > 0 ? durationMs ~/ 2 : 0;
        final captureMs = startMs + midOffset;
        bytes = await VideoThumbnail.thumbnailData(
          video: videoPath,
          imageFormat: ImageFormat.JPEG,
          timeMs: captureMs,
          quality: 85,
        );
      }
      
      if (bytes == null || bytes.isEmpty) return null;
      
      final filename = 'thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final res = await UploadApi().uploadThumbnailBytes(bytes: bytes, filename: filename);
      final rawThumbs = res['thumbnails'];
      if (rawThumbs == null) return null;
      List<Map<String, dynamic>>? thumbs;
      if (rawThumbs is List) {
        thumbs = rawThumbs.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } else if (rawThumbs is Map) {
        thumbs = [Map<String, dynamic>.from(rawThumbs)];
      }
      if (thumbs == null || thumbs.isEmpty) return null;
      return {
        'thumbs': thumbs,
        'timeMs': 0, // Should be actual time if auto-generated, but 0 is fine for custom
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

      await PostsApi().createPost(
        media: [mediaItem],
        caption: captionText.isEmpty ? null : captionText,
        location: _location.isEmpty ? null : _location,
        tags: tags,
        type: 'reel',
        peopleTags: _peopleTags,
        hideLikesCount: _hideLikes,
        turnOffCommenting: _turnOffCommenting,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('Cover', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        SizedBox(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              // Current selection preview
              GestureDetector(
                onTap: _pickCustomThumbnail,
                child: Container(
                  width: 80,
                  height: 120,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                    image: _selectedThumbnailPath != null
                        ? DecorationImage(
                            image: FileImage(File(_selectedThumbnailPath!)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _selectedThumbnailPath == null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            if (_videoController != null && _videoController!.value.isInitialized)
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
                              const Center(child: Icon(LucideIcons.image, color: Colors.grey)),
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
                      Icon(Icons.add_photo_alternate_outlined, color: Colors.black54),
                      SizedBox(height: 4),
                      Text('Upload', style: TextStyle(fontSize: 12, color: Colors.black54)),
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
                : const Text('Share', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
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
                    child: _videoController != null && _videoController!.value.isInitialized
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
                        : const Center(child: CircularProgressIndicator(color: Colors.white)),
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
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      Icon(
                        _advancedOpen ? LucideIcons.chevronUp : LucideIcons.chevronDown,
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                          onChanged: (v) => setState(() => _turnOffCommenting = v),
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
            title: const Text('Select Cover', style: TextStyle(color: Colors.black)),
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
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                          future: asset.thumbnailDataWithSize(const ThumbnailSize(200, 200)),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              return Image.memory(snapshot.data!, fit: BoxFit.cover);
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
