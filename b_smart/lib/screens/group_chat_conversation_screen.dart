import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:just_audio/just_audio.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/chat_api.dart';
import '../api/api_client.dart';
import '../api/users_api.dart';
import '../services/chat_unread_service.dart';
import '../services/ads_service.dart';
import '../services/chat_media_auto_save_service.dart';
import '../utils/app_error_handler.dart';
import '../theme/design_tokens.dart';
import '../utils/current_user.dart';
import '../utils/url_helper.dart';
import '../widgets/safe_network_image.dart';
import '../widgets/post_detail_modal.dart';
import '../widgets/voice_recorder_sheet.dart';
import '../widgets/chat_bubble/chat_bubble_shell.dart';
import '../widgets/chat_bubble/models.dart';
import '../widgets/chat_bubble/content/document_message_content.dart';
import '../widgets/chat_bubble/content/text_message_content.dart';
import '../widgets/chat_bubble/content/image_message_content.dart';
import '../widgets/chat_bubble/content/voice_message_content.dart';
import '../widgets/chat_bubble/content/tap_to_load_media_preview.dart';
import 'group_chat_info_screen.dart';

class GroupChatConversationScreen extends StatefulWidget {
  final String conversationId;
  final Map<String, dynamic>? initialConversation;

  const GroupChatConversationScreen({
    super.key,
    required this.conversationId,
    this.initialConversation,
  });

  @override
  State<GroupChatConversationScreen> createState() =>
      _GroupChatConversationScreenState();
}

