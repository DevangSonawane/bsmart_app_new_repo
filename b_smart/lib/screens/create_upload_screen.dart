import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:ui';
import 'dart:typed_data';
import 'package:photo_manager/photo_manager.dart';
import '../services/create_service.dart';
import 'create_edit_preview_screen.dart';
import 'create_post_screen.dart';
import 'story_camera_screen.dart';
import '../models/media_model.dart';
import 'advertiser_create_ad_screen.dart';
import '../widgets/instagram_tab_scaffold.dart';

enum _GallerySource {
  recents,
  videos,
  favourites,
  allAlbums,
}

class CreateUploadScreen extends StatefulWidget {
  final UploadMode initialMode;
  final bool isAdFlow;

  const CreateUploadScreen({
    super.key,
    this.initialMode = UploadMode.post,
    this.isAdFlow = false,
  });

  @override
  State<CreateUploadScreen> createState() => _CreateUploadScreenState();
}

class _CreateUploadScreenState extends State<CreateUploadScreen> {
  final CreateService _createService = CreateService();
  final List<AssetEntity> _assets = [];
  final List<AssetEntity> _recentAssets = [];
  final List<AssetEntity> _allAlbumAssets = [];
  final Set<String> _selectedIds = {};
  final List<String> _selectedOrder = [];
  AssetEntity? _currentAsset;
  bool _multiSelect = false;
  bool _galleryPermissionDenied = false;
  bool _galleryPermissionLimited = false;
  late UploadMode _mode;
  _GallerySource _source = _GallerySource.recents;
  bool _showSourceMenu = false;
  final GlobalKey _sourceBarKey = GlobalKey();
  Offset _sourceMenuPosition = const Offset(16, 328);

  static const Duration _modeAnimDuration = Duration(milliseconds: 90);

