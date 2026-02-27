import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:photo_manager/photo_manager.dart';
import '../models/media_model.dart';
import '../services/create_service.dart';
import 'create_post_screen.dart';
import 'create_edit_preview_screen.dart';
import 'story_camera_screen.dart';

enum _GallerySource {
  recents,
  videos,
  favourites,
  allAlbums,
}

class CreateUploadScreen extends StatefulWidget {
  final UploadMode initialMode;

  const CreateUploadScreen({super.key, this.initialMode = UploadMode.post});

  @override
  State<CreateUploadScreen> createState() => _CreateUploadScreenState();
}

class _CreateUploadScreenState extends State<CreateUploadScreen> {
  final CreateService _createService = CreateService();
  final List<AssetEntity> _assets = [];
  final List<AssetEntity> _recentAssets = [];
  final List<AssetEntity> _allAlbumAssets = [];
  final Set<String> _selectedIds = {};
  AssetEntity? _currentAsset;
  bool _multiSelect = false;
  bool _galleryPermissionDenied = false;
  late UploadMode _mode;
  _GallerySource _source = _GallerySource.recents;
  bool _showSourceMenu = false;

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
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth) {
      if (mounted) {
        setState(() {
          _galleryPermissionDenied = true;
          _assets.clear();
          _selectedIds.clear();
          _currentAsset = null;
        });
      }
      return;
    }
 
    if (mounted && _galleryPermissionDenied) {
      setState(() {
        _galleryPermissionDenied = false;
      });
    }
    final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
      type: RequestType.common,
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
          _currentAsset = null;
        });
      }
      return;
    }
    final AssetPathEntity recent = paths.first;
    final List<AssetEntity> recentAssets = await recent.getAssetListPaged(page: 0, size: 120);
    final List<AssetEntity> allAlbumAssets = [];
    for (final path in paths) {
      final list = await path.getAssetListPaged(page: 0, size: 60);
      allAlbumAssets.addAll(list);
      if (allAlbumAssets.length >= 120) {
        allAlbumAssets.removeRange(120, allAlbumAssets.length);
        break;
      }
    }
    if (mounted) {
      setState(() {
        _recentAssets
          ..clear()
          ..addAll(recentAssets);
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
      } else {
        _currentAsset = newCurrent;
        _selectedIds.clear();
        if (_currentAsset != null) {
          _selectedIds.add(_currentAsset!.id);
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
    if (mode == UploadMode.post) {
      if (_mode != UploadMode.post) {
        setState(() {
          _mode = UploadMode.post;
        });
      }
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const StoryCameraScreen(),
      ),
    );
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
        } else {
          _selectedIds.add(asset.id);
        }
      } else {
        _selectedIds
          ..clear()
          ..add(asset.id);
      }
    });
  }

  Future<void> _handleNext() async {
    if (_assets.isEmpty && _currentAsset == null) return;
    AssetEntity? asset;
    if (_selectedIds.isNotEmpty) {
      asset = _assets.firstWhere(
        (a) => _selectedIds.contains(a.id),
        orElse: () => _currentAsset ?? _assets.first,
      );
    } else {
      asset = _currentAsset ?? _assets.first;
    }
    final file = await asset.originFile;
    if (file == null) return;
    final media = MediaItem(
      id: asset.id,
      type: asset.type == AssetType.video ? MediaType.video : MediaType.image,
      filePath: file.path,
      createdAt: asset.createDateTime,
      duration: asset.type == AssetType.video ? Duration(seconds: asset.duration) : null,
    );
    if (!_createService.validateMedia(media)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video must be 60 seconds or less')),
        );
      }
      return;
    }
    if (!mounted) return;
    if (_mode == UploadMode.reel) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => CreateEditPreviewScreen(
            media: media,
          ),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => CreatePostScreen(
            initialMedia: media,
          ),
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    final isReelMode = _mode == UploadMode.reel;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
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
          Column(
            children: [
              if (!isReelMode)
                AspectRatio(
                  aspectRatio: 1.0,
                  child: Container(
                    width: double.infinity,
                    color: Colors.black,
                    child: _currentAsset == null
                        ? Center(
                            child: Icon(Icons.image, size: 64, color: Colors.grey[700]),
                          )
                        : FutureBuilder<Uint8List?>(
                            future: () {
                              final asset = _currentAsset!;
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _showSourceMenu = !_showSourceMenu;
                        });
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _sourceLabel,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                        ],
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _multiSelect = !_multiSelect;
                        });
                      },
                      child: Text(
                        _multiSelect ? 'Deselect' : 'Select',
                        style: TextStyle(
                          color: _multiSelect ? Colors.black : Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: _multiSelect ? Colors.white : Colors.white10,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _galleryPermissionDenied
                    ? SingleChildScrollView(
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
                                onPressed: _loadGalleryMedia,
                                child: const Text(
                                  'Try again',
                                  style: TextStyle(color: Color(0xFF0095F6)),
                                ),
                              ),
                              const SizedBox(height: 4),
                              TextButton(
                                onPressed: PhotoManager.openSetting,
                                child: const Text(
                                  'Open Settings',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _assets.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.image_search, size: 64, color: Colors.white30),
                                SizedBox(height: 12),
                                Text(
                                  'No photos or videos',
                                  style: TextStyle(color: Colors.white60),
                                ),
                              ],
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.all(1),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              crossAxisSpacing: 1,
                              mainAxisSpacing: 1,
                            ),
                            itemCount: _assets.length,
                            itemBuilder: (context, index) {
                              final asset = _assets[index];
                              final isSelected = _selectedIds.contains(asset.id);
                              return GestureDetector(
                                onTap: () => _onAssetTap(asset),
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
                                    if (isSelected)
                                      Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(color: const Color(0xFF0095F6), width: 2),
                                        ),
                                        child: Align(
                                          alignment: Alignment.topRight,
                                          child: Container(
                                            margin: const EdgeInsets.all(4),
                                            padding: const EdgeInsets.all(2),
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF0095F6),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.check,
                                              size: 14,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
              if (!isReelMode || !_hasSelection)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16, top: 8),
                  child: Center(
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
                            onTap: () => _onModeTap(UploadMode.post),
                            child: AnimatedDefaultTextStyle(
                              duration: _modeAnimDuration,
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
                            onTap: () => _onModeTap(UploadMode.story),
                            child: AnimatedDefaultTextStyle(
                              duration: _modeAnimDuration,
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
                            onTap: () => _onModeTap(UploadMode.reel),
                            child: AnimatedDefaultTextStyle(
                              duration: _modeAnimDuration,
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
                            onTap: () => _onModeTap(UploadMode.live),
                            child: AnimatedDefaultTextStyle(
                              duration: _modeAnimDuration,
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
                  ),
                ),
            ],
          ),
          if (!isReelMode)
            Positioned(
              left: 16,
              bottom: 96,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const StoryCameraScreen(),
                    ),
                  );
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF262626),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          if (isReelMode && _hasSelection)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 16, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0),
                      Colors.black.withOpacity(0.8),
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
                            final asset = _firstSelectedAsset();
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
                      onPressed: _handleNext,
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
              left: 16,
              top: 328,
              child: Container(
                width: 220,
                decoration: BoxDecoration(
                  color: const Color(0xFF262626),
                  borderRadius: BorderRadius.circular(12),
                ),
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