class _GroupChatConversationScreenState
    extends State<GroupChatConversationScreen> with WidgetsBindingObserver {
  final _chatApi = ChatApi();
  final _usersApi = UsersApi();
  final _scrollController = ScrollController();
  final _inputController = TextEditingController();
  final _inputFocusNode = FocusNode();
  final _picker = ImagePicker();
  final _adsService = AdsService();
  final _autoSaveService = ChatMediaAutoSaveService.instance;

  static const bool _showCallButtons = false;

  // TODO: populate from the backend (following list) and keep in sync.
  final Set<String> _followingIds = <String>{};

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
  bool _dataSaverMode = false;
  Timer? _pollTimer;
  bool _refreshingLatest = false;
  int _pendingNewCount = 0;
  Timer? _scrollPinTimer;
  int _scrollPinAttempts = 0;

  final Map<String, double> _sharedPreviewAspectRatios = <String, double>{};
  final Set<String> _resolvingSharedPreviewAspectRatioUrls = <String>{};
  final Map<String, String> _sharedAdPreviewById = <String, String>{};
  final Set<String> _loadingSharedAdIds = <String>{};
  late final VoidCallback _mediaPrefsListener;

  static const int _pageLimit = 20;

  bool _isGroupConversation() => true;

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

  String _headerSystemMessageId() =>
      '__conversation_header__${_effectiveConversationId()}';

  String _groupName() {
    final c = _conversation;
    final explicit =
        (c?['groupName'] ?? c?['group_name'] ?? c?['name'])?.toString().trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;

    // Fallback: build a name from participant display names (excluding self).
    final uid = (_currentUserId ?? '').trim();
    final names = <String>[];
    for (final p in _participants()) {
      final pid =
          (p['_id'] ?? p['id'] ?? p['user_id'])?.toString().trim() ?? '';
      if (uid.isNotEmpty && pid == uid) continue;
      final n = (p['full_name'] ?? p['fullName'] ?? p['name'] ?? p['username'])
          ?.toString()
          .trim();
      if (n != null && n.isNotEmpty) names.add(n);
      if (names.length >= 3) break;
    }
    if (names.isNotEmpty) return names.join(', ');
    return 'Group';
  }

  String? _groupAvatar() {
    final c = _conversation;
    final v = (c?['groupAvatar'] ?? c?['group_avatar'])?.toString().trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  List<Map<String, dynamic>> _participants() {
    final p = _conversation?['participants'];
    if (p is! List) return const [];
    return p.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  String _groupCreatorId() {
    final c = _conversation;
    return (c?['createdBy'] ??
                c?['created_by'] ??
                c?['groupAdmin'] ??
                c?['group_admin'] ??
                c?['requestedBy'] ??
                c?['requested_by'])
            ?.toString()
            .trim() ??
        '';
  }

  String _labelForUser(Map<String, dynamic>? u) {
    if (u == null) return 'User';
    return (u['full_name'] ??
            u['fullName'] ??
            u['name'] ??
            u['username'] ??
            'User')
        .toString()
        .trim();
  }

  String _groupCreatedLine() {
    final creatorId = _groupCreatorId();
    final uid = (_currentUserId ?? '').trim();
    if (creatorId.isNotEmpty && uid.isNotEmpty && creatorId == uid) {
      return 'You created the group.';
    }
    if (creatorId.isNotEmpty) {
      final match = _participants().firstWhere(
        (p) =>
            (p['_id'] ?? p['id'] ?? p['user_id'])?.toString().trim() ==
            creatorId,
        orElse: () => const <String, dynamic>{},
      );
      if (match.isNotEmpty) {
        final name = _labelForUser(match);
        if (name.isNotEmpty) return '$name created the group.';
      }
    }
    return 'Group created.';
  }

  DateTime? _groupCreatedAt() {
    final raw = (_conversation?['createdAt'] ??
            _conversation?['created_at'] ??
            _conversation?['updatedAt'] ??
            _conversation?['updated_at'])
        ?.toString()
        .trim();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  String _groupCreatedTimeLabel() {
    final dt = _groupCreatedAt();
    if (dt == null) return '';
    return DateFormat('h:mm a').format(dt);
  }

  void _showGroupMembersSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final participants = _participants();
        final theme = Theme.of(context);
        final muted = theme.textTheme.bodySmall?.color?.withValues(alpha: 0.75);
        final maxHeight = MediaQuery.of(context).size.height * 0.75;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _groupName(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${participants.length} members',
                    style: TextStyle(
                      color: muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView.separated(
                      itemCount: participants.length,
                      separatorBuilder: (_, __) => const Divider(height: 18),
                      itemBuilder: (context, index) {
                        final u = participants[index];
                        final name = (u['full_name'] ??
                                u['fullName'] ??
                                u['name'] ??
                                u['username'] ??
                                'User')
                            .toString()
                            .trim();
                        final handle = (u['username'] ?? u['handle'] ?? '')
                            .toString()
                            .trim();
                        final avatar = (u['avatar_url'] ??
                                u['avatarUrl'] ??
                                u['profile_pic'] ??
                                u['profilePic'])
                            ?.toString()
                            .trim();
                        return Row(
                          children: [
                            if (avatar != null && avatar.isNotEmpty)
                              ClipOval(
                                child: SafeNetworkImage(
                                  url: avatar,
                                  width: 34,
                                  height: 34,
                                  fit: BoxFit.cover,
                                ),
                              )
                            else
                              CircleAvatar(
                                radius: 17,
                                backgroundColor: DesignTokens.instaPink,
                                child: Text(
                                  name.isNotEmpty
                                      ? name.characters.first.toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (handle.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      handle.startsWith('@')
                                          ? handle
                                          : '@$handle',
                                      style: TextStyle(
                                        color: muted,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _leaveGroup,
                      icon: const Icon(LucideIcons.logOut, size: 18),
                      label: const Text('Leave group'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppBarGroupAvatar() {
    final borderColor = Theme.of(context).scaffoldBackgroundColor;
    final uid = (_currentUserId ?? '').trim();
    final participants = _participants();
    final others = participants
        .where((p) => (p['_id'] ?? p['id'])?.toString().trim() != uid)
        .take(2)
        .toList();

    // Ensure we have 2 (fill from all if needed).
    while (others.length < 2 && participants.length > others.length) {
      final extra = participants.firstWhere(
        (p) => !others.contains(p),
        orElse: () => const <String, dynamic>{},
      );
      if (extra.isEmpty) break;
      others.add(extra);
    }

    Widget avatarCircle(Map<String, dynamic> user, {double size = 28}) {
      final url = (user['avatar_url'] ?? user['avatarUrl'])?.toString().trim();
      final label = _labelForUser(user);
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: ClipOval(
          child: (url != null && url.isNotEmpty)
              ? SafeNetworkImage(
                  url: url,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                )
              : CircleAvatar(
                  radius: size / 2,
                  backgroundColor: DesignTokens.instaPink,
                  child: Text(
                    label.isNotEmpty
                        ? label.characters.first.toUpperCase()
                        : 'G',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: size * 0.4,
                    ),
                  ),
                ),
        ),
      );
    }

    return SizedBox(
      width: 44,
      height: 32,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (others.length >= 2)
            Positioned(left: 14, top: 2, child: avatarCircle(others[1])),
          Positioned(
            left: 0,
            top: 2,
            child: avatarCircle(
              others.isNotEmpty ? others[0] : const <String, dynamic>{},
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditGroupSheet() async {
    if (!_isGroupConversation()) return;
    final convId = widget.conversationId.trim();
    if (convId.isEmpty) return;

    final initialName =
        (_conversation?['groupName'] ?? _conversation?['group_name'])
            ?.toString()
            .trim();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return _EditGroupSheet(
          conversationId: convId,
          initialName: initialName,
          groupAvatarUrl: _groupAvatar(),
          participants: _participants(),
          chatApi: _chatApi,
          picker: _picker,
          extractUploadedMediaUrl: _extractUploadedMediaUrl,
          groupAvatarStackBuilder: (participants, size) => _groupAvatarStack(
            participants: participants,
            size: size,
          ),
          onConversationUpdated: (normalized) {
            if (!mounted) return;
            setState(() => _conversation = normalized);
          },
        );
      },
    );
  }

  Future<void> _leaveGroup() async {
    final cid = widget.conversationId.trim();
    final uid = (_currentUserId ?? '').trim();
    if (cid.isEmpty || uid.isEmpty) return;
    try {
      await _chatApi.removeGroupMember(conversationId: cid, userId: uid);
      if (!mounted) return;
      Navigator.of(context).pop(); // sheet
      Navigator.of(context).maybePop();
    } catch (e, st) {
      AppErrorHandler.logError('group-chat-leave', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppErrorHandler.userMessage(
            e,
            fallback: 'Unable to leave the group right now.',
          )),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mediaPrefsListener = () {
      if (!mounted) return;
      setState(() => _dataSaverMode = _autoSaveService.dataSaverModeNotifier.value);
    };
    _autoSaveService.dataSaverModeNotifier.addListener(_mediaPrefsListener);
    _conversation = widget.initialConversation;
    ChatUnreadService().markConversationRead(widget.conversationId);
    _init();
    unawaited(_loadMediaPrefs());
    _scrollController.addListener(_handleScroll);
    _inputController.addListener(_handleComposerChanged);
    _startPolling();
  }

  Future<void> _loadMediaPrefs() async {
    await _autoSaveService.load();
    if (!mounted) return;
    setState(() => _dataSaverMode = _autoSaveService.dataSaverMode);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
    _scrollPinTimer?.cancel();
    _inputController.removeListener(_handleComposerChanged);
    _autoSaveService.dataSaverModeNotifier.removeListener(_mediaPrefsListener);
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

  types.User get _chatUiUser {
    final id = (_currentUserId ?? '').trim();
    return types.User(id: id.isEmpty ? 'me' : id);
  }

  bool _isAudioMessage(Map<String, dynamic> m) {
    final mediaTypeRaw = (m['mediaType'] ?? m['media_type'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (mediaTypeRaw.isEmpty) return false;
    if (mediaTypeRaw == 'audio' || mediaTypeRaw == 'voice') return true;
    if (mediaTypeRaw.startsWith('audio/')) return true;
    if (mediaTypeRaw == 'm4a' ||
        mediaTypeRaw == 'aac' ||
        mediaTypeRaw == 'mp3' ||
        mediaTypeRaw == 'wav') {
      return true;
    }
    return false;
  }

  bool _looksLikeAudioUrl(String url) {
    final u = url.trim().toLowerCase();
    return u.endsWith('.m4a') ||
        u.endsWith('.aac') ||
        u.endsWith('.mp3') ||
        u.endsWith('.wav') ||
        u.contains('.m4a?') ||
        u.contains('.aac?') ||
        u.contains('.mp3?') ||
        u.contains('.wav?');
  }

  bool _looksLikeDocumentUrl(String url) {
    final u = url.trim().toLowerCase();
    return u.endsWith('.pdf') ||
        u.endsWith('.doc') ||
        u.endsWith('.docx') ||
        u.endsWith('.xls') ||
        u.endsWith('.xlsx') ||
        u.endsWith('.ppt') ||
        u.endsWith('.pptx') ||
        u.endsWith('.txt') ||
        u.contains('.pdf?') ||
        u.contains('.doc?') ||
        u.contains('.docx?') ||
        u.contains('.xls?') ||
        u.contains('.xlsx?') ||
        u.contains('.ppt?') ||
        u.contains('.pptx?') ||
        u.contains('.txt?');
  }

  String _documentTitleFor(Map<String, dynamic> message) {
    final candidates = [
      message['fileName'],
      message['file_name'],
      message['name'],
      message['title'],
      message['mediaName'],
      message['media_name'],
      message['label'],
    ];
    for (final candidate in candidates) {
      final value = candidate?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    final url = _mediaUrlFor(message);
    final uri = Uri.tryParse(url);
    if (uri == null || uri.pathSegments.isEmpty) return 'Document';
    final file = uri.pathSegments.last.trim();
    return file.isNotEmpty ? file : 'Document';
  }

  String _documentSubtitleFor(Map<String, dynamic> message) {
    final mime = (message['mimeType'] ?? message['mime_type'] ?? '')
        .toString()
        .trim();
    if (mime.isNotEmpty) return mime;
    final url = _mediaUrlFor(message).toLowerCase();
    if (url.endsWith('.pdf') || url.contains('.pdf?')) return 'PDF document';
    return 'Document';
  }

  types.User _authorFor(Map<String, dynamic> message) {
    final sender = message['sender'];
    final senderId = (sender is Map
            ? (sender['_id'] ?? sender['id'] ?? sender['user_id'])
            : sender)
        ?.toString()
        .trim();
    final id = (senderId ?? '').isEmpty ? 'unknown' : senderId!;
    final senderMap = sender is Map ? Map<String, dynamic>.from(sender) : null;
    final name = (senderMap?['username'] ??
            senderMap?['full_name'] ??
            senderMap?['name'])
        ?.toString()
        .trim();
    return types.User(
      id: id,
      firstName: (name != null && name.isNotEmpty) ? name : null,
    );
  }

  List<types.Message> _chatUiMessages() {
    final out = <types.Message>[];
    for (final m in _messages) {
      final id = _messageId(m).trim();
      if (id.isEmpty) continue;
      final createdAt = _createdAtMillis(m);
      final author = _authorFor(m);

      if (_isGroupSystemNoticeMessage(m)) {
        final text = _groupSystemNoticeDisplayText(m).trim();
        if (text.isNotEmpty) {
          out.add(
            types.SystemMessage(
              id: id,
              createdAt: createdAt == 0 ? null : createdAt,
              text: text,
            ),
          );
        }
        continue;
      }

      if (m['isDeleted'] == true) {
        out.add(
          types.TextMessage(
            id: id,
            author: author,
            createdAt: createdAt == 0 ? null : createdAt,
            text: 'Message unsent',
          ),
        );
        continue;
      }

      final mediaUrl = _mediaUrlFor(m);
      final mediaTypeLower = (m['mediaType'] ?? m['media_type'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final text = (m['text'] ?? '').toString();

      final isAudio = _isAudioMessage(m) || _looksLikeAudioUrl(mediaUrl);
      if (isAudio && mediaUrl.isNotEmpty) {
        final storedDuration = (m['audioDuration'] ?? m['duration'] ?? 0);
        final totalSecs = storedDuration is num
            ? storedDuration.toInt()
            : int.tryParse(storedDuration.toString()) ?? 0;
        out.add(
          types.AudioMessage(
            id: id,
            author: author,
            createdAt: createdAt == 0 ? null : createdAt,
            duration: Duration(seconds: totalSecs.clamp(0, 60 * 60)),
            name: 'voice',
            size: 0,
            mimeType: mediaTypeLower.startsWith('audio/')
                ? mediaTypeLower
                : 'audio/m4a',
            uri: UrlHelper.normalizeUrl(mediaUrl),
          ),
        );
        continue;
      }

      final isDocument = mediaTypeLower.contains('document') ||
          mediaTypeLower.contains('pdf') ||
          mediaTypeLower.contains('file') ||
          _looksLikeDocumentUrl(mediaUrl);
      if (isDocument && mediaUrl.isNotEmpty) {
        out.add(
          types.FileMessage(
            id: id,
            author: author,
            createdAt: createdAt == 0 ? null : createdAt,
            mimeType: mediaTypeLower.isNotEmpty ? mediaTypeLower : null,
            name: _documentTitleFor(m),
            size: 0,
            uri: UrlHelper.normalizeUrl(mediaUrl),
          ),
        );
        continue;
      }

      if (mediaUrl.isNotEmpty && mediaTypeLower != 'audio') {
        out.add(
          types.ImageMessage(
            id: id,
            author: author,
            createdAt: createdAt == 0 ? null : createdAt,
            name: 'image',
            size: 0,
            uri: UrlHelper.normalizeUrl(mediaUrl),
          ),
        );
        continue;
      }

      out.add(
        types.TextMessage(
          id: id,
          author: author,
          createdAt: createdAt == 0 ? null : createdAt,
          text: text,
        ),
      );
    }

    out.sort((a, b) => (b.createdAt ?? 0).compareTo(a.createdAt ?? 0));
    out.add(
      types.SystemMessage(
        id: _headerSystemMessageId(),
        createdAt: null,
        text: '',
      ),
    );
    return out;
  }

  void _handleSendPressed(types.PartialText message) {
    final text = message.text.trim();
    if (text.isEmpty) return;
    _inputController.text = text;
    unawaited(_send());
  }

  Widget _chatStatusBuilder(types.Message message,
      {required BuildContext context}) {
    final label = _readReceiptLabelForMessage(message.id, context: context);
    if (label == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        label,
        textAlign: TextAlign.right,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.48),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Map<String, dynamic>? _rawMessageById(String messageId) {
    final id = messageId.trim();
    if (id.isEmpty) return null;
    for (final message in _messages.reversed) {
      if (_messageId(message) == id) return message;
    }
    return null;
  }

  String? _readReceiptLabelForMessage(
    String messageId, {
    required BuildContext context,
  }) {
    final raw = _rawMessageById(messageId);
    if (raw == null) return null;
    final uid = (_currentUserId ?? '').trim();
    if (uid.isEmpty) return null;
    final sender = raw['sender'];
    final senderId = (sender is Map
            ? (sender['_id'] ?? sender['id'] ?? sender['user_id'])
            : sender)
        ?.toString()
        .trim();
    if (senderId == null || senderId != uid) return null;
    final seenBy = raw['seenBy'];
    if (seenBy is! List || seenBy.isEmpty) return null;
    return 'Seen';
  }

  String _timeLabelFor(types.Message message) {
    final createdAt = message.createdAt;
    if (createdAt == null || createdAt == 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(createdAt).toLocal();
    return DateFormat('h:mm a').format(dt);
  }

  Widget _bubbleTimestamp({
    required String label,
    required bool outgoing,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final color = outgoing
        ? cs.onPrimary.withValues(alpha: isDark ? 0.82 : 0.78)
        : cs.onSurface.withValues(alpha: isDark ? 0.65 : 0.55);
    return Text(
      label,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        height: 1.0,
        color: color,
      ),
    );
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
    if (_isGroupConversation()) return;
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
    } catch (e, st) {
      AppErrorHandler.logError('group-chat-load', e, st);
      if (!mounted) return;
      setState(() {
        _error = AppErrorHandler.userMessage(
          e,
          fallback: 'Unable to load this conversation right now.',
        );
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
      ChatUnreadService().markConversationRead(widget.conversationId);
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
    } catch (e, st) {
      AppErrorHandler.logError('group-chat-send', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppErrorHandler.userMessage(
            e,
            fallback: 'Unable to send your message right now.',
          )),
        ),
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
    } catch (e, st) {
      AppErrorHandler.logError('group-chat-voice', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppErrorHandler.userMessage(
                e,
                fallback: 'Failed to send voice message. Please try again.',
              ),
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

  String? _seenAtRaw(Map<String, dynamic>? message) {
    if (message == null) return null;
    final raw = (message['seenAt'] ?? message['seen_at'])?.toString().trim();
    return (raw != null && raw.isNotEmpty) ? raw : null;
  }

  String _formatSeenAgo(String? dateValue) {
    if (dateValue == null || dateValue.trim().isEmpty) return 'Seen';
    final parsed = DateTime.tryParse(dateValue);
    if (parsed == null) return 'Seen';
    final diff = DateTime.now().difference(parsed);
    final minutes = max(1, diff.inMinutes);
    if (minutes < 60) return 'Seen ${minutes}m ago';
    final hours = minutes ~/ 60;
    if (hours < 24) return 'Seen ${hours}h ago';
    final days = hours ~/ 24;
    if (days < 7) return 'Seen ${days}d ago';
    final formatted = DateFormat('d MMM', 'en_IN').format(parsed);
    return 'Seen $formatted';
  }

  Map<String, dynamic>? _latestSeenOwnMessage(String otherUserId) {
    final uid = _currentUserId ?? '';
    final other = otherUserId.trim();
    if (uid.isEmpty || other.isEmpty) return null;
    for (var index = _messages.length - 1; index >= 0; index -= 1) {
      final m = _messages[index];
      if (m['isDeleted'] == true) continue;
      final mine = _senderIdForMessage(m) == uid;
      if (!mine) continue;
      if (_hasSeen(m, other)) return m;
    }
    return null;
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
    required bool showSeen,
    required String seenText,
    required ChatBubbleGroupPosition groupPosition,
    required bool showTail,
    required EdgeInsets outerPadding,
  }) {
    final isDeleted = message['isDeleted'] == true;
    final timeText = _messageTimeText(message);

    final reactionsRaw = message['reactions'];
    final reactions = (reactionsRaw is List ? reactionsRaw : const <dynamic>[])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final uid = _currentUserId ?? '';
    final own = uid.isEmpty ? null : _ownReactionFor(message, uid);
    final primaryEmoji = (own?['emoji']?.toString().trim().isNotEmpty == true)
        ? own!['emoji'].toString().trim()
        : (reactions.isNotEmpty
            ? (reactions.first['emoji']?.toString().trim() ?? '')
            : '');

    final shell = ChatBubbleShell(
      isOutgoing: mine,
      isGroup: true,
      senderName: mine ? null : _labelFromUser(senderMap),
      reply: null,
      isSelected: false,
      bareContent: true,
      showTail: false,
      groupPosition: groupPosition,
      timestampText: timeText,
      deliveryStatus:
          _deliveryStatusFor(message, mine: mine, showSeen: showSeen),
      reactions: (!isDeleted && reactions.isNotEmpty && primaryEmoji.isNotEmpty)
          ? [
              ChatReaction(
                emoji: primaryEmoji,
                count: reactions.length,
                isMine: own != null,
              )
            ]
          : const [],
      onDoubleTap: () => _reactToMessage(message, '❤️'),
      onLongPress: () => _showMessageActions(context, message, mine: mine),
      child: ImageMessageContent(
        urls: urls.map((e) => UrlHelper.normalizeUrl(e)).toList(),
        caption: '',
        isOutgoing: mine,
        onTap: () => _openImageViewer(
          urls.map((e) => UrlHelper.normalizeUrl(e)).toList(),
          initialIndex: 0,
        ),
      ),
    );

    final wrapped = _SwipeToReply(
      onReply: () => _setReplyTo(message),
      child: Padding(
        padding: outerPadding,
        child: shell,
      ),
    );

    if (mine) return wrapped;

    final otherAvatarUrl = _avatarUrlFromUser(senderMap);
    final otherLabel = _labelFromUser(senderMap);
    return Row(
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
        Flexible(child: wrapped),
      ],
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
    } catch (e, st) {
      AppErrorHandler.logError('group-chat-media', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppErrorHandler.userMessage(
            e,
            fallback: 'Unable to send this media right now.',
          )),
        ),
      );
    } finally {
      if (mounted) setState(() => _uploadingMedia = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final appBarBg =
        theme.appBarTheme.backgroundColor ?? theme.scaffoldBackgroundColor;
    final isGroup = _isGroupConversation();
    final other = isGroup ? null : _otherParticipant();
    final otherName = isGroup
        ? _groupName()
        : (_otherProfile?['username'] as String?)?.trim().isNotEmpty == true
            ? (_otherProfile?['username'] as String).trim()
            : _nameFor(other);
    final otherAvatar =
        isGroup ? _groupAvatar() : _avatarFor(_otherProfile ?? other);
    final otherId = isGroup ? '' : (_idFor(_otherProfile ?? other) ?? '');
    final latestSeenOwn = isGroup ? null : _latestSeenOwnMessage(otherId);
    final latestSeenOwnId = isGroup ? '' : _messageId(latestSeenOwn);
    final seenText = isGroup ? '' : _formatSeenAgo(_seenAtRaw(latestSeenOwn));
    final membersCount = isGroup ? _participants().length : 0;

    return Scaffold(
      appBar: isGroup
          ? AppBar(
              backgroundColor: appBarBg,
              surfaceTintColor: appBarBg,
              elevation: 0,
              scrolledUnderElevation: 0,
              foregroundColor: cs.onSurface,
              titleSpacing: 0,
              title: Row(
                children: [
                  _buildAppBarGroupAvatar(),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                otherName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurface,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right,
                              size: 16,
                              color: cs.onSurface.withValues(alpha: 0.55),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => GroupChatInfoScreen(
                          title: otherName,
                          groupAvatarUrl: otherAvatar,
                          currentUserId: _currentUserId ?? '',
                          participants: _participants(),
                          onEdit: _showEditGroupSheet,
                          onShowMembers: _showGroupMembersSheet,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(LucideIcons.info),
                ),
              ],
            )
          : AppBar(
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
                : ClipRect(
                    child: RefreshIndicator(
                      onRefresh: () => _load(page: 1, replace: true),
                      child: Chat(
                        messages: _chatUiMessages(),
                        onSendPressed: _handleSendPressed,
                        user: _chatUiUser,
                        scrollPhysics: const ClampingScrollPhysics(),
                        showUserAvatars: false,
                        showUserNames: true,
                        isAttachmentUploading: _sending || _uploadingMedia,
                        isLastPage: !_hasMore,
                        customBottomWidget: const SizedBox.shrink(),
                        customStatusBuilder: _chatStatusBuilder,
                        textMessageBuilder: (text, {required messageWidth, required showName}) {
                          final outgoing =
                              text.author.id == (_currentUserId ?? '').trim();
                          final label = _timeLabelFor(text);
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              TextMessage(
                                emojiEnlargementBehavior:
                                    EmojiEnlargementBehavior.multi,
                                hideBackgroundOnEmojiMessages: true,
                                message: text,
                                showName: showName,
                                usePreviewData: true,
                              ),
                              if (label.isNotEmpty)
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(12, 0, 12, 6),
                                  child: _bubbleTimestamp(
                                    label: label,
                                    outgoing: outgoing,
                                  ),
                                ),
                            ],
                          );
                        },
                        imageMessageBuilder: (image, {required messageWidth}) {
                          final outgoing =
                              image.author.id == (_currentUserId ?? '').trim();
                          final label = _timeLabelFor(image);
                          final loadedImage = ImageMessage(
                            message: image,
                            messageWidth: messageWidth,
                          );
                          return Stack(
                            children: [
                              Padding(
                                padding: EdgeInsets.only(
                                  right: 54,
                                  bottom: label.isEmpty ? 0 : 16,
                                ),
                                child: _dataSaverMode
                                    ? TapToLoadMediaPreview(
                                        icon: LucideIcons.image,
                                        title: 'Image preview hidden',
                                        subtitle:
                                            'Data saver is on. Tap to load this image.',
                                        loadedChild: loadedImage,
                                      )
                                    : loadedImage,
                              ),
                              if (label.isNotEmpty)
                                Positioned(
                                  right: 8,
                                  bottom: 6,
                                  child: _bubbleTimestamp(
                                    label: label,
                                    outgoing: outgoing,
                                  ),
                                ),
                            ],
                          );
                        },
                        fileMessageBuilder: (file, {required messageWidth}) {
                          final outgoing =
                              file.author.id == (_currentUserId ?? '').trim();
                          final label = _timeLabelFor(file);
                          final loadedFile = DocumentMessageContent(
                            title: file.name,
                            subtitle: _documentSubtitleFor({
                              'mimeType': file.mimeType,
                              'mediaUrl': file.uri,
                            }),
                            isOutgoing: outgoing,
                            onTap: () async {
                              final uri = Uri.tryParse(file.uri);
                              if (uri == null) return;
                              await launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                            },
                          );
                          return Stack(
                            children: [
                              Padding(
                                padding: EdgeInsets.only(
                                  right: 54,
                                  bottom: label.isEmpty ? 0 : 16,
                                ),
                                child: _dataSaverMode
                                    ? TapToLoadMediaPreview(
                                        icon: LucideIcons.fileText,
                                        title: 'Document hidden',
                                        subtitle:
                                            'Data saver is on. Tap to load this document.',
                                        loadedChild: loadedFile,
                                      )
                                    : loadedFile,
                              ),
                              if (label.isNotEmpty)
                                Positioned(
                                  right: 8,
                                  bottom: 6,
                                  child: _bubbleTimestamp(
                                    label: label,
                                    outgoing: outgoing,
                                  ),
                                ),
                            ],
                          );
                        },
                        systemMessageBuilder: (message) {
                          if (message.id == _headerSystemMessageId()) {
                            if (isGroup) {
                              return Container(
                                width: double.infinity,
                                color: theme.scaffoldBackgroundColor,
                                child: Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          12, 12, 12, 0),
                                      child: _groupHeader(
                                        name: otherName,
                                        avatarUrl: otherAvatar,
                                        membersCount: membersCount,
                                        participants: _participants(),
                                        onEdit: _showEditGroupSheet,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    if (_groupCreatedTimeLabel().isNotEmpty)
                                      Text(
                                        _groupCreatedTimeLabel(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: cs.onSurface
                                              .withValues(alpha: 0.40),
                                        ),
                                      ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _groupCreatedLine(),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color:
                                            cs.onSurface.withValues(alpha: 0.45),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                ),
                              );
                            }
                            return Container(
                              width: double.infinity,
                              color: theme.scaffoldBackgroundColor,
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(12, 12, 12, 12),
                                child: _conversationHeader(
                                  userId: otherId,
                                  username: otherName,
                                  avatarUrl: otherAvatar ?? '',
                                ),
                              ),
                            );
                          }
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: Center(
                              child: Text(
                                message.text,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurface.withValues(alpha: 0.55),
                                ),
                              ),
                            ),
                          );
                        },
                        audioMessageBuilder: (audio, {required messageWidth}) {
                          final outgoing =
                              audio.author.id == (_currentUserId ?? '').trim();
                          final label = _timeLabelFor(audio);
                          return Stack(
                            children: [
                              Padding(
                                padding: EdgeInsets.only(
                                  right: 54,
                                  bottom: label.isEmpty ? 0 : 16,
                                ),
                                child: VoiceMessageContent(
                                  audioUrl: UrlHelper.normalizeUrl(audio.uri),
                                  totalDurationSeconds:
                                      audio.duration.inSeconds,
                                  isOutgoing: outgoing,
                                ),
                              ),
                              if (label.isNotEmpty)
                                Positioned(
                                  right: 8,
                                  bottom: 6,
                                  child: _bubbleTimestamp(
                                    label: label,
                                    outgoing: outgoing,
                                  ),
                                ),
                            ],
                          );
                        },
                        onEndReached: () async {
                          if (_loadingMore || _loading) return;
                          if (!_hasMore) return;
                          await _load(page: _page + 1, replace: false);
                        },
                      ),
                    ),
                  ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
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

  bool _isGroupSystemNoticeMessage(Map<String, dynamic> message) {
    final raw = (message['text'] ?? '').toString().trim();
    if (raw.isEmpty) return false;
    final text = raw.toLowerCase();
    return text.contains('created the group') ||
        text.contains('created this group') ||
        RegExp(r'\badded\b').hasMatch(text);
  }

  String _groupSystemNoticeDisplayText(Map<String, dynamic> message) {
    final rawText = (message['text'] ?? '').toString().trim();
    if (rawText.isEmpty) return '';
    final lower = rawText.toLowerCase();
    var displayText = rawText;

    if (lower.contains('created the group') ||
        lower.contains('created this group')) {
      final senderLabel = _senderLabelForMessage(message).trim();
      if (senderLabel.isNotEmpty) {
        final createdStart = lower.indexOf('created');
        final suffix = createdStart >= 0
            ? rawText.substring(createdStart)
            : 'created the group chat.';
        displayText =
            '$senderLabel $suffix'.replaceAll(RegExp(r'\s+'), ' ').trim();
      }
    }

    return displayText;
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
    } catch (e, st) {
      AppErrorHandler.logError('group-chat-unsend', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppErrorHandler.userMessage(
            e,
            fallback: 'Unable to unsend the message right now.',
          )),
        ),
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
    if (ratio >= 1.25) return 16 / 9;
    if (ratio >= 0.95) return 1.0;
    return 4 / 5;
  }

  double _defaultSharedAspectRatioForType(String type) {
    if (type == 'reel') return 4 / 5;
    if (type == 'post' || type == 'tweet') return 4 / 5;
    if (type == 'ad') return 4 / 5;
    return 4 / 5;
  }

  void _ensureSharedPreviewAspectRatio(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    if (_sharedPreviewAspectRatios.containsKey(trimmed)) return;
    if (_resolvingSharedPreviewAspectRatioUrls.contains(trimmed)) return;
    _resolvingSharedPreviewAspectRatioUrls.add(trimmed);

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
            _sharedAdPreviewById[id] = url;
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
      final m =
          RegExp(pattern.toString(), caseSensitive: false).firstMatch(path);
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

  ({String type, String id}) _resolveSharedContent(
      Map<String, dynamic> shared) {
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
      if (media is Map) return pickFirstThumbnail([media]);
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
            final u =
                norm(t['fileUrl'] ?? t['file_url'] ?? t['url'] ?? t['path']);
            if (u.isNotEmpty && !isVideoLike(u)) return u;
          }
        }

        final mediaType = (m['media_type'] ?? m['type'] ?? m['mediaType'] ?? '')
            .toString()
            .toLowerCase()
            .trim();
        final fileUrl =
            norm(m['fileUrl'] ?? m['file_url'] ?? m['url'] ?? m['path']);
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
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.10);
    final textColor = isDark ? Colors.white : cs.onSurface;
    final mutedText = isDark
        ? Colors.white.withValues(alpha: 0.75)
        : cs.onSurface.withValues(alpha: 0.70);
    final pillBg = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.06);
    final pillBorder = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.08);
    final headerBg = isDark
        ? Colors.black.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.03);
    final captionBg = isDark
        ? Colors.black.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.04);

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
        color: isDark
            ? Colors.black.withValues(alpha: 0.20)
            : Colors.black.withValues(alpha: 0.06),
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
    final resolvedRatio =
        (resolvedRaw != null && resolvedRaw > 0) ? resolvedRaw : null;
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
          final availableWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : maxCardWidth;
          final width = min(availableWidth, maxCardWidth);
          final height = width / frameAspect;
          final bg = contain
              ? (isDark
                  ? Colors.black.withValues(alpha: 0.18)
                  : Colors.black.withValues(alpha: 0.04))
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
    bool showSeen = false,
    String seenText = 'Seen',
    required ChatBubbleGroupPosition groupPosition,
    required bool showTail,
  }) {
    final isDeleted = message['isDeleted'] == true;
    final text = message['text']?.toString() ?? '';
    final mediaUrl = message['mediaUrl']?.toString() ?? '';
    final w = MediaQuery.sizeOf(context).width;
    final maxBubbleWidth = min(420.0, w * 0.78);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeText = _messageTimeText(message);

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
                  if (timeText != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      timeText,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                  reactionPill(),
                  if (showSeen)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        seenText,
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.48),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
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
                      if (timeText != null) ...[
                        const SizedBox(height: 2),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            timeText,
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurface.withValues(alpha: 0.55),
                            ),
                          ),
                        ),
                      ],
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
        ? text.replaceAll(
            RegExp(r'https?:\\/\\/\\S+', caseSensitive: false), '')
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
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Message unsent',
                    style: TextStyle(
                      color: fg.withValues(alpha: 0.75),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  if (timeText != null) ...[
                    const SizedBox(height: 2),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        timeText,
                        style: TextStyle(
                          fontSize: 11,
                          color: fg.withValues(alpha: mine ? 0.75 : 0.55),
                        ),
                      ),
                    ),
                  ],
                ],
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
                          padding: EdgeInsets.fromLTRB(
                            12,
                            sharedCard != null ? 0 : 10,
                            12,
                            8,
                          ),
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
                      Stack(
                        children: [
                          _chatImageFrame(
                            url: mediaUrl,
                            maxWidth: maxBubbleWidth,
                          ),
                          if (timeText != null)
                            Positioned(
                              right: 8,
                              bottom: 8,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 3),
                                  child: Text(
                                    timeText,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
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
                      if (timeText != null) ...[
                        const SizedBox(height: 2),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              timeText,
                              style: TextStyle(
                                fontSize: 11,
                                color: fg.withValues(alpha: mine ? 0.75 : 0.55),
                              ),
                            ),
                          ),
                        ),
                      ],
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
                              leadingDistribution: TextLeadingDistribution.even,
                            ),
                          ),
                        ),
                      if (timeText != null) ...[
                        const SizedBox(height: 2),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            timeText,
                            style: TextStyle(
                              fontSize: 11,
                              color: fg.withValues(alpha: mine ? 0.75 : 0.55),
                            ),
                          ),
                        ),
                      ],
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
              if (showSeen)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    seenText,
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.48),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
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

  Widget _bubbleWhatsapp(
    Map<String, dynamic> message,
    bool mine, {
    required Map<String, dynamic>? senderMap,
    bool showSeen = false,
    String seenText = 'Seen',
    required ChatBubbleGroupPosition groupPosition,
    required bool showTail,
    required EdgeInsets outerPadding,
  }) {
    final isDeleted = message['isDeleted'] == true;
    final text = message['text']?.toString() ?? '';
    final mediaType = message['mediaType']?.toString() ?? '';
    final mediaUrl = (message['mediaUrl'] ?? message['url'])?.toString() ?? '';
    final timeText = _messageTimeText(message);

    final reactionsRaw = message['reactions'];
    final reactions = (reactionsRaw is List ? reactionsRaw : const <dynamic>[])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final uid = _currentUserId ?? '';
    final own = uid.isEmpty ? null : _ownReactionFor(message, uid);
    final primaryEmoji = (own?['emoji']?.toString().trim().isNotEmpty == true)
        ? own!['emoji'].toString().trim()
        : (reactions.isNotEmpty
            ? (reactions.first['emoji']?.toString().trim() ?? '')
            : '');

    final replied = _repliedMessageFor(message);
    final replySender = _senderLabelForMessage(replied);
    final replyPreview = _previewForMessage(replied);
    final replyData = (replied != null &&
            (replySender.trim().isNotEmpty || replyPreview.trim().isNotEmpty))
        ? ChatReplyPreview(
            senderLabel: replySender.trim().isNotEmpty ? replySender : 'Reply',
            text: replyPreview.trim().isNotEmpty ? replyPreview : 'Message',
          )
        : null;

    final shared = _sharedContentFor(message);
    final sharedCard = shared == null ? null : _sharedContentCard(shared, mine);
    final cleanedText = shared != null
        ? text.replaceAll(
            RegExp(r'https?:\\/\\/\\S+', caseSensitive: false), '')
        : text;

    final isMediaMessage = !isDeleted && mediaUrl.trim().isNotEmpty;
    Widget content;
    if (isDeleted) {
      content = Text(
        'Message unsent',
        style: const TextStyle(fontStyle: FontStyle.italic),
      );
    } else if (mediaType == 'audio') {
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
      content = VoiceMessageContent(
        audioUrl: UrlHelper.normalizeUrl(audioUrl),
        totalDurationSeconds: totalSecs,
        isOutgoing: mine,
      );
    } else if (mediaUrl.trim().isNotEmpty) {
      content = ImageMessageContent(
        urls: [UrlHelper.normalizeUrl(mediaUrl)],
        caption: cleanedText.trim(),
        isOutgoing: mine,
        onTap: () => _openImageViewer(
          [UrlHelper.normalizeUrl(mediaUrl)],
          initialIndex: 0,
        ),
      );
    } else {
      content = TextMessageContent(
        text: cleanedText.trim(),
        isOutgoing: mine,
        leading: sharedCard,
      );
    }

    final shell = ChatBubbleShell(
      isOutgoing: mine,
      isGroup: true,
      senderName: mine ? null : _labelFromUser(senderMap),
      reply: replyData,
      isSelected: false,
      bareContent: isMediaMessage,
      showTail: isMediaMessage ? false : showTail,
      groupPosition: groupPosition,
      timestampText: timeText,
      deliveryStatus:
          _deliveryStatusFor(message, mine: mine, showSeen: showSeen),
      reactions: (!isDeleted && reactions.isNotEmpty && primaryEmoji.isNotEmpty)
          ? [
              ChatReaction(
                emoji: primaryEmoji,
                count: reactions.length,
                isMine: own != null,
              )
            ]
          : const [],
      onDoubleTap: () => _reactToMessage(message, '❤️'),
      onLongPress: () => _showMessageActions(context, message, mine: mine),
      child: content,
    );

    final wrapped = _SwipeToReply(
      onReply: () => _setReplyTo(message),
      child: Padding(
        padding: outerPadding,
        child: shell,
      ),
    );

    if (mine) return wrapped;

    final otherAvatarUrl = _avatarUrlFromUser(senderMap);
    final otherLabel = _labelFromUser(senderMap);
    return Row(
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
        Flexible(child: wrapped),
      ],
    );
  }

  String? _messageTimeText(Map<String, dynamic> message) {
    final raw = message['createdAt'] ??
        message['created_at'] ??
        message['sentAt'] ??
        message['sent_at'] ??
        message['timestamp'] ??
        message['time'];

    DateTime? dt;
    if (raw is DateTime) {
      dt = raw;
    } else if (raw is num) {
      final v = raw.toInt();
      // Heuristic: treat 13-digit as ms, 10-digit as seconds.
      dt = (v > 1000000000000)
          ? DateTime.fromMillisecondsSinceEpoch(v, isUtc: true)
          : DateTime.fromMillisecondsSinceEpoch(v * 1000, isUtc: true);
    } else {
      final s = raw?.toString().trim();
      if (s != null && s.isNotEmpty) {
        dt = DateTime.tryParse(s);
        if (dt == null) {
          final v = int.tryParse(s);
          if (v != null) {
            dt = (v > 1000000000000)
                ? DateTime.fromMillisecondsSinceEpoch(v, isUtc: true)
                : DateTime.fromMillisecondsSinceEpoch(v * 1000, isUtc: true);
          }
        }
      }
    }

    if (dt == null) return null;
    final local = dt.toLocal();
    final tod = TimeOfDay.fromDateTime(local);
    return MaterialLocalizations.of(context).formatTimeOfDay(
      tod,
      alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat,
    );
  }

  void _openImageViewer(
    List<String> urls, {
    int initialIndex = 0,
  }) {
    final images = urls.where((e) => e.trim().isNotEmpty).toList();
    if (images.isEmpty) return;
    final start = initialIndex.clamp(0, images.length - 1);
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.95),
      builder: (ctx) {
        final controller = PageController(initialPage: start);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(ctx).pop(),
          child: SafeArea(
            child: Stack(
              children: [
                PageView.builder(
                  controller: controller,
                  itemCount: images.length,
                  itemBuilder: (context, i) {
                    final url = images[i];
                    return Center(
                      child: InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 4.0,
                        child: SafeNetworkImage(
                          url: url,
                          fit: BoxFit.contain,
                        ),
                      ),
                    );
                  },
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  ChatDeliveryStatus? _deliveryStatusFor(
    Map<String, dynamic> message, {
    required bool mine,
    required bool showSeen,
  }) {
    if (!mine) return null;
    if (showSeen) return ChatDeliveryStatus.read;
    final seenBy = message['seenBy'];
    if (seenBy is List && seenBy.isNotEmpty) return ChatDeliveryStatus.read;
    return ChatDeliveryStatus.sent;
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
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return n.toString();
  }

  Widget _groupHeader({
    required String name,
    required String? avatarUrl,
    required int membersCount,
    required List<Map<String, dynamic>> participants,
    required VoidCallback onEdit,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final borderColor = theme.scaffoldBackgroundColor;
    final uid = (_currentUserId ?? '').trim();
    final title = name.trim().isEmpty ? 'Group' : name.trim();

    final others = participants
        .where((p) => (p['_id'] ?? p['id'])?.toString().trim() != uid)
        .take(2)
        .toList();
    while (others.length < 2 && participants.length > others.length) {
      final extra = participants.firstWhere(
        (p) => !others.contains(p),
        orElse: () => const <String, dynamic>{},
      );
      if (extra.isEmpty) break;
      others.add(extra);
    }

    Widget bigAvatar(Map<String, dynamic> user) {
      final url = (user['avatar_url'] ?? user['avatarUrl'])?.toString().trim();
      final label = _labelForUser(user);
      return Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: 3),
        ),
        child: ClipOval(
          child: (url != null && url.isNotEmpty)
              ? SafeNetworkImage(
                  url: url,
                  width: 68,
                  height: 68,
                  fit: BoxFit.cover,
                )
              : CircleAvatar(
                  radius: 34,
                  backgroundColor: DesignTokens.instaPink,
                  child: Text(
                    label.isNotEmpty
                        ? label.characters.first.toUpperCase()
                        : 'G',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                    ),
                  ),
                ),
        ),
      );
    }

    final followCount = _followingIds.isNotEmpty
        ? participants
            .where((p) =>
                (p['_id'] ?? p['id'])?.toString().trim() != uid &&
                _followingIds.contains(
                  (p['_id'] ?? p['id'])?.toString().trim(),
                ))
            .length
        : max(0, membersCount - 1); // TODO: compute from following ids.

    return Column(
      children: [
        const SizedBox(height: 14),
        SizedBox(
          width: 96,
          height: 96,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                bottom: 0,
                right: 0,
                child: bigAvatar(
                  others.length >= 2
                      ? others[1]
                      : (others.isNotEmpty
                          ? others[0]
                          : const <String, dynamic>{}),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                child: bigAvatar(
                  others.isNotEmpty ? others[0] : const <String, dynamic>{},
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: onEdit,
          child: const Text(
            'Change name and image',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4A90D9),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'You follow $followCount people on Instagram',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: cs.onSurface.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(height: 22),
        const SizedBox(height: 8),
        Divider(
          height: 1,
          thickness: 0.5,
          color: cs.onSurface.withValues(alpha: 0.10),
        ),
      ],
    );
  }

  Widget _groupAvatarStack({
    required List<Map<String, dynamic>> participants,
    required double size,
  }) {
    final borderColor = Theme.of(context).scaffoldBackgroundColor;
    final uid = (_currentUserId ?? '').trim();
    final others = participants
        .where((p) => (p['_id'] ?? p['id'])?.toString().trim() != uid)
        .take(2)
        .toList();
    while (others.length < 2 && participants.length > others.length) {
      final extra = participants.firstWhere(
        (p) => !others.contains(p),
        orElse: () => const <String, dynamic>{},
      );
      if (extra.isEmpty) break;
      others.add(extra);
    }

    Widget avatarCircle(Map<String, dynamic> user, {required double s}) {
      final url = (user['avatar_url'] ?? user['avatarUrl'])?.toString().trim();
      final label = _labelForUser(user);
      return Container(
        width: s,
        height: s,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: 3),
        ),
        child: ClipOval(
          child: (url != null && url.isNotEmpty)
              ? SafeNetworkImage(
                  url: url, width: s, height: s, fit: BoxFit.cover)
              : CircleAvatar(
                  radius: s / 2,
                  backgroundColor: DesignTokens.instaPink,
                  child: Text(
                    label.isNotEmpty
                        ? label.characters.first.toUpperCase()
                        : 'G',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: s * 0.35,
                    ),
                  ),
                ),
        ),
      );
    }

    final avatarSize = min(68.0, size * 0.71);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            bottom: 0,
            right: 0,
            child: avatarCircle(
              others.length >= 2
                  ? others[1]
                  : (others.isNotEmpty ? others[0] : const <String, dynamic>{}),
              s: avatarSize,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            child: avatarCircle(
              others.isNotEmpty ? others[0] : const <String, dynamic>{},
              s: avatarSize,
            ),
          ),
        ],
      ),
    );
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

typedef _GroupAvatarStackBuilder = Widget Function(
  List<Map<String, dynamic>> participants,
  double size,
);

class _EditGroupSheet extends StatefulWidget {
  final String conversationId;
  final String? initialName;
  final String? groupAvatarUrl;
  final List<Map<String, dynamic>> participants;
  final ChatApi chatApi;
  final ImagePicker picker;
  final String Function(Map<String, dynamic> payload) extractUploadedMediaUrl;
  final _GroupAvatarStackBuilder groupAvatarStackBuilder;
  final ValueChanged<Map<String, dynamic>> onConversationUpdated;

  const _EditGroupSheet({
    required this.conversationId,
    required this.initialName,
    required this.groupAvatarUrl,
    required this.participants,
    required this.chatApi,
    required this.picker,
    required this.extractUploadedMediaUrl,
    required this.groupAvatarStackBuilder,
    required this.onConversationUpdated,
  });

  @override
  State<_EditGroupSheet> createState() => _EditGroupSheetState();
}

class _EditGroupSheetState extends State<_EditGroupSheet> {
  late final TextEditingController _nameController;
  Uint8List? _pickedBytes;
  String _pickedFilename = 'group-avatar.jpg';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final x = await widget.picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (x == null) return;
    final bytes = await x.readAsBytes();
    if (!mounted || bytes.isEmpty) return;
    setState(() {
      _pickedBytes = bytes;
      _pickedFilename = x.name.trim().isNotEmpty ? x.name : _pickedFilename;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final name = _nameController.text.trim();
      String? avatarUrl;
      if (_pickedBytes != null) {
        final uploaded = await widget.chatApi.uploadChatMediaManyBytes(
          conversationId: widget.conversationId,
          files: [
            MultipartBytesFile(
              bytes: _pickedBytes!,
              filename: _pickedFilename,
            ),
          ],
        );
        avatarUrl = widget.extractUploadedMediaUrl(uploaded);
        if (avatarUrl.isEmpty) {
          final mediaAny = uploaded['media'];
          if (mediaAny is List &&
              mediaAny.isNotEmpty &&
              mediaAny.first is Map) {
            avatarUrl = widget.extractUploadedMediaUrl(
              Map<String, dynamic>.from(mediaAny.first as Map),
            );
          }
        }
        if (avatarUrl.isEmpty) avatarUrl = null;
      }

      final updated = await widget.chatApi.updateGroup(
        conversationId: widget.conversationId,
        groupName: name.isEmpty ? null : name,
        groupAvatar: avatarUrl,
      );

      if (!mounted) return;
      final normalized = updated['conversation'] is Map
          ? Map<String, dynamic>.from(updated['conversation'] as Map)
          : Map<String, dynamic>.from(updated);
      if (normalized.isNotEmpty) {
        widget.onConversationUpdated(normalized);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e, st) {
      AppErrorHandler.logError('group-chat-save', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppErrorHandler.userMessage(
            e,
            fallback: 'Unable to save this conversation right now.',
          )),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.color?.withValues(alpha: 0.75);

    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final screenH = MediaQuery.of(context).size.height;
          final maxH = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : (screenH * 0.75);
          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
                top: 8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Change name and image',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed:
                            _saving ? null : () => Navigator.of(context).pop(),
                        icon: const Icon(LucideIcons.x),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: GestureDetector(
                      onTap: _saving ? null : _pickPhoto,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipOval(
                            child: Container(
                              width: 96,
                              height: 96,
                              color: cs.onSurface.withValues(alpha: 0.08),
                              child: _pickedBytes != null
                                  ? Image.memory(
                                      _pickedBytes!,
                                      fit: BoxFit.cover,
                                    )
                                  : (widget.groupAvatarUrl?.trim().isNotEmpty ==
                                          true)
                                      ? SafeNetworkImage(
                                          url: widget.groupAvatarUrl!,
                                          width: 96,
                                          height: 96,
                                          fit: BoxFit.cover,
                                        )
                                      : widget.groupAvatarStackBuilder(
                                          widget.participants,
                                          96,
                                        ),
                            ),
                          ),
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: cs.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.scaffoldBackgroundColor,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                LucideIcons.camera,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 56,
                    child: TextField(
                      controller: _nameController,
                      maxLines: 1,
                      expands: false,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: 'Group name',
                        hintText: 'Enter group name',
                        filled: true,
                        fillColor: cs.onSurface.withValues(alpha: 0.06),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _saving
                                ? null
                                : () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _saving ? null : _save,
                            child: Text(_saving ? 'Saving…' : 'Save'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (muted != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Tip: tap the photo to change it.',
                      style: TextStyle(color: muted),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
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
