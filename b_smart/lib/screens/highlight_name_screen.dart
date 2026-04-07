import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../models/story_model.dart';
import '../models/highlight_model.dart';
import '../api/highlights_api.dart';
import '../api/upload_api.dart';

const _kBlue = Color(0xFF3897F0);
const _kSheet = Color(0xFF1C1C1E);
const _kBg = Color(0xFF000000);
const _kField = Color(0xFF1C1C1E);
const _kDivider = Color(0x1FFFFFFF);

class HighlightNameScreen extends StatefulWidget {
  final List<Story> selectedStories;
  final String userId;
  final String userName;
  final String? userAvatar;

  const HighlightNameScreen({
    super.key,
    required this.selectedStories,
    required this.userId,
    required this.userName,
    this.userAvatar,
  });

  @override
  State<HighlightNameScreen> createState() => _HighlightNameScreenState();
}

class _HighlightNameScreenState extends State<HighlightNameScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final HighlightsApi _api = HighlightsApi();
  final UploadApi _uploadApi = UploadApi();

  bool _loading = false;
  File? _customCoverFile;
  late final AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _pickCustomCover() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() {
      _customCoverFile = File(picked.path);
    });
  }

  Future<void> _createAndAdd() async {
    if (_loading) return;
    final title = _nameController.text.trim();
    if (title.isEmpty) {
      _shakeController.forward(from: 0);
      return;
    }
    setState(() => _loading = true);
    try {
      String coverUrl = _bestCoverUrl(widget.selectedStories.first);
      if (_customCoverFile != null) {
        final uploaded = await _uploadApi.uploadFile(_customCoverFile!.path);
        coverUrl = (uploaded['fileUrl'] as String?) ??
            (uploaded['url'] as String?) ??
            coverUrl;
      }
      final created = await _api.create(title: title, coverUrl: coverUrl);
      final id =
          (created['_id'] as String?) ?? (created['id'] as String?) ?? '';
      if (id.isEmpty) throw Exception('Missing highlight id');
      final storyIds = widget.selectedStories
          .map((s) => s.id.trim())
          .where((id) => id.isNotEmpty && id != 'item')
          .toList();
      if (storyIds.isEmpty) {
        throw Exception('No valid story ids found to add');
      }
      await _api.addItems(
        id,
        storyIds,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create highlight: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _bestCoverUrl(Story story) {
    final thumb = (story.thumbnailUrl ?? '').trim();
    final media = story.mediaUrl.trim();
    bool isBad(String url) {
      final lower = url.toLowerCase();
      return lower.endsWith('.m3u8') ||
          lower.endsWith('.mp4') ||
          lower.endsWith('.mov') ||
          lower.endsWith('.m4v') ||
          lower.endsWith('.mkv') ||
          lower.endsWith('.webm');
    }

    if (thumb.isNotEmpty && !isBad(thumb)) return thumb;
    if (media.isNotEmpty && !isBad(media)) return media;
    // Fallback: server may still accept it, but clients won't decode it as an image.
    return media.isNotEmpty ? media : thumb;
  }

  Future<void> _showExistingHighlightsSheet() async {
    if (_loading) return;
    List<Map<String, dynamic>> raw;
    try {
      raw = await _api.userHighlights(widget.userId);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load highlights')),
      );
      return;
    }
    Map<String, dynamic> _normalizeId(Map<String, dynamic> m) {
      final copy = Map<String, dynamic>.from(m);
      final id = copy['_id'];
      if (id != null && id is! String) copy['_id'] = id.toString();
      final id2 = copy['id'];
      if (id2 != null && id2 is! String) copy['id'] = id2.toString();
      return copy;
    }

    final highlights = raw
        .map((m) => Highlight.fromMap(_normalizeId(m)))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    if (!mounted) return;
    if (highlights.isEmpty) {
      return;
    }
    final selectedId = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ExistingHighlightsSheet(highlights: highlights),
    );
    if (selectedId == null || selectedId.isEmpty || !mounted) return;
    setState(() => _loading = true);
    try {
      await _api.addItems(
        selectedId,
        widget.selectedStories
            .map((s) => s.id.trim())
            .where((id) => id.isNotEmpty && id != 'item')
            .toList(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add to highlight: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final coverUrl = _bestCoverUrl(widget.selectedStories.first);
    final shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
    );

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
            Column(
              children: [
                const SizedBox(height: 60),
                const Text(
                  'New Highlight',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: _pickCustomCover,
                  child: Stack(
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _customCoverFile != null
                            ? Image.file(
                                _customCoverFile!,
                                fit: BoxFit.cover,
                              )
                            : CachedNetworkImage(
                                imageUrl: coverUrl,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) =>
                                    Container(color: _kField),
                              ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: _kBlue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt,
                              size: 13, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                AnimatedBuilder(
                  animation: shakeAnimation,
                  builder: (context, child) {
                    final t = shakeAnimation.value;
                    final dx = sin(t * pi * 6) * 6;
                    return Transform.translate(
                      offset: Offset(dx, 0),
                      child: child,
                    );
                  },
                  child: TextField(
                    controller: _nameController,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLength: 30,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Highlight name',
                      hintStyle: TextStyle(color: Colors.white38, fontSize: 22),
                      counterStyle:
                          TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          onPressed: _loading ? null : _createAndAdd,
                          style: FilledButton.styleFrom(
                            backgroundColor: _kBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4)),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Text(
                                  'Add',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed:
                            _loading ? null : _showExistingHighlightsSheet,
                        child: const Text(
                          'Add to existing highlight',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExistingHighlightsSheet extends StatelessWidget {
  final List<Highlight> highlights;

  const _ExistingHighlightsSheet({required this.highlights});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _kSheet,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Text(
                    'Add to highlight',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: highlights.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: _kDivider),
                itemBuilder: (ctx, i) {
                  final h = highlights[i];
                  return ListTile(
                    leading: _HighlightCoverThumb(coverUrl: h.coverUrl),
                    title: Text(h.title,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14)),
                    subtitle: Text(
                      '${h.itemsCount} item${h.itemsCount == 1 ? '' : 's'}',
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    trailing:
                        const Icon(Icons.chevron_right, color: Colors.white38),
                    onTap: () => Navigator.of(ctx).pop(h.id),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _HighlightCoverThumb extends StatelessWidget {
  final String? coverUrl;

  const _HighlightCoverThumb({this.coverUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: _kField,
      ),
      clipBehavior: Clip.antiAlias,
      child: coverUrl != null && coverUrl!.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: coverUrl!,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) =>
                  const Icon(Icons.image, color: Colors.white30, size: 20),
            )
          : const Icon(Icons.image, color: Colors.white30, size: 20),
    );
  }
}
