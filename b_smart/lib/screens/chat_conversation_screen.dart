import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:just_audio/just_audio.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../api/chat_api.dart';
import '../api/api_client.dart';
import '../api/users_api.dart';
import '../theme/design_tokens.dart';
import '../utils/current_user.dart';
import '../utils/url_helper.dart';
import '../widgets/safe_network_image.dart';
import '../widgets/voice_recorder_sheet.dart';

class ChatConversationScreen extends StatefulWidget {
  final String conversationId;
  final Map<String, dynamic>? initialConversation;

  const ChatConversationScreen({
    super.key,
    required this.conversationId,
    this.initialConversation,
  });

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen>
    with WidgetsBindingObserver {
  final _chatApi = ChatApi();
  final _usersApi = UsersApi();
  final _scrollController = ScrollController();
  final _inputController = TextEditingController();
  final _inputFocusNode = FocusNode();
  final _picker = ImagePicker();

  static const bool _showCallButtons = false;

  String? _currentUserId;
  Map<String, dynamic>? _conversation;
  Map<String, dynamic>? _otherProfile;
  List<Map<String, dynamic>> _messages = const [];
  bool _loading = true;
  bool _sending = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;
  Map<String, dynamic>? _replyToMessage;
  bool _unsending = false;
  bool _uploadingMedia = false;
  Timer? _pollTimer;
  bool _refreshingLatest = false;
  int _pendingNewCount = 0;

  static const int _pageLimit = 20;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _conversation = widget.initialConversation;
    _init();
    _scrollController.addListener(_handleScroll);
    _inputController.addListener(_handleComposerChanged);
    _startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
    _inputController.removeListener(_handleComposerChanged);
    _scrollController.dispose();
    _inputController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      unawaited(_refreshLatest());
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _stopPolling();
    }
  }

  void _handleComposerChanged() {
    if (!mounted) return;
    // Only used to refresh send-button state. Kept intentionally lightweight.
    setState(() {});
  }

  bool _shallowMapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key)) return false;
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      unawaited(_refreshLatest());
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _init() async {
    final uid = await CurrentUser.id;
    if (!mounted) return;
    setState(() => _currentUserId = uid);
    await _load(page: 1, replace: true);
  }

  Map<String, dynamic>? _otherParticipant() {
    final uid = _currentUserId;
    final participants = _conversation?['participants'];
    if (participants is! List || participants.isEmpty) return null;
    if (uid == null || uid.isEmpty) {
      final p0 = participants.first;
      return p0 is Map ? Map<String, dynamic>.from(p0) : null;
    }
    for (final p in participants) {
      if (p is! Map) continue;
      final id = (p['_id'] ?? p['id'] ?? p['user_id'])?.toString();
      if (id != null && id.isNotEmpty && id != uid) {
        return Map<String, dynamic>.from(p);
      }
    }
    final p0 = participants.first;
    return p0 is Map ? Map<String, dynamic>.from(p0) : null;
  }

  String _nameFor(Map<String, dynamic>? user) {
    if (user == null) return 'Messages';
    return (user['full_name'] ?? user['name'] ?? user['username'] ?? 'User')
        .toString();
  }

  String? _avatarFor(Map<String, dynamic>? user) {
    if (user == null) return null;
    return (user['avatar_url'] ??
            user['avatarUrl'] ??
            user['profile_pic'] ??
            user['profilePic'])
        ?.toString();
  }

  String? _idFor(Map<String, dynamic>? user) {
    if (user == null) return null;
    return (user['_id'] ?? user['id'] ?? user['user_id'])?.toString();
  }

  Future<void> _loadOtherProfileIfNeeded() async {
    if (_otherProfile != null) return;
    final other = _otherParticipant();
    final otherId = _idFor(other);
    if (otherId == null || otherId.isEmpty) return;
    try {
      final res = await _usersApi.getUserProfile(otherId);
      final user = res['user'];
      if (!mounted) return;
      if (user is Map) {
        setState(() => _otherProfile = Map<String, dynamic>.from(user));
      } else {
        setState(() => _otherProfile = Map<String, dynamic>.from(res));
      }
    } catch (_) {
      // ignore; show UI without counts
    }
  }

  Future<void> _load({required int page, required bool replace}) async {
    setState(() {
      _error = null;
      if (replace) _loading = true;
      if (!replace) _loadingMore = true;
    });
    try {
      final res = await _chatApi.getMessages(
        conversationId: widget.conversationId,
        page: page,
        limit: _pageLimit,
      );

      final raw = res['messages'];
      final hasMore = res['hasMore'] == true;

      final items = (raw is List ? raw : const <dynamic>[])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      if (!mounted) return;
      setState(() {
        _messages = replace
            ? items.reversed.toList()
            : [...items.reversed, ..._messages];
        _page = page;
        _hasMore = hasMore;
        _loading = false;
        _loadingMore = false;
      });

      // Auto-mark latest message as seen (best-effort, matches web).
      unawaited(_markLatestSeen());
      unawaited(_loadOtherProfileIfNeeded());

      if (replace) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_scrollController.hasClients) {
            _scrollController
                .jumpTo(_scrollController.position.maxScrollExtent);
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    if (_loading || _loadingMore || !_hasMore) return;
    if (_scrollController.position.pixels <= 80) {
      unawaited(_load(page: _page + 1, replace: false));
    }
    if (_pendingNewCount > 0 && _isNearBottom()) {
      setState(() => _pendingNewCount = 0);
    }
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    final pos = _scrollController.position;
    final remaining = pos.maxScrollExtent - pos.pixels;
    return remaining <= 140;
  }

  bool _hasSeen(Map<String, dynamic> message, String uid) {
    final seenBy = message['seenBy'];
    if (seenBy is! List) return false;
    return seenBy.any((entry) {
      if (entry is Map) {
        final id =
            (entry['_id'] ?? entry['id'] ?? entry['user_id'])?.toString();
        return id == uid;
      }
      return entry?.toString() == uid;
    });
  }

  Future<void> _markLatestSeen() async {
    final uid = _currentUserId;
    if (uid == null || uid.isEmpty) return;
    final latest = _messages.reversed.cast<Map<String, dynamic>?>().firstWhere(
      (m) {
        if (m == null) return false;
        if (m['isDeleted'] == true) return false;
        final sender = m['sender'];
        final senderId = (sender is Map
                ? (sender['_id'] ?? sender['id'] ?? sender['user_id'])
                : sender)
            ?.toString();
        if (senderId == null || senderId.isEmpty) return false;
        if (senderId == uid) return false;
        return !_hasSeen(m, uid);
      },
      orElse: () => null,
    );
    if (latest == null) return;
    final messageId = (latest['_id'] ?? latest['id'])?.toString();
    if (messageId == null || messageId.isEmpty) return;
    try {
      final updated = await _chatApi.markMessageSeen(messageId: messageId);
      if (!mounted) return;
      setState(() {
        _messages = _messages
            .map((m) =>
                (m['_id']?.toString() == messageId) ? {...m, ...updated} : m)
            .toList();
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _send() async {
    if (_sending) return;
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      final replyId = (_replyToMessage?['_id'] ?? _replyToMessage?['id'])
          ?.toString()
          .trim();
      final created = await _chatApi.sendMessage(
        conversationId: widget.conversationId,
        payload: {
          'text': text,
          'mediaUrl': '',
          'mediaType': 'none',
          'replyTo': (replyId != null && replyId.isNotEmpty) ? replyId : null,
        },
      );
      final msg = Map<String, dynamic>.from(created);
      if (!mounted) return;
      setState(() {
        _messages = [..._messages, msg];
        _inputController.clear();
        _replyToMessage = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scrollToBottom();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _refreshLatest() async {
    if (_refreshingLatest) return;
    if (_loading || _loadingMore) return;
    final convId = widget.conversationId.trim();
    if (convId.isEmpty) return;
    _refreshingLatest = true;
    final wasNearBottom = _isNearBottom();
    try {
      final res = await _chatApi.getMessages(
        conversationId: convId,
        page: 1,
        limit: _pageLimit,
      );
      final raw = res['messages'];
      final items = (raw is List ? raw : const <dynamic>[])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final latestChrono = items.reversed.toList();
      if (!mounted) return;

      final existingById = <String, int>{};
      for (var i = 0; i < _messages.length; i++) {
        existingById[_messageId(_messages[i])] = i;
      }

      var appended = 0;
      var changed = false;
      var next = List<Map<String, dynamic>>.from(_messages);
      for (final m in latestChrono) {
        final id = _messageId(m);
        if (id.isEmpty) continue;
        final existingIndex = existingById[id];
        if (existingIndex == null) {
          next.add(m);
          appended++;
          changed = true;
        } else {
          final current = next[existingIndex];
          final merged = {...current, ...m};
          if (!_shallowMapEquals(current, merged)) {
            next[existingIndex] = merged;
            changed = true;
          }
        }
      }

      if (changed) {
        setState(() {
          _messages = next;
          if (!wasNearBottom) _pendingNewCount += appended;
        });
        if (wasNearBottom) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _scrollToBottom();
          });
        }
      }

      // Best-effort.
      unawaited(_markLatestSeen());
      unawaited(_loadOtherProfileIfNeeded());
    } catch (_) {
      // ignore (polling is best-effort)
    } finally {
      _refreshingLatest = false;
    }
  }

  Future<void> _sendVoiceMessage(Uint8List bytes, int durationSeconds) async {
    final conv = _conversation;
    final convId = (conv?['_id'] ?? conv?['id'] ?? widget.conversationId)
        ?.toString()
        .trim();
    if (convId == null || convId.isEmpty) return;
    try {
      final replyId = (_replyToMessage?['_id'] ?? _replyToMessage?['id'])
          ?.toString()
          .trim();
      final result = await ChatApi().uploadVoiceMessage(
        conversationId: convId,
        audioBytes: bytes,
        durationSeconds: durationSeconds,
        replyTo: (replyId != null && replyId.isNotEmpty) ? replyId : null,
      );
      final msgRaw = result['message'] ?? result['data'] ?? result;
      if (msgRaw is Map) {
        final msg = Map<String, dynamic>.from(msgRaw);
        if (mounted) {
          setState(() {
            _messages = [..._messages, msg];
            _replyToMessage = null;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceAll('Exception: ', '').isNotEmpty
                  ? e.toString().replaceAll('Exception: ', '')
                  : 'Failed to send voice message. Please try again.',
            ),
          ),
        );
      }
    }
  }

  String _extractUploadedMediaUrl(Map<String, dynamic> payload) {
    String pick(dynamic v) => UrlHelper.normalizeUrl((v ?? '').toString().trim());
    final url = pick(payload['mediaUrl'] ??
        payload['media_url'] ??
        payload['url'] ??
        payload['fileUrl'] ??
        payload['file_url']);
    return url;
  }

  String _extractUploadedMediaType(Map<String, dynamic> payload) {
    final t = (payload['mediaType'] ??
            payload['media_type'] ??
            payload['type'] ??
            payload['kind'])
        ?.toString()
        .trim();
    if (t == null || t.isEmpty) return 'image';
    return t;
  }

  String _mediaUrlFor(Map<String, dynamic> message) {
    final raw =
        (message['mediaUrl'] ?? message['media_url'] ?? '').toString().trim();
    return UrlHelper.normalizeUrl(raw);
  }

  String _senderIdForMessage(Map<String, dynamic> message) {
    final sender = message['sender'];
    final senderId = (sender is Map
            ? (sender['_id'] ?? sender['id'] ?? sender['user_id'])
            : sender)
        ?.toString();
    return (senderId ?? '').trim();
  }

  int _createdAtMillis(Map<String, dynamic> message) {
    final raw = (message['createdAt'] ?? message['created_at'] ?? '')
        .toString()
        .trim();
    if (raw.isEmpty) return 0;
    return DateTime.tryParse(raw)?.millisecondsSinceEpoch ?? 0;
  }

  bool _isImageOnlyMessage(Map<String, dynamic> message) {
    if (message['isDeleted'] == true) return false;
    final mediaType = (message['mediaType'] ?? message['media_type'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (mediaType == 'audio') return false;
    final url = _mediaUrlFor(message);
    if (url.isEmpty) return false;
    final text = (message['text'] ?? '').toString().trim();
    if (text.isNotEmpty) return false;
    final reply = message['replyTo'] ??
        message['reply_to'] ??
        message['reply'] ??
        message['replyMessage'];
    if (reply != null && reply.toString().trim().isNotEmpty) return false;
    return true;
  }

  bool _shouldGroupWith(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (!_isImageOnlyMessage(a) || !_isImageOnlyMessage(b)) return false;
    final sidA = _senderIdForMessage(a);
    final sidB = _senderIdForMessage(b);
    if (sidA.isEmpty || sidB.isEmpty || sidA != sidB) return false;
    final tA = _createdAtMillis(a);
    final tB = _createdAtMillis(b);
    if (tA == 0 || tB == 0) return true;
    return (tB - tA).abs() <= const Duration(minutes: 2).inMilliseconds;
  }

  Widget _chatImageFrame({
    required String url,
    required double maxWidth,
    double? fixedHeight,
  }) {
    if (fixedHeight != null) {
      // Used inside carousels: enforce a consistent viewport.
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: maxWidth,
          height: fixedHeight,
          child: SafeNetworkImage(
            url: url,
            width: maxWidth,
            height: fixedHeight,
            fit: BoxFit.cover,
            assumeRaster: true,
          ),
        ),
      );
    }

    // Standalone image messages: preserve original aspect ratio with no
    // letterboxing/background frame (like Instagram DMs).
    return _AspectPreservingChatImage(
      url: url,
      maxWidth: maxWidth,
      maxHeight: 420,
    );
  }

  Widget _albumBubble({
    required Map<String, dynamic> message,
    required bool mine,
    required Map<String, dynamic>? senderMap,
    required List<String> urls,
  }) {
    final w = MediaQuery.sizeOf(context).width;
    final maxBubbleWidth = min(420.0, w * 0.78);
    final frameHeight = min(360.0, maxBubbleWidth * 1.05);

    Widget reactionPill() {
      if (message['isDeleted'] == true) return const SizedBox.shrink();
      final reactionsRaw = message['reactions'];
      final reactions = (reactionsRaw is List ? reactionsRaw : const <dynamic>[])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (reactions.isEmpty) return const SizedBox.shrink();

      final cs = Theme.of(context).colorScheme;
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final uid = _currentUserId ?? '';
      final own = uid.isEmpty ? null : _ownReactionFor(message, uid);
      final primaryEmoji =
          (own?['emoji']?.toString().trim().isNotEmpty == true)
              ? own!['emoji'].toString().trim()
              : (reactions.first['emoji']?.toString().trim() ?? '');
      final count = reactions.length;
      final label = count > 1 ? '$primaryEmoji $count' : primaryEmoji;

      return Container(
        margin: const EdgeInsets.only(top: 3),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0B0B0B) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: cs.onSurface.withValues(alpha: 0.10)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.08),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 14, height: 1.0),
        ),
      );
    }

    final carousel = _ChatImageCarousel(
      urls: urls,
      width: maxBubbleWidth,
      height: frameHeight,
      buildFrame: (url) => _chatImageFrame(
        url: url,
        maxWidth: maxBubbleWidth,
        fixedHeight: frameHeight,
      ),
    );

    final bubble = GestureDetector(
      onDoubleTap: () => _reactToMessage(message, '❤️'),
      onLongPress: () => _showMessageActions(context, message, mine: mine),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(maxWidth: maxBubbleWidth),
        child: carousel,
      ),
    );

    final wrapped = _SwipeToReply(
      onReply: () => _setReplyTo(message),
      child: bubble,
    );

    if (mine) {
      return Align(
        alignment: Alignment.centerRight,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            wrapped,
            reactionPill(),
          ],
        ),
      );
    }

    final otherAvatarUrl = _avatarUrlFromUser(senderMap);
    final otherLabel = _labelFromUser(senderMap);
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _messageAvatar(
              label: otherLabel,
              size: 22,
              avatarUrl: otherAvatarUrl,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                wrapped,
                reactionPill(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndSendImages({required bool fromCamera}) async {
    if (_uploadingMedia) return;
    final convId = widget.conversationId.trim();
    if (convId.isEmpty) return;

    setState(() => _uploadingMedia = true);
    try {
      final List<XFile> picked;
      if (fromCamera) {
        final one = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 88,
        );
        picked = one == null ? const [] : [one];
      } else {
        picked = await _picker.pickMultiImage(imageQuality: 88);
      }

      if (picked.isEmpty) return;

      final files = <MultipartBytesFile>[];
      for (final f in picked) {
        final bytes = await f.readAsBytes();
        if (bytes.isEmpty) continue;
        final name = (f.name).trim().isNotEmpty ? f.name : 'image.jpg';
        files.add(MultipartBytesFile(bytes: bytes, filename: name));
      }
      if (files.isEmpty) return;

      final uploaded = await _chatApi.uploadChatMediaManyBytes(
        conversationId: convId,
        files: files,
      );

      final uploadedMedia = <Map<String, dynamic>>[];
      final mediaAny = uploaded['media'];
      if (mediaAny is List) {
        for (final item in mediaAny) {
          if (item is Map) uploadedMedia.add(Map<String, dynamic>.from(item));
        }
      } else {
        // Some backends respond with a single {mediaUrl, mediaType}.
        uploadedMedia.add(uploaded);
      }

      final replyId = (_replyToMessage?['_id'] ?? _replyToMessage?['id'])
          ?.toString()
          .trim();

      final toSend = <Map<String, dynamic>>[];
      for (final item in uploadedMedia) {
        final url = _extractUploadedMediaUrl(item);
        if (url.isEmpty) continue;
        toSend.add(item);
      }
      if (toSend.isEmpty) return;

      final createdMessages = await Future.wait(
        toSend.map((item) async {
          final url = _extractUploadedMediaUrl(item);
          final type = _extractUploadedMediaType(item);
          final created = await _chatApi.sendMessage(
            conversationId: convId,
            payload: {
              'text': '',
              'mediaUrl': url,
              'mediaType': type,
              'replyTo': (replyId != null && replyId.isNotEmpty)
                  ? replyId
                  : null,
            },
          );
          return Map<String, dynamic>.from(created);
        }).toList(),
      );

      if (!mounted) return;
      setState(() => _messages = [..._messages, ...createdMessages]);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

      if (mounted) setState(() => _replyToMessage = null);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _uploadingMedia = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final other = _otherParticipant();
    final otherName =
        (_otherProfile?['username'] as String?)?.trim().isNotEmpty == true
            ? (_otherProfile?['username'] as String).trim()
            : _nameFor(other);
    final otherAvatar = _avatarFor(_otherProfile ?? other);
    final otherId = _idFor(_otherProfile ?? other) ?? '';

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            if (otherAvatar != null && otherAvatar.trim().isNotEmpty)
              ClipOval(
                child: SafeNetworkImage(
                  url: otherAvatar,
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                ),
              )
            else
              CircleAvatar(
                radius: 16,
                backgroundColor: DesignTokens.instaPink,
                child: Text(
                  otherName.isNotEmpty
                      ? otherName.characters.first.toUpperCase()
                      : 'U',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    otherName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_showCallButtons)
            IconButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Calling coming soon')),
                );
              },
              icon: const Icon(LucideIcons.phone),
            ),
          if (_showCallButtons)
            IconButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Video call coming soon')),
                );
              },
              icon: const Icon(LucideIcons.video),
            ),
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Coming soon')),
              );
            },
            icon: const Icon(LucideIcons.info),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: DesignTokens.instaPink),
                  )
                : RefreshIndicator(
                    onRefresh: () => _load(page: 1, replace: true),
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      itemCount: _messages.length + 1 + (_loadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_loadingMore && index == 0) {
                          return const Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          );
                        }
                        final base = _loadingMore ? index - 1 : index;
                        if (base == 0) {
                          return _conversationHeader(
                            userId: otherId,
                            username: otherName,
                            avatarUrl: otherAvatar ?? '',
                          );
                        }
                        final i = base - 1;
                        final message = _messages[i];
                        final uid = _currentUserId ?? '';
                        final sender = message['sender'];
                        final senderId = (sender is Map
                                ? (sender['_id'] ??
                                    sender['id'] ??
                                    sender['user_id'])
                                : sender)
                            ?.toString();
                        final mine = senderId != null &&
                            senderId.isNotEmpty &&
                            senderId == uid;
                        final senderMap = sender is Map
                            ? Map<String, dynamic>.from(sender)
                            : null;

                        // Instagram-like grouping: if multiple images were sent
                        // together, they arrive as consecutive image-only
                        // messages. Render them as a single carousel bubble.
                        if (_isImageOnlyMessage(message) &&
                            i > 0 &&
                            _shouldGroupWith(_messages[i - 1], message)) {
                          return const SizedBox.shrink();
                        }

                        if (_isImageOnlyMessage(message)) {
                          final urls = <String>[_mediaUrlFor(message)];
                          var j = i + 1;
                          while (j < _messages.length &&
                              urls.length < 10 &&
                              _shouldGroupWith(message, _messages[j])) {
                            final u = _mediaUrlFor(_messages[j]);
                            if (u.isNotEmpty) urls.add(u);
                            j++;
                          }
                          if (urls.length > 1) {
                            return _albumBubble(
                              message: message,
                              mine: mine,
                              senderMap: senderMap,
                              urls: urls,
                            );
                          }
                        }

                        return _bubble(message, mine, senderMap: senderMap);
                      },
                    ),
                  ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          if (_pendingNewCount > 0)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Align(
                  alignment: Alignment.center,
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _pendingNewCount = 0);
                      _scrollToBottom();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.08),
                        ),
                      ),
                      child: Text(
                        '$_pendingNewCount new message${_pendingNewCount == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: _bottomComposer(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomComposer() {
    final cs = Theme.of(context).colorScheme;
    final muted = cs.onSurface.withValues(alpha: 0.70);
    final hint = cs.onSurface.withValues(alpha: 0.55);
    final bg = cs.onSurface.withValues(alpha: 0.08);
    final canSend = _inputController.text.trim().isNotEmpty;

    final reply = _replyToMessage;
    final replyText = _previewForMessage(reply);
    final replySender = _senderLabelForMessage(reply);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (reply != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFF5B5EF4),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          replySender,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          replyText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _replyToMessage = null),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: cs.onSurface.withValues(alpha: 0.06),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        LucideIcons.x,
                        size: 16,
                        color: cs.onSurface.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF3B82F6),
              ),
              child: IconButton(
                onPressed: _uploadingMedia ? null : () => _pickAndSendImages(fromCamera: true),
                icon: const Icon(
                  LucideIcons.camera,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        focusNode: _inputFocusNode,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        style: TextStyle(color: cs.onSurface),
                        cursorColor: cs.primary,
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: 'Message…',
                          hintStyle: TextStyle(color: hint),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          barrierColor: Colors.black54,
                          builder: (_) => Padding(
                            padding: EdgeInsets.only(
                              bottom: MediaQuery.of(context).viewInsets.bottom,
                            ),
                            child: VoiceRecorderSheet(
                              onSend: (bytes, duration) async {
                                Navigator.of(context).pop();
                                await _sendVoiceMessage(bytes, duration);
                              },
                              onCancel: () => Navigator.of(context).pop(),
                            ),
                          ),
                        );
                      },
                      icon: Icon(LucideIcons.mic, size: 20, color: muted),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 22, minHeight: 32),
                    ),
                    IconButton(
                      onPressed: _uploadingMedia
                          ? null
                          : () => _pickAndSendImages(fromCamera: false),
                      icon: _uploadingMedia
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: cs.primary,
                              ),
                            )
                          : Icon(LucideIcons.image, size: 20, color: muted),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 22, minHeight: 32),
                    ),
                    IconButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Comments coming soon')),
                        );
                      },
                      icon: Icon(LucideIcons.messageCircle,
                          size: 20, color: muted),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 22, minHeight: 32),
                    ),
                    IconButton(
                      onPressed: canSend
                          ? (_sending ? null : _send)
                          : () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('More options coming soon')),
                              );
                            },
                      icon: _sending && canSend
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: cs.primary,
                              ),
                            )
                          : Icon(
                              canSend ? Icons.send_rounded : LucideIcons.plus,
                              size: 22,
                              color: canSend ? cs.primary : muted,
                            ),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 22, minHeight: 32),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _messageId(Map<String, dynamic>? message) {
    return (message?['_id'] ?? message?['id'])?.toString() ?? '';
  }

  String _senderLabelForMessage(Map<String, dynamic>? message) {
    if (message == null) return 'Reply';
    final uid = _currentUserId ?? '';
    final sender = message['sender'];
    final senderId = (sender is Map
            ? (sender['_id'] ?? sender['id'] ?? sender['user_id'])
            : sender)
        ?.toString();
    final mine = senderId != null && senderId.isNotEmpty && senderId == uid;
    if (mine) return 'You';
    final senderMap = sender is Map ? Map<String, dynamic>.from(sender) : null;
    final name = (senderMap?['username'] ??
            senderMap?['full_name'] ??
            senderMap?['name'])
        ?.toString()
        .trim();
    return (name != null && name.isNotEmpty) ? name : 'User';
  }

  String _previewForMessage(Map<String, dynamic>? message) {
    if (message == null) return '';
    if (message['isDeleted'] == true) return 'Message unsent';
    final mediaType = message['mediaType']?.toString() ?? '';
    final text = message['text']?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
    if (mediaType == 'audio') return 'Voice message';
    final mediaUrl = (message['mediaUrl'] ?? '').toString().trim();
    if (mediaUrl.isNotEmpty) return 'Photo';
    return 'Message';
  }

  Future<void> _unsendMessage(Map<String, dynamic> message) async {
    if (_unsending) return;
    final id = _messageId(message).trim();
    if (id.isEmpty) return;
    setState(() => _unsending = true);
    try {
      await _chatApi.deleteMessage(messageId: id);
      if (!mounted) return;
      setState(() {
        _messages = _messages.map((m) {
          final mid = (m['_id'] ?? m['id'])?.toString() ?? '';
          if (mid != id) return m;
          return {
            ...m,
            'isDeleted': true,
            'text': '',
            'mediaUrl': '',
            'mediaType': m['mediaType'],
          };
        }).toList();
        if (_messageId(_replyToMessage) == id) {
          _replyToMessage = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _unsending = false);
    }
  }

  void _setReplyTo(Map<String, dynamic> message) {
    setState(() => _replyToMessage = message);
    _inputFocusNode.requestFocus();
  }

  Future<void> _copyMessageText(Map<String, dynamic> message) async {
    final text = message['text']?.toString().trim() ?? '';
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied')),
    );
  }

  void _reactToMessage(Map<String, dynamic> message, String emoji) {
    final id = _messageId(message).trim();
    if (id.isEmpty) return;
    final e = emoji.trim();
    if (e.isEmpty) return;
    final uid = _currentUserId ?? '';
    if (uid.isEmpty) return;

    final currentOwn = _ownReactionFor(message, uid);
    final shouldRemove = (currentOwn?['emoji']?.toString() ?? '') == e;

    // Optimistic update (will be reconciled by API/polling).
    setState(() {
      _messages = _messages.map((m) {
        if (_messageId(m) != id) return m;
        final nextReactions =
            _toggleReactionLocally(m, uid, shouldRemove ? null : e);
        return {...m, 'reactions': nextReactions};
      }).toList();
    });

    // Mirror React web app: POST /reaction, DELETE /reaction.
    unawaited(() async {
      try {
        final updated = shouldRemove
            ? await _chatApi.removeMessageReaction(messageId: id)
            : await _chatApi.addMessageReaction(messageId: id, emoji: e);
        if (!mounted) return;
        final mid = _messageId(updated).trim();
        if (mid.isEmpty) return;
        setState(() {
          _messages = _messages
              .map((m) => _messageId(m) == mid ? {...m, ...updated} : m)
              .toList();
        });
      } catch (_) {
        // ignore (polling will reconcile)
      }
    }());
  }

  Map<String, dynamic>? _ownReactionFor(Map<String, dynamic> message, String uid) {
    final reactions = message['reactions'];
    if (reactions is! List) return null;
    for (final r in reactions) {
      if (r is! Map) continue;
      final userId = r['userId'] ?? r['user_id'] ?? r['user'];
      final id = (userId is Map
              ? (userId['_id'] ?? userId['id'] ?? userId['user_id'])
              : userId)
          ?.toString();
      if (id != null && id.isNotEmpty && id == uid) {
        return Map<String, dynamic>.from(r);
      }
    }
    return null;
  }

  List<Map<String, dynamic>> _toggleReactionLocally(
    Map<String, dynamic> message,
    String uid,
    String? emoji,
  ) {
    final raw = message['reactions'];
    final list = (raw is List ? raw : const <dynamic>[])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    // Remove existing by this user.
    list.removeWhere((r) {
      final userId = r['userId'] ?? r['user_id'] ?? r['user'];
      final id = (userId is Map
              ? (userId['_id'] ?? userId['id'] ?? userId['user_id'])
              : userId)
          ?.toString();
      return id == uid;
    });

    if (emoji != null && emoji.trim().isNotEmpty) {
      list.add({'emoji': emoji.trim(), 'userId': uid});
    }
    return list;
  }

  void _showMessageActions(BuildContext context, Map<String, dynamic> message,
      {required bool mine}) {
    if (message['isDeleted'] == true) return;
    final text = message['text']?.toString().trim() ?? '';
    final hasCopy = text.isNotEmpty;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) {
        final cs = Theme.of(context).colorScheme;
        final sheetBg = Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF111111)
            : Colors.white;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: cs.onSurface.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        for (final e in ['❤️', '😂', '😮', '😢', '👍'])
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                Navigator.of(context).pop();
                                _reactToMessage(message, e);
                              },
                              borderRadius: BorderRadius.circular(999),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  e,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _actionRow(
                    icon: LucideIcons.reply,
                    label: 'Reply',
                    onTap: () {
                      Navigator.of(context).pop();
                      _setReplyTo(message);
                    },
                  ),
                  if (hasCopy)
                    _actionRow(
                      icon: LucideIcons.copy,
                      label: 'Copy',
                      onTap: () {
                        Navigator.of(context).pop();
                        unawaited(_copyMessageText(message));
                      },
                    ),
                  if (mine)
                    _actionRow(
                      icon: LucideIcons.trash2,
                      label: _unsending ? 'Unsending…' : 'Unsend',
                      destructive: true,
                      enabled: !_unsending,
                      onTap: () {
                        Navigator.of(context).pop();
                        unawaited(_unsendMessage(message));
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _actionRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool destructive = false,
    bool enabled = true,
  }) {
    final cs = Theme.of(context).colorScheme;
    final color = destructive ? const Color(0xFFEF4444) : cs.onSurface;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: enabled ? color : cs.onSurface.withValues(alpha: 0.35),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color:
                        enabled ? color : cs.onSurface.withValues(alpha: 0.35),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _avatarUrlFromUser(Map<String, dynamic>? user) {
    if (user == null) return null;
    return (user['avatar_url'] ??
            user['avatarUrl'] ??
            user['profile_pic'] ??
            user['profilePic'] ??
            user['avatar'])
        ?.toString();
  }

  String _labelFromUser(Map<String, dynamic>? user) {
    if (user == null) return 'U';
    final username =
        (user['username'] ?? user['name'] ?? user['full_name'])?.toString() ??
            '';
    final trimmed = username.trim();
    if (trimmed.isEmpty) return 'U';
    return trimmed.characters.first.toUpperCase();
  }

  Widget _messageAvatar({
    required String label,
    required double size,
    String? avatarUrl,
  }) {
    final cs = Theme.of(context).colorScheme;
    final subtle = cs.onSurface.withValues(alpha: 0.08);
    if (avatarUrl == null || avatarUrl.trim().isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: subtle,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: cs.onSurface,
            fontWeight: FontWeight.w800,
            fontSize: size * 0.45,
          ),
        ),
      );
    }

    return ClipOval(
      child: SafeNetworkImage(
        url: avatarUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: Container(width: size, height: size, color: subtle),
        errorWidget: Container(
          width: size,
          height: size,
          color: subtle,
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: cs.onSurface,
              fontWeight: FontWeight.w800,
              fontSize: size * 0.45,
            ),
          ),
        ),
      ),
    );
  }

  Widget _bubble(
    Map<String, dynamic> message,
    bool mine, {
    required Map<String, dynamic>? senderMap,
  }) {
    final isDeleted = message['isDeleted'] == true;
    final text = message['text']?.toString() ?? '';
    final mediaUrl = message['mediaUrl']?.toString() ?? '';
    final w = MediaQuery.sizeOf(context).width;
    final maxBubbleWidth = min(420.0, w * 0.78);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget wrapReply(Widget child) {
      return _SwipeToReply(
        onReply: () => _setReplyTo(message),
        child: child,
      );
    }

    Widget reactionPill() {
      if (isDeleted) return const SizedBox.shrink();
      final reactionsRaw = message['reactions'];
      final reactions = (reactionsRaw is List ? reactionsRaw : const <dynamic>[])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (reactions.isEmpty) return const SizedBox.shrink();

      final uid = _currentUserId ?? '';
      final own = uid.isEmpty ? null : _ownReactionFor(message, uid);
      final primaryEmoji =
          (own?['emoji']?.toString().trim().isNotEmpty == true)
              ? own!['emoji'].toString().trim()
              : (reactions.first['emoji']?.toString().trim() ?? '');
      final count = reactions.length;
      final label = count > 1 ? '$primaryEmoji $count' : primaryEmoji;
      return Container(
        margin: const EdgeInsets.only(top: 3),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0B0B0B) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: cs.onSurface.withValues(alpha: 0.10)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.08),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 14, height: 1.0),
        ),
      );
    }

    final mediaType = message['mediaType']?.toString() ?? '';
    if (!isDeleted && mediaType == 'audio') {
      final audioUrl = (message['mediaUrl'] ??
                  message['audioUrl'] ??
                  message['fileUrl'] ??
                  message['url'])
              ?.toString() ??
          '';
      final storedDuration =
          (message['audioDuration'] ?? message['duration'] ?? 0);
      final totalSecs = storedDuration is num
          ? storedDuration.toInt()
          : int.tryParse(storedDuration.toString()) ?? 0;

      final voice = _VoiceMessageBubble(
        audioUrl: UrlHelper.normalizeUrl(audioUrl),
        totalDuration: totalSecs,
        isMine: mine,
      );

      if (mine) {
        return wrapReply(
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onDoubleTap: () => _reactToMessage(message, '❤️'),
              onLongPress: () =>
                  _showMessageActions(context, message, mine: true),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  voice,
                  reactionPill(),
                ],
              ),
            ),
          ),
        );
      }

      final otherAvatarUrl = _avatarUrlFromUser(senderMap);
      final otherLabel = _labelFromUser(senderMap);
      return wrapReply(
        Align(
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _messageAvatar(
                  label: otherLabel,
                  size: 22,
                  avatarUrl: otherAvatarUrl,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: GestureDetector(
                  onDoubleTap: () => _reactToMessage(message, '❤️'),
                  onLongPress: () =>
                      _showMessageActions(context, message, mine: false),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      voice,
                      reactionPill(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final bg = mine
        ? const Color(0xFF7C3AED)
        : (isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6));
    final fg = mine ? Colors.white : cs.onSurface;
    final border =
        mine ? Colors.transparent : cs.onSurface.withValues(alpha: 0.06);

    final replied = _repliedMessageFor(message);
    final replySender = _senderLabelForMessage(replied);
    final replyPreview = _previewForMessage(replied);
    final hasMedia = mediaUrl.trim().isNotEmpty;
    final hasText = text.trim().isNotEmpty;

    final bubble = GestureDetector(
      onDoubleTap: () => _reactToMessage(message, '❤️'),
      onLongPress: () => _showMessageActions(context, message, mine: mine),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: hasMedia
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: BoxConstraints(maxWidth: maxBubbleWidth),
        decoration: BoxDecoration(
          color: hasMedia ? Colors.transparent : bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: hasMedia ? Colors.transparent : border),
          boxShadow: mine
              ? const []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: isDeleted
            ? Text(
                'Message unsent',
                style: TextStyle(
                  color: fg.withValues(alpha: 0.75),
                  fontStyle: FontStyle.italic,
                ),
              )
            : (hasMedia
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (replied != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black
                                  .withValues(alpha: mine ? 0.14 : 0.06),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 3,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: mine
                                        ? Colors.white.withValues(alpha: 0.75)
                                        : const Color(0xFF5B5EF4),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        replySender,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: fg.withValues(alpha: 0.9),
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        replyPreview,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: fg.withValues(alpha: 0.75),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      _chatImageFrame(
                        url: mediaUrl,
                        maxWidth: maxBubbleWidth,
                      ),
                      if (hasText)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          child: Text(
                            text,
                            style: TextStyle(
                              color: fg,
                              fontSize: 14,
                              height: 1.25,
                            ),
                          ),
                        ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (replied != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black
                                .withValues(alpha: mine ? 0.14 : 0.06),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 3,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: mine
                                      ? Colors.white.withValues(alpha: 0.75)
                                      : const Color(0xFF5B5EF4),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      replySender,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: fg.withValues(alpha: 0.9),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      replyPreview,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: fg.withValues(alpha: 0.75),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (hasText)
                        Text(
                          text,
                          style:
                              TextStyle(color: fg, fontSize: 14, height: 1.25),
                        ),
                    ],
                  )),
      ),
    );

    if (mine) {
      return wrapReply(
        Align(
          alignment: Alignment.centerRight,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              bubble,
              reactionPill(),
            ],
          ),
        ),
      );
    }

    final otherAvatarUrl = _avatarUrlFromUser(senderMap);
    final otherLabel = _labelFromUser(senderMap);
    return wrapReply(
      Align(
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _messageAvatar(
                label: otherLabel,
                size: 22,
                avatarUrl: otherAvatarUrl,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  bubble,
                  reactionPill(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic>? _repliedMessageFor(Map<String, dynamic> message) {
    final raw = message['replyTo'] ??
        message['reply_to'] ??
        message['reply'] ??
        message['replyMessage'];
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      if (map.isEmpty) return null;
      final id = (map['_id'] ?? map['id'])?.toString().trim();
      final hasId = id != null && id.isNotEmpty;
      final hasAnyContent = (map['text']?.toString().trim().isNotEmpty == true) ||
          (map['mediaUrl']?.toString().trim().isNotEmpty == true) ||
          (map['mediaType']?.toString().trim().isNotEmpty == true) ||
          (map['sender'] != null);
      if (!hasId && !hasAnyContent) return null;
      return map;
    }
    final id = raw?.toString().trim();
    if (id == null || id.isEmpty) return null;
    for (final m in _messages) {
      final mid = _messageId(m);
      if (mid == id) return m;
    }
    return null;
  }

  String _formatCount(num n) {
    final value = n.toDouble();
    if (value >= 1000000000) return '${(value / 1000000000).toStringAsFixed(1)}B';
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  Widget _conversationHeader({
    required String userId,
    required String username,
    required String avatarUrl,
  }) {
    final cs = Theme.of(context).colorScheme;
    final profile = _otherProfile;
    final rawName =
        (profile?['full_name'] ?? profile?['fullName'] ?? profile?['name'])
            ?.toString()
            .trim();
    final displayName =
        (rawName != null && rawName.isNotEmpty) ? rawName : username.trim();

    final rawHandle = (profile?['username'] ??
            profile?['userName'] ??
            profile?['handle'] ??
            username)
        .toString()
        .trim();
    final handle = rawHandle.isNotEmpty
        ? (rawHandle.startsWith('@') ? rawHandle : '@$rawHandle')
        : '';
    final followersRaw =
        (_otherProfile?['followers_count'] ?? _otherProfile?['followersCount']);
    final postsRaw = (_otherProfile?['posts_count'] ??
        _otherProfile?['postsCount'] ??
        _otherProfile?['posts']);
    final followers = followersRaw is num
        ? followersRaw
        : (followersRaw is String ? num.tryParse(followersRaw) : null);
    final posts = postsRaw is num
        ? postsRaw
        : (postsRaw is String ? num.tryParse(postsRaw) : null);
    final stats = (followers != null && posts != null)
        ? '${_formatCount(followers)} followers • ${_formatCount(posts)} posts'
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          const SizedBox(height: 4),
          ClipOval(
            child: SafeNetworkImage(
              url: avatarUrl,
              width: 96,
              height: 96,
              fit: BoxFit.cover,
              placeholder: Container(
                width: 96,
                height: 96,
                color: cs.onSurface.withValues(alpha: 0.08),
                alignment: Alignment.center,
                child: Text(
                  displayName.isNotEmpty
                      ? displayName.characters.first.toUpperCase()
                      : 'U',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w800,
                    fontSize: 28,
                  ),
                ),
              ),
              errorWidget: Container(
                width: 96,
                height: 96,
                color: cs.onSurface.withValues(alpha: 0.08),
                alignment: Alignment.center,
                child: Text(
                  displayName.isNotEmpty
                      ? displayName.characters.first.toUpperCase()
                      : 'U',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w800,
                    fontSize: 28,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            displayName,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (handle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              handle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.70),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (stats != null) ...[
            const SizedBox(height: 6),
            Text(
              stats,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.70),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: userId.isEmpty
                  ? null
                  : () => Navigator.of(context).pushNamed('/profile/$userId'),
              style: OutlinedButton.styleFrom(
                backgroundColor: cs.onSurface.withValues(alpha: 0.06),
                foregroundColor: cs.onSurface,
                side: const BorderSide(color: Colors.transparent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: const Text(
                'View profile',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwipeToReply extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;

  const _SwipeToReply({
    required this.child,
    required this.onReply,
  });

  @override
  State<_SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<_SwipeToReply>
    with SingleTickerProviderStateMixin {
  static const double _maxOffset = 72;
  static const double _triggerOffset = 56;

  late final AnimationController _controller;
  Animation<double>? _backAnim;
  double _dx = 0;
  bool _triggered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    )..addListener(() {
        final a = _backAnim;
        if (a == null) return;
        setState(() => _dx = a.value);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _animateBack() {
    _controller.stop();
    _backAnim = Tween<double>(begin: _dx, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward(from: 0);
  }

  void _handleUpdate(DragUpdateDetails d) {
    if (d.delta.dx <= 0) return;
    final next = (_dx + d.delta.dx).clamp(0.0, _maxOffset);
    if (!mounted) return;
    setState(() => _dx = next);
    if (!_triggered && next >= _triggerOffset) {
      _triggered = true;
      HapticFeedback.selectionClick();
      widget.onReply();
    }
  }

  void _handleEnd(DragEndDetails d) {
    _animateBack();
    _triggered = false;
  }

  @override
  Widget build(BuildContext context) {
    final opacity = (_dx / _maxOffset).clamp(0.0, 1.0);
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: _handleUpdate,
      onHorizontalDragEnd: _handleEnd,
      onHorizontalDragCancel: () {
        _animateBack();
        _triggered = false;
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: 34,
                  height: 34,
                  margin: const EdgeInsets.only(left: 6),
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    LucideIcons.reply,
                    size: 18,
                    color: cs.onSurface.withValues(alpha: 0.70),
                  ),
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(_dx, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

class _ChatImageCarousel extends StatefulWidget {
  final List<String> urls;
  final double width;
  final double height;
  final Widget Function(String url) buildFrame;

  const _ChatImageCarousel({
    required this.urls,
    required this.width,
    required this.height,
    required this.buildFrame,
  });

  @override
  State<_ChatImageCarousel> createState() => _ChatImageCarouselState();
}

class _ChatImageCarouselState extends State<_ChatImageCarousel> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final count = widget.urls.length;
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: PageView.builder(
              controller: _controller,
              itemCount: count,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => widget.buildFrame(widget.urls[i]),
            ),
          ),
          Positioned(
            right: 10,
            top: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${_index + 1}/$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          if (count > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(count, (i) {
                  final active = i == _index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: active
                          ? Colors.white
                          : cs.onSurface.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class _AspectPreservingChatImage extends StatefulWidget {
  final String url;
  final double maxWidth;
  final double maxHeight;

  const _AspectPreservingChatImage({
    required this.url,
    required this.maxWidth,
    required this.maxHeight,
  });

  @override
  State<_AspectPreservingChatImage> createState() =>
      _AspectPreservingChatImageState();
}

class _AspectPreservingChatImageState extends State<_AspectPreservingChatImage> {
  static final Map<String, double> _aspectCache = <String, double>{};

  ImageStream? _stream;
  ImageStreamListener? _listener;
  double? _aspect;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant _AspectPreservingChatImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _aspect = null;
      _removeListener();
      _resolve();
    }
  }

  @override
  void dispose() {
    _removeListener();
    super.dispose();
  }

  void _removeListener() {
    final s = _stream;
    final l = _listener;
    if (s != null && l != null) {
      s.removeListener(l);
    }
    _stream = null;
    _listener = null;
  }

  void _resolve() {
    final url = widget.url.trim();
    if (url.isEmpty) return;
    final cached = _aspectCache[url];
    if (cached != null && cached > 0) {
      setState(() => _aspect = cached);
      return;
    }

    final provider = CachedNetworkImageProvider(url);
    final stream = provider.resolve(ImageConfiguration.empty);
    _stream = stream;

    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        final w = info.image.width.toDouble();
        final h = info.image.height.toDouble();
        final a = (h <= 0) ? 1.0 : (w / h);
        _aspectCache[url] = a;
        if (!mounted) return;
        setState(() => _aspect = a);
        _removeListener();
      },
      onError: (_, __) {
        if (!mounted) return;
        setState(() => _aspect = 1.0);
        _removeListener();
      },
    );
    _listener = listener;
    stream.addListener(listener);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final a = (_aspect ?? 1.0).clamp(0.25, 4.0);

    var width = widget.maxWidth;
    var height = width / a;
    if (height > widget.maxHeight) {
      height = widget.maxHeight;
      width = height * a;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: width,
        height: height,
        child: SafeNetworkImage(
          url: widget.url,
          width: width,
          height: height,
          fit: BoxFit.cover,
          assumeRaster: true,
          placeholder: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: cs.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VoiceMessageBubble extends StatefulWidget {
  final String audioUrl;
  final int totalDuration;
  final bool isMine;

  const _VoiceMessageBubble({
    required this.audioUrl,
    required this.totalDuration,
    required this.isMine,
  });

  @override
  State<_VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<_VoiceMessageBubble> {
  static const List<double> waveformHeights = [
    8,
    11,
    16,
    12,
    18,
    10,
    20,
    14,
    9,
    17,
    12,
    15,
    19,
    11,
    13,
    18,
    10,
    16,
    12,
    20,
  ];

  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _playerStateSub;
  Timer? _playbackTimer;
  bool _isPlaying = false;
  int _currentSeconds = 0;
  late int _resolvedDuration;

  @override
  void initState() {
    super.initState();
    _resolvedDuration = widget.totalDuration;
    _playerStateSub = _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _playbackTimer?.cancel();
        _player.seek(Duration.zero);
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _currentSeconds = 0;
          });
        }
      }
    });
    unawaited(_init());
  }

  Future<void> _init() async {
    final url = widget.audioUrl.trim();
    if (url.isEmpty) return;
    try {
      await _player.setUrl(url);
      final d = _player.duration;
      if (d != null && d.inSeconds > 0 && mounted) {
        setState(() => _resolvedDuration = d.inSeconds);
      }
    } catch (_) {
      // ignore
    }
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    _playerStateSub?.cancel();
    unawaited(_player.dispose());
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _startPlaybackTimer() {
    _playbackTimer?.cancel();
    _playbackTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      setState(() => _currentSeconds = _player.position.inSeconds);
    });
  }

  Future<void> _togglePlayPause() async {
    if (widget.audioUrl.trim().isEmpty) return;
    if (_isPlaying) {
      await _player.pause();
      _playbackTimer?.cancel();
      if (mounted) setState(() => _isPlaying = false);
      return;
    }

    final dur = max(1, _resolvedDuration);
    if (_currentSeconds >= dur) {
      await _player.seek(Duration.zero);
      if (mounted) setState(() => _currentSeconds = 0);
    }

    await _player.play();
    _startPlaybackTimer();
    if (mounted) setState(() => _isPlaying = true);
  }

  Future<void> _seekToFraction(double fraction) async {
    final dur = max(1, _resolvedDuration);
    final target = (fraction.clamp(0.0, 1.0) * dur).round();
    await _player.seek(Duration(seconds: target));
    if (mounted) setState(() => _currentSeconds = target);
  }

  @override
  Widget build(BuildContext context) {
    final bg =
        widget.isMine ? const Color(0xFF5B5EF4) : const Color(0xFF202020);
    final progress =
        (_currentSeconds / max(1, _resolvedDuration)).clamp(0.0, 1.0);
    final activeBars = (progress * waveformHeights.length).floor();

    final timeLabel = _isPlaying
        ? _formatDuration(_currentSeconds)
        : _formatDuration(_resolvedDuration);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 220, maxWidth: 280),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    _isPlaying ? LucideIcons.pause : LucideIcons.play,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    return GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTapDown: (d) {
                        if (w <= 0) return;
                        unawaited(_seekToFraction(d.localPosition.dx / w));
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: 22,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children:
                                  List.generate(waveformHeights.length, (i) {
                                final active = i <= activeBars;
                                return Container(
                                  width: 3,
                                  height: waveformHeights[i],
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 1.3),
                                  decoration: BoxDecoration(
                                    color: active
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.30),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                );
                              }),
                            ),
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: Stack(
                              children: [
                                Container(
                                  height: 2,
                                  color:
                                      Colors.white.withValues(alpha: 0.22),
                                ),
                                FractionallySizedBox(
                                  widthFactor: progress,
                                  child: Container(
                                    height: 2,
                                    color:
                                        Colors.white.withValues(alpha: 0.85),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Text(
                timeLabel,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
