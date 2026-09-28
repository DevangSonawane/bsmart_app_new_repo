import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../api/upload_api.dart';
import '../../../utils/url_helper.dart';
import '../../../widgets/safe_network_image.dart';

/// Edit the `images` payload of an influencer product/service.
///
/// Keeps existing entries untouched (passed back verbatim) and uploads new
/// picks via [UploadApi.uploadPromoteProductFile], appending `{fileName}`.
/// [minCount] is 1 for products (spec requires at least one image) and 0
/// for services (images optional).
class StoreImageEditor extends StatefulWidget {
  final List<Map<String, dynamic>> initial;
  final int minCount;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;

  const StoreImageEditor({
    super.key,
    required this.initial,
    required this.minCount,
    required this.onChanged,
  });

  /// Image entries from a product/service payload, normalized to maps.
  static List<Map<String, dynamic>> entriesOf(Map<String, dynamic> raw) {
    final images = raw['images'];
    if (images is! List) return [];
    return images.whereType<Map>().map((entry) {
      return entry.map((key, value) => MapEntry(key.toString(), value));
    }).toList();
  }

  static String thumbUrl(Map<String, dynamic> entry) {
    for (final key in ['url', 'fileName', 'filename', 'path', 'src']) {
      final value = entry[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return UrlHelper.absoluteUrl(value);
    }
    return '';
  }

  @override
  State<StoreImageEditor> createState() => _StoreImageEditorState();
}

class _StoreImageEditorState extends State<StoreImageEditor> {
  late List<Map<String, dynamic>> _images;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _images = List<Map<String, dynamic>>.from(widget.initial);
  }

  Future<void> _pickAndUpload() async {
    if (_uploading) return;
    setState(() => _uploading = true);
    try {
      final picked =
          await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null || !mounted) return;
      final upload =
          await UploadApi().uploadPromoteProductFile(picked.path);
      final name = _uploadName(upload);
      if (name.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload failed: empty response.')),
        );
        return;
      }
      setState(() => _images.add({'fileName': name}));
      widget.onChanged(List<Map<String, dynamic>>.from(_images));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image upload failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  static String _uploadName(Map<String, dynamic> upload) {
    for (final key in ['fileName', 'filename', 'path', 'url']) {
      final value = upload[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    for (final key in ['data', 'file', 'result']) {
      final nested = upload[key];
      if (nested is Map) {
        final name = _uploadName(
            nested.map((k, v) => MapEntry(k.toString(), v)));
        if (name.isNotEmpty) return name;
      }
      if (nested is List && nested.isNotEmpty && nested.first is Map) {
        final name = _uploadName((nested.first as Map)
            .map((k, v) => MapEntry(k.toString(), v)));
        if (name.isNotEmpty) return name;
      }
    }
    return '';
  }

  void _removeAt(int index) {
    if (_images.length <= widget.minCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.minCount == 0
              ? 'Nothing to remove.'
              : 'Products need at least one image.'),
        ),
      );
      return;
    }
    setState(() => _images.removeAt(index));
    widget.onChanged(List<Map<String, dynamic>>.from(_images));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Images (${_images.length})',
                style: const TextStyle(
                  color: Color(0xFF060D35),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _pickAndUpload,
              icon: _uploading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(LucideIcons.plus, size: 16),
              label: Text(_uploading ? 'Uploading...' : 'Add'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (_images.isEmpty)
          const Text(
            'No images yet. Add one from your gallery.',
            style: TextStyle(color: Color(0xFF6E748B), fontSize: 12),
          )
        else
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final url =
                    StoreImageEditor.thumbUrl(_images[index]);
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: url.isEmpty
                          ? Container(
                              width: 72,
                              height: 72,
                              color: const Color(0xFFF1F4F8),
                              child: const Icon(
                                LucideIcons.image,
                                color: Color(0xFF6E748B),
                              ),
                            )
                          : SafeNetworkImage(
                              url: url,
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                              debugLabel: 'store-edit-image',
                            ),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: InkWell(
                        onTap: () => _removeAt(index),
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            color: Colors.black87,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}
