import 'dart:async';
import 'dart:developer' as developer;
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
import '../services/chat_socket_service.dart';
import '../theme/design_tokens.dart';
import '../utils/current_user.dart';
import '../utils/url_helper.dart';
import '../services/ads_service.dart';
import '../widgets/safe_network_image.dart';
import '../widgets/post_detail_modal.dart';
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
  final ChatSocketService _chatSocket = ChatSocketService();
  final _scrollController = ScrollController();
  final _inputController = TextEditingController();
  final _inputFocusNode = FocusNode();
  final _picker = ImagePicker();
  final _adsService = AdsService();

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
  bool _requestActionLoading = false;
  Timer? _presenceTimer;
  bool _otherOnline = false;
  bool _refreshingPresence = false;
  Timer? _scrollPinTimer;
  int _scrollPinAttempts = 0;
  SocketHandler? _onSocketNewMessage;
  SocketHandler? _onSocketMessageRemoved;
  SocketHandler? _onSocketReactionUpdate;

  final Map<String, double> _sharedPreviewAspectRatios = <String, double>{};
  final Set<String> _resolvingSharedPreviewAspectRatioUrls = <String>{};
  final Map<String, String> _sharedAdPreviewById = <String, String>{};
  final Set<String> _loadingSharedAdIds = <String>{};

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
    _startPresencePolling();
  }

  @override
  void dispose() {
    final convId = _effectiveConversationId();
    if (convId.isNotEmpty) {
      _chatSocket.leaveRoom(convId);
    }
    if (_onSocketNewMessage != null) {
      _chatSocket.off('new-message', _onSocketNewMessage!);
    }
    if (_onSocketMessageRemoved != null) {
      _chatSocket.off('message-removed', _onSocketMessageRemoved!);
    }
    if (_onSocketReactionUpdate != null) {
      _chatSocket.off('message-reaction-update', _onSocketReactionUpdate!);
    }
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
    _stopPresencePolling();
    _scrollPinTimer?.cancel();
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
      _startPresencePolling();
      unawaited(_refreshLatest());
      unawaited(_refreshOtherOnlineStatus());
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _stopPolling();
      _stopPresencePolling();
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

  void _startPresencePolling() {
    _presenceTimer?.cancel();
    _presenceTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      unawaited(_refreshOtherOnlineStatus());
    });
  }

  void _stopPresencePolling() {
    _presenceTimer?.cancel();
    _presenceTimer = null;
  }

  String _otherParticipantId() {
    final other = _otherProfile ?? _otherParticipant();
    return (_idFor(other) ?? '').trim();
  }

  Future<void> _refreshOtherOnlineStatus() async {
    if (_refreshingPresence) return;
    final otherId = _otherParticipantId();
    if (otherId.isEmpty) return;
    _refreshingPresence = true;
    try {
      final online = await _chatApi.getOnlineUsers(ids: [otherId]);
      if (!mounted) return;
      final next = online.contains(otherId);
      if (next != _otherOnline) setState(() => _otherOnline = next);
    } catch (_) {
      // Best-effort: ignore errors.
    } finally {
      _refreshingPresence = false;
    }
  }

  Future<void> _init() async {
    final uid = await CurrentUser.id;
    if (!mounted) return;
    setState(() => _currentUserId = uid);
    await _initSocket();
    await _load(page: 1, replace: true);
    unawaited(_refreshOtherOnlineStatus());
  }

  Future<void> _initSocket() async {
    final token = await ApiClient().getToken();
    if (token == null || token.trim().isEmpty) return;
    final uid = (_currentUserId ?? '').trim();
    _chatSocket.connect(token: token, userId: uid.isEmpty ? null : uid);

    // If socket comes up, stop REST polling (socket is primary; polling is fallback).
    if (_chatSocket.isConnected) {
      _stopPolling();
    } else {
      Timer(const Duration(seconds: 2), () {
        if (!mounted) return;
        if (_chatSocket.isConnected) _stopPolling();
      });
    }

    final convId = _effectiveConversationId();
    if (convId.isNotEmpty) {
      _chatSocket.joinRoom(convId);
    }

    _onSocketNewMessage ??= (data) {
      String? conversationId;
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        conversationId = (map['conversationId'] ??
                map['conversation_id'] ??
                (map['conversation'] is Map
                    ? (map['conversation']['_id'] ?? map['conversation']['id'])
                    : null))
            ?.toString();
      }
      final normalized = conversationId?.trim() ?? '';
      if (normalized.isEmpty) return;
      if (normalized != _effectiveConversationId()) return;
      unawaited(_refreshLatest());
    };
    _chatSocket.on('new-message', _onSocketNewMessage!);

    _onSocketMessageRemoved ??= (data) {
      if (data is! Map) return;
      final map = Map<String, dynamic>.from(data);
      final conversationId =
          (map['conversationId'] ?? map['conversation_id'])?.toString().trim();
      if (conversationId == null || conversationId.isEmpty) return;
      if (conversationId != _effectiveConversationId()) return;
      final messageId =
          (map['messageId'] ?? map['message_id'] ?? map['_id'] ?? map['id'])
              ?.toString()
              .trim();
      if (messageId == null || messageId.isEmpty) return;
      if (!mounted) return;
      setState(() {
        _messages = _messages.where((m) => _messageId(m) != messageId).toList();
      });
    };
    _chatSocket.on('message-removed', _onSocketMessageRemoved!);

    _onSocketReactionUpdate ??= (data) {
      if (data is! Map) return;
      final map = Map<String, dynamic>.from(data);
      final conversationId =
          (map['conversationId'] ?? map['conversation_id'])?.toString().trim();
      if (conversationId == null || conversationId.isEmpty) return;
      if (conversationId != _effectiveConversationId()) return;
      // Simplest robust behavior: refresh latest to pick up server truth.
      unawaited(_refreshLatest());
    };
    _chatSocket.on('message-reaction-update', _onSocketReactionUpdate!);
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

  bool _isRequestConversation(Map<String, dynamic>? conversation) {
    if (conversation == null || conversation.isEmpty) return false;
    final status = (conversation['requestStatus'] ??
            conversation['request_status'] ??
            conversation['requestState'] ??
            conversation['request_state'])
        ?.toString()
        .trim()
        .toLowerCase();
    if (status == 'pending' || status == 'requested') return true;

    final type = conversation['type']?.toString().toLowerCase();
    final folder = conversation['folder']?.toString().toLowerCase();
    final category = conversation['category']?.toString().toLowerCase();
    final isRequest = conversation['isRequest'] == true ||
        conversation['is_request'] == true ||
        conversation['request'] == true ||
        type == 'request' ||
        folder == 'requests' ||
        category == 'requests';
    if (isRequest) return true;
    final approved = conversation['isApproved'];
    if (approved is bool && approved == false) return true;
    return false;
  }

  String _effectiveConversationId() {
    final fromState = (_conversation?['_id'] ??
            _conversation?['id'] ??
            _conversation?['conversationId'] ??
            _conversation?['conversation_id'])
        ?.toString()
        .trim();
    if (fromState != null && fromState.isNotEmpty) return fromState;
    return widget.conversationId.trim();
  }

  Future<void> _acceptRequest() async {
    if (_requestActionLoading) return;
    final convId = _effectiveConversationId();
    if (convId.isEmpty) return;
    developer.log(
      '[acceptRequest] widget.conversationId="${widget.conversationId}" effectiveId="$convId" conversationKeys=${_conversation?.keys.toList()}',
      name: 'ChatConversationScreen',
    );
    setState(() => _requestActionLoading = true);
    try {
      final res =
          await _chatApi.acceptConversationRequest(conversationId: convId);
      if (!mounted) return;
      setState(() {
        _conversation = {
          ...?_conversation,
          ...res,
          'requestStatus': 'accepted',
          'request_status': 'accepted',
          'isApproved': true,
          'isRequest': false,
          'is_request': false,
          'type': 'normal',
          'folder': 'primary',
        };
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request accepted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _requestActionLoading = false);
    }
  }

  Future<void> _deleteRequest() async {
    if (_requestActionLoading) return;
    final convId = _effectiveConversationId();
    if (convId.isEmpty) return;
    setState(() => _requestActionLoading = true);
    try {
      await _chatApi.deleteConversation(conversationId: convId);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _requestActionLoading = false);
    }
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
        _pinToBottom(force: true);
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
        _pinToBottom(force: true);
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

  void _pinToBottom({bool force = false}) {
    if (!mounted) return;
    if (!force && !_isNearBottom()) return;
    _scrollPinTimer?.cancel();
    _scrollPinAttempts = 4;

    void tick() {
      if (!mounted) return;
      if (_scrollPinAttempts <= 0) return;
      _scrollPinAttempts--;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!_scrollController.hasClients) return;
        try {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        } catch (_) {}
      });
      if (_scrollPinAttempts > 0) {
        _scrollPinTimer = Timer(const Duration(milliseconds: 140), tick);
      }
    }

    tick();
  }

  Future<void> _refreshLatest() async {
    if (_refreshingLatest) return;
    if (_loading || _loadingMore) return;
    final convId = _effectiveConversationId();
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
        if (wasNearBottom) _pinToBottom();
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
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _pinToBottom(force: true));
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
    String pick(dynamic v) =>
        UrlHelper.normalizeUrl((v ?? '').toString().trim());
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
    final raw =
        (message['createdAt'] ?? message['created_at'] ?? '').toString().trim();
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
      final reactions =
          (reactionsRaw is List ? reactionsRaw : const <dynamic>[])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
      if (reactions.isEmpty) return const SizedBox.shrink();

      final cs = Theme.of(context).colorScheme;
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final uid = _currentUserId ?? '';
      final own = uid.isEmpty ? null : _ownReactionFor(message, uid);
      final primaryEmoji = (own?['emoji']?.toString().trim().isNotEmpty == true)
          ? own!['emoji'].toString().trim()
          : (reactions.first['emoji']?.toString().trim() ?? '');
      final count = reactions.length;
      final label = count > 1 ? '$primaryEmoji $count' : primaryEmoji;

      return Container(
        margin: const EdgeInsets.only(top: 3),
        constraints: const BoxConstraints(minHeight: 28),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
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
          textAlign: TextAlign.center,
          textHeightBehavior: const TextHeightBehavior(
            applyHeightToFirstAscent: false,
            applyHeightToLastDescent: false,
          ),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
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
              'replyTo':
                  (replyId != null && replyId.isNotEmpty) ? replyId : null,
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
    final otherDisplayName = _nameFor(_otherProfile ?? other);
    final otherHandle =
        (_otherProfile?['username'] ?? other?['username'])?.toString().trim();
    final otherName =
        (_otherProfile?['username'] as String?)?.trim().isNotEmpty == true
            ? (_otherProfile?['username'] as String).trim()
            : otherDisplayName;
    final otherAvatar = _avatarFor(_otherProfile ?? other);
    final otherId = _idFor(_otherProfile ?? other) ?? '';
    final isRequestPending = _isRequestConversation(_conversation);
    final requestWho = (otherHandle != null &&
            otherHandle.isNotEmpty &&
            otherHandle != otherDisplayName)
        ? '$otherDisplayName ($otherHandle)'
        : otherName;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
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
                if (_otherOnline && otherId.isNotEmpty)
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2ECC71),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              Theme.of(context).appBarTheme.backgroundColor ??
                                  Theme.of(context).scaffoldBackgroundColor,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
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
                  if (_otherOnline && otherId.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        'Online',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF2ECC71),
                        ),
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
              child: isRequestPending
                  ? _messageRequestFooter(requestWho: requestWho)
                  : _bottomComposer(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageRequestFooter({required String requestWho}) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final divider = cs.onSurface.withValues(alpha: 0.10);
    final muted = cs.onSurface.withValues(alpha: 0.70);
    final acceptBg = cs.onSurface.withValues(alpha: isDark ? 0.18 : 0.10);

    String? requestedById() {
      final raw = _conversation?['requestedBy'] ??
          _conversation?['requested_by'] ??
          _conversation?['requestedById'] ??
          _conversation?['requested_by_id'];
      if (raw is Map) {
        final map = Map<String, dynamic>.from(raw);
        return (map['_id'] ?? map['id'] ?? map['userId'] ?? map['user_id'])
            ?.toString()
            .trim();
      }
      return raw?.toString().trim();
    }

    final currentUserId = (_currentUserId ?? '').trim();
    final isRequester = currentUserId.isNotEmpty &&
        (requestedById() ?? '').trim().isNotEmpty &&
        requestedById() == currentUserId;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: divider)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isRequester) ...[
            Text(
              "$requestWho hasn't approved your message request yet.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: cs.onSurface.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Please wait.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: cs.onSurface.withValues(alpha: 0.45),
              ),
            ),
          ] else ...[
            Text(
              'Accept message request from $requestWho?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "If you accept, they will also be able to call you and see info such as your activity status and when you've read messages.",
              textAlign: TextAlign.center,
              style: TextStyle(
                height: 1.25,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: muted,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: TextButton(
                      onPressed: _requestActionLoading ? null : _deleteRequest,
                      style: TextButton.styleFrom(
                        shape: const StadiumBorder(),
                        foregroundColor: Colors.redAccent,
                        textStyle: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      child: _requestActionLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Delete'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      onPressed: _requestActionLoading ? null : _acceptRequest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: acceptBg,
                        foregroundColor: cs.onSurface,
                        elevation: 0,
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      child: _requestActionLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Accept'),
                    ),
                  ),
                ),
              ],
            ),
          ],
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
                onPressed: _uploadingMedia
                    ? null
                    : () => _pickAndSendImages(fromCamera: true),
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
                                    content: Text('More options coming soon')),
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

  Map<String, dynamic>? _ownReactionFor(
      Map<String, dynamic> message, String uid) {
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

  Map<String, dynamic>? _sharedContentFor(Map<String, dynamic> message) {
    final raw = message['sharedContent'] ?? message['shared_content'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  String _sharedContentType(Map<String, dynamic> shared) {
    final raw = (shared['contentType'] ?? shared['content_type'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (raw == 'reels') return 'reel';
    if (raw == 'ads') return 'ad';
    if (raw == 'posts') return 'post';
    if (raw == 'tweets') return 'tweet';
    return raw;
  }

  String _sharedContentId(Map<String, dynamic> shared) {
    final raw = shared['contentId'] ?? shared['content_id'] ?? shared['id'];
    if (raw is Map) {
      return ((raw['_id'] ?? raw['id'])?.toString() ?? '').trim();
    }
    return (raw?.toString() ?? '').trim();
  }

  String _sharedShareUrl(Map<String, dynamic> shared) {
    return (shared['shareUrl'] ?? shared['share_url'] ?? '').toString().trim();
  }

  double _quantizeSharedAspectRatio(double ratio) {
    if (ratio <= 0 || ratio.isNaN || ratio.isInfinite) return 4 / 5;
    // Bucket to common social aspect ratios for stable layout.
    if (ratio >= 1.25) return 16 / 9; // landscape
    if (ratio >= 0.95) return 1.0; // square
    return 4 / 5; // portrait
  }

  double _defaultSharedAspectRatioForType(String type) {
    if (type == 'reel') return 4 / 5;
    if (type == 'post' || type == 'tweet') return 4 / 5;
    // Ads in chat should feel like reel shares (usually video-first).
    if (type == 'ad') return 4 / 5;
    return 4 / 5;
  }

  void _ensureSharedPreviewAspectRatio(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    if (_sharedPreviewAspectRatios.containsKey(trimmed)) return;
    if (_resolvingSharedPreviewAspectRatioUrls.contains(trimmed)) return;
    _resolvingSharedPreviewAspectRatioUrls.add(trimmed);

    // Best-effort: resolve without auth headers. Fallback keeps default ratios.
    final provider = CachedNetworkImageProvider(trimmed);
    final stream = provider.resolve(ImageConfiguration.empty);

    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        stream.removeListener(listener);
        _resolvingSharedPreviewAspectRatioUrls.remove(trimmed);
        final w = info.image.width.toDouble();
        final h = info.image.height.toDouble();
        if (w <= 0 || h <= 0) return;
        final ratio = w / h;
        if (!mounted) return;
        // Avoid calling setState during build (this method is triggered from build).
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _sharedPreviewAspectRatios[trimmed] = ratio;
          });
        });
      },
      onError: (Object _, StackTrace? __) {
        stream.removeListener(listener);
        _resolvingSharedPreviewAspectRatioUrls.remove(trimmed);
        if (!mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          // Cache a sentinel so we don't repeatedly attempt to decode
          // unsupported/corrupt images (common for ad creatives).
          setState(() {
            _sharedPreviewAspectRatios.putIfAbsent(trimmed, () => -1);
          });
        });
      },
    );
    stream.addListener(listener);
  }

  void _ensureSharedAdPreview(String adId) {
    final id = adId.trim();
    if (id.isEmpty) return;
    if (_sharedAdPreviewById.containsKey(id)) return;
    if (_loadingSharedAdIds.contains(id)) return;
    _loadingSharedAdIds.add(id);

    unawaited(() async {
      try {
        final ad = await _adsService.fetchAdById(id);
        final url = UrlHelper.normalizeUrl(ad?.imageUrl ?? '');
        if (!mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _sharedAdPreviewById[id] = url; // may be empty if backend missing
            _loadingSharedAdIds.remove(id);
          });
        });
      } catch (_) {
        if (!mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _sharedAdPreviewById[id] = '';
            _loadingSharedAdIds.remove(id);
          });
        });
      }
    }());
  }

  String _inferSharedTypeFromUrl(String url) {
    if (url.isEmpty) return '';
    final uri = Uri.tryParse(url);
    final path = uri?.path.isNotEmpty == true ? uri!.path : url;
    final lower = path.toLowerCase();
    if (lower.contains('/reels/')) return 'reel';
    if (lower.contains('/ads/') && lower.contains('/details')) return 'ad';
    if (lower.contains('/ad/')) return 'ad';
    if (lower.contains('/post/')) {
      final qp = uri?.queryParameters;
      if (qp != null && (qp['type'] ?? '').toLowerCase().trim() == 'tweet') {
        return 'tweet';
      }
      return 'post';
    }
    if (lower.contains('/posts/')) return 'post';
    return '';
  }

  String _inferSharedIdFromUrl(String url, String type) {
    if (url.isEmpty) return '';
    final uri = Uri.tryParse(url);
    final path = uri?.path.isNotEmpty == true ? uri!.path : url;

    String? matchGroup(Pattern pattern) {
      final m = RegExp(pattern.toString(), caseSensitive: false).firstMatch(path);
      final v = m?.groupCount == 1 ? m?.group(1) : null;
      return v?.trim();
    }

    String? candidate;
    if (type == 'reel') candidate = matchGroup(r'\/reels\/([^\/?#]+)');
    if (type == 'ad') {
      candidate ??= matchGroup(r'\/ads\/([^\/?#]+)\/details');
      candidate ??= matchGroup(r'\/ad\/([^\/?#]+)');
    }
    if (type == 'tweet' || type == 'post') {
      candidate ??= matchGroup(r'\/post\/([^\/?#]+)');
      candidate ??= matchGroup(r'\/posts\/([^\/?#]+)');
    }
    if (candidate == null || candidate.isEmpty) return '';
    try {
      return Uri.decodeComponent(candidate);
    } catch (_) {
      return candidate;
    }
  }

  ({String type, String id}) _resolveSharedContent(Map<String, dynamic> shared) {
    var type = _sharedContentType(shared);
    var id = _sharedContentId(shared);
    final shareUrl = _sharedShareUrl(shared);

    final inferredType = _inferSharedTypeFromUrl(shareUrl);
    if (inferredType.isNotEmpty) {
      type = inferredType;
    }

    if (id.isEmpty && type.isNotEmpty) {
      id = _inferSharedIdFromUrl(shareUrl, type);
    }
    if (type.isEmpty && id.isNotEmpty) {
      // Best effort: default to post if backend didn't send contentType.
      type = 'post';
    }
    return (type: type, id: id);
  }

  String _sharedCreatorName(Map<String, dynamic> shared) {
    return (shared['creatorUsername'] ??
            shared['creator_username'] ??
            shared['creatorName'] ??
            shared['creator_name'] ??
            shared['title'])
        .toString()
        .trim();
  }

  String _sharedCreatorAvatar(Map<String, dynamic> shared) {
    return (shared['creatorAvatarUrl'] ??
            shared['creator_avatar_url'] ??
            shared['creatorAvatar'] ??
            shared['creator_avatar'])
        .toString()
        .trim();
  }

  String _sharedPreviewUrl(Map<String, dynamic> shared) {
    bool isVideoLike(String url) {
      final u = url.trim().toLowerCase();
      return u.endsWith('.m3u8') ||
          u.contains('.m3u8?') ||
          u.endsWith('.mp4') ||
          u.contains('.mp4?') ||
          u.endsWith('.mov') ||
          u.endsWith('.m4v') ||
          u.endsWith('.webm') ||
          u.endsWith('.mkv');
    }

    String norm(dynamic v) =>
        UrlHelper.normalizeUrl((v ?? '').toString().trim());

    String pickFirstThumbnail(dynamic media) {
      if (media is Map) {
        return pickFirstThumbnail([media]);
      }
      if (media is! List) return '';
      for (final raw in media) {
        if (raw is! Map) continue;
        final m = Map<String, dynamic>.from(raw);

        final thumbKeys = [
          'thumbnailUrl',
          'thumbnail_url',
          'thumbUrl',
          'thumb_url',
          'thumb',
          'thumbnail',
          'imageUrl',
          'image_url',
        ];
        for (final k in thumbKeys) {
          final u = norm(m[k]);
          if (u.isNotEmpty && !isVideoLike(u)) return u;
        }

        final thumbs = m['thumbnails'] ?? m['thumbs'];
        if (thumbs is List) {
          for (final tRaw in thumbs) {
            if (tRaw is! Map) continue;
            final t = Map<String, dynamic>.from(tRaw);
            final u = norm(t['fileUrl'] ?? t['file_url'] ?? t['url'] ?? t['path']);
            if (u.isNotEmpty && !isVideoLike(u)) return u;
          }
        }

        final mediaType = (m['media_type'] ?? m['type'] ?? m['mediaType'] ?? '')
            .toString()
            .toLowerCase()
            .trim();
        final fileUrl = norm(m['fileUrl'] ?? m['file_url'] ?? m['url'] ?? m['path']);
        if (fileUrl.isNotEmpty &&
            (mediaType.contains('image') || !isVideoLike(fileUrl)) &&
            !isVideoLike(fileUrl)) {
          return fileUrl;
        }
      }
      return '';
    }

    final direct = norm(shared['previewUrl'] ?? shared['preview_url']);
    if (direct.isNotEmpty && !isVideoLike(direct)) return direct;

    final fallbacks = [
      shared['thumbnailUrl'] ?? shared['thumbnail_url'],
      shared['thumbUrl'] ?? shared['thumb_url'],
      shared['imageUrl'] ?? shared['image_url'],
      shared['image'],
    ];
    for (final v in fallbacks) {
      final u = norm(v);
      if (u.isNotEmpty && !isVideoLike(u)) return u;
    }

    final media = shared['media'] ??
        shared['medias'] ??
        shared['assets'] ??
        shared['items'];
    final fromMedia = pickFirstThumbnail(media);
    if (fromMedia.isNotEmpty) return fromMedia;

    // If previewUrl points at a video/playlist, fall back to a thumbnail inside media.
    if (direct.isNotEmpty && isVideoLike(direct)) {
      final thumbFromMedia = pickFirstThumbnail(media);
      if (thumbFromMedia.isNotEmpty) return thumbFromMedia;
    }

    return '';
  }

  String _sharedCaption(Map<String, dynamic> shared) {
    final v = (shared['caption'] ?? shared['message'] ?? shared['title'])
        ?.toString()
        .trim();
    return v ?? '';
  }

  Future<void> _openSharedContent(Map<String, dynamic> shared) async {
    final resolved = _resolveSharedContent(shared);
    final type = resolved.type;
    final id = resolved.id;
    if (type.isEmpty || id.isEmpty) return;

    if (type == 'reel') {
      Navigator.of(context).pushNamed(
        '/reels',
        arguments: <String, dynamic>{'initialReelId': id},
      );
      return;
    }
    if (type == 'ad') {
      Navigator.of(context).pushNamed('/ads/$id/details');
      return;
    }
    if (type == 'tweet') {
      final isMobile = MediaQuery.sizeOf(context).width < 600;
      if (isMobile) {
        Navigator.of(context).pushNamed('/post/$id?type=tweet');
      } else {
        showDialog(
          context: context,
          barrierColor: Colors.black54,
          builder: (ctx) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: PostDetailModal(
              postId: id,
              isTweet: true,
              onClose: () => Navigator.of(ctx).pop(),
            ),
          ),
        );
      }
      return;
    }
    if (type == 'post') {
      final isMobile = MediaQuery.sizeOf(context).width < 600;
      if (isMobile) {
        Navigator.of(context).pushNamed('/post/$id');
      } else {
        showDialog(
          context: context,
          barrierColor: Colors.black54,
          builder: (ctx) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: PostDetailModal(
              postId: id,
              onClose: () => Navigator.of(ctx).pop(),
            ),
          ),
        );
      }
      return;
    }
  }

  Widget _sharedContentCard(Map<String, dynamic> shared, bool mine) {
    final resolved = _resolveSharedContent(shared);
    final type = resolved.type;
    if (type.isEmpty) return const SizedBox.shrink();
    final creator = _sharedCreatorName(shared);
    final creatorAvatar = _sharedCreatorAvatar(shared);
    var preview = _sharedPreviewUrl(shared);
    if (preview.isEmpty && type == 'ad') {
      final cached = _sharedAdPreviewById[resolved.id]?.trim() ?? '';
      if (cached.isNotEmpty) {
        preview = cached;
      } else {
        _ensureSharedAdPreview(resolved.id);
      }
    }
    final caption = _sharedCaption(shared);
    final verified = shared['creatorVerified'] == true ||
        (shared['creator_verified'] == true);

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final contentLabel = switch (type) {
      'reel' => 'Reel',
      'post' => 'Post',
      'tweet' => 'Tweet',
      'ad' => 'Ad',
      _ => type,
    };

    final isReelShare = type == 'reel' || type == 'ad';
    final isPostOrTweetShare = type == 'post' || type == 'tweet';

    final cardBg = isDark ? theme.cardColor : Colors.white;
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.10);
    final textColor = isDark ? Colors.white : cs.onSurface;
    final mutedText =
        isDark ? Colors.white.withValues(alpha: 0.75) : cs.onSurface.withValues(alpha: 0.70);
    final pillBg =
        isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.06);
    final pillBorder =
        isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.08);
    final headerBg =
        isDark ? Colors.black.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.03);
    final captionBg =
        isDark ? Colors.black.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.04);

    Widget typePill() {
      IconData icon = LucideIcons.share2;
      if (type == 'reel') icon = LucideIcons.clapperboard;
      if (type == 'post') icon = LucideIcons.image;
      if (type == 'tweet') icon = LucideIcons.messageSquare;
      if (type == 'ad') icon = LucideIcons.megaphone;

      return Container(
        constraints: const BoxConstraints(minHeight: 30),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: pillBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: pillBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: textColor.withValues(alpha: 0.92)),
            const SizedBox(width: 6),
            Text(
              contentLabel,
              textAlign: TextAlign.center,
              textHeightBehavior: const TextHeightBehavior(
                applyHeightToFirstAscent: false,
                applyHeightToLastDescent: false,
              ),
              style: TextStyle(
                color: textColor.withValues(alpha: 0.92),
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      );
    }

    Widget avatar() {
      return ClipOval(
        child: creatorAvatar.isNotEmpty
            ? SafeNetworkImage(
                url: creatorAvatar,
                width: 28,
                height: 28,
                fit: BoxFit.cover,
              )
            : Container(
                width: 28,
                height: 28,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.black.withValues(alpha: 0.06),
                alignment: Alignment.center,
                child: Text(
                  (creator.isNotEmpty ? creator : 'U')
                      .characters
                      .first
                      .toUpperCase(),
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
      );
    }

    Widget verifiedBadge() {
      if (!verified) return const SizedBox.shrink();
      return Container(
        width: 16,
        height: 16,
        decoration: const BoxDecoration(
          color: Color(0xFF0095F6),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Text(
          '✓',
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }

    Widget header({EdgeInsets padding = const EdgeInsets.all(12)}) {
      return Padding(
        padding: padding,
        child: Row(
          children: [
            avatar(),
            const SizedBox(width: 10),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      creator.isNotEmpty ? creator : 'Shared',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  verifiedBadge(),
                ],
              ),
            ),
            const SizedBox(width: 8),
            typePill(),
          ],
        ),
      );
    }

    Widget previewPlaceholder(String label, {double height = 260}) {
      return Container(
        height: height,
        color:
            isDark ? Colors.black.withValues(alpha: 0.20) : Colors.black.withValues(alpha: 0.06),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: mutedText,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    final maxCardWidth = (type == 'reel' || type == 'ad')
        ? 280.0
        : (isPostOrTweetShare ? 320.0 : 300.0);

    final resolvedRaw =
        preview.isNotEmpty ? _sharedPreviewAspectRatios[preview] : null;
    if (preview.isNotEmpty && resolvedRaw == null && type != 'ad') {
      _ensureSharedPreviewAspectRatio(preview);
    }
    final resolvedRatio = (resolvedRaw != null && resolvedRaw > 0)
        ? resolvedRaw
        : null;
    final frameAspect = _quantizeSharedAspectRatio(
      resolvedRatio ?? _defaultSharedAspectRatioForType(type),
    );

    Widget previewFrame({required BoxFit fit, required bool contain}) {
      bool isLikelyRasterImage(String url) {
        final u = url.toLowerCase();
        return u.endsWith('.png') ||
            u.contains('.png?') ||
            u.endsWith('.jpg') ||
            u.contains('.jpg?') ||
            u.endsWith('.jpeg') ||
            u.contains('.jpeg?') ||
            u.endsWith('.webp') ||
            u.contains('.webp?') ||
            u.endsWith('.gif') ||
            u.contains('.gif?') ||
            u.endsWith('.bmp') ||
            u.contains('.bmp?');
      }

      return LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth =
              constraints.maxWidth.isFinite ? constraints.maxWidth : maxCardWidth;
          final width = min(availableWidth, maxCardWidth);
          final height = width / frameAspect;
          final bg = contain
              ? (isDark ? Colors.black.withValues(alpha: 0.18) : Colors.black.withValues(alpha: 0.04))
              : Colors.transparent;
          return SizedBox(
            width: width,
            height: height,
            child: Container(
              color: bg,
              child: preview.isNotEmpty
                  ? SafeNetworkImage(
                      url: preview,
                      fit: fit,
                      assumeRaster: isLikelyRasterImage(preview),
                      trustExtension: isLikelyRasterImage(preview),
                      placeholder: previewPlaceholder(
                        'Loading $contentLabel…',
                        height: height,
                      ),
                      errorWidget: previewPlaceholder(
                        '$contentLabel preview unavailable',
                        height: height,
                      ),
                    )
                  : previewPlaceholder(
                      'Open shared $contentLabel',
                      height: height,
                    ),
            ),
          );
        },
      );
    }

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxCardWidth),
        child: InkWell(
          onTap: () => unawaited(_openSharedContent(shared)),
          borderRadius: BorderRadius.circular(22),
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: borderColor),
            ),
            clipBehavior: Clip.antiAlias,
            child: isReelShare
                ? Stack(
                    children: [
                      previewFrame(fit: BoxFit.cover, contain: false),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.65),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: Row(
                            children: [
                              avatar(),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        creator.isNotEmpty ? creator : 'Reel',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 18,
                                          height: 1.1,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    verifiedBadge(),
                                  ],
                                ),
                              ),
                              typePill(),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 12,
                        left: 12,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(color: headerBg, child: header()),
                      previewFrame(
                        fit: isPostOrTweetShare ? BoxFit.contain : BoxFit.cover,
                        contain: isPostOrTweetShare,
                      ),
                      Container(
                        color: captionBg,
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                        child: Text(
                          caption.isNotEmpty
                              ? caption
                              : 'Open shared $contentLabel',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textColor.withValues(alpha: 0.95),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
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
      final reactions =
          (reactionsRaw is List ? reactionsRaw : const <dynamic>[])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
      if (reactions.isEmpty) return const SizedBox.shrink();

      final uid = _currentUserId ?? '';
      final own = uid.isEmpty ? null : _ownReactionFor(message, uid);
      final primaryEmoji = (own?['emoji']?.toString().trim().isNotEmpty == true)
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
    final shared = _sharedContentFor(message);
    final sharedCard = shared == null ? null : _sharedContentCard(shared, mine);
    final hasMedia = mediaUrl.trim().isNotEmpty;
    final cleanedText = shared != null
        ? text.replaceAll(RegExp(r'https?:\\/\\/\\S+', caseSensitive: false), '')
        : text;
    final hasText = cleanedText.trim().isNotEmpty;
    final sharedOnly = !isDeleted &&
        !hasMedia &&
        sharedCard != null &&
        replied == null &&
        !hasText;

    final bubble = GestureDetector(
      onDoubleTap: () => _reactToMessage(message, '❤️'),
      onLongPress: () => _showMessageActions(context, message, mine: mine),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: sharedOnly
            ? EdgeInsets.zero
            : hasMedia
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        constraints: BoxConstraints(maxWidth: maxBubbleWidth),
        decoration: BoxDecoration(
          color: (hasMedia || sharedOnly) ? Colors.transparent : bg,
          borderRadius: sharedOnly
              ? BorderRadius.zero
              : BorderRadius.only(
                  topLeft: const Radius.circular(22),
                  topRight: const Radius.circular(22),
                  bottomLeft: Radius.circular(mine ? 22 : 8),
                  bottomRight: Radius.circular(mine ? 8 : 22),
                ),
          border: Border.all(
              color: (hasMedia || sharedOnly) ? Colors.transparent : border),
          boxShadow: mine || sharedOnly
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
                      if (sharedCard != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                          child: sharedCard,
                        ),
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
                          padding: const EdgeInsets.fromLTRB(12, 5, 12, 5),
                          child: Transform.translate(
                            offset: const Offset(0, -1),
                            child: Text(
                              cleanedText.trim(),
                              textHeightBehavior: const TextHeightBehavior(
                                applyHeightToFirstAscent: false,
                                applyHeightToLastDescent: false,
                              ),
                              style: TextStyle(
                                color: fg,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                height: 1.0,
                                leadingDistribution:
                                    TextLeadingDistribution.even,
                              ),
                            ),
                          ),
                        ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (sharedCard != null) sharedCard,
                      if (sharedCard != null && (replied != null || hasText))
                        const SizedBox(height: 8),
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
                        Transform.translate(
                          offset: const Offset(0, -1),
                          child: Text(
                            cleanedText.trim(),
                            textHeightBehavior: const TextHeightBehavior(
                              applyHeightToFirstAscent: false,
                              applyHeightToLastDescent: false,
                            ),
                            style: TextStyle(
                              color: fg,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              height: 1.0,
                              leadingDistribution:
                                  TextLeadingDistribution.even,
                            ),
                          ),
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
      final hasAnyContent =
          (map['text']?.toString().trim().isNotEmpty == true) ||
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
    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(1)}B';
    }
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
          Align(
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

class _AspectPreservingChatImageState
    extends State<_AspectPreservingChatImage> {
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
                                  color: Colors.white.withValues(alpha: 0.22),
                                ),
                                FractionallySizedBox(
                                  widthFactor: progress,
                                  child: Container(
                                    height: 2,
                                    color: Colors.white.withValues(alpha: 0.85),
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