  String get _sourceLabel {
    switch (_source) {
      case _GallerySource.recents:
        return 'Recents';
      case _GallerySource.videos:
        return 'Videos';
      case _GallerySource.favourites:
        return 'Favourites';
      case _GallerySource.allAlbums:
        return 'All albums';
    }
  }

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _loadGalleryMedia();
  }

  Future<void> _loadGalleryMedia() async {
    // Let photo_manager handle permission requests on both iOS and Android
    final PermissionState ps = await PhotoManager.requestPermissionExtend(
      requestOption: const PermissionRequestOption(
        iosAccessLevel: IosAccessLevel.readWrite,
        androidPermission: AndroidPermission(
          type: RequestType.all,
          mediaLocation: false,
        ),
      ),
    );
    if (!ps.hasAccess) {
      if (mounted) {
        setState(() {
          _galleryPermissionDenied = true;
          _galleryPermissionLimited = false;
          _assets.clear();
          _selectedIds.clear();
          _selectedOrder.clear();
          _currentAsset = null;
        });
      }
      return;
    }
 
    if (mounted) {
      setState(() {
        _galleryPermissionDenied = false;
        _galleryPermissionLimited = ps.isLimited;
      });
    }
    final RequestType requestType =
        _mode == UploadMode.reel ? RequestType.video : RequestType.all;
    final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
      type: requestType,
      filterOption: FilterOptionGroup(
        orders: [const OrderOption(type: OrderOptionType.createDate, asc: false)],
      ),
    );
    if (paths.isEmpty) {
      if (mounted) {
        setState(() {
          _assets.clear();
          _recentAssets.clear();
          _allAlbumAssets.clear();
          _selectedIds.clear();
          _selectedOrder.clear();
          _currentAsset = null;
        });
      }
      return;
    }
    final AssetPathEntity recent = paths.firstWhere(
      (p) => p.isAll,
      orElse: () => paths.first,
    );
    final int recentSize = _mode == UploadMode.reel ? 1000 : 120;
    final int albumSize = _mode == UploadMode.reel ? 300 : 60;
    final int albumCap = _mode == UploadMode.reel ? 1000 : 120;
    List<AssetEntity> recentAssets =
        await recent.getAssetListPaged(page: 0, size: recentSize);
    final List<AssetEntity> allAlbumAssets = [];
    for (final path in paths) {
      final list = await path.getAssetListPaged(page: 0, size: albumSize);
      allAlbumAssets.addAll(list);
      if (allAlbumAssets.length >= albumCap) {
        allAlbumAssets.removeRange(albumCap, allAlbumAssets.length);
        break;
      }
    }
    List<AssetEntity> normalizedRecent = List<AssetEntity>.from(recentAssets);
    if (_mode != UploadMode.reel) {
      // Always merge image+video recents to ensure videos appear in post flow.
      final imagePaths = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        filterOption: FilterOptionGroup(
          orders: [const OrderOption(type: OrderOptionType.createDate, asc: false)],
        ),
      );
      final videoPaths = await PhotoManager.getAssetPathList(
        type: RequestType.video,
        filterOption: FilterOptionGroup(
          orders: [const OrderOption(type: OrderOptionType.createDate, asc: false)],
        ),
      );
      final AssetPathEntity imageRecent = imagePaths.firstWhere(
        (p) => p.isAll,
        orElse: () => imagePaths.isNotEmpty ? imagePaths.first : recent,
      );
      final AssetPathEntity videoRecent = videoPaths.firstWhere(
        (p) => p.isAll,
        orElse: () => videoPaths.isNotEmpty ? videoPaths.first : recent,
      );
      final images = await imageRecent.getAssetListPaged(page: 0, size: recentSize);
      final videos = await videoRecent.getAssetListPaged(page: 0, size: recentSize);
      final byId = <String, AssetEntity>{};
      for (final a in images) {
        byId[a.id] = a;
      }
      for (final v in videos) {
        byId[v.id] = v;
      }
      final merged = byId.values.toList();
      merged.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));
      normalizedRecent = List<AssetEntity>.from(merged);

      // Ensure a minimum number of videos are visible in the grid.
      const minVideoCount = 6;
      int videoCount = normalizedRecent.where((a) => a.type == AssetType.video).length;
      if (videoCount < minVideoCount) {
        for (final v in videos) {
          if (byId.containsKey(v.id)) continue;
          normalizedRecent.add(v);
          videoCount++;
          if (videoCount >= minVideoCount) break;
        }
      }

      // Trim to recentSize but preserve videos when possible.
      while (normalizedRecent.length > recentSize) {
        final idx = normalizedRecent.lastIndexWhere((a) => a.type != AssetType.video);
        if (idx == -1) {
          normalizedRecent.removeLast();
        } else {
          normalizedRecent.removeAt(idx);
        }
      }
      recentAssets = normalizedRecent;
    }
    if (mounted) {
      setState(() {
        _recentAssets
          ..clear()
          ..addAll(normalizedRecent);
        _allAlbumAssets
          ..clear()
          ..addAll(allAlbumAssets.isEmpty ? recentAssets : allAlbumAssets);
      });
      _applySource(_source);
    }
  }

  void _applySource(_GallerySource newSource) {
    List<AssetEntity> visible;
    final List<AssetEntity> baseRecent = List<AssetEntity>.from(_recentAssets);
    final List<AssetEntity> baseAll = List<AssetEntity>.from(_allAlbumAssets.isEmpty ? _recentAssets : _allAlbumAssets);
    switch (newSource) {
      case _GallerySource.recents:
        visible = baseRecent;
        break;
      case _GallerySource.videos:
        visible = baseRecent.where((a) => a.type == AssetType.video).toList();
        break;
      case _GallerySource.favourites:
        visible = baseRecent.where((a) => a.isFavorite).toList();
        break;
      case _GallerySource.allAlbums:
        visible = baseAll;
        break;
    }
    if (_mode == UploadMode.reel) {
      visible = visible.where((a) => a.type == AssetType.video).toList();
    }
    AssetEntity? newCurrent;
    if (visible.isNotEmpty) {
      final currentId = _currentAsset?.id;
      if (currentId != null && visible.any((a) => a.id == currentId)) {
        newCurrent = visible.firstWhere((a) => a.id == currentId);
      } else {
        newCurrent = visible.first;
      }
    }
    setState(() {
      _source = newSource;
      _assets
        ..clear()
        ..addAll(visible);
      if (_mode == UploadMode.reel) {
        _currentAsset = null;
        _selectedIds.clear();
        _selectedOrder.clear();
      } else {
        _currentAsset = newCurrent;
        _selectedIds.clear();
        _selectedOrder.clear();
        if (_currentAsset != null) {
          _selectedIds.add(_currentAsset!.id);
          _selectedOrder.add(_currentAsset!.id);
        }
      }
    });
  }

  void _onSourceSelected(_GallerySource source) {
    setState(() {
      _showSourceMenu = false;
    });
    _applySource(source);
  }

  void _onModeTap(UploadMode mode) {
    if (_mode == mode) return;
    if (widget.isAdFlow) {
      if (mode != UploadMode.post && mode != UploadMode.reel) return;
      setState(() {
        _mode = mode;
      });
      _loadGalleryMedia();
      return;
    }

    setState(() {
      _mode = mode;
    });
    if (mode == UploadMode.post || mode == UploadMode.reel) {
      _selectedIds.clear();
      _selectedOrder.clear();
      _currentAsset = null;
      _loadGalleryMedia();
    }
  }

  void _onAssetTap(AssetEntity asset) {
    if (_mode == UploadMode.reel) {
      setState(() {
        if (_selectedIds.contains(asset.id)) {
          _selectedIds.remove(asset.id);
          if (_selectedIds.isEmpty) {
            _currentAsset = null;
          } else if (_currentAsset?.id == asset.id) {
            final firstId = _selectedIds.first;
            try {
              _currentAsset = _assets.firstWhere((a) => a.id == firstId);
            } catch (_) {
              _currentAsset = null;
            }
          }
        } else {
          _selectedIds.add(asset.id);
          _currentAsset ??= asset;
        }
      });
      return;
    }

    setState(() {
      _currentAsset = asset;
      if (_multiSelect) {
        if (_selectedIds.contains(asset.id)) {
          _selectedIds.remove(asset.id);
          _selectedOrder.remove(asset.id);
        } else {
          _selectedIds.add(asset.id);
          _selectedOrder.add(asset.id);
        }
      } else {
        _selectedIds
          ..clear()
          ..add(asset.id);
        _selectedOrder
          ..clear()
          ..add(asset.id);
      }
    });
  }

  Future<void> _handleNext() async {
    if (_assets.isEmpty && _currentAsset == null) return;
    final selectedAssets = _selectedOrder.isNotEmpty
        ? _selectedOrder
            .map((id) => _assets.where((a) => a.id == id).toList())
            .expand((e) => e)
            .toList()
        : (_selectedIds.isNotEmpty
            ? _assets.where((a) => _selectedIds.contains(a.id)).toList()
            : <AssetEntity>[]);
    final primaryAsset = _currentAsset ?? (_assets.isNotEmpty ? _assets.first : null);
    if (selectedAssets.isEmpty && primaryAsset != null) {
      selectedAssets.add(primaryAsset);
    }
    if (selectedAssets.isEmpty) return;

    final mediaList = <MediaItem>[];
    for (final asset in selectedAssets) {
      final file = await asset.originFile;
      if (file == null) continue;
      final pathLower = file.path.toLowerCase();
      final isVideo = asset.type == AssetType.video ||
          (asset.mimeType?.toLowerCase().startsWith('video/') ?? false) ||
          pathLower.endsWith('.mp4') ||
          pathLower.endsWith('.mov') ||
          pathLower.endsWith('.m4v') ||
          pathLower.endsWith('.3gp') ||
          pathLower.endsWith('.webm') ||
          pathLower.endsWith('.mkv');
      final media = MediaItem(
        id: asset.id,
        type: isVideo ? MediaType.video : MediaType.image,
        filePath: file.path,
        createdAt: asset.createDateTime,
        duration: isVideo ? Duration(seconds: asset.duration) : null,
      );
      if (!_createService.validateMedia(media)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Video must be 60 seconds or less')),
          );
        }
        return;
      }
      mediaList.add(media);
    }
    if (mediaList.isEmpty) return;

    final media = mediaList.first;
    if (!mounted) return;
    if (widget.isAdFlow) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => AdvertiserCreateAdScreen(
            initialContentType: _mode == UploadMode.reel ? 'reel' : 'post',
            initialMediaPath: media.filePath!,
            initialMediaIsVideo: media.type == MediaType.video,
          ),
        ),
      );
      return;
    }
    final shouldGoReelFlow = _mode == UploadMode.reel ||
        (!widget.isAdFlow &&
            _mode == UploadMode.post &&
            mediaList.length == 1 &&
            media.type == MediaType.video);
    if (shouldGoReelFlow) {
      final created = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => CreateEditPreviewScreen(
            media: media,
          ),
        ),
      );
      if (created == true && mounted) {
        Navigator.of(context).pop(true);
      }
    } else {
      final created = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => CreateEditPreviewScreen(
            media: mediaList.first,
            mediaList: mediaList,
            isPostFlow: true,
          ),
        ),
      );
      if (created == true && mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  bool get _hasSelection =>
      _mode == UploadMode.reel ? _selectedIds.isNotEmpty : (_currentAsset != null || _selectedIds.isNotEmpty);

  AssetEntity? _firstSelectedAsset() {
    if (_assets.isEmpty && _currentAsset == null) return null;
    if (_selectedIds.isNotEmpty) {
      try {
        return _assets.firstWhere((a) => _selectedIds.contains(a.id));
      } catch (_) {
        return _currentAsset ?? (_assets.isNotEmpty ? _assets.first : null);
      }
    }
    return _currentAsset ?? (_assets.isNotEmpty ? _assets.first : null);
  }

  String _titleForMode() {
    switch (_mode) {
      case UploadMode.post:
        return 'New post';
      case UploadMode.story:
        return 'New story';
      case UploadMode.reel:
        return 'New reel';
      case UploadMode.live:
        return 'New live';
    }
  }

  int _indexForMode(UploadMode mode) {
    switch (mode) {
      case UploadMode.post:
        return 0;
      case UploadMode.story:
        return 1;
      case UploadMode.reel:
        return 2;
      case UploadMode.live:
        return 3;
    }
  }

  UploadMode _modeForIndex(int index) {
    switch (index) {
      case 0:
        return UploadMode.post;
      case 1:
        return UploadMode.story;
      case 2:
        return UploadMode.reel;
      case 3:
        return UploadMode.live;
      default:
        return UploadMode.post;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isStoryOrLive = _mode == UploadMode.story || _mode == UploadMode.live;
    final modeIndex = _indexForMode(_mode);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: isStoryOrLive
          ? null
          : AppBar(
              backgroundColor: Colors.black,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
              ),
              centerTitle: true,
              title: Text(
                _titleForMode(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              actions: [
                TextButton(
                  onPressed: _hasSelection ? _handleNext : null,
                  child: Text(
                    'Next',
                    style: TextStyle(
                      color: _hasSelection ? const Color(0xFF0095F6) : Colors.white30,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
      body: Stack(
        children: [
          Positioned.fill(
            child: InstagramTabScaffold(
              initialIndex: _indexForMode(_mode),
              onTabChanged: (index) => _onModeTap(_modeForIndex(index)),
              bottomPaddingForIndex: (index) => 20,
              pillBackgroundColorForIndex: (index) =>
                  (index == 1 || index == 3) ? Colors.transparent : Colors.black.withValues(alpha: 0.6),
              pages: List.generate(
                4,
                (index) {
                  if (index == 1) {
                    return const StoryCameraScreen(
                      initialMode: UploadMode.story,
                      lockMode: true,
                      showModeTabs: false,
                    );
                  }
                  if (index == 3) {
                    return const StoryCameraScreen(
                      initialMode: UploadMode.live,
                      lockMode: true,
                      showModeTabs: false,
                    );
                  }
                  return _UploadPage(
                    isReelMode: _mode == UploadMode.reel,
                    galleryPermissionDenied: _galleryPermissionDenied,
                    assets: _assets,
                    currentAsset: _currentAsset,
                    selectedIds: _selectedIds,
                    selectedOrder: _selectedOrder,
                    multiSelect: _multiSelect,
                    hasSelection: _hasSelection,
                    galleryPermissionLimited: _galleryPermissionLimited,
                    sourceLabel: _sourceLabel,
                    sourceBarKey: index == modeIndex ? _sourceBarKey : GlobalKey(),
                    onSourceBarTap: () {
                      final box = _sourceBarKey.currentContext?.findRenderObject();
                      if (box is RenderBox) {
                        final pos = box.localToGlobal(Offset.zero);
                        _sourceMenuPosition = Offset(pos.dx, pos.dy + box.size.height + 6);
                      }
                      setState(() {
                        _showSourceMenu = !_showSourceMenu;
                      });
                    },
                    onMultiSelectToggle: () => setState(() {
                      _multiSelect = !_multiSelect;
                      if (!_multiSelect) {
                        _selectedIds
                          ..clear();
                        _selectedOrder.clear();
                        if (_currentAsset != null) {
                          _selectedIds.add(_currentAsset!.id);
                          _selectedOrder.add(_currentAsset!.id);
                        }
                      }
                    }),
                    onLoadGalleryMedia: _loadGalleryMedia,
                    onAssetTap: _onAssetTap,
                    onCameraTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const StoryCameraScreen(
                          initialMode: UploadMode.post,
                          lockMode: true,
                        ),
                      ),
                    ),
                    onNext: _hasSelection ? _handleNext : null,
                    firstSelectedAsset: _firstSelectedAsset(),
                  );
                },
              ),
            ),
          ),
          if (_showSourceMenu)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  setState(() {
                    _showSourceMenu = false;
                  });
                },
                child: const SizedBox.shrink(),
              ),
            ),
          if (_showSourceMenu)
            Positioned(
              left: _sourceMenuPosition.dx,
              top: _sourceMenuPosition.dy,
              child: Container(
                width: 220,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSourceItem(
                          gallerySource: _GallerySource.recents,
                          icon: Icons.photo_library_outlined,
                          label: 'Recents',
                        ),
                        _buildSourceItem(
                          gallerySource: _GallerySource.videos,
                          icon: Icons.play_arrow_rounded,
                          label: 'Videos',
                        ),
                        _buildSourceItem(
                          gallerySource: _GallerySource.favourites,
                          icon: Icons.favorite_border,
                          label: 'Favourites',
                        ),
                        _buildSourceItem(
                          gallerySource: _GallerySource.allAlbums,
                          icon: Icons.grid_view_rounded,
                          label: 'All albums',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSourceItem({
    required _GallerySource gallerySource,
    required IconData icon,
    required String label,
  }) {
    final selected = _source == gallerySource;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onSourceSelected(gallerySource),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white12 : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check,
                  color: Color(0xFF0095F6),
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UploadPage extends StatelessWidget {
  final bool isReelMode;
  final bool galleryPermissionDenied;
  final List<AssetEntity> assets;
  final AssetEntity? currentAsset;
  final Set<String> selectedIds;
  final List<String> selectedOrder;
  final bool multiSelect;
  final bool hasSelection;
  final bool galleryPermissionLimited;
  final String sourceLabel;
  final GlobalKey sourceBarKey;
  final VoidCallback onSourceBarTap;
  final VoidCallback onMultiSelectToggle;
  final VoidCallback onLoadGalleryMedia;
  final ValueChanged<AssetEntity> onAssetTap;
  final VoidCallback onCameraTap;
  final VoidCallback? onNext;
  final AssetEntity? firstSelectedAsset;

  const _UploadPage({
    required this.isReelMode,
    required this.galleryPermissionDenied,
    required this.assets,
    required this.currentAsset,
    required this.selectedIds,
    required this.selectedOrder,
    required this.multiSelect,
    required this.hasSelection,
    required this.galleryPermissionLimited,
    required this.sourceLabel,
    required this.sourceBarKey,
    required this.onSourceBarTap,
    required this.onMultiSelectToggle,
    required this.onLoadGalleryMedia,
    required this.onAssetTap,
    required this.onCameraTap,
    this.onNext,
    this.firstSelectedAsset,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  if (!isReelMode)
                    SliverToBoxAdapter(
                      child: AspectRatio(
                        aspectRatio: 1.0,
                        child: Container(
                          width: double.infinity,
                          color: Colors.black,
                          child: currentAsset == null
                              ? Center(
                                  child: Icon(Icons.image, size: 64, color: Colors.grey[700]),
                                )
                              : FutureBuilder<Uint8List?>(
                                  future: () {
                                    final asset = currentAsset!;
                                    final w = asset.width;
                                    final h = asset.height;
                                    const maxSide = 1000;
                                    int thumbW;
                                    int thumbH;
                                    if (w >= h && w > 0 && h > 0) {
                                      thumbW = maxSide;
                                      thumbH = (maxSide * h / w).round();
                                    } else if (h > 0 && w > 0) {
                                      thumbH = maxSide;
                                      thumbW = (maxSide * w / h).round();
                                    } else {
                                      thumbW = maxSide;
                                      thumbH = maxSide;
                                    }
                                    return asset.thumbnailDataWithSize(ThumbnailSize(thumbW, thumbH));
                                  }(),
                                  builder: (context, snap) {
                                    if (snap.connectionState != ConnectionState.done || snap.data == null) {
                                      return const Center(child: CircularProgressIndicator(color: Colors.white));
                                    }
                                    return Image.memory(
                                      snap.data!,
                                      fit: BoxFit.contain,
                                    );
                                  },
                                ),
                        ),
                      ),
                    ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _FixedSliverHeaderDelegate(
                      height: 56,
                      child: Container(
                        color: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: onSourceBarTap,
                              child: Row(
                                key: sourceBarKey,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    sourceLabel,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                                ],
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: onMultiSelectToggle,
                              style: TextButton.styleFrom(
                                backgroundColor: multiSelect ? Colors.white : Colors.white10,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              child: Text(
                                multiSelect ? 'Cancel' : 'Select',
                                style: TextStyle(
                                  color: multiSelect ? Colors.black : Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (galleryPermissionDenied)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.photo_library_outlined,
                              size: 72,
                              color: Colors.white54,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Allow access to your photos',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                'Enable photo library permission in Settings to choose photos and videos.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: onLoadGalleryMedia,
                              child: const Text(
                                'Try again',
                                style: TextStyle(color: Color(0xFF0095F6)),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const TextButton(
                              onPressed: PhotoManager.openSetting,
                              child: Text(
                                'Open Settings',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (galleryPermissionLimited)
                    SliverToBoxAdapter(
                      child: Container(
                        color: Colors.black,
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.white70, size: 18),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Limited photo access. Videos may be hidden.',
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                if (Platform.isIOS) {
                                  PhotoManager.presentLimited(type: RequestType.all);
                                } else {
                                  PhotoManager.openSetting();
                                }
                              },
                              child: Text(
                                Platform.isIOS ? 'Manage' : 'Settings',
                                style: const TextStyle(color: Color(0xFF0095F6)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (assets.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.image_search, size: 64, color: Colors.white30),
                            SizedBox(height: 12),
                            Text(
                              'No photos or videos',
                              style: TextStyle(color: Colors.white60),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(1),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 1,
                          mainAxisSpacing: 1,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index == 0) {
                              return GestureDetector(
                                onTap: onCameraTap,
                                child: Container(
                                  color: const Color(0xFF262626),
                                  child: const Center(
                                    child: Icon(
                                      Icons.camera_alt,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                ),
                              );
                            }

                            final asset = assets[index - 1];
                            final isSelected = selectedIds.contains(asset.id);
                            final orderIndex = isSelected
                                ? selectedOrder.indexOf(asset.id)
                                : -1;
                            return GestureDetector(
                              onTap: () => onAssetTap(asset),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  FutureBuilder<Uint8List?>(
                                    future: asset.thumbnailDataWithSize(const ThumbnailSize(300, 300)),
                                    builder: (context, snap) {
                                      if (snap.connectionState != ConnectionState.done || snap.data == null) {
                                        return Container(
                                          color: Colors.grey[850],
                                          child: const Center(
                                            child: Icon(Icons.image, color: Colors.white38),
                                          ),
                                        );
                                      }
                                      return Image.memory(
                                        snap.data!,
                                        fit: BoxFit.cover,
                                      );
                                    },
                                  ),
                                  if (asset.type == AssetType.video)
                                    Positioned(
                                      bottom: 4,
                                      right: 4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '${asset.duration}s',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (multiSelect)
                                    Align(
                                      alignment: Alignment.topRight,
                                      child: Container(
                                        margin: const EdgeInsets.all(6),
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Colors.white.withValues(alpha: 0.9)
                                              : Colors.black.withValues(alpha: 0.25),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.8),
                                            width: 1,
                                          ),
                                        ),
                                        child: Center(
                                          child: isSelected
                                              ? Text(
                                                  '${orderIndex + 1}',
                                                  style: const TextStyle(
                                                    color: Colors.black,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                )
                                              : const SizedBox.shrink(),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                          childCount: assets.length + 1,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (isReelMode && hasSelection)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 16, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0),
                      Colors.black.withValues(alpha: 0.8),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Builder(
                          builder: (context) {
                            final asset = firstSelectedAsset;
                            if (asset == null) {
                              return Container(color: Colors.black);
                            }
                            return FutureBuilder<Uint8List?>(
                              future: asset.thumbnailDataWithSize(const ThumbnailSize(300, 300)),
                              builder: (context, snap) {
                                if (snap.connectionState != ConnectionState.done || snap.data == null) {
                                  return Container(
                                    color: Colors.grey[850],
                                    child: const Center(
                                      child: Icon(Icons.image, color: Colors.white38),
                                    ),
                                  );
                                }
                                return Image.memory(
                                  snap.data!,
                                  fit: BoxFit.cover,
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: onNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0095F6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      child: const Text('Next →'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FixedSliverHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;

  _FixedSliverHeaderDelegate({
    required this.height,
    required this.child,
  });

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _FixedSliverHeaderDelegate oldDelegate) {
    return height != oldDelegate.height || child != oldDelegate.child;
  }
}
