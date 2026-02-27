import 'package:flutter/material.dart';
import 'dart:io';
import '../models/media_model.dart';
import '../models/content_moderation_model.dart';
import '../services/create_service.dart';
import '../services/content_moderation_service.dart';
import 'content_moderation_dialog.dart';
import '../api/posts_api.dart';
import '../api/upload_api.dart';
import '../utils/current_user.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class CreatePostDetailsScreen extends StatefulWidget {
  final MediaItem media;
  final String? selectedFilter;
  final String? selectedMusic;
  final double musicVolume;
  final Duration? trimStart;
  final Duration? trimEnd;

  const CreatePostDetailsScreen({
    super.key,
    required this.media,
    this.selectedFilter,
    this.selectedMusic,
    this.musicVolume = 0.5,
    this.trimStart,
    this.trimEnd,
  });

  @override
  State<CreatePostDetailsScreen> createState() => _CreatePostDetailsScreenState();
}

class _CreatePostDetailsScreenState extends State<CreatePostDetailsScreen> {
  final CreateService _createService = CreateService();
  final ContentModerationService _moderationService = ContentModerationService();
  final _captionController = TextEditingController();
  final _hashtagController = TextEditingController();
  
  PrivacyLevel _privacy = PrivacyLevel.public;
  bool _commentsEnabled = true;
  String? _location;
  final List<String> _taggedUsers = [];
  final List<String> _hashtags = [];
  String? _suggestedCaption;
  List<String> _suggestedHashtags = [];
  final bool _isSponsored = false; // Can be set from UI if needed

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  @override
  void dispose() {
    _captionController.dispose();
    _hashtagController.dispose();
    super.dispose();
  }

  void _loadSuggestions() {
    // Get AI suggestions
    _suggestedCaption = _createService.suggestCaption(widget.media);
    _suggestedHashtags = _createService.suggestHashtags(widget.media);
    
    if (_suggestedCaption != null) {
      _captionController.text = _suggestedCaption!;
    }
  }

  void _addHashtag() {
    final text = _hashtagController.text.trim();
    if (text.isNotEmpty && !text.startsWith('#')) {
      _hashtagController.text = '#$text';
    }
    if (_hashtagController.text.isNotEmpty) {
      setState(() {
        _hashtags.add(_hashtagController.text.trim());
        _hashtagController.clear();
      });
    }
  }

  void _removeHashtag(String hashtag) {
    setState(() {
      _hashtags.remove(hashtag);
    });
  }

  void _tagUser(String username) {
    if (!_taggedUsers.contains(username)) {
      setState(() {
        _taggedUsers.add(username);
      });
    }
  }

  void _removeTaggedUser(String username) {
    setState(() {
      _taggedUsers.remove(username);
    });
  }

  void _goToLogin() {
    Navigator.of(context).pushNamed('/login');
  }

  Future<void> _handlePost() async {
    if (_captionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a caption')),
      );
      return;
    }

    final userId = await CurrentUser.id;
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please login to post'),
            action: SnackBarAction(label: 'Login', onPressed: _goToLogin),
          ),
        );
      }
      return;
    }

    // Check if user can post (strike system)
    if (!_moderationService.canUserPost(userId)) {
      final strikes = _moderationService.getUserStrikes(userId);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Posting Restricted'),
          content: Text(
            'You have ${strikes?.policyStrikes ?? 0} policy violations. '
            'Posting is restricted. Please contact support if you believe this is an error.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // Show moderation check dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    // Run content moderation check
    final moderationResult = await _moderationService.moderateMedia(
      media: widget.media,
      caption: _captionController.text.trim(),
      hashtags: _hashtags,
      isSponsored: _isSponsored,
    );

    if (mounted) {
      Navigator.of(context).pop(); // Close loading

      // Handle moderation result
      if (moderationResult.isBlocked) {
        // Add strike
        _moderationService.addStrike(userId, 'sexual_content');
        
        // Show block dialog
        showDialog(
          context: context,
          builder: (context) => ContentModerationDialog(
            result: moderationResult,
            onAppeal: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Appeal submitted. We will review your case.')),
              );
            },
          ),
        );
        return;
      }

      if (moderationResult.isRestricted || moderationResult.hasRestrictions) {
        // Show restriction warning but allow posting
        showDialog(
          context: context,
          builder: (context) => ContentModerationDialog(
            result: moderationResult,
            onDismiss: () {
              _proceedWithPosting(moderationResult);
            },
          ),
        );
        return;
      }

      // Content is safe, proceed with posting
      _proceedWithPosting(moderationResult);
    }
  }

  void _proceedWithPosting(ContentModerationResult moderationResult) async {
    // Show posting dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // 1. Upload media
      final filePath = widget.media.filePath;
      if (filePath == null) {
         throw Exception('File path is missing');
      }

      Map<String, dynamic> uploadRes;
      if (widget.media.type == MediaType.image) {
        final bytes = await File(filePath).readAsBytes();
        var jpg = await FlutterImageCompress.compressWithList(
          bytes,
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
        uploadRes = await UploadApi().uploadFileBytes(bytes: jpg, filename: 'post_${DateTime.now().millisecondsSinceEpoch}.jpg');
      } else {
        uploadRes = await UploadApi().uploadFile(filePath);
      }
      final fileName = uploadRes['fileName'] as String;
      final fileUrl = uploadRes['fileUrl'] as String?;

      // 2. Create post
      final mediaItem = {
        'fileName': fileName,
        if (fileUrl != null && fileUrl.isNotEmpty) 'fileUrl': fileUrl,
        'ratio': 1.0, // Default ratio
        'filter': widget.selectedFilter ?? 'none',
        'type': widget.media.type == MediaType.video ? 'video' : 'image',
        if (widget.trimStart != null)
          'trimStartMs': widget.trimStart!.inMilliseconds,
        if (widget.trimEnd != null)
          'trimEndMs': widget.trimEnd!.inMilliseconds,
      };

      await PostsApi().createPost(
        media: [mediaItem],
        caption: _captionController.text.trim(),
        location: _location,
        tags: _hashtags,
        hideLikesCount: false,
        turnOffCommenting: !_commentsEnabled,
        type: widget.media.type == MediaType.video ? 'reel' : 'post',
      );

      if (mounted) {
        Navigator.of(context).pop(); // Close loading
        Navigator.of(context).popUntil((route) => route.isFirst); // Go back to home
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Post shared successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to post: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
      final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = <String>[
          if ((p.name ?? '').isNotEmpty) p.name!,
          if ((p.subLocality ?? '').isNotEmpty) p.subLocality!,
          if ((p.locality ?? '').isNotEmpty) p.locality!,
          if ((p.administrativeArea ?? '').isNotEmpty) p.administrativeArea!,
          if ((p.country ?? '').isNotEmpty) p.country!,
        ];
        setState(() {
          _location = parts.where((e) => e.trim().isNotEmpty).toList().join(', ');
        });
      } else {
        setState(() {
          _location = '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Post Details', style: TextStyle(color: Colors.black)),
        actions: [
          TextButton(
            onPressed: _handlePost,
            child: const Text(
              'Post',
              style: TextStyle(color: Colors.blue, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              height: 300,
              width: double.infinity,
              color: Colors.grey[300],
              child: widget.media.type == MediaType.video
                  ? const Icon(Icons.play_circle_outline, size: 80, color: Colors.grey)
                  : const Icon(Icons.image, size: 80, color: Colors.grey),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Caption',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _captionController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: 'Write a caption...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                  if (_suggestedCaption != null)
                    TextButton.icon(
                      icon: const Icon(Icons.auto_awesome, size: 16),
                      label: const Text('Use AI suggestion'),
                      onPressed: () {
                        _captionController.text = _suggestedCaption!;
                      },
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hashtags',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _hashtagController,
                          decoration: InputDecoration(
                            hintText: '#hashtag',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          onSubmitted: (_) => _addHashtag(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: _addHashtag,
                      ),
                    ],
                  ),
                  if (_suggestedHashtags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _suggestedHashtags.map((tag) {
                        return Chip(
                          label: Text('#$tag'),
                          onDeleted: () {
                            setState(() {
                              _hashtags.add('#$tag');
                            });
                          },
                          deleteIcon: const Icon(Icons.add, size: 16),
                        );
                      }).toList(),
                    ),
                  ],
                  if (_hashtags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _hashtags.map((tag) {
                        return Chip(
                          label: Text(tag),
                          onDeleted: () => _removeHashtag(tag),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('Tag Friends'),
              subtitle: Text(_taggedUsers.isEmpty ? 'No one tagged' : _taggedUsers.join(', ')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showTagFriendsDialog(),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Privacy'),
              subtitle: Text(_privacy.name.toUpperCase()),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showPrivacyDialog(),
            ),
            const Divider(),
            SwitchListTile(
              secondary: const Icon(Icons.comment_outlined),
              title: const Text('Enable Comments'),
              value: _commentsEnabled,
              onChanged: (value) {
                setState(() {
                  _commentsEnabled = value;
                });
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: const Text('Add Location'),
              subtitle: Text(_location ?? 'Fetching current location...'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showLocationDialog(),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showTagFriendsDialog() {
    final users = _createService.getUsersForTagging();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tag Friends'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final isTagged = _taggedUsers.contains(user);
              return CheckboxListTile(
                title: Text(user),
                value: isTagged,
                onChanged: (value) {
                  if (value == true) {
                    _tagUser(user);
                  } else {
                    _removeTaggedUser(user);
                  }
                  Navigator.pop(context);
                  setState(() {});
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy'),
        content: RadioGroup<PrivacyLevel>(
          groupValue: _privacy,
          onChanged: (value) {
            setState(() {
              _privacy = value!;
            });
            Navigator.pop(context);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<PrivacyLevel>(
                title: const Text('Public'),
                subtitle: const Text('Anyone can see this post'),
                value: PrivacyLevel.public,
              ),
              RadioListTile<PrivacyLevel>(
                title: const Text('Followers'),
                subtitle: const Text('Only your followers can see this'),
                value: PrivacyLevel.followers,
              ),
              RadioListTile<PrivacyLevel>(
                title: const Text('Private'),
                subtitle: const Text('Only you can see this'),
                value: PrivacyLevel.private,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLocationDialog() {
    _fetchCurrentLocation();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.my_location),
              title: const Text('Use current location'),
              subtitle: Text(_location ?? 'Detecting...'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search location...',
                prefixIcon: Icon(Icons.search),
              ),
              onSubmitted: (value) {
                setState(() {
                  _location = value;
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _location = null;
              });
              Navigator.pop(context);
            },
            child: const Text('Remove'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
