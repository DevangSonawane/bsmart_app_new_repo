import {
  Check,
  ChevronDown,
  ChevronLeft,
  Info,
  ImagePlus,
  MessageCircle,
  Search,
  SendHorizontal,
  Smile,
  SquarePen,
  Sticker,
  UserMinus,
  X,
} from 'lucide-react';
import EmojiPicker from 'emoji-picker-react';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { Link, useLocation, useNavigate, useParams } from 'react-router-dom';
import VoiceMessageBubble from '../components/VoiceMessageBubble';
import VoiceRecorder from '../components/VoiceRecorder';
import PostDetailModal from '../components/PostDetailModal';
import * as chatService from '../services/chatService';
import { getFollowing } from '../services/followService';
import api from '../lib/api';
import {
  emitStopTyping,
  emitTyping,
  initChatSocket,
  joinRoom,
  leaveRoom,
  removeChatSocketCallbacks,
} from '../socket/chatSocket';
import {
  appendMessage,
  markConversationRead,
  removeMessage,
  setActiveConversation,
  setConversations,
  setHasMore,
  setIsLoadingConversations,
  setIsLoadingMessages,
  setMessages,
  setPage,
  setTypingUser,
  setUnreadCount,
  upsertConversation,
  updateLastMessage,
} from '../store/chatSlice';

const PAGE_LIMIT = 20;

const getUserId = (user) => user?._id || user?.id || '';
const getUserName = (user) => user?.full_name || user?.name || user?.username || 'User';
const getUserAvatar = (user) => user?.avatar_url || user?.profilePicture || user?.profile_picture || '';
const getInitial = (user) => getUserName(user).trim().charAt(0).toUpperCase() || 'U';
const isVideoUrl = (url = '') => /\.(mp4|mov|webm|ogg|m4v)$/i.test(url) || url.includes('.m3u8');
const getConversationAvatar = (conversation, currentUserId) => (
  conversation?.isGroup ? conversation?.groupAvatar : getUserAvatar(otherParticipant(conversation, currentUserId))
);
const getConversationTitle = (conversation, currentUserId) => {
  if (!conversation) return 'Conversation';
  if (conversation.isGroup) {
    const explicitName = typeof conversation.groupName === 'string' ? conversation.groupName.trim() : '';
    if (explicitName) return explicitName;

    const participantNames = getGroupParticipantNames(conversation, currentUserId);
    if (!participantNames.length) return 'Group';
    if (participantNames.length <= 2) return participantNames.join(', ');
    return `${participantNames.slice(0, 2).join(', ')} +${participantNames.length - 2}`;
  }
  return getUserName(otherParticipant(conversation, currentUserId));
};
const getGroupParticipantNames = (conversation, currentUserId) => (
  (conversation?.participants || [])
    .filter((user) => String(getUserId(user)) !== String(currentUserId))
    .map((user) => getUserName(user))
    .filter(Boolean)
);
const getGroupMemberLabel = (conversation, currentUserId, limit = 3) => {
  if (!conversation?.isGroup) return '';
  const names = getGroupParticipantNames(conversation, currentUserId);

  if (!names.length) return 'Only you';
  if (names.length <= limit) return names.join(', ');
  return `${names.slice(0, limit).join(', ')} +${names.length - limit} more`;
};
const getConversationSubtitle = (conversation, currentUserId, onlineUserIds = []) => {
  if (!conversation) return '';
  if (conversation.isGroup) {
    const memberCount = Math.max((conversation?.participants?.length || 0) - 1, 0);
    if (!memberCount) return 'Only you';
    if (memberCount === 1) return getGroupMemberLabel(conversation, currentUserId, 2);
    return `${memberCount} members`;
  }
  const otherUser = otherParticipant(conversation, currentUserId);
  const otherUserId = getUserId(otherUser);
  return onlineUserIds.includes(String(otherUserId)) ? 'Online' : getUserName(otherUser);
};
const isConversationRequestForMe = (conversation, currentUserId) => (
  Boolean(conversation?.isRequest)
  && conversation?.requestStatus === 'pending'
  && String(conversation?.requestedBy?._id || conversation?.requestedBy) !== String(currentUserId)
);
const canSendInConversation = (conversation, currentUserId) => (
  !conversation?.isRequest
  || conversation?.requestStatus !== 'pending'
  || String(conversation?.requestedBy?._id || conversation?.requestedBy) === String(currentUserId)
);

const formatAgo = (dateValue) => {
  if (!dateValue) return '';
  const diff = Date.now() - new Date(dateValue).getTime();
  const minutes = Math.floor(diff / 60000);
  if (minutes < 1) return 'now';
  if (minutes < 60) return `${minutes}m`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h`;
  const days = Math.floor(hours / 24);
  if (days < 7) return `${days}d`;
  return new Date(dateValue).toLocaleDateString('en-IN', { day: 'numeric', month: 'short' });
};

const formatSeenAgo = (dateValue) => {
  if (!dateValue) return 'Seen';
  const diff = Date.now() - new Date(dateValue).getTime();
  const minutes = Math.max(1, Math.floor(diff / 60000));
  if (minutes < 60) return `Seen ${minutes}m ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `Seen ${hours}h ago`;
  const days = Math.floor(hours / 24);
  if (days < 7) return `Seen ${days}d ago`;
  return `Seen ${new Date(dateValue).toLocaleDateString('en-IN', { day: 'numeric', month: 'short' })}`;
};

const formatSeparator = (dateValue) =>
  new Date(dateValue).toLocaleString('en-IN', {
    weekday: 'short',
    hour: 'numeric',
    minute: '2-digit',
    hour12: true,
  });

const otherParticipant = (conversation, currentUserId) =>
  conversation?.participants?.find((item) => String(item?._id) !== String(currentUserId))
  || conversation?.participants?.[0]
  || null;
const getMessageSender = (conversation, message, currentUserId) => {
  if (!conversation?.isGroup) return otherParticipant(conversation, currentUserId);
  const senderId = String(message?.sender?._id || message?.sender || '');
  return conversation?.participants?.find((item) => String(getUserId(item)) === senderId) || message?.sender || null;
};

const sortConversations = (conversations) =>
  [...conversations].sort((a, b) => new Date(b.lastMessageAt || 0) - new Date(a.lastMessageAt || 0));
const mergeUniqueConversations = (...lists) => {
  const map = new Map();
  lists.flat().forEach((conversation) => {
    const id = String(conversation?._id || conversation?.id || '');
    if (!id || map.has(id)) return;
    map.set(id, conversation);
  });
  return Array.from(map.values());
};
const isOutgoingPendingRequest = (conversation, currentUserId) => (
  Boolean(conversation?.isRequest)
  && conversation?.requestStatus === 'pending'
  && String(conversation?.requestedBy?._id || conversation?.requestedBy) === String(currentUserId)
);

const previousNonDeleted = (messages) => {
  for (let index = messages.length - 1; index >= 0; index -= 1) {
    if (!messages[index]?.isDeleted) return messages[index];
  }
  return null;
};

const hasUserSeenMessage = (message, userId) =>
  (message?.seenBy || []).some((entry) => String(entry?._id || entry) === String(userId));

const getOwnReaction = (message, userId) =>
  (message?.reactions || []).find((reaction) => String(reaction?.userId?._id || reaction?.userId) === String(userId)) || null;

const getReactionBadge = (message, userId) => {
  const reactions = message?.reactions || [];
  if (!reactions.length) return null;
  const ownReaction = getOwnReaction(message, userId);
  const primaryEmoji = ownReaction?.emoji || reactions[0]?.emoji || '';
  const count = reactions.length;
  return {
    label: count > 1 ? `${primaryEmoji} ${count}` : primaryEmoji,
    removable: Boolean(ownReaction),
  };
};
const extractSharedReelId = (sharedContent) => {
  if (!sharedContent || typeof sharedContent !== 'object') return '';
  const directId = sharedContent?.contentId?._id || sharedContent?.contentId;
  if (directId) return String(directId);
  const shareUrl = String(sharedContent?.shareUrl || '');
  const match = shareUrl.match(/\/reels\/([^/?#]+)/i);
  return match?.[1] ? String(match[1]) : '';
};
const getSharedContentId = (sharedContent) => String(
  sharedContent?.contentId?._id
  || sharedContent?.contentId
  || ''
).trim();
const getSharedCreatorId = (sharedContent) => String(
  sharedContent?.creatorId?._id
  || sharedContent?.creatorId
  || ''
).trim();
const getConversationSenderName = (conversation, message, currentUserId) => {
  const senderId = String(message?.sender?._id || message?.sender || '');
  if (!senderId) return 'User';
  if (String(senderId) === String(currentUserId)) return 'You';

  if (conversation?.isGroup) {
    const participants = Array.isArray(conversation?.participants) ? conversation.participants : [];
    const sender = participants.find((item) => String(getUserId(item)) === senderId);
    return getUserName(sender || message?.sender || {});
  }

  return getUserName(otherParticipant(conversation, currentUserId));
};
const isAttachmentLikeMessage = (message) => Boolean(
  message?.sharedContent?.contentType
  || message?.mediaUrl
  || message?.mediaType === 'audio'
);

const messagePreview = (message, isMine, name) => {
  if (!message) return 'Start chatting';
  if (message.isDeleted) return 'Message unsent';
  if (message.sharedContent?.contentType) {
    return isMine ? 'You sent an attachment.' : `${name} has send a attachedment`;
  }
  if (message.text) return isMine ? `You: ${message.text}` : message.text;
  if (message.mediaType === 'audio') return isMine ? 'You sent a voice message 🎤' : `${name} sent a voice message 🎤`;
  if (message.mediaUrl) return isMine ? 'You sent an attachment.' : `${name} has send a attachedment`;
  return 'Start chatting';
};

const mobileBubblePreview = (message, isMine, name) => {
  const preview = messagePreview(message, isMine, name);
  return preview.replace(/^You:\s*/i, '').replace(/\.$/, '');
};

const mobileListPreview = (message, isMine, name) => {
  if (!message) return 'Start chatting';
  if (message.isDeleted) return 'Message unsent';
  if (message.sharedContent?.contentType) {
    return isMine ? 'You sent an attachment.' : `${name} has send a attachedment`;
  }
  if (message.mediaType === 'audio') return isMine ? 'You sent a voice message 🎤' : `${name} sent a voice message 🎤`;
  if (message.mediaUrl) return isMine ? 'You sent an attachment.' : `${name} has send a attachedment`;
  if (message.text) return isMine ? `You: ${message.text}` : message.text;
  return 'Start chatting';
};

const isGroupSystemNotice = (message) => {
  const text = String(message?.text || '').trim().toLowerCase();
  if (!text) return false;
  return (
    text.includes('created the group')
    || text.includes('created this group')
    || /\badded\b/.test(text)
  );
};

const hasReplyContent = (replyTo) => Boolean(
  replyTo && (
    replyTo.messageId
    || (typeof replyTo.text === 'string' && replyTo.text.trim())
    || replyTo.senderId
    || (typeof replyTo.senderName === 'string' && replyTo.senderName.trim())
  )
);

const getConversationListMeta = (conversation, currentUserId, unread, isTyping, subtitle) => {
  if (isTyping) return 'Typing...';
  if (unread >= 4) return '4+ new messages';
  if (unread >= 2) return `${unread} new messages`;
  if (unread === 1) {
    const lastMessage = conversation?.lastMessage || null;
    if (!lastMessage) return '1 new message';

    const mine = String(lastMessage?.sender?._id || lastMessage?.sender) === String(currentUserId);
    const senderName = getConversationSenderName(conversation, lastMessage, currentUserId);
    const otherUser = otherParticipant(conversation, currentUserId);
    const messagePreviewText = mobileListPreview(lastMessage, mine, getUserName(otherUser));

    if (!isAttachmentLikeMessage(lastMessage) && messagePreviewText && messagePreviewText !== 'Start chatting') {
      return messagePreviewText;
    }
    return mine ? 'You sent an attachment' : `${senderName} has send a attachedment`;
  }

  const otherUser = otherParticipant(conversation, currentUserId);
  const mine = String(conversation?.lastMessage?.sender?._id || conversation?.lastMessage?.sender) === String(currentUserId);
  const messagePreviewText = mobileListPreview(conversation?.lastMessage, mine, getUserName(otherUser));

  if (messagePreviewText && messagePreviewText !== 'Start chatting') {
    return messagePreviewText;
  }

  if (conversation?.isRequest && conversation?.requestStatus === 'pending') {
    return String(conversation?.requestedBy?._id || conversation?.requestedBy) === String(currentUserId)
      ? 'Sent request'
      : 'Message request';
  }

  return subtitle || 'Start chatting';
};

const Avatar = ({ user, className = 'h-10 w-10', src = '', alt = '' }) => {
  const avatar = src || getUserAvatar(user);
  const [imageFailed, setImageFailed] = useState(false);

  useEffect(() => {
    setImageFailed(false);
  }, [avatar]);

  if (avatar && !imageFailed) {
    return (
      <img
        src={avatar}
        alt={alt || getUserName(user)}
        onError={() => setImageFailed(true)}
        className={`${className} rounded-full object-cover border border-gray-100 dark:border-white/10`}
      />
    );
  }
  return (
    <div className={`${className} flex items-center justify-center rounded-full bg-gradient-to-br from-[#7C3AED] to-[#3B82F6] text-sm font-bold text-white shadow-sm`}>
      {getInitial(user)}
    </div>
  );
};

const MergedGroupAvatar = ({ conversation, currentUserId, className = 'h-10 w-10' }) => {
  const members = (conversation?.participants || [])
    .filter((item) => String(getUserId(item)) !== String(currentUserId))
    .slice(0, 2);

  if (members.length <= 1) {
    return (
      <Avatar
        user={members[0] || { full_name: conversation?.groupName || 'Group' }}
        src={getUserAvatar(members[0]) || conversation?.groupAvatar}
        alt={conversation?.groupName || 'Group'}
        className={className}
      />
    );
  }

  return (
    <div className={`${className} relative`}>
      <div className="absolute left-0 top-0 h-[72%] w-[72%] overflow-hidden rounded-full ring-2 ring-black md:ring-white dark:md:ring-[#0a0a0a]">
        <Avatar user={members[0]} src={getUserAvatar(members[0])} className="h-full w-full" />
      </div>
      <div className="absolute bottom-0 right-0 h-[72%] w-[72%] overflow-hidden rounded-full ring-2 ring-black md:ring-white dark:md:ring-[#0a0a0a]">
        <Avatar user={members[1]} src={getUserAvatar(members[1])} className="h-full w-full" />
      </div>
    </div>
  );
};

const TypingIndicator = () => (
  <div className="mb-3 flex items-end gap-2">
    <div className="w-7 h-7 flex-shrink-0" />
    <div
      className="flex items-center gap-1.5 rounded-2xl rounded-bl-md bg-gray-100 dark:bg-[#262626] px-4 py-3 border border-gray-200 dark:border-white/5"
      style={{ minWidth: '60px' }}
    >
      <span className="typing-dot bg-gray-400 dark:bg-gray-500" style={{ animationDelay: '0ms' }} />
      <span className="typing-dot bg-gray-400 dark:bg-gray-500" style={{ animationDelay: '200ms' }} />
      <span className="typing-dot bg-gray-400 dark:bg-gray-500" style={{ animationDelay: '400ms' }} />
    </div>
  </div>
);

const REACTION_EMOJIS = ['❤️', '😂', '😮', '😢', '😡', '👍'];

const ReactionPicker = ({ onSelect, mine }) => (
  <div
    className={`absolute ${mine ? 'right-0' : 'left-0'} -top-10 z-50 
                flex gap-1 rounded-full bg-white dark:bg-[#1a1a1a] border border-gray-200 dark:border-white/10 
                px-2 py-1.5 shadow-xl animate-in fade-in zoom-in duration-200`}
    onClick={(e) => e.stopPropagation()}
  >
    {REACTION_EMOJIS.map((emoji) => (
      <button
        key={emoji}
        onClick={() => onSelect(emoji)}
        className="text-base transition-transform hover:scale-125 active:scale-95 leading-none"
      >
        {emoji}
      </button>
    ))}
  </div>
);

const MessageActions = ({ message, mine, onReply, onReact, onMore }) => (
  <div
    className={`flex items-center gap-0.5 opacity-0 group-hover/msg:opacity-100 
                transition-opacity duration-150 flex-shrink-0
                ${mine ? 'flex-row' : 'flex-row-reverse'}`}
    onClick={(e) => e.stopPropagation()}
  >
    <button
      onClick={(e) => onMore(e, message)}
      className="rounded-full p-1.5 text-gray-500 hover:text-gray-900 dark:hover:text-white 
                 hover:bg-gray-100 dark:hover:bg-white/10 transition-colors"
      title="More"
    >
      <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
        <circle cx="5" cy="12" r="2"/><circle cx="12" cy="12" r="2"/><circle cx="19" cy="12" r="2"/>
      </svg>
    </button>
    <button
      onClick={() => onReply(message)}
      className="rounded-full p-1.5 text-gray-500 hover:text-gray-900 dark:hover:text-white 
                 hover:bg-gray-100 dark:hover:bg-white/10 transition-colors"
      title="Reply"
    >
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        <polyline points="9 17 4 12 9 7"/><path d="M20 18v-2a4 4 0 0 0-4-4H4"/>
      </svg>
    </button>
    <button
      onClick={() => onReact(message)}
      className="rounded-full p-1.5 text-gray-500 hover:text-gray-900 dark:hover:text-white 
                 hover:bg-gray-100 dark:hover:bg-white/10 transition-colors"
      title="React"
    >
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        <circle cx="12" cy="12" r="10"/><path d="M8 13s1.5 2 4 2 4-2 4-2"/>
        <line x1="9" y1="9" x2="9.01" y2="9"/><line x1="15" y1="9" x2="15.01" y2="9"/>
      </svg>
    </button>
  </div>
);

const GroupCreateModal = ({
  isOpen,
  onClose,
  onSubmit,
  users = [],
  loading = false,
}) => {
  const [groupName, setGroupName] = useState('');
  const [search, setSearch] = useState('');
  const [selectedIds, setSelectedIds] = useState([]);

  useEffect(() => {
    if (!isOpen) {
      setGroupName('');
      setSearch('');
      setSelectedIds([]);
    }
  }, [isOpen]);

  const filteredUsers = useMemo(() => {
    const query = search.trim().toLowerCase();
    if (!query) return users;
    return users.filter((user) => (
      [getUserName(user), user?.username].filter(Boolean).some((value) => value.toLowerCase().includes(query))
    ));
  }, [search, users]);
  const isGroup = selectedIds.length > 1;

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-[130] flex items-center justify-center bg-black/70 px-4 backdrop-blur-sm" onClick={onClose}>
      <div
        className="flex max-h-[80vh] w-full max-w-[610px] flex-col overflow-hidden rounded-[28px] bg-[#24252b] text-white shadow-2xl"
        onClick={(event) => event.stopPropagation()}
      >
        <div className="flex items-center justify-between border-b border-white/10 px-5 py-4">
          <div className="w-8" />
          <p className="text-xl font-bold tracking-tight">New message</p>
          <button onClick={onClose} className="rounded-full p-2 text-white/70 transition hover:bg-white/5 hover:text-white">
            <X size={18} />
          </button>
        </div>

        <div className="border-b border-white/10 px-5 py-3">
          <div className="flex items-center gap-3 text-sm">
            <span className="font-semibold text-white">To:</span>
            <div className="min-w-0 flex flex-1 flex-wrap items-center gap-2">
              {selectedIds.map((userId) => {
                const user = users.find((item) => String(getUserId(item)) === String(userId));
                if (!user) return null;
                return (
                  <span key={userId} className="inline-flex items-center gap-1 rounded-full bg-[#34353c] px-2.5 py-1 text-xs font-semibold text-white">
                    {user?.username || getUserName(user)}
                    <button
                      type="button"
                      onClick={() => setSelectedIds((prev) => prev.filter((id) => id !== userId))}
                      className="text-white/70 hover:text-white"
                    >
                      <X size={12} />
                    </button>
                  </span>
                );
              })}
              <input
                value={search}
                onChange={(event) => setSearch(event.target.value)}
                placeholder="Search..."
                className="min-w-[140px] flex-1 bg-transparent text-sm text-white outline-none placeholder:text-white/35"
              />
            </div>
          </div>
          {isGroup ? (
            <input
              value={groupName}
              onChange={(event) => setGroupName(event.target.value)}
              placeholder="Group name"
              className="mt-3 w-full rounded-xl border border-white/10 bg-[#1b1c21] px-4 py-3 text-sm outline-none transition focus:border-white/20"
            />
          ) : null}
        </div>

        <div className="flex-1 overflow-y-auto px-0 pb-3">
          {filteredUsers.map((user) => {
            const userId = getUserId(user);
            const selected = selectedIds.includes(userId);
            return (
              <button
                key={userId}
                type="button"
                onClick={() => setSelectedIds((prev) => (
                  selected
                    ? prev.filter((id) => id !== userId)
                    : [...prev.filter((id) => id !== userId), userId]
                ))}
                className="flex w-full items-center gap-3 px-5 py-3 text-left transition hover:bg-white/5"
              >
                <Avatar user={user} className="h-11 w-11" />
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm font-semibold text-white">{getUserName(user)}</p>
                  <p className="truncate text-xs text-white/60">@{user?.username || 'user'}</p>
                </div>
                <span className={`flex h-7 w-7 items-center justify-center rounded-full border text-xs ${
                  selected
                    ? 'border-white bg-white text-[#24252b]'
                    : 'border-white/70 text-transparent'
                }`}>
                  <Check size={14} />
                </span>
              </button>
            );
          })}
          {!filteredUsers.length ? (
            <div className="px-4 py-8 text-center text-sm text-white/55">No following users found.</div>
          ) : null}
        </div>

        <div className="border-t border-white/10 px-5 py-4">
          <button
            type="button"
            disabled={loading || selectedIds.length === 0}
            onClick={() => onSubmit({ groupName: groupName.trim(), participantIds: selectedIds })}
            className="w-full rounded-2xl bg-[#2a2f9f] px-5 py-3 text-sm font-bold text-white transition hover:bg-[#3137b5] disabled:cursor-not-allowed disabled:opacity-50"
          >
            {loading ? 'Please wait...' : (isGroup ? 'Create group' : 'Chat')}
          </button>
        </div>
      </div>
    </div>
  );
};

const GroupManageModal = ({
  isOpen,
  onClose,
  conversation,
  currentUserId,
  followingUsers = [],
  onSave,
  onAddMember,
  onRemoveMember,
  onLeaveChat,
  onDeleteChat,
  loading = false,
}) => {
  const [groupName, setGroupName] = useState('');
  const [groupAvatar, setGroupAvatar] = useState('');
  const [search, setSearch] = useState('');
  const [showRenameModal, setShowRenameModal] = useState(false);
  const [renameDraft, setRenameDraft] = useState('');
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const [showLeaveConfirm, setShowLeaveConfirm] = useState(false);

  useEffect(() => {
    if (!isOpen) return;
    setGroupName(conversation?.groupName || '');
    setGroupAvatar(conversation?.groupAvatar || '');
    setSearch('');
    setShowRenameModal(false);
    setRenameDraft(conversation?.groupName || '');
    setShowDeleteConfirm(false);
    setShowLeaveConfirm(false);
  }, [conversation, isOpen]);

  const participantIds = useMemo(
    () => new Set((conversation?.participants || []).map((user) => String(getUserId(user)))),
    [conversation]
  );
  const groupAdminId = String(conversation?.groupAdmin?._id || conversation?.groupAdmin || '');
  const isAdmin = groupAdminId === String(currentUserId);
  const addableUsers = useMemo(() => {
    const query = search.trim().toLowerCase();
    return followingUsers.filter((user) => {
      const userId = String(getUserId(user));
      if (!userId || participantIds.has(userId)) return false;
      if (!query) return true;
      return [getUserName(user), user?.username].filter(Boolean).some((value) => value.toLowerCase().includes(query));
    });
  }, [followingUsers, participantIds, search]);

  if (!isOpen || !conversation) return null;

  return (
    <div className="fixed inset-0 z-[135] flex items-center justify-center bg-black/70 px-4 backdrop-blur-sm" onClick={onClose}>
      <div
        className="relative flex max-h-[85vh] w-full max-w-2xl flex-col overflow-hidden rounded-[28px] bg-white text-gray-900 shadow-2xl dark:bg-[#111111] dark:text-white"
        onClick={(event) => event.stopPropagation()}
      >
        <div className="flex items-center justify-between border-b border-gray-100 px-5 py-4 dark:border-white/10">
          <div>
            <p className="text-lg font-bold">Manage group</p>
            <p className="text-xs text-gray-500 dark:text-gray-400">{conversation?.participants?.length || 0} members</p>
          </div>
          <button onClick={onClose} className="rounded-full p-2 text-gray-400 transition hover:bg-gray-100 hover:text-gray-900 dark:hover:bg-white/5 dark:hover:text-white">
            <X size={18} />
          </button>
        </div>

        <div className="grid gap-5 overflow-y-auto p-5 md:grid-cols-[1.1fr,0.9fr]">
          <div className="space-y-4">
            <div className="rounded-2xl border border-gray-200 bg-gray-50 px-4 py-3 dark:border-white/10 dark:bg-[#181818]">
              <div className="flex items-center justify-between gap-3">
                <p className="text-base font-medium">Change group name</p>
                <button
                  type="button"
                  disabled={!isAdmin || loading}
                  onClick={() => {
                    setRenameDraft(groupName || conversation?.groupName || '');
                    setShowRenameModal(true);
                  }}
                  className="rounded-xl bg-gray-200 px-4 py-2 text-sm font-bold text-gray-900 transition hover:bg-gray-300 disabled:opacity-50 dark:bg-[#2b2f39] dark:text-white dark:hover:bg-[#353a45]"
                >
                  Change
                </button>
              </div>
            </div>

            <div>
              <p className="mb-3 text-sm font-semibold">Members</p>
              <div className="space-y-2">
                {(conversation?.participants || []).map((user) => {
                  const userId = getUserId(user);
                  const canRemove = isAdmin || String(userId) === String(currentUserId);
                  return (
                    <div key={userId} className="flex items-center gap-3 rounded-2xl bg-gray-50 px-3 py-3 dark:bg-[#181818]">
                      <Avatar user={user} className="h-10 w-10" />
                      <div className="min-w-0 flex-1">
                        <p className="truncate text-sm font-semibold">{getUserName(user)}</p>
                        <p className="truncate text-xs text-gray-500 dark:text-gray-400">
                          {String(userId) === groupAdminId ? 'Admin' : 'Member'}
                        </p>
                      </div>
                      {canRemove ? (
                        <button
                          type="button"
                          disabled={loading || String(userId) === groupAdminId && !isAdmin}
                          onClick={() => {
                            if (String(userId) === String(currentUserId)) {
                              onLeaveChat?.();
                            } else {
                              onRemoveMember(String(userId));
                            }
                          }}
                          className="rounded-full border border-gray-200 px-3 py-1.5 text-xs font-semibold text-gray-600 transition hover:bg-gray-100 disabled:opacity-50 dark:border-white/10 dark:text-gray-300 dark:hover:bg-white/5"
                        >
                          {String(userId) === String(currentUserId) ? 'Leave' : 'Remove'}
                        </button>
                      ) : null}
                    </div>
                  );
                })}
              </div>
            </div>
          </div>

          <div className="space-y-3">
            <p className="text-sm font-semibold">Add members</p>
            <div className="flex items-center gap-3 rounded-2xl border border-gray-200 bg-gray-50 px-4 py-3 text-sm text-gray-500 dark:border-white/10 dark:bg-[#181818] dark:text-gray-400">
              <Search size={16} />
              <input
                value={search}
                onChange={(event) => setSearch(event.target.value)}
                disabled={!isAdmin || loading}
                placeholder="Search following"
                className="w-full bg-transparent outline-none"
              />
            </div>
            <div className="max-h-[360px] space-y-2 overflow-y-auto">
              {addableUsers.map((user) => {
                const userId = getUserId(user);
                return (
                  <div key={userId} className="flex items-center gap-3 rounded-2xl bg-gray-50 px-3 py-3 dark:bg-[#181818]">
                    <Avatar user={user} className="h-10 w-10" />
                    <div className="min-w-0 flex-1">
                      <p className="truncate text-sm font-semibold">{getUserName(user)}</p>
                      <p className="truncate text-xs text-gray-500 dark:text-gray-400">@{user?.username || 'user'}</p>
                    </div>
                    <button
                      type="button"
                      disabled={!isAdmin || loading}
                      onClick={() => onAddMember(String(userId))}
                      className="rounded-full bg-gray-900 px-3 py-1.5 text-xs font-semibold text-white transition hover:bg-black disabled:opacity-50 dark:bg-white dark:text-black dark:hover:bg-gray-200"
                    >
                      Add
                    </button>
                  </div>
                );
              })}
              {!addableUsers.length ? (
                <div className="rounded-2xl bg-gray-50 px-4 py-6 text-center text-sm text-gray-500 dark:bg-[#181818] dark:text-gray-400">
                  {isAdmin ? 'No more following users available to add.' : 'Only the group admin can add members.'}
                </div>
              ) : null}
            </div>
          </div>
        </div>

        <div className="border-t border-gray-100 px-5 py-5 dark:border-white/10">
          <button
            type="button"
            disabled={loading}
            onClick={() => setShowLeaveConfirm(true)}
            className="text-left text-[16px] font-semibold text-red-400 transition hover:text-red-300 disabled:opacity-50"
          >
            Leave Chat
          </button>
          <p className="mt-3 max-w-3xl text-[14px] leading-8 text-gray-500 dark:text-gray-400">
            You won't be able to send or receive messages unless someone adds you back to the chat. No one will be notified that you left the chat.
          </p>
          <button
            type="button"
            disabled={loading}
            onClick={() => setShowDeleteConfirm(true)}
            className="mt-6 text-left text-[16px] font-semibold text-red-400 transition hover:text-red-300 disabled:opacity-50"
          >
            Delete Chat
          </button>
          <p className="mt-3 max-w-3xl text-[14px] leading-8 text-gray-500 dark:text-gray-400">
            This will remove the chat from your inbox and erase the chat history
          </p>
        </div>

        {showRenameModal ? (
          <div className="absolute inset-0 z-[10] flex items-center justify-center bg-black/70 px-4" onClick={() => setShowRenameModal(false)}>
            <div
              className="w-full max-w-[620px] overflow-hidden rounded-[24px] border border-white/10 bg-[#1f222b] text-white shadow-2xl"
              onClick={(event) => event.stopPropagation()}
            >
              <div className="relative border-b border-white/10 px-5 py-4 text-center">
                <button
                  type="button"
                  onClick={() => setShowRenameModal(false)}
                  className="absolute left-5 top-1/2 -translate-y-1/2 text-white/90 hover:text-white"
                  aria-label="Close"
                >
                  <X size={30} strokeWidth={2} />
                </button>
                <p className="text-[30px] font-semibold">Change group name</p>
              </div>

              <div className="px-5 py-4">
                <p className="mb-4 text-xl text-white/90">
                  Changing the name of a group chat changes it for everyone.
                </p>
                <div className="rounded-xl border border-white/20 bg-transparent px-3 py-2.5">
                  <p className="text-xs text-white/60">Group name</p>
                  <input
                    value={renameDraft}
                    onChange={(event) => setRenameDraft(event.target.value)}
                    disabled={!isAdmin || loading}
                    className="mt-1 w-full bg-transparent text-3xl font-medium outline-none disabled:opacity-60"
                  />
                </div>
              </div>

              <div className="border-t border-white/10 px-5 py-4">
                <button
                  type="button"
                  disabled={!isAdmin || loading || !renameDraft.trim()}
                  onClick={() => {
                    const nextGroupName = renameDraft.trim();
                    setGroupName(nextGroupName);
                    onSave({ groupName: nextGroupName, groupAvatar: groupAvatar.trim() });
                    setShowRenameModal(false);
                  }}
                  className="w-full rounded-2xl bg-[#2429a8] px-5 py-3.5 text-2xl font-bold text-white transition hover:bg-[#2b31bf] disabled:opacity-50"
                >
                  Save
                </button>
              </div>
            </div>
          </div>
        ) : null}

        {showLeaveConfirm ? (
          <div className="absolute inset-0 z-[12] flex items-center justify-center bg-black/70 px-4" onClick={() => setShowLeaveConfirm(false)}>
            <div
              className="w-full max-w-[620px] overflow-hidden rounded-[24px] border border-white/10 bg-[#1f222b] text-white shadow-2xl"
              onClick={(event) => event.stopPropagation()}
            >
              <div className="border-b border-white/10 px-6 py-5 text-center">
                <p className="text-3xl font-semibold leading-tight">Leave chat?</p>
                <p className="mx-auto mt-3 max-w-[560px] text-[14px] leading-7 text-white/60">
                  You won't be able to send or receive messages unless someone adds you back to the chat. No one will be notified that you left the chat.
                </p>
              </div>
              <button
                type="button"
                disabled={loading}
                onClick={() => {
                  setShowLeaveConfirm(false);
                  onLeaveChat?.();
                }}
                className="w-full border-b border-white/10 px-6 py-4 text-xl font-semibold text-red-400 transition hover:bg-white/5 disabled:opacity-50"
              >
                Leave
              </button>
              <button
                type="button"
                disabled={loading}
                onClick={() => setShowLeaveConfirm(false)}
                className="w-full px-6 py-4 text-xl font-medium text-white/85 transition hover:bg-white/5 disabled:opacity-50"
              >
                Cancel
              </button>
            </div>
          </div>
        ) : null}

        {showDeleteConfirm ? (
          <div className="absolute inset-0 z-[11] flex items-center justify-center bg-black/70 px-4" onClick={() => setShowDeleteConfirm(false)}>
            <div
              className="w-full max-w-[620px] overflow-hidden rounded-[24px] border border-white/10 bg-[#1f222b] text-white shadow-2xl"
              onClick={(event) => event.stopPropagation()}
            >
              <div className="border-b border-white/10 px-6 py-5 text-center">
                <p className="text-3xl font-semibold leading-tight">Delete chat from inbox?</p>
                <p className="mx-auto mt-3 max-w-[560px] text-[14px] leading-7 text-white/60">
                  This will remove the chat from your inbox and erase the chat history.
                </p>
              </div>
              <button
                type="button"
                disabled={loading}
                onClick={() => {
                  setShowDeleteConfirm(false);
                  onDeleteChat?.();
                }}
                className="w-full border-b border-white/10 px-6 py-4 text-xl font-semibold text-red-400 transition hover:bg-white/5 disabled:opacity-50"
              >
                Delete
              </button>
              <button
                type="button"
                disabled={loading}
                onClick={() => setShowDeleteConfirm(false)}
                className="w-full px-6 py-4 text-xl font-medium text-white/85 transition hover:bg-white/5 disabled:opacity-50"
              >
                Cancel
              </button>
            </div>
          </div>
        ) : null}
      </div>
    </div>
  );
};

export default function ChatPage() {
  const dispatch = useDispatch();
  const navigate = useNavigate();
  const location = useLocation();
  const { conversationId: conversationIdFromUrl } = useParams();
  const fileInputRef = useRef(null);
  const inputRef = useRef(null);
  const scrollerRef = useRef(null);
  const stopTypingRef = useRef(null);
  const roomRef = useRef(null);
  const contextRef = useRef(null);
  const emojiPickerRef = useRef(null);
  const longPressRef = useRef(null);
  const activeConversationIdRef = useRef(null);
  const chatPageCallbacksRef = useRef(null);
  const onNewMessageRef = useRef(null);
  const onMessageRemovedRef = useRef(null);
  const onMessageReactionUpdateRef = useRef(null);
  const messagesRef = useRef([]);
  const unreadCountsRef = useRef({});
  const currentUserIdRef = useRef('');
  const fetchConversationsPromiseRef = useRef(null);
  const activatingConversationRef = useRef({ conversationId: '', promise: null });
  const fetchedSharedReelIdsRef = useRef(new Set());

  const [search, setSearch] = useState('');
  const [input, setInput] = useState('');
  const [replyTo, setReplyTo] = useState(null);
  const [contextMenu, setContextMenu] = useState(null);
  const [uploading, setUploading] = useState(false);
  const [sending, setSending] = useState(false);
  const [isRecording, setIsRecording] = useState(false);
  const [showEmojiPicker, setShowEmojiPicker] = useState(false);
  const [reactionPickerFor, setReactionPickerFor] = useState(null);
  const [hoveredMessageId, setHoveredMessageId] = useState(null);
  const [conversationType, setConversationType] = useState('normal');
  const [onlineUserIds, setOnlineUserIds] = useState([]);
  const [showGroupModal, setShowGroupModal] = useState(false);
  const [showManageGroupModal, setShowManageGroupModal] = useState(false);
  const [groupMembers, setGroupMembers] = useState([]);
  const [loadingGroupMembers, setLoadingGroupMembers] = useState(false);
  const [creatingGroup, setCreatingGroup] = useState(false);
  const [groupActionLoading, setGroupActionLoading] = useState(false);
  const [sharedReelMetaMap, setSharedReelMetaMap] = useState({});
  const [sharedDetailItem, setSharedDetailItem] = useState(null);
  const [showTopbarLeaveConfirm, setShowTopbarLeaveConfirm] = useState(false);

  const closeActiveChat = useCallback(() => {
    dispatch(setActiveConversation(null));
    dispatch(setMessages([]));
    navigate('/messages');
  }, [dispatch, navigate]);

  const {
    conversations, activeConversation, messages, page, hasMore,
    isLoadingConversations, isLoadingMessages, typingUsers, unreadCounts,
  } = useSelector((state) => state.chat);
  const { userObject } = useSelector((state) => state.auth);
  const { mode } = useSelector((state) => state.theme);

  const currentUserId = getUserId(userObject);
  const token = localStorage.getItem('token');
  const initialConversation = location.state?.conversation || null;
  const activeId = activeConversation?._id || conversationIdFromUrl || null;
  const otherUser = useMemo(() => otherParticipant(activeConversation, currentUserId), [activeConversation, currentUserId]);
  const activeTyping = (typingUsers[activeId] || []).filter((id) => String(id) !== String(currentUserId));
  const otherUserId = getUserId(otherUser);
  const currentUserLabel = userObject?.username || getUserName(userObject);
  const activeConversationTitle = getConversationTitle(activeConversation, currentUserId);
  const activeConversationSubtitle = getConversationSubtitle(activeConversation, currentUserId, onlineUserIds);
  const activeConversationCanSend = canSendInConversation(activeConversation, currentUserId);
  const activeConversationIsRequestForMe = isConversationRequestForMe(activeConversation, currentUserId);
  const activeConversationIsGroupAdmin = String(activeConversation?.groupAdmin?._id || activeConversation?.groupAdmin || '') === String(currentUserId);
  const isRequestsView = conversationType === 'requests';
  const requestCount = conversations.length;

  useEffect(() => { activeConversationIdRef.current = activeId; }, [activeId]);
  useEffect(() => { messagesRef.current = messages; }, [messages]);
  useEffect(() => { unreadCountsRef.current = unreadCounts; }, [unreadCounts]);
  useEffect(() => { currentUserIdRef.current = currentUserId; }, [currentUserId]);

  const filteredConversations = useMemo(() => {
    const query = search.trim().toLowerCase();
    if (!query) return conversations;
    return conversations.filter((conversation) => {
      const other = otherParticipant(conversation, currentUserId);
      return [
        getConversationTitle(conversation, currentUserId),
        getUserName(other),
        other?.username,
      ].filter(Boolean).some((value) => value.toLowerCase().includes(query));
    });
  }, [conversations, currentUserId, search]);

  const onlineConversations = useMemo(() => (
    conversations.filter((conversation) => {
      if (conversation?.isGroup) return false;
      const user = otherParticipant(conversation, currentUserId);
      const userId = getUserId(user);
      return Boolean(userId) && onlineUserIds.includes(String(userId));
    })
  ), [conversations, currentUserId, onlineUserIds]);

  const groupedMessages = useMemo(() => {
    const result = [];
    let lastLabel = '';
    messages.forEach((message, index) => {
      const label = formatSeparator(message.createdAt);
      if (label !== lastLabel) {
        result.push({ type: 'separator', id: `sep-${label}-${index}`, label });
        lastLabel = label;
      }
      result.push({ type: 'message', message });
    });
    return result;
  }, [messages]);

  const showGroupProfileIntro = useMemo(() => {
    if (!activeConversation?.isGroup) return false;
    return !messages.some((message) => {
      if (message?.isDeleted) return false;
      if (message?.mediaUrl || message?.mediaType === 'audio') return true;
      const text = String(message?.text || '').trim().toLowerCase();
      if (!text) return false;
      const isSystemMessage = (
        text.includes('created the group')
        || text.includes('created this group')
        || /\badded\b/.test(text)
      );
      return !isSystemMessage;
    });
  }, [activeConversation?.isGroup, messages]);

  const setConversationAsActive = useCallback(async (conversation, options = {}) => {
    if (!conversation?._id || !currentUserId) return;
    const { skipNavigation = false, forceReload = false } = options;
    const conversationId = String(conversation._id);

    if (!skipNavigation && String(activeConversationIdRef.current || '') !== conversationId) {
      navigate(`/messages/${conversation._id}`);
    }

    dispatch(setActiveConversation(conversation));
    dispatch(markConversationRead(conversation._id));

    if (
      !forceReload
      && String(activeConversationIdRef.current || '') === conversationId
      && messagesRef.current.length > 0
    ) {
      return;
    }

    if (activatingConversationRef.current.conversationId === conversationId && activatingConversationRef.current.promise) {
      return activatingConversationRef.current.promise;
    }

    dispatch(setActiveConversation(conversation));
    dispatch(markConversationRead(conversation._id));
    dispatch(setMessages([]));
    dispatch(setPage(1));
    dispatch(setHasMore(true));
    dispatch(setIsLoadingMessages(true));

    const request = (async () => {
      try {
        const response = await chatService.getMessages(conversation._id, 1, PAGE_LIMIT);
        if (String(activeConversationIdRef.current || conversationId) !== conversationId) return;
        dispatch(setMessages([...(response?.messages || [])].reverse()));
        dispatch(setHasMore(Boolean(response?.hasMore)));
        dispatch(setPage(1));
        dispatch(markConversationRead(conversation._id));
      } catch (error) {
        console.error('Failed to load messages:', error);
        if (String(activeConversationIdRef.current || conversationId) !== conversationId) return;
        dispatch(setMessages([]));
        dispatch(setHasMore(false));
      } finally {
        if (String(activeConversationIdRef.current || conversationId) === conversationId) {
          dispatch(setIsLoadingMessages(false));
        }
        if (activatingConversationRef.current.promise === request) {
          activatingConversationRef.current = { conversationId: '', promise: null };
        }
      }
    })();

    activatingConversationRef.current = { conversationId, promise: request };
    return request;
  }, [currentUserId, dispatch, navigate]);

  const refreshOnlineUsers = useCallback(async (items = []) => {
    const targetIds = items
      .filter((conversation) => !conversation?.isGroup)
      .map((conversation) => getUserId(otherParticipant(conversation, currentUserId)))
      .filter(Boolean);

    if (!targetIds.length) {
      setOnlineUserIds([]);
      return;
    }

    try {
      const response = await chatService.getOnlineUsers(targetIds);
      setOnlineUserIds(Array.isArray(response?.onlineUserIds) ? response.onlineUserIds.map(String) : []);
    } catch (error) {
      console.error('Failed to load online users:', error);
    }
  }, [currentUserId]);

  const fetchConversations = useCallback(async () => {
    if (fetchConversationsPromiseRef.current) {
      return fetchConversationsPromiseRef.current;
    }

    const request = (async () => {
      dispatch(setIsLoadingConversations(true));
      try {
        let ordered = [];
        if (conversationType === 'normal') {
          const [normalData, requestsData] = await Promise.all([
            chatService.getConversations('normal').catch(() => []),
            chatService.getConversations('requests').catch(() => []),
          ]);
          const normalList = Array.isArray(normalData) ? normalData : [];
          const requestsList = Array.isArray(requestsData) ? requestsData : [];
          const outgoingRequests = requestsList.filter((conversation) => isOutgoingPendingRequest(conversation, currentUserId));
          ordered = sortConversations(mergeUniqueConversations(normalList, outgoingRequests));
        } else {
          const requestOnly = await chatService.getConversations(conversationType);
          ordered = sortConversations(requestOnly || []);
        }
        dispatch(setConversations(ordered));
        refreshOnlineUsers(ordered);
        return ordered;
      } catch (error) {
        console.error('Failed to load conversations:', error);
        dispatch(setConversations([]));
        setOnlineUserIds([]);
        return [];
      } finally {
        dispatch(setIsLoadingConversations(false));
        if (fetchConversationsPromiseRef.current === request) {
          fetchConversationsPromiseRef.current = null;
        }
      }
    })();

    fetchConversationsPromiseRef.current = request;
    return request;
  }, [conversationType, currentUserId, dispatch, refreshOnlineUsers]);

  const markLatestSeen = useCallback(async (items = messages, conversation = activeConversation) => {
    if (!conversation?._id || !currentUserId) return;
    const latest = [...items].reverse().find((message) => (
      !message.isDeleted
      && String(message?.sender?._id || message?.sender) !== String(currentUserId)
      && !(message.seenBy || []).some((id) => String(id?._id || id) === String(currentUserId))
    ));
    if (!latest?._id) return;
    try {
      const updatedMessage = await chatService.markMessageSeen(latest._id);
      const nextMessages = items.map((message) => (message._id === latest._id ? { ...message, ...updatedMessage } : message));
      messagesRef.current = nextMessages;
      dispatch(setMessages(nextMessages));
    } catch (error) {
      console.error('Failed to mark seen:', error);
    }
  }, [activeConversation, currentUserId, dispatch, messages]);

  const refreshConversationOrdering = useCallback((conversationId, lastMessage, lastMessageAt) => {
    dispatch(updateLastMessage({ conversationId, lastMessage, lastMessageAt }));
  }, [dispatch]);

  const syncConversationPreview = useCallback((conversation, lastMessage) => {
    if (!conversation?._id) return;
    dispatch(upsertConversation({
      ...conversation,
      lastMessage: lastMessage || conversation.lastMessage || null,
      lastMessageAt: lastMessage?.createdAt || conversation.lastMessageAt || new Date().toISOString(),
      unreadCount: 0,
    }));
  }, [dispatch]);

  const onNewMessage = useCallback(async (message) => {
    const incomingConversationId = String(message?.conversationId?._id || message?.conversationId?.id || message?.conversationId || '');
    if (!incomingConversationId) return;
    refreshConversationOrdering(incomingConversationId, message, message.createdAt || new Date().toISOString());
    if (!conversations.some((conversation) => String(conversation._id) === incomingConversationId)) {
      fetchConversations();
    }
    const currentActiveConversationId = String(roomRef.current || activeConversationIdRef.current || conversationIdFromUrl || '');
    if (currentActiveConversationId === incomingConversationId) {
      const existingMessages = messagesRef.current || [];
      const nextMessages = existingMessages.some((item) => item._id === message._id)
        ? existingMessages.map((item) => (item._id === message._id ? { ...item, ...message } : item))
        : [...existingMessages, message];
      messagesRef.current = nextMessages;
      dispatch(setMessages(nextMessages));
      dispatch(markConversationRead(incomingConversationId));
      if (String(message?.sender?._id || message?.sender || message?.senderId) !== String(currentUserIdRef.current)) {
        try {
          const updatedMessage = await chatService.markMessageSeen(message._id);
          const seenMessages = messagesRef.current.map((item) => (item._id === message._id ? { ...item, ...updatedMessage } : item));
          messagesRef.current = seenMessages;
          dispatch(setMessages(seenMessages));
        } catch (error) { console.error('Failed to auto-mark seen:', error); }
      }
      return;
    }
    dispatch(setUnreadCount({ conversationId: incomingConversationId, count: (unreadCountsRef.current[incomingConversationId] || 0) + 1 }));
  }, [conversations, dispatch, fetchConversations, refreshConversationOrdering]);

  useEffect(() => { onNewMessageRef.current = onNewMessage; }, [onNewMessage]);

  const onMessageRemoved = useCallback(({ conversationId, messageId }) => {
    dispatch(removeMessage({ messageId, deletedAt: new Date().toISOString() }));
    if (!messagesRef.current.some((item) => item._id === messageId)) return;
    const nextMessages = messagesRef.current.map((item) => (item._id === messageId ? { ...item, isDeleted: true, deletedAt: new Date().toISOString() } : item));
    messagesRef.current = nextMessages;
    dispatch(setMessages(nextMessages));
    if (String(activeConversationIdRef.current || '') !== String(conversationId || '')) return;
    const lastVisible = previousNonDeleted(nextMessages);
    refreshConversationOrdering(conversationId, lastVisible, lastVisible?.createdAt || activeConversation?.createdAt);
  }, [activeConversation?.createdAt, dispatch, refreshConversationOrdering]);

  useEffect(() => { onMessageRemovedRef.current = onMessageRemoved; }, [onMessageRemoved]);

  const onMessageReactionUpdate = useCallback(({ messageId, reactions: nextReactions }) => {
    if (!messageId || !messagesRef.current.some((message) => message._id === messageId)) return;
    const nextMessages = messagesRef.current.map((message) => (
      message._id === messageId ? { ...message, reactions: Array.isArray(nextReactions) ? nextReactions : [] } : message
    ));
    messagesRef.current = nextMessages;
    dispatch(setMessages(nextMessages));
  }, [dispatch]);

  useEffect(() => { onMessageReactionUpdateRef.current = onMessageReactionUpdate; }, [onMessageReactionUpdate]);

  useEffect(() => {
    if (!token) return undefined;
    const callbacks = {
      onNewMessage: (...args) => onNewMessageRef.current?.(...args),
      onUserTyping: ({ conversationId, userId: typingUserId }) =>
        dispatch(setTypingUser({ conversationId, userId: typingUserId, isTyping: true })),
      onUserStopTyping: ({ conversationId, userId: typingUserId }) =>
        dispatch(setTypingUser({ conversationId, userId: typingUserId, isTyping: false })),
      onMessageSeenUpdate: ({ conversationId, messageId, userId: seenUserId, seenAt }) => {
        if (!messagesRef.current.some((m) => m._id === messageId)) return;
        const nextMessages = messagesRef.current.map((m) =>
          m._id === messageId
            ? { ...m, seenBy: Array.from(new Set([...(m.seenBy || []), seenUserId])), seenAt: seenAt || m.seenAt }
            : m
        );
        messagesRef.current = nextMessages;
        dispatch(setMessages(nextMessages));
      },
      onMessageReactionUpdate: (...args) => onMessageReactionUpdateRef.current?.(...args),
      onMessageRemoved: (...args) => onMessageRemovedRef.current?.(...args),
      onGroupMemberAdded: () => { fetchConversations(); },
      onGroupMemberRemoved: () => { fetchConversations(); },
      onOnlineUsersUpdated: ({ onlineUserIds: nextOnlineUserIds = [] }) => {
        setOnlineUserIds(Array.isArray(nextOnlineUserIds) ? nextOnlineUserIds.map(String) : []);
      },
    };
    chatPageCallbacksRef.current = callbacks;
    initChatSocket(token, callbacks, currentUserId);
    return () => {
      if (roomRef.current) leaveRoom(roomRef.current);
      roomRef.current = null;
      if (chatPageCallbacksRef.current) removeChatSocketCallbacks(chatPageCallbacksRef.current);
    };
  }, [currentUserId, dispatch, fetchConversations, token]);

  useEffect(() => {
    if (!activeId) return undefined;
    if (roomRef.current && roomRef.current !== activeId) leaveRoom(roomRef.current);
    roomRef.current = activeId;
    joinRoom(activeId);
    return () => {
      if (roomRef.current === activeId) { leaveRoom(activeId); roomRef.current = null; }
    };
  }, [activeId]);

  useEffect(() => {
    let cancelled = false;

    const loadPage = async () => {
      const loaded = await fetchConversations();
      if (cancelled) return;

      if (!conversationIdFromUrl) {
        dispatch(setActiveConversation(null));
        dispatch(setMessages([]));
        return;
      }

      const conversation = loaded.find((item) => item._id === conversationIdFromUrl);
      if (conversation) {
        await setConversationAsActive(conversation, { skipNavigation: true });
        return;
      }

      if (initialConversation?._id === conversationIdFromUrl) {
        await setConversationAsActive(initialConversation, { skipNavigation: true });
        return;
      }

      if (conversationType === 'requests') {
        dispatch(setActiveConversation(null));
        dispatch(setMessages([]));
      }
    };

    loadPage();

    return () => {
      cancelled = true;
    };
  }, [conversationIdFromUrl, conversationType, dispatch, fetchConversations, initialConversation, setConversationAsActive]);

  useEffect(() => {
    if (!conversationIdFromUrl || activeConversation?._id === conversationIdFromUrl) return;
    if (activatingConversationRef.current.conversationId === String(conversationIdFromUrl)) return;
    const conversation = conversations.find((item) => item._id === conversationIdFromUrl);
    if (conversation) setConversationAsActive(conversation, { skipNavigation: true });
  }, [activeConversation?._id, conversationIdFromUrl, conversations, setConversationAsActive]);

  useEffect(() => {
    const handleGlobalEsc = (event) => {
      if (event.key !== 'Escape') return;
      if (!activeConversation?._id) return;
      event.preventDefault();
      closeActiveChat();
    };

    window.addEventListener('keydown', handleGlobalEsc);
    return () => window.removeEventListener('keydown', handleGlobalEsc);
  }, [activeConversation?._id, closeActiveChat]);

  useEffect(() => {
    refreshOnlineUsers(conversations);
  }, [conversations, refreshOnlineUsers]);

  useEffect(() => {
    if (!conversations.length) return undefined;
    const interval = setInterval(() => refreshOnlineUsers(conversations), 20000);
    return () => clearInterval(interval);
  }, [conversations, refreshOnlineUsers]);

  useEffect(() => {
    if (!scrollerRef.current || !activeId) return;
    scrollerRef.current.scrollTop = scrollerRef.current.scrollHeight;
  }, [activeId, messages.length, activeTyping.length]);

  useEffect(() => {
    if (messages.length && activeConversation?._id) markLatestSeen(messages, activeConversation);
  }, [activeConversation, markLatestSeen, messages]);

  useEffect(() => {
    const handler = (event) => { if (contextRef.current && !contextRef.current.contains(event.target)) setContextMenu(null); };
    window.addEventListener('click', handler);
    return () => window.removeEventListener('click', handler);
  }, []);

  useEffect(() => {
    if (!reactionPickerFor) return undefined;
    const handler = () => setReactionPickerFor(null);
    window.addEventListener('click', handler);
    return () => window.removeEventListener('click', handler);
  }, [reactionPickerFor]);

  useEffect(() => {
    if (!showEmojiPicker) return undefined;
    const handlePointerDown = (event) => { if (emojiPickerRef.current?.contains(event.target)) return; setShowEmojiPicker(false); };
    const handleEscape = (event) => { if (event.key === 'Escape') setShowEmojiPicker(false); };
    document.addEventListener('mousedown', handlePointerDown);
    document.addEventListener('touchstart', handlePointerDown);
    window.addEventListener('keydown', handleEscape);
    return () => {
      document.removeEventListener('mousedown', handlePointerDown);
      document.removeEventListener('touchstart', handlePointerDown);
      window.removeEventListener('keydown', handleEscape);
    };
  }, [showEmojiPicker]);

  useEffect(() => {
    const missingReelIds = [];
    for (const message of messages) {
      const shared = message?.sharedContent;
      if (!shared) continue;
      const reelId = extractSharedReelId(shared);
      if (!reelId) continue;
      if (shared?.previewUrl) continue;
      if (fetchedSharedReelIdsRef.current.has(reelId)) continue;
      missingReelIds.push(reelId);
      fetchedSharedReelIdsRef.current.add(reelId);
    }

    if (!missingReelIds.length) return;
    let cancelled = false;

    (async () => {
      for (const reelId of missingReelIds) {
        try {
          const { data } = await api.get(`/posts/reels/${reelId}`);
          const reel = data?.data || data?.reel || data;
          const media0 = reel?.media?.[0] || {};
          const previewUrl =
            media0?.thumbnail?.fileUrl
            || media0?.thumbnails?.[0]?.fileUrl
            || media0?.fileUrl
            || '';
          const creatorUsername = reel?.user_id?.username || '';
          const creatorAvatarUrl = reel?.user_id?.avatar_url || '';

          if (!cancelled) {
            setSharedReelMetaMap((prev) => ({
              ...prev,
              [reelId]: {
                previewUrl,
                creatorUsername,
                creatorAvatarUrl,
              },
            }));
          }
        } catch {
          // Keep silent; fallback UI still renders.
        }
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [messages]);

  const stopTyping = useCallback(() => {
    if (activeConversation?._id && currentUserId) emitStopTyping(activeConversation._id, currentUserId);
  }, [activeConversation, currentUserId]);

  const scheduleStopTyping = useCallback(() => {
    clearTimeout(stopTypingRef.current);
    stopTypingRef.current = setTimeout(() => stopTyping(), 1500);
  }, [stopTyping]);

  const handleLoadMore = async () => {
    if (!activeConversation?._id || !hasMore || isLoadingMessages) return;
    dispatch(setIsLoadingMessages(true));
    try {
      const nextPage = page + 1;
      const response = await chatService.getMessages(activeConversation._id, nextPage, PAGE_LIMIT);
      dispatch(setMessages([...[...(response?.messages || [])].reverse(), ...messages]));
      dispatch(setPage(nextPage));
      dispatch(setHasMore(Boolean(response?.hasMore)));
    } catch (error) { console.error('Failed to load older messages:', error); }
    finally { dispatch(setIsLoadingMessages(false)); }
  };

  const handleSend = async (customPayload = null) => {
    if (!activeConversation?._id || !currentUserId || sending || !activeConversationCanSend) return;
    const payload = customPayload || { text: input.trim(), mediaUrl: '', mediaType: 'none', replyTo };
    if (!payload.text && !payload.mediaUrl) return;
    setSending(true);
    try {
      const created = await chatService.sendMessage(activeConversation._id, payload);
      const enriched = { ...created, replyTo: payload.replyTo || null };
      dispatch(appendMessage(enriched));
      refreshConversationOrdering(activeConversation._id, enriched, enriched.createdAt);
      syncConversationPreview(activeConversation, enriched);
      dispatch(markConversationRead(activeConversation._id));
      setInput(''); setReplyTo(null); stopTyping();
    } catch (error) { console.error('Failed to send message:', error); }
    finally { setSending(false); }
  };

  const handleFile = async (event) => {
    const files = Array.from(event.target.files || []);
    if (!files.length || !activeConversation?._id || !currentUserId || !activeConversationCanSend) return;
    setUploading(true);
    try {
      const uploaded = await chatService.uploadChatMedia(activeConversation._id, files);
      const uploadedMedia = Array.isArray(uploaded?.media)
        ? uploaded.media
        : (uploaded?.mediaUrl ? [{ mediaUrl: uploaded.mediaUrl, mediaType: uploaded.mediaType }] : []);

      for (const item of uploadedMedia) {
        if (!item?.mediaUrl || !item?.mediaType) continue;
        const created = await chatService.sendMessage(activeConversation._id, {
          text: '',
          mediaUrl: item.mediaUrl,
          mediaType: item.mediaType,
          replyTo,
        });
        const enriched = { ...created, replyTo: replyTo || null };
        dispatch(appendMessage(enriched));
        refreshConversationOrdering(activeConversation._id, enriched, enriched.createdAt);
        syncConversationPreview(activeConversation, enriched);
        dispatch(markConversationRead(activeConversation._id));
      }

      setReplyTo(null);
      stopTyping();
    } catch (error) { console.error('Failed to upload media:', error); }
    finally { setUploading(false); event.target.value = ''; }
  };

  const handleVoiceSend = async (audioBlob, duration) => {
    if (!activeConversation?._id || !activeConversationCanSend) return;
    try {
      const created = await chatService.uploadVoiceMessage(activeConversation._id, audioBlob, duration);
      if (created?._id) {
        dispatch(appendMessage(created));
        refreshConversationOrdering(activeConversation._id, created, created.createdAt);
        syncConversationPreview(activeConversation, created);
        dispatch(markConversationRead(activeConversation._id));
      }
      setReplyTo(null);
      stopTyping();
    } catch (error) {
      console.error('Voice message send failed:', error);
    }
    setIsRecording(false);
  };

  const handleDelete = async (message) => {
    if (!message?._id || !activeConversation?._id) return;
    try {
      await chatService.deleteMessage(message._id);
      dispatch(removeMessage({ messageId: message._id, deletedAt: new Date().toISOString() }));
      const nextMessages = messages.map((item) => (item._id === message._id ? { ...item, isDeleted: true, deletedAt: new Date().toISOString() } : item));
      const lastVisible = previousNonDeleted(nextMessages);
      refreshConversationOrdering(activeConversation._id, lastVisible, lastVisible?.createdAt || activeConversation.createdAt);
      setContextMenu(null);
    } catch (error) { console.error('Failed to unsend message:', error); }
  };

  const handleAcceptRequest = async () => {
    if (!activeConversation?._id || groupActionLoading) return;
    setGroupActionLoading(true);
    try {
      const updatedConversation = await chatService.acceptMessageRequest(activeConversation._id);
      const normalConversations = sortConversations(await chatService.getConversations('normal') || []);
      dispatch(setConversations(normalConversations));
      dispatch(upsertConversation({ ...updatedConversation, unreadCount: 0 }));
      setConversationType('normal');
      dispatch(setActiveConversation(updatedConversation));
      dispatch(markConversationRead(updatedConversation._id));
      await refreshOnlineUsers(normalConversations);
      await setConversationAsActive(updatedConversation, { skipNavigation: true, forceReload: true });
      navigate(`/messages/${updatedConversation._id}`);
    } catch (error) {
      console.error('Failed to accept message request:', error);
    } finally {
      setGroupActionLoading(false);
    }
  };

  const handleDeclineRequest = async () => {
    if (!activeConversation?._id || groupActionLoading) return;
    setGroupActionLoading(true);
    try {
      await chatService.declineMessageRequest(activeConversation._id);
      const requestConversations = sortConversations(await chatService.getConversations('requests') || []);
      dispatch(setConversations(requestConversations));
      setConversationType('requests');
      dispatch(setActiveConversation(null));
      dispatch(setMessages([]));
      await refreshOnlineUsers(requestConversations);
      navigate('/messages');
    } catch (error) {
      console.error('Failed to decline message request:', error);
    } finally {
      setGroupActionLoading(false);
    }
  };

  const loadFollowingForGroup = useCallback(async () => {
    if (!currentUserId) return;
    setLoadingGroupMembers(true);
    try {
      const response = await getFollowing(currentUserId, { page: 1, limit: 100 });
      setGroupMembers(Array.isArray(response?.users) ? response.users : []);
    } catch (error) {
      console.error('Failed to load following users for group:', error);
      setGroupMembers([]);
    } finally {
      setLoadingGroupMembers(false);
    }
  }, [currentUserId]);

  const handleOpenGroupModal = async () => {
    setShowGroupModal(true);
    if (!groupMembers.length) {
      await loadFollowingForGroup();
    }
  };

  const handleCreateGroup = async (payload) => {
    setCreatingGroup(true);
    try {
      if ((payload?.participantIds || []).length === 1) {
        const conversation = await chatService.createOrGetConversation(payload.participantIds[0]);
        setShowGroupModal(false);
        await fetchConversations();
        await setConversationAsActive(conversation);
        return;
      }

      const conversation = await chatService.createGroupConversation(payload);
      setShowGroupModal(false);
      await fetchConversations();
      await setConversationAsActive(conversation);
    } catch (error) {
      console.error('Failed to create group:', error);
    } finally {
      setCreatingGroup(false);
    }
  };

  const handleSaveGroup = async (payload) => {
    if (!activeConversation?._id || groupActionLoading) return;
    setGroupActionLoading(true);
    try {
      const updatedConversation = await chatService.updateGroupConversation(activeConversation._id, payload);
      await fetchConversations();
      dispatch(setActiveConversation(updatedConversation));
      setShowManageGroupModal(false);
    } catch (error) {
      console.error('Failed to update group:', error);
    } finally {
      setGroupActionLoading(false);
    }
  };

  const handleAddGroupMember = async (userId) => {
    if (!activeConversation?._id || groupActionLoading) return;
    setGroupActionLoading(true);
    try {
      const updatedConversation = await chatService.addGroupMember(activeConversation._id, userId);
      dispatch(setActiveConversation(updatedConversation));

      const addedUser =
        (updatedConversation?.participants || []).find((item) => String(getUserId(item)) === String(userId))
        || groupMembers.find((item) => String(getUserId(item)) === String(userId))
        || null;

      const addedUserLabel = addedUser?.username || getUserName(addedUser);
      const adderLabel = userObject?.username || getUserName(userObject);

      if (addedUserLabel && adderLabel) {
        const created = await chatService.sendMessage(activeConversation._id, {
          text: `${adderLabel} added ${addedUserLabel}`,
          mediaUrl: '',
          mediaType: 'none',
          replyTo: null,
        });

        if (created?._id) {
          dispatch(appendMessage(created));
          refreshConversationOrdering(activeConversation._id, created, created.createdAt);
          syncConversationPreview(updatedConversation, created);
          dispatch(markConversationRead(activeConversation._id));
        }
      }

      await fetchConversations();
    } catch (error) {
      console.error('Failed to add group member:', error);
    } finally {
      setGroupActionLoading(false);
    }
  };

  const handleRemoveGroupMember = async (userId) => {
    if (!activeConversation?._id || groupActionLoading) return;
    setGroupActionLoading(true);
    try {
      const response = await chatService.removeGroupMember(activeConversation._id, userId);
      await fetchConversations();
      if (response?.conversationDeleted) {
        dispatch(setActiveConversation(null));
        dispatch(setMessages([]));
        setShowManageGroupModal(false);
        navigate('/messages');
      } else {
        dispatch(setActiveConversation(response));
      }
    } catch (error) {
      console.error('Failed to remove group member:', error);
    } finally {
      setGroupActionLoading(false);
    }
  };

  const handleLeaveGroup = async () => {
    if (!activeConversation?._id || groupActionLoading) return;
    setGroupActionLoading(true);
    try {
      await chatService.leaveGroupConversation(activeConversation._id);
      await fetchConversations();
      dispatch(setActiveConversation(null));
      dispatch(setMessages([]));
      setShowManageGroupModal(false);
      navigate('/messages');
    } catch (error) {
      console.error('Failed to leave group:', error);
    } finally {
      setGroupActionLoading(false);
    }
  };

  const handleDeleteGroupChat = async () => {
    if (!activeConversation?._id || groupActionLoading) return;
    setGroupActionLoading(true);
    try {
      await chatService.deleteGroupConversationForUser(activeConversation._id);
      await fetchConversations();
      dispatch(setActiveConversation(null));
      dispatch(setMessages([]));
      setShowManageGroupModal(false);
      navigate('/messages');
    } catch (error) {
      console.error('Failed to delete group chat:', error);
      const serverMessage = error?.response?.data?.message;
      if (serverMessage) window.alert(serverMessage);
    } finally {
      setGroupActionLoading(false);
    }
  };

  const handleReply = (message) => {
    const sender = getMessageSender(activeConversation, message, currentUserId);
    const senderName = String(message?.sender?._id || message?.sender) === String(currentUserId) ? 'You' : getUserName(sender);
    setReplyTo({ messageId: message._id, text: message.text || 'Attachment', senderName, senderId: message?.sender?._id || message?.sender });
    setReactionPickerFor(null); setContextMenu(null);
  };

  const handleReact = (message) => {
    if (message?.isDeleted) return;
    setReactionPickerFor((prev) => prev === message._id ? null : message._id);
  };

  const handleInputChange = (value) => {
    setInput(value);
    if (activeConversation?._id && currentUserId) { emitTyping(activeConversation._id, currentUserId); scheduleStopTyping(); }
  };

  const handleEmojiSelect = (emojiData) => {
    setInput((prev) => `${prev}${emojiData.emoji}`);
    if (activeConversation?._id && currentUserId) { emitTyping(activeConversation._id, currentUserId); scheduleStopTyping(); }
    inputRef.current?.focus();
  };

  const handleSelectReaction = async (message, emoji) => {
    if (!message?._id) return;
    try {
      const ownReaction = getOwnReaction(message, currentUserId);
      const updatedMessage = ownReaction?.emoji === emoji
        ? await chatService.removeMessageReaction(message._id)
        : await chatService.addMessageReaction(message._id, emoji);
      const nextMessages = messagesRef.current.map((item) => (item._id === message._id ? { ...item, ...updatedMessage } : item));
      messagesRef.current = nextMessages; dispatch(setMessages(nextMessages));
    } catch (error) { console.error('Failed to update reaction:', error); }
    finally { setReactionPickerFor(null); }
  };

  const handleRemoveOwnReaction = async (message) => {
    if (!message?._id || !getOwnReaction(message, currentUserId)) return;
    try {
      const updatedMessage = await chatService.removeMessageReaction(message._id);
      const nextMessages = messagesRef.current.map((item) => (item._id === message._id ? { ...item, ...updatedMessage } : item));
      messagesRef.current = nextMessages; dispatch(setMessages(nextMessages));
    } catch (error) { console.error('Failed to remove reaction:', error); }
  };

  const handleMoreMenu = (event, message) => {
    event.preventDefault();
    setContextMenu({ x: Math.min(event.clientX || window.innerWidth / 2 - 90, window.innerWidth - 190), y: Math.min(event.clientY || window.innerHeight - 150, window.innerHeight - 110), message });
    setReactionPickerFor(null);
  };

  const openContext = (event, message) => {
    event.preventDefault();
    setReactionPickerFor(null);
    setContextMenu({ x: Math.min(event.clientX, window.innerWidth - 190), y: Math.min(event.clientY, window.innerHeight - 110), message });
  };

  const startLongPress = (message) => {
    clearTimeout(longPressRef.current);
    longPressRef.current = setTimeout(() => {
      setContextMenu({ x: window.innerWidth / 2 - 90, y: window.innerHeight - 150, message });
    }, 450);
  };

  const clearLongPress = () => clearTimeout(longPressRef.current);

  const renderBubble = (message, mine) => {
    if (message.isDeleted) return <p className="text-sm italic text-gray-500">Message unsent</p>;
    const sender = getMessageSender(activeConversation, message, currentUserId);
    const sharedContent = message?.sharedContent || null;
    const hasSharedContent = Boolean(sharedContent?.contentType);
    const sharedContentType = String(sharedContent?.contentType || '').toLowerCase();
    const sharedReelId = extractSharedReelId(sharedContent);
    const sharedReelMeta = sharedReelId ? sharedReelMetaMap[sharedReelId] : null;
    const isReelShare = Boolean(
      sharedContent
      && (
        sharedContentType === 'reel'
        || Boolean(sharedReelId)
      )
    );
    const isPostOrTweetShare = sharedContentType === 'post' || sharedContentType === 'tweet';
    const resolvedSharedPreview = sharedContent?.previewUrl || sharedReelMeta?.previewUrl || '';
    const resolvedSharedCreatorName = sharedContent?.creatorUsername || sharedReelMeta?.creatorUsername || 'reel';
    const resolvedSharedCreatorAvatar = sharedContent?.creatorAvatarUrl || sharedReelMeta?.creatorAvatarUrl || '';

    const messageText = typeof message?.text === 'string' ? message.text.trim() : '';
    const cleanedMessageText = hasSharedContent
      ? messageText.replace(/https?:\/\/\S+/gi, '').trim()
      : messageText;
    const hasMessageText = (isReelShare || isPostOrTweetShare) ? false : Boolean(cleanedMessageText);
    const sharedCreatorId = getSharedCreatorId(sharedContent);
    const sharedContentId = getSharedContentId(sharedContent);
    const sharedCardCreatorName = sharedContent?.creatorUsername || sharedContent?.title || 'shared';
    const sharedCardBodyText = String(
      sharedContent?.caption
      || sharedContent?.title
      || cleanedMessageText
      || ''
    ).trim();
    const sharedReelBodyText = String(
      sharedContent?.caption
      || sharedContent?.title
      || cleanedMessageText
      || ''
    ).trim();

    const bubbleClass = mine
      ? 'bg-[#7C3AED] rounded-[22px] rounded-br-md shadow-sm'
      : 'bg-gray-100 dark:bg-[#262626] rounded-[22px] rounded-bl-md border border-gray-200 dark:border-white/5 shadow-sm';
    const mediaFrameClass = mine
      ? 'overflow-hidden rounded-[22px] rounded-br-md shadow-sm bg-transparent'
      : 'overflow-hidden rounded-[22px] rounded-bl-md shadow-sm bg-transparent';

    const resolveSharedContentRoute = () => {
      if (sharedContentType === 'reel') {
        const reelId = String(sharedReelId || sharedContentId).trim();
        return reelId ? `/reels?reel=${encodeURIComponent(reelId)}` : '';
      }
      if (sharedContentType === 'ad') {
        return sharedContentId ? `/ads/${encodeURIComponent(sharedContentId)}/details` : '';
      }
      if (sharedContentType === 'tweet') {
        return sharedContentId ? `/post/${encodeURIComponent(sharedContentId)}?type=tweet` : '';
      }
      if (sharedContentType === 'post') {
        return sharedContentId ? `/post/${encodeURIComponent(sharedContentId)}` : '';
      }

      const shareUrl = String(sharedContent?.shareUrl || '').trim();
      if (!shareUrl) return '';
      try {
        const url = new URL(shareUrl, window.location.origin);
        return `${url.pathname}${url.search}${url.hash}`;
      } catch {
        return '';
      }
    };

    const handleOpenSharedContent = (event) => {
      event.preventDefault();
      event.stopPropagation();
      const openSharedContent = async () => {
        const id = String(sharedContentId || '').trim();
        const isMobileViewport = typeof window !== 'undefined' && window.innerWidth < 768;

        // Match profile behavior on mobile: open dedicated mobile post/tweet screen.
        if (id && isMobileViewport && (sharedContentType === 'post' || sharedContentType === 'tweet')) {
          const suffix = sharedContentType === 'tweet' ? '?type=tweet' : '';
          navigate(`/post/${encodeURIComponent(id)}${suffix}`);
          return;
        }

        if (id && ['post', 'reel', 'ad', 'tweet'].includes(sharedContentType)) {
          try {
            let payload = null;

            if (sharedContentType === 'ad') {
              const response = await api.get(`/ads/${id}`);
              payload = response?.data || null;
              if (payload && typeof payload === 'object') {
                payload = { ...payload, item_type: 'ad' };
              }
            } else if (sharedContentType === 'reel') {
              try {
                const response = await api.get(`/posts/${id}`);
                payload = response?.data || null;
              } catch {
                const response = await api.get(`/posts/reels/${id}`);
                payload = response?.data || null;
              }
              if (payload && typeof payload === 'object') {
                payload = { ...payload, type: 'reel' };
              }
            } else if (sharedContentType === 'tweet') {
              const response = await api.get(`/tweets/${id}`);
              payload = response?.data || null;
              if (payload && typeof payload === 'object') {
                payload = { ...payload, item_type: 'tweet' };
              }
            } else {
              const response = await api.get(`/posts/${id}`);
              payload = response?.data || null;
            }

            if (payload && typeof payload === 'object') {
              setSharedDetailItem(payload);
              return;
            }
          } catch (error) {
            console.error('Failed to open shared content in modal:', error);
          }
        }

        const route = resolveSharedContentRoute();
        if (route) {
          navigate(route);
          return;
        }
        const fallbackUrl = String(sharedContent?.shareUrl || '').trim();
        if (fallbackUrl) window.open(fallbackUrl, '_blank', 'noopener,noreferrer');
      };

      openSharedContent();
    };

    const handleOpenSharedCreatorProfile = (event) => {
      event.preventDefault();
      event.stopPropagation();
      if (!sharedCreatorId) return;
      if (sharedContentType === 'ad') {
        navigate(`/vendor/${sharedCreatorId}/public`);
        return;
      }
      navigate(`/profile/${sharedCreatorId}`);
    };

    return (
      <div className="max-w-[280px] sm:max-w-[340px]">
        {!mine && activeConversation?.isGroup ? (
          <p className="mb-1 px-1 text-[11px] font-semibold tracking-wide text-gray-500 dark:text-gray-400">
            {getUserName(sender)}
          </p>
        ) : null}
        {hasReplyContent(message.replyTo) ? (
          <div className={`mb-1 rounded-2xl border px-3 py-2 text-xs ${mine ? 'bg-[#672ec3] border-white/10' : 'bg-gray-200/50 dark:bg-[#1a1a1a] border-gray-300 dark:border-white/10'}`}>
            <p className={`mb-1 font-semibold ${mine ? 'text-white/80' : 'text-gray-900 dark:text-white/80'}`}>
              {String(message.replyTo.senderId) === String(currentUserId) ? 'You replied' : `${message.replyTo.senderName || 'User'} replied`}
            </p>
            <p className={`line-clamp-2 ${mine ? 'text-white/70' : 'text-gray-600 dark:text-white/70'}`}>{message.replyTo.text || 'Attachment'}</p>
          </div>
        ) : null}

        {hasSharedContent ? (
          isReelShare ? (
            <button
              type="button"
              onClick={handleOpenSharedContent}
              className={`mb-2 block w-[280px] overflow-hidden rounded-[22px] border text-left shadow-sm transition hover:opacity-95 sm:w-[360px] ${
                mode === 'dark'
                  ? 'border-white/10 bg-[#1b1d23]'
                  : 'border-gray-200 bg-[#f3f4f6]'
              }`}
            >
              <div className={`flex items-center gap-2 px-3 py-3 ${
                mode === 'dark' ? 'bg-white/[0.03]' : 'bg-black/[0.03]'
              }`}>
                <button
                  type="button"
                  onClick={handleOpenSharedCreatorProfile}
                  className={`h-7 w-7 overflow-hidden rounded-full ${
                    mode === 'dark' ? 'bg-white/10' : 'bg-black/10'
                  }`}
                >
                  {resolvedSharedCreatorAvatar ? (
                    <img
                      src={resolvedSharedCreatorAvatar}
                      alt={resolvedSharedCreatorName || 'creator'}
                      className="h-full w-full object-cover"
                    />
                  ) : (
                    <div className={`flex h-full w-full items-center justify-center text-[11px] font-bold ${
                      mode === 'dark' ? 'text-white' : 'text-gray-900'
                    }`}>
                      {String(resolvedSharedCreatorName || 'U').charAt(0).toUpperCase()}
                    </div>
                  )}
                </button>
                <button
                  type="button"
                  onClick={handleOpenSharedCreatorProfile}
                  className={`truncate text-left text-[22px] font-semibold leading-none ${
                    mode === 'dark' ? 'text-white' : 'text-gray-900'
                  }`}
                >
                  {resolvedSharedCreatorName}
                </button>
                {sharedContent?.creatorVerified ? (
                  <span className="inline-flex h-4 w-4 items-center justify-center rounded-full bg-[#0095f6] text-white">
                    <Check size={10} strokeWidth={3} />
                  </span>
                ) : null}
              </div>

              <div className="relative">
                {resolvedSharedPreview ? (
                  <img
                    src={resolvedSharedPreview}
                    alt={sharedContent?.title || 'Shared reel'}
                    className="block w-full h-auto max-h-[520px] object-contain bg-black"
                  />
                ) : (
                  <div className={`flex h-[320px] w-full items-center justify-center px-4 text-center text-sm ${
                    mode === 'dark' ? 'bg-black/30 text-white/70' : 'bg-black/10 text-gray-700'
                  }`}>
                    Open shared reel
                  </div>
                )}
                {sharedContentType === 'reel' ? (
                  <span className="absolute bottom-3 left-3 inline-flex h-8 w-8 items-center justify-center rounded-full bg-black/55 text-white backdrop-blur-sm">
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
                      <path d="M8 5v14l11-7z" />
                    </svg>
                  </span>
                ) : null}
              </div>

              <div className={`px-3 py-2 text-sm ${
                mode === 'dark' ? 'bg-black/20 text-white/95' : 'bg-white text-gray-900'
              }`}>
                <p className="line-clamp-3">
                  <span className="font-semibold">{resolvedSharedCreatorName}</span>
                  {sharedReelBodyText ? ` ${sharedReelBodyText}` : ''}
                </p>
              </div>
            </button>
          ) : isPostOrTweetShare ? (
            <button
              type="button"
              onClick={handleOpenSharedContent}
              className={`mb-2 block w-[280px] overflow-hidden rounded-[22px] border text-left shadow-sm transition hover:opacity-95 sm:w-[360px] ${
                mode === 'dark'
                  ? 'border-white/10 bg-[#1b1d23]'
                  : 'border-gray-200 bg-[#f3f4f6]'
              }`}
            >
              <div className={`flex items-center gap-2 px-3 py-3 ${
                mode === 'dark' ? 'bg-white/[0.03]' : 'bg-black/[0.03]'
              }`}>
                <button
                  type="button"
                  onClick={handleOpenSharedCreatorProfile}
                  className={`h-7 w-7 overflow-hidden rounded-full ${
                    mode === 'dark' ? 'bg-white/10' : 'bg-black/10'
                  }`}
                >
                  {sharedContent?.creatorAvatarUrl ? (
                    <img
                      src={sharedContent.creatorAvatarUrl}
                      alt={sharedCardCreatorName || 'creator'}
                      className="h-full w-full object-cover"
                    />
                  ) : (
                    <div className={`flex h-full w-full items-center justify-center text-[11px] font-bold ${
                      mode === 'dark' ? 'text-white' : 'text-gray-900'
                    }`}>
                      {String(sharedCardCreatorName || 'U').charAt(0).toUpperCase()}
                    </div>
                  )}
                </button>
                <button
                  type="button"
                  onClick={handleOpenSharedCreatorProfile}
                  className={`truncate text-left text-[22px] font-semibold leading-none ${
                    mode === 'dark' ? 'text-white' : 'text-gray-900'
                  }`}
                >
                  {sharedCardCreatorName}
                </button>
                {sharedContent?.creatorVerified ? (
                  <span className="inline-flex h-4 w-4 items-center justify-center rounded-full bg-[#0095f6] text-white">
                    <Check size={10} strokeWidth={3} />
                  </span>
                ) : null}
              </div>

              <div className="relative">
                {sharedContent?.previewUrl ? (
                  <img
                    src={sharedContent.previewUrl}
                    alt={sharedContent?.title || 'Shared post'}
                    className="block w-full h-auto max-h-[420px] object-contain bg-black"
                  />
                ) : (
                  <div className={`flex h-[260px] w-full items-center justify-center px-4 text-center text-sm ${
                    mode === 'dark' ? 'bg-black/30 text-white/70' : 'bg-black/10 text-gray-700'
                  }`}>
                    Open shared {isPostOrTweetShare ? sharedContentType : 'content'}
                  </div>
                )}
              </div>

              <div className={`px-3 py-2 text-sm ${
                mode === 'dark' ? 'bg-black/20 text-white/95' : 'bg-white text-gray-900'
              }`}>
                <p className="line-clamp-3">
                  <span className="font-semibold">{sharedCardCreatorName}</span>
                  {sharedCardBodyText ? ` ${sharedCardBodyText}` : ''}
                </p>
              </div>
            </button>
          ) : (
            <button
              type="button"
              onClick={handleOpenSharedContent}
              className={`mb-2 block overflow-hidden rounded-[20px] border ${
                mine ? 'border-white/20 bg-[#4f46e5]/40' : 'border-white/10 bg-[#1d1f27]'
              } shadow-sm transition hover:opacity-95`}
            >
              <div className={`flex items-center gap-2 px-3 py-2 ${mine ? 'bg-black/10' : 'bg-black/20'}`}>
                <button
                  type="button"
                  onClick={handleOpenSharedCreatorProfile}
                  className="h-7 w-7 overflow-hidden rounded-full bg-white/10"
                >
                  {sharedContent?.creatorAvatarUrl ? (
                    <img
                      src={sharedContent.creatorAvatarUrl}
                      alt={sharedContent?.creatorUsername || 'creator'}
                      className="h-full w-full object-cover"
                    />
                  ) : (
                    <div className="flex h-full w-full items-center justify-center text-[11px] font-bold text-white">
                      {String(sharedContent?.creatorUsername || 'U').charAt(0).toUpperCase()}
                    </div>
                  )}
                </button>
                <button
                  type="button"
                  onClick={handleOpenSharedCreatorProfile}
                  className="truncate text-left text-sm font-semibold text-white"
                >
                  {sharedContent?.creatorUsername || sharedContent?.title || 'Shared'}
                </button>
                {sharedContent?.creatorVerified ? (
                  <span className="inline-flex h-4 w-4 items-center justify-center rounded-full bg-[#0095f6] text-[10px] font-bold text-white">
                    ?
                  </span>
                ) : null}
              </div>
              <div className="relative">
                {sharedContent?.previewUrl ? (
                  <img
                    src={sharedContent.previewUrl}
                    alt={sharedContent?.title || 'Shared content'}
                    className="block h-[280px] w-full object-cover"
                  />
                ) : (
                  <div className="flex h-[220px] w-full items-center justify-center bg-black/30 text-sm text-white/70">
                    Open shared content
                  </div>
                )}
                {sharedContent?.previewType === 'video' && !isPostOrTweetShare ? (
                  <span className="absolute bottom-3 left-3 inline-flex h-8 w-8 items-center justify-center rounded-full bg-black/55 text-white backdrop-blur-sm">
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
                      <path d="M8 5v14l11-7z" />
                    </svg>
                  </span>
                ) : null}
              </div>
              <div className={`px-3 py-2 text-sm ${mine ? 'text-white/95' : 'text-white/90'}`}>
                <p className="line-clamp-2">
                  <span className="font-semibold">
                    {sharedContent?.creatorUsername || 'shared'}
                  </span>
                  {sharedContent?.caption || sharedContent?.title
                    ? ` ${sharedContent.caption || sharedContent.title}`
                    : ''}
                </p>
              </div>
            </button>
          )
        ) : null}

        {message.mediaUrl ? (
          <div className="space-y-2">
            {message.mediaType === 'audio' ? (
              <VoiceMessageBubble message={message} isMine={mine} />
            ) : (
              <div className={mediaFrameClass}>
                {message.mediaType === 'video' || isVideoUrl(message.mediaUrl)
                  ? <video src={message.mediaUrl} controls className="block max-h-80 w-full object-cover outline-none border-0 ring-0 shadow-none" />
                  : <img src={message.mediaUrl} alt="attachment" className="block max-h-80 w-full object-cover outline-none border-0 ring-0 shadow-none" />}
              </div>
            )}
            {hasMessageText ? (
              <div className={`${bubbleClass} overflow-hidden px-3 py-2.5 ${mine ? 'text-white' : 'text-gray-900 dark:text-white'}`}>
                <p className="whitespace-pre-wrap break-words text-sm leading-relaxed">{cleanedMessageText}</p>
              </div>
            ) : null}
          </div>
        ) : hasMessageText ? (
          <div className={`${bubbleClass} overflow-hidden px-3 py-2.5 ${mine ? 'text-white' : 'text-gray-900 dark:text-white'}`}>
            <p className="whitespace-pre-wrap break-words text-sm leading-relaxed">{cleanedMessageText}</p>
          </div>
        ) : !hasSharedContent ? (
          <div className={`${bubbleClass} overflow-hidden px-3 py-2.5 ${mine ? 'text-white' : 'text-gray-900 dark:text-white'}`}>
            <p className="whitespace-pre-wrap break-words text-sm leading-relaxed">{message.text}</p>
          </div>
        ) : null}
      </div>
    );
  };

  const latestSeenOwnMessageId = useMemo(() => {
    if (!otherUserId) return null;
    for (let index = messages.length - 1; index >= 0; index -= 1) {
      const message = messages[index];
      const mine = String(message?.sender?._id || message?.sender) === String(currentUserId);
      if (mine && !message?.isDeleted && hasUserSeenMessage(message, otherUserId)) return message._id;
    }
    return null;
  }, [currentUserId, messages, otherUserId]);

  return (
    <div className="h-[100dvh] bg-white dark:bg-black text-gray-900 dark:text-white md:h-screen">
      <div className="flex h-full">

        {/* ═══════════════════════════════════════════════════════════
            SIDEBAR — Mobile: Instagram dark style | Desktop: unchanged
            ═══════════════════════════════════════════════════════════ */}
        <aside className={`
          ${activeId ? 'hidden' : 'flex'}
          h-full w-full flex-shrink-0 flex-col
          bg-[#000000] text-white
          md:flex md:w-[380px]
          md:bg-gray-50/50 md:text-gray-900
          md:dark:bg-[#0a0a0a] md:dark:text-white
          md:border-r md:border-gray-100 md:dark:border-white/10
        `}>

          {/* ── Mobile top bar: back + username + compose ── */}
          <div className={`${isRequestsView ? 'hidden' : 'px-4 pb-2 pt-3 md:hidden'}`}>
            <div className="flex items-center justify-between">
              {/* Back arrow */}
              <button
                onClick={() => navigate('/')}
                className="flex h-9 w-9 items-center justify-center rounded-full text-white transition hover:bg-white/10"
                aria-label="Back"
              >
                <ChevronLeft size={22} strokeWidth={2.5} />
              </button>

              {/* Username + dropdown chevron — centered */}
              <button type="button" className="flex items-center gap-1">
                <span className="text-[17px] font-bold tracking-tight text-white">
                  {currentUserLabel}
                </span>
                <ChevronDown size={16} className="mt-[1px] text-white" strokeWidth={2.5} />
              </button>

              {/* Compose icon */}
              <button
                type="button"
                onClick={handleOpenGroupModal}
                className="flex h-9 w-9 items-center justify-center rounded-full text-white transition hover:bg-white/10"
                aria-label="Compose"
              >
                <SquarePen size={20} strokeWidth={2} />
              </button>
            </div>
          </div>

          {/* ── Desktop top bar ── */}
          <div className={`${isRequestsView ? 'hidden' : 'hidden md:block px-5 py-5 border-b border-gray-100 dark:border-white/10'}`}>
            <div className="flex items-center justify-between mb-4">
              <h1 className="text-xl font-bold text-gray-900 dark:text-white">{currentUserLabel}</h1>
              <button type="button" onClick={handleOpenGroupModal} className="text-gray-500 hover:text-gray-900 dark:hover:text-white transition">
                <SquarePen size={20} />
              </button>
            </div>

            {/* Desktop search */}
            <div className="flex items-center gap-3 rounded-full bg-white border border-gray-200 dark:bg-[#111111] dark:border-transparent px-4 py-2.5 text-sm text-gray-400 shadow-sm focus-within:border-gray-300 dark:focus-within:border-white/20 transition-colors">
              <Search size={17} className="text-gray-400 dark:text-gray-500" />
              <input
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder="Search"
                className="w-full bg-transparent text-[15px] outline-none placeholder:text-gray-400 text-gray-900 dark:placeholder:text-gray-500 dark:text-white"
              />
            </div>
          </div>

          {/* ── Mobile search bar ── */}
          <div className={`${isRequestsView ? 'hidden' : 'px-4 pt-2 pb-3 md:hidden'}`}>
            <div className="flex items-center gap-3 rounded-[12px] bg-[#1c1c1e] px-4 py-2.5 text-sm text-white/50">
              <Search size={16} className="shrink-0 text-white/40" />
              <input
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder="Search"
                className="w-full bg-transparent text-[15px] outline-none placeholder:text-white/40 text-white"
              />
            </div>
          </div>

          {/* ── Online users horizontal row (mobile + desktop) ── */}
          <div className={`${isRequestsView ? 'hidden' : 'flex gap-4 overflow-x-auto px-4 pb-3 pt-1 [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden md:px-5 md:pb-4 md:pt-3'}`}>
            {onlineConversations.map((conversation) => {
              const user = otherParticipant(conversation, currentUserId);
              const unread = unreadCounts[conversation._id] ?? conversation.unreadCount ?? 0;
              const title = getConversationTitle(conversation, currentUserId);
              const avatar = getConversationAvatar(conversation, currentUserId);

              return (
                <button
                  key={conversation._id}
                  onClick={() => setConversationAsActive(conversation)}
                  className="flex flex-col items-center gap-2 shrink-0"
                >
                  {/* Avatar with gradient ring */}
                  <div className={`rounded-full p-[2px] ${unread > 0 ? 'bg-gradient-to-tr from-[#f9ce34] via-[#ee2a7b] to-[#6228d7]' : 'bg-[#333] md:bg-gray-300 dark:md:bg-white/20'}`}>
                    <div className="relative rounded-full bg-black p-[2px] md:bg-white dark:md:bg-black">
                      <Avatar
                        user={user}
                        src={avatar}
                        alt={title}
                        className="h-[56px] w-[56px]"
                      />
                      <span className="absolute bottom-[2px] right-[2px] h-3.5 w-3.5 rounded-full border-2 border-black bg-[#38d430] md:border-white dark:md:border-black" />
                    </div>
                  </div>

                  {/* Username */}
                  <span className="max-w-[80px] truncate text-[11px] font-medium tracking-[0.02em] text-white/80 md:text-gray-700 md:dark:text-white/80">
                    {title}
                  </span>
                </button>
              );
            })}
            {!onlineConversations.length ? (
              <p className="py-2 text-xs text-white/45 md:text-gray-500 md:dark:text-gray-400">No one is online right now.</p>
            ) : null}
          </div>

          {/* ── Desktop story row ── */}
          <div className="hidden">
            {conversations.map((conversation) => {
              const user = otherParticipant(conversation, currentUserId);
              const title = getConversationTitle(conversation, currentUserId);
              const avatar = getConversationAvatar(conversation, currentUserId);
              return (
                <button
                  key={conversation._id}
                  onClick={() => setConversationAsActive(conversation)}
                  className="group flex min-w-[64px] flex-col items-center gap-2 transition-transform hover:scale-105 active:scale-95"
                >
                  <div className="rounded-full bg-gradient-to-br from-[#7C3AED] to-[#3B82F6] p-[2px]">
                    <div className="rounded-full bg-white dark:bg-black p-[2px]">
                      {conversation?.isGroup ? (
                        <MergedGroupAvatar
                          conversation={conversation}
                          currentUserId={currentUserId}
                          className="h-14 w-14"
                        />
                      ) : (
                        <Avatar
                          user={user}
                          src={avatar}
                          alt={title}
                          className="h-14 w-14"
                        />
                      )}
                    </div>
                  </div>
                  <span className="max-w-[64px] truncate text-[11px] font-medium text-gray-600 dark:text-gray-300">
                    {title}
                  </span>
                </button>
              );
            })}
          </div>

          {/* ── Messages label row ── */}
          <div className={`${isRequestsView ? 'hidden' : 'flex items-center justify-between px-4 pb-2 pt-3 md:px-5 md:pb-3 md:pt-4'}`}>
            <div className="flex items-center gap-3">
              {[
                { key: 'normal', label: 'Messages' },
                { key: 'requests', label: 'Requests' },
              ].map((tab) => (
                <button
                  key={tab.key}
                  type="button"
                  onClick={() => {
                    setConversationType(tab.key);
                    dispatch(setActiveConversation(null));
                    dispatch(setMessages([]));
                    navigate('/messages');
                  }}
                  className={`text-[15px] font-bold transition md:text-[15px] ${
                    conversationType === tab.key
                      ? 'text-white md:text-gray-900 md:dark:text-white'
                      : 'text-white/55 hover:text-white md:text-gray-500 md:hover:text-gray-700 md:dark:text-gray-400 md:dark:hover:text-white'
                  }`}
                >
                  {tab.label}
                </button>
              ))}
            </div>
          </div>

          {/* ── Conversation list ── */}
          {isRequestsView ? (
            <>
              <div className="px-4 pb-3 pt-4 md:hidden">
                <div className="flex items-center gap-3">
                  <button
                    type="button"
                    onClick={() => { setConversationType('normal'); dispatch(setActiveConversation(null)); dispatch(setMessages([])); navigate('/messages'); }}
                    className="flex h-9 w-9 items-center justify-center rounded-full text-white transition hover:bg-white/10"
                    aria-label="Back to messages"
                  >
                    <ChevronLeft size={22} strokeWidth={2.5} />
                  </button>
                  <p className="text-[26px] font-bold tracking-tight text-white">Message requests</p>
                </div>
              </div>

              <div className="hidden border-b border-gray-100 px-5 py-5 dark:border-white/10 md:block">
                <div className="flex items-center gap-3">
                  <button
                    type="button"
                    onClick={() => { setConversationType('normal'); dispatch(setActiveConversation(null)); dispatch(setMessages([])); navigate('/messages'); }}
                    className="rounded-full p-2 text-gray-500 transition hover:bg-gray-100 hover:text-gray-900 dark:hover:bg-white/5 dark:hover:text-white"
                    aria-label="Back to messages"
                  >
                    <ChevronLeft size={20} />
                  </button>
                  <h1 className="text-[18px] font-bold text-gray-900 dark:text-white">Message requests</h1>
                </div>
              </div>

              <div className="px-4 py-4 md:px-5">
                <button
                  type="button"
                  className="flex w-full items-center justify-between rounded-[18px] bg-white/5 px-4 py-4 text-left transition hover:bg-white/[0.08] md:bg-white md:hover:bg-gray-50 dark:md:bg-[#111111] dark:md:hover:bg-[#151515]"
                >
                  <div className="flex items-center gap-3">
                    <div className="flex h-14 w-14 items-center justify-center rounded-full bg-white/10 md:bg-gray-100 dark:md:bg-white/5">
                      <UserMinus size={22} className="text-white/80 md:text-gray-500 dark:md:text-gray-300" />
                    </div>
                    <div>
                      <p className="text-sm font-semibold text-white md:text-gray-900 dark:md:text-white">Hidden requests</p>
                      <p className="mt-1 text-xs text-white/45 md:text-gray-500 dark:md:text-gray-400">Restricted chats appear here.</p>
                    </div>
                  </div>
                  <ChevronLeft size={18} className="rotate-180 text-white/60 md:text-gray-400" />
                </button>
              </div>
            </>
          ) : null}

          <div className="flex-1 overflow-y-auto px-2 pb-6 [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden">
            {isLoadingConversations ? (
              <div className="space-y-1 px-2 pt-2">
                {Array.from({ length: 7 }).map((_, index) => (
                  <div key={index} className="flex animate-pulse items-center gap-3 rounded-2xl px-3 py-3">
                    <div className="h-[54px] w-[54px] rounded-full bg-white/10 md:bg-gray-200 md:dark:bg-[#1f1f1f]" />
                    <div className="flex-1 space-y-2">
                      <div className="h-3 w-1/3 rounded bg-white/10 md:bg-gray-200 md:dark:bg-[#1f1f1f]" />
                      <div className="h-3 w-2/3 rounded bg-white/5 md:bg-gray-100 md:dark:bg-[#161616]" />
                    </div>
                  </div>
                ))}
              </div>
            ) : filteredConversations.length ? (
              filteredConversations.map((conversation) => {
                const user = otherParticipant(conversation, currentUserId);
                const unread = unreadCounts[conversation._id] ?? conversation.unreadCount ?? 0;
                const active = activeId === conversation._id;
                const isTyping = (typingUsers[conversation._id] || []).some((id) => String(id) !== String(currentUserId));
                const title = getConversationTitle(conversation, currentUserId);
                const subtitle = getConversationSubtitle(conversation, currentUserId, onlineUserIds);
                const avatar = getConversationAvatar(conversation, currentUserId);
                const isRequest = isConversationRequestForMe(conversation, currentUserId);
                const previewText = getConversationListMeta(conversation, currentUserId, unread, isTyping, subtitle);
                const timeText = formatAgo(conversation.lastMessageAt);

                return (
                  <button
                    key={conversation._id}
                    onClick={() => setConversationAsActive(conversation)}
                    className={`flex w-full items-center gap-3 rounded-2xl px-3 py-2.5 text-left transition-all
                      ${active
                        ? 'bg-white/5 md:bg-white md:shadow-sm md:border md:border-gray-100 md:dark:bg-[#141414] md:dark:border-white/5'
                        : 'hover:bg-white/[0.04] md:hover:bg-white/70 md:dark:hover:bg-[#111111] border border-transparent'
                      }
                    `}
                  >
                    {/* Avatar */}
                    <div className="relative shrink-0">
                      {conversation?.isGroup ? (
                        <MergedGroupAvatar
                          conversation={conversation}
                          currentUserId={currentUserId}
                          className="h-[54px] w-[54px] md:h-12 md:w-12"
                        />
                      ) : (
                        <Avatar
                          user={user}
                          src={avatar}
                          alt={title}
                          className="h-[54px] w-[54px] md:h-12 md:w-12"
                        />
                      )}
                      {!conversation?.isGroup && onlineUserIds.includes(String(getUserId(user))) ? (
                        <span className="absolute bottom-1 right-1 h-3.5 w-3.5 rounded-full border-2 border-black bg-[#38d430] md:border-white dark:md:border-[#0a0a0a]" />
                      ) : null}
                    </div>

                    {/* Text content */}
                    <div className="min-w-0 flex-1">
                      <div className="flex items-start justify-between gap-3">
                        <p className={`min-w-0 truncate text-[14.5px] leading-snug md:text-[15px] md:text-gray-900 md:dark:text-white
                          ${unread > 0 ? 'font-bold text-white' : 'font-semibold text-white/90'}`}>
                          {title}
                        </p>
                        <span className="shrink-0 pt-0.5 text-[12px] text-white/40 md:text-gray-400">
                          {timeText}
                        </span>
                        {isRequest ? (
                          <span className="hidden rounded-full bg-amber-100 px-1.5 py-0.5 text-[9px] font-semibold uppercase tracking-wide text-amber-700 dark:bg-amber-500/20 dark:text-amber-300 md:inline-flex">
                            Request
                          </span>
                        ) : null}
                        {conversation?.isPinned && (
                          <span className="text-white/40 md:text-gray-400 text-xs">📌</span>
                        )}
                      </div>

                      <div className="mt-1 flex items-center gap-1.5 pr-2">
                        {unread > 0 ? (
                          <>
                            <p className="truncate text-[13px] font-semibold text-white md:text-gray-900 md:dark:text-white">
                              {previewText}
                            </p>
                            <span className="shrink-0 text-[13px] text-white/30">·</span>
                            <span className="shrink-0 text-[12px] text-white/40">
                              {formatAgo(conversation.lastMessageAt)}
                            </span>
                          </>
                        ) : (
                          <>
                            <p className={`truncate text-[13px] ${isTyping ? 'font-semibold text-[#4f6bff]' : 'text-white/50 md:text-gray-500 md:dark:text-gray-400'}`}>
                              {previewText}
                            </p>
                            <span className="shrink-0 text-[13px] text-white/25 md:text-gray-400">·</span>
                            <span className="shrink-0 text-[12px] text-white/40 md:text-gray-400">
                              {formatAgo(conversation.lastMessageAt)}
                            </span>
                          </>
                        )}
                      </div>
                    </div>

                    {/* Unread dot */}
                    {unread > 0 && !active && (
                      <span className="mr-1 h-2.5 w-2.5 shrink-0 rounded-full bg-[#3478f6] shadow-lg shadow-blue-500/30 md:bg-[#3B82F6]" />
                    )}
                  </button>
                );
              })
            ) : (
              <div className="px-5 py-6">
                <p className="text-sm text-white/55 md:text-gray-500 dark:md:text-gray-400">
                  {isRequestsView
                    ? "Chats will appear here after you send or receive a message request."
                    : 'No conversations found.'}
                </p>
              </div>
            )}
          </div>
          {isRequestsView ? (
            <div className="border-t border-white/10 px-5 py-4 text-center md:border-gray-100 md:dark:border-white/10">
              <button
                type="button"
                className="text-sm font-semibold text-red-400 transition hover:text-red-300 md:text-red-500 md:hover:text-red-600"
              >
                Delete all {requestCount}
              </button>
            </div>
          ) : null}
        </aside>

        {/* ═══════════════════════════════════════════════════════════
            CHAT SECTION — unchanged, same as original
            ═══════════════════════════════════════════════════════════ */}
        <section className={`${!activeId && !isRequestsView ? 'hidden' : 'flex'} min-w-0 flex-1 flex-col bg-white dark:bg-black overflow-hidden relative md:flex`}>
          {!activeConversation ? (
            <div className="flex flex-1 flex-col items-center justify-center px-6 text-center animate-in fade-in duration-500">
              <div className="flex h-24 w-24 items-center justify-center rounded-full border-2 border-gray-100 bg-gray-50/50 shadow-sm dark:border-white/10 dark:bg-[#0a0a0a]">
                {isRequestsView ? (
                  <UserMinus size={42} className="text-gray-300 dark:text-gray-700" />
                ) : (
                  <MessageCircle size={42} className="text-gray-300 dark:text-gray-700" />
                )}
              </div>
              <h2 className="mt-6 text-2xl font-bold tracking-tight">
                {isRequestsView ? 'Message requests' : 'Your messages'}
              </h2>
              <p className="mt-2 max-w-xs text-sm leading-relaxed text-gray-500 dark:text-gray-400">
                {isRequestsView
                  ? "These messages are from people you don't follow yet. They won't know you've seen them until you accept."
                  : 'Send private photos and messages to a friend or group.'}
              </p>
              {!isRequestsView ? (
                <button onClick={handleOpenGroupModal} className="mt-6 rounded-full bg-[#7C3AED] px-6 py-3 text-sm font-bold text-white shadow-lg shadow-purple-500/20 transition hover:bg-[#6d28d9] hover:scale-105 active:scale-95">Send message</button>
              ) : null}
            </div>
          ) : (
            <>
              <header className="flex items-center gap-3 border-b border-gray-100 dark:border-white/10 px-4 py-3 bg-white/80 dark:bg-black/80 backdrop-blur-md z-10 sticky top-0">
                <button
                  onClick={closeActiveChat}
                  className="md:hidden p-1 rounded-full hover:bg-gray-100 dark:hover:bg-white/10"
                >
                  <ChevronLeft size={24} />
                </button>
                {activeConversation?.isGroup ? (
                  <>
                    <div className="flex-shrink-0">
                      <MergedGroupAvatar
                        conversation={activeConversation}
                        currentUserId={currentUserId}
                        className="h-9 w-9"
                      />
                    </div>
                    <div className="min-w-0 flex-1">
                      <p className="truncate text-sm font-bold tracking-tight">{activeConversationTitle}</p>
                      <p className="truncate text-[11px] font-medium text-gray-500 dark:text-gray-400">
                        {getGroupMemberLabel(activeConversation, currentUserId, 4)}
                      </p>
                    </div>
                  </>
                ) : (
                  <Link
                    to={`/profile/${otherUserId}`}
                    className="flex min-w-0 flex-1 items-center gap-3 transition hover:opacity-90"
                  >
                    <Avatar user={otherUser} className="h-9 w-9 flex-shrink-0" />
                    <div className="min-w-0">
                      <p className="truncate text-sm font-bold tracking-tight">{activeConversationTitle}</p>
                      <p className="truncate text-[11px] font-medium uppercase tracking-widest text-gray-500 dark:text-gray-400">
                        {activeConversationSubtitle}
                      </p>
                    </div>
                  </Link>
                )}
                {activeConversation?.isGroup ? (
                  <div className="flex items-center gap-2">
                    <button
                      type="button"
                      onClick={() => setShowTopbarLeaveConfirm(true)}
                      disabled={groupActionLoading}
                      className="rounded-full border border-gray-200 px-3 py-1.5 text-xs font-semibold text-gray-600 transition hover:bg-gray-50 disabled:opacity-50 dark:border-white/10 dark:text-gray-300 dark:hover:bg-white/5"
                    >
                      <span className="inline-flex items-center gap-1">
                        <UserMinus size={13} />
                        Leave
                      </span>
                    </button>
                    <button
                      type="button"
                      onClick={() => { loadFollowingForGroup(); setShowManageGroupModal(true); }}
                      disabled={groupActionLoading}
                      className="rounded-full border border-gray-200 p-2 text-gray-600 transition hover:bg-gray-50 disabled:opacity-50 dark:border-white/10 dark:text-gray-300 dark:hover:bg-white/5"
                      aria-label="Group details"
                      title="Group details"
                    >
                      <Info size={16} />
                    </button>
                  </div>
                ) : null}
              </header>

              {activeConversationIsRequestForMe ? (
                <div className="border-b border-amber-200 bg-amber-50 px-4 py-3 dark:border-amber-500/20 dark:bg-amber-500/10">
                  <p className="text-sm font-semibold text-amber-800 dark:text-amber-200">Message request</p>
                  <p className="mt-1 text-xs text-amber-700 dark:text-amber-300">Accept this request to start replying in this chat.</p>
                  <div className="mt-3 flex items-center gap-2">
                    <button
                      type="button"
                      onClick={handleAcceptRequest}
                      disabled={groupActionLoading}
                      className="rounded-full bg-amber-500 px-4 py-2 text-xs font-bold text-white transition hover:bg-amber-600 disabled:opacity-50"
                    >
                      Accept
                    </button>
                    <button
                      type="button"
                      onClick={handleDeclineRequest}
                      disabled={groupActionLoading}
                      className="rounded-full border border-amber-300 px-4 py-2 text-xs font-bold text-amber-700 transition hover:bg-amber-100 disabled:opacity-50 dark:border-amber-400/30 dark:text-amber-200 dark:hover:bg-amber-500/10"
                    >
                      Decline
                    </button>
                  </div>
                </div>
              ) : null}

              <div
                ref={scrollerRef}
                onScroll={(e) => { if (e.currentTarget.scrollTop <= 60) handleLoadMore(); }}
                className="flex-1 min-h-0 overflow-y-auto px-3 py-4 [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden"
              >
                {isLoadingMessages && messages.length === 0 ? (
                  <div className="flex h-full items-center justify-center">
                    <div className="h-8 w-8 animate-spin rounded-full border-2 border-gray-100 dark:border-[#262626] border-t-[#7C3AED]" />
                  </div>
                ) : (!messages.length && activeConversation && !activeConversation?.isGroup) ? (
                  <div className="flex min-h-full items-start justify-center px-6 py-10">
                    <div className="flex w-full max-w-md flex-col items-start text-center">
                      <Link to={`/profile/${otherUserId}`} className="self-center transition hover:opacity-90">
                        <Avatar user={otherUser} className="h-24 w-24 md:h-28 md:w-28" />
                      </Link>
                      <h2 className="mt-6 w-full text-[22px] font-bold tracking-tight text-gray-900 dark:text-white">
                        {getUserName(otherUser)}
                      </h2>
                      <p className="mt-2 w-full text-base text-gray-500 dark:text-gray-400">
                        @{otherUser?.username || getUserName(otherUser).toLowerCase().replace(/\s+/g, '_')}
                      </p>
                      <p className="mt-1 w-full text-sm text-gray-500 dark:text-gray-400">
                        {otherUser?.username || getUserName(otherUser)} · Instagram
                      </p>
                      <Link
                        to={`/profile/${otherUserId}`}
                        className="mt-6 inline-flex self-center items-center justify-center rounded-xl bg-gray-100 px-5 py-2.5 text-sm font-bold text-gray-900 transition hover:bg-gray-200 dark:bg-[#262626] dark:text-white dark:hover:bg-[#303030]"
                      >
                        View Profile
                      </Link>
                    </div>
                  </div>
                ) : (
                  <div className="flex min-h-full flex-col">
                    {showGroupProfileIntro ? (
                      <div className="flex flex-1 items-start justify-center px-6 py-10">
                        <div className="flex w-full max-w-md flex-col items-center text-center">
                          <MergedGroupAvatar
                            conversation={activeConversation}
                            currentUserId={currentUserId}
                            className="h-24 w-24 md:h-28 md:w-28"
                          />
                          <h2 className="mt-6 w-full text-[22px] font-bold tracking-tight text-gray-900 dark:text-white">
                            {activeConversationTitle}
                          </h2>
                          <p className="mt-2 w-full text-sm text-gray-500 dark:text-gray-400">
                            {activeConversationIsGroupAdmin
                              ? 'You created this group'
                              : getGroupMemberLabel(activeConversation, currentUserId, 3)}
                          </p>
                        </div>
                      </div>
                    ) : null}
                    <div className="mt-auto">
                      {groupedMessages.map((item, index) => {
                      if (item.type === 'separator') {
                        return (
                          <div key={item.id} className="my-6 flex justify-center">
                            <span className="rounded-full bg-gray-50 dark:bg-[#111111] border border-gray-100 dark:border-white/5 px-4 py-1 text-[10px] font-bold text-gray-400 dark:text-gray-500 uppercase tracking-widest">
                              {item.label}
                            </span>
                          </div>
                        );
                      }

                      const message = item.message;
                      const mine = String(message?.sender?._id || message?.sender) === String(currentUserId);
                      const senderUser = getMessageSender(activeConversation, message, currentUserId);
                      const senderName = senderUser?.username || getUserName(senderUser);
                      const isSystemNotice = activeConversation?.isGroup && isGroupSystemNotice(message);
                      if (isSystemNotice) {
                        const rawText = String(message?.text || '').trim();
                        const lowerText = rawText.toLowerCase();
                        let displayText = rawText;

                        if (
                          senderName
                          && (lowerText.includes('created the group') || lowerText.includes('created this group'))
                        ) {
                          const createdStart = lowerText.indexOf('created');
                          const suffix = createdStart >= 0 ? rawText.slice(createdStart) : 'created the group chat.';
                          displayText = `${senderName} ${suffix}`.replace(/\s+/g, ' ').trim();
                        }

                        return (
                          <div key={message._id || `sys-${index}`} className="my-3 flex justify-center">
                            <span className="px-2 text-sm text-gray-400 dark:text-gray-500">
                              {displayText}
                            </span>
                          </div>
                        );
                      }
                      const previous = groupedMessages[index - 1]?.message;
                      const next = groupedMessages[index + 1]?.message;
                      const samePrev = previous && String(previous?.sender?._id || previous?.sender) === String(message?.sender?._id || message?.sender);
                      const sameNext = next && String(next?.sender?._id || next?.sender) === String(message?.sender?._id || message?.sender);
                      const showAvatar = !mine && !sameNext;
                      const showSeen = mine && message._id === latestSeenOwnMessageId;
                      const reactionBadge = getReactionBadge(message, currentUserId);
                      const senderUserId = getUserId(senderUser);

                        return (
                          <div
                            key={message._id || `${message.createdAt}-${index}`}
                            className={`mb-1 flex group/msg 
                            ${mine ? 'justify-end pr-4 sm:pr-6' : 'justify-start'} 
                            ${samePrev ? 'mt-1' : 'mt-4'}
                            outline-none select-none [-webkit-tap-highlight-color:transparent]`}
                            onContextMenu={(event) => openContext(event, message)}
                            onTouchStart={() => startLongPress(message)}
                            onTouchEnd={clearLongPress}
                            onTouchMove={clearLongPress}
                            onMouseEnter={() => setHoveredMessageId(message._id)}
                            onMouseLeave={() => setHoveredMessageId(null)}
                          >
                            <div className={`relative flex max-w-[85%] sm:max-w-[75%] flex-col ${mine ? 'items-end' : 'items-start'}`}>
                              <div className={`flex max-w-full items-end gap-2 ${mine ? 'flex-row-reverse' : ''}`}>
                                {!mine ? (showAvatar ? (
                                  <Link to={`/profile/${senderUserId || otherUserId}`} className="flex-shrink-0">
                                    <Avatar user={senderUser || otherUser} className="h-7 w-7 shadow-sm hover:opacity-80 transition-opacity" />
                                  </Link>
                                ) : <div className="w-7" />) : null}

                                <div className="relative">
                                  {reactionPickerFor === message._id && (
                                    <ReactionPicker mine={mine} onSelect={(emoji) => handleSelectReaction(message, emoji)} />
                                  )}
                                  {renderBubble(message, mine)}
                                  {reactionBadge ? (
                                    <div
                                      className={`absolute -bottom-3 ${mine ? 'right-2' : 'left-2'} 
                                      text-[13px] bg-white dark:bg-[#1a1a1a] border border-gray-200 dark:border-white/10 
                                      rounded-full px-2 py-0.5 leading-none cursor-pointer shadow-sm
                                      hover:scale-110 transition-transform z-10`}
                                      onClick={() => handleRemoveOwnReaction(message)}
                                      title={reactionBadge.removable ? 'Remove your reaction' : undefined}
                                    >
                                      {reactionBadge.label}
                                    </div>
                                  ) : null}
                                </div>

                                {!message.isDeleted && hoveredMessageId === message._id && (
                                  <MessageActions
                                    message={message}
                                    mine={mine}
                                    onReply={() => handleReply(message)}
                                    onReact={() => handleReact(message)}
                                    onMore={(e) => handleMoreMenu(e, message)}
                                  />
                                )}
                              </div>
                              {showSeen && (
                                <span className="mt-1.5 px-2 text-[10px] font-bold text-gray-400 dark:text-gray-500 uppercase tracking-widest">
                                  {formatSeenAgo(message.seenAt)}
                                </span>
                              )}
                            </div>
                          </div>
                        );
                      })}
                      {activeTyping.length > 0 && <TypingIndicator />}
                    </div>
                  </div>
                )}
              </div>

              {replyTo && (
                <div className="border-t border-gray-100 dark:border-white/10 bg-white dark:bg-[#050505] px-4 py-3 animate-in slide-in-from-bottom-2 duration-200">
                  <div className="flex items-center justify-between rounded-2xl bg-gray-50 dark:bg-[#121212] border border-gray-100 dark:border-white/5 px-4 py-2.5">
                    <div className="min-w-0">
                      <p className="text-[11px] font-bold text-[#7C3AED] uppercase tracking-wider">Replying to {replyTo.senderName}</p>
                      <p className="truncate text-sm text-gray-500 dark:text-gray-400 mt-0.5">{replyTo.text || 'Attachment'}</p>
                    </div>
                    <button onClick={() => setReplyTo(null)} className="rounded-full p-1.5 text-gray-400 hover:text-gray-900 dark:hover:text-white hover:bg-gray-100 dark:hover:bg-white/5 transition-colors">
                      <X size={16} />
                    </button>
                  </div>
                </div>
              )}

              {!activeConversationCanSend ? (
                <div className="border-t border-gray-100 bg-gray-50 px-4 py-3 text-xs font-medium text-gray-500 dark:border-white/10 dark:bg-[#050505] dark:text-gray-400">
                  You can view this request, but you cannot reply until you accept it.
                </div>
              ) : null}

              <div className="border-t border-gray-100 dark:border-white/10 px-4 py-4 flex-shrink-0 bg-white dark:bg-black">
                <div ref={emojiPickerRef} className="relative">
                  {showEmojiPicker && (
                    <div className="absolute bottom-full left-0 mb-3 z-[120] max-w-[calc(100vw-2rem)] overflow-hidden rounded-2xl border border-gray-200 dark:border-white/10 shadow-2xl">
                      <EmojiPicker
                        theme={mode === 'dark' ? 'dark' : 'light'}
                        onEmojiClick={handleEmojiSelect}
                        lazyLoadEmojis
                        skinTonesDisabled
                        searchDisabled={false}
                        previewConfig={{ showPreview: false }}
                        width="min(352px, calc(100vw - 2rem))"
                        height={400}
                      />
                    </div>
                  )}
                  <div className="flex items-center gap-2 rounded-[28px] bg-gray-50 dark:bg-[#111111] border border-gray-200 dark:border-white/5 px-3 py-2 min-h-[52px] shadow-sm focus-within:shadow-md focus-within:border-gray-300 dark:focus-within:border-white/20 transition-all">
                    {!isRecording ? (
                      <>
                        <button
                          type="button"
                          onClick={() => setShowEmojiPicker((prev) => !prev)}
                          className="rounded-full p-2.5 text-gray-400 hover:text-gray-900 dark:hover:text-white hover:bg-gray-100 dark:hover:bg-white/5 transition-colors"
                          aria-label="Toggle emoji picker"
                        >
                          <Smile size={20} />
                        </button>
                        <input
                          ref={inputRef}
                          value={input}
                          disabled={!activeConversationCanSend}
                          onChange={(event) => handleInputChange(event.target.value)}
                          onKeyDown={(event) => {
                            if (event.key === 'Escape' && showEmojiPicker) { setShowEmojiPicker(false); return; }
                            if (event.key === 'Enter' && !event.shiftKey) { event.preventDefault(); handleSend(); }
                          }}
                          placeholder={activeConversationCanSend ? 'Message...' : 'Accept request to reply'}
                          className="flex-1 bg-transparent text-[15px] outline-none placeholder:text-gray-400 dark:placeholder:text-gray-500 text-gray-900 dark:text-white min-w-0 px-1"
                        />
                        <button onClick={() => fileInputRef.current?.click()} disabled={uploading || !activeConversationCanSend} className="rounded-full p-2.5 text-gray-400 hover:text-gray-900 dark:hover:text-white hover:bg-gray-100 dark:hover:bg-white/5 transition-colors disabled:opacity-50"><ImagePlus size={20} /></button>
                        <button className="rounded-full p-2.5 text-gray-400 hover:text-gray-900 dark:hover:text-white hover:bg-gray-100 dark:hover:bg-white/5 transition-colors hidden sm:block"><Sticker size={20} /></button>
                      </>
                    ) : null}
                    <div className={isRecording ? 'flex-1' : 'flex-shrink-0'}>
                      <VoiceRecorder
                        onSend={handleVoiceSend}
                        onCancel={() => setIsRecording(false)}
                        onStateChange={setIsRecording}
                        disabled={uploading || sending || !activeConversationCanSend}
                      />
                    </div>
                    {!isRecording && input.trim() && !sending && activeConversationCanSend ? (
                      <button
                        onClick={() => handleSend()}
                        disabled={sending || uploading}
                        className="rounded-full p-2.5 text-[#7C3AED] transition hover:bg-purple-50 dark:hover:bg-purple-500/10 hover:text-[#8b5cf6] disabled:opacity-50"
                      >
                        <SendHorizontal size={20} />
                      </button>
                    ) : null}
                  </div>
                </div>
                <input ref={fileInputRef} type="file" accept="image/*,video/*" multiple onChange={handleFile} className="hidden" />
              </div>
            </>
          )}
        </section>
      </div>

      {/* Context menu — unchanged */}
      {contextMenu && (
        <div
          ref={contextRef}
          className="fixed z-[100] min-w-[200px] rounded-2xl border border-gray-100 dark:border-white/10 bg-white dark:bg-[#111111] p-1.5 shadow-2xl animate-in fade-in zoom-in-95 duration-200"
          style={{ left: contextMenu.x, top: contextMenu.y }}
        >
          <button
            onClick={() => {
              const sender = getMessageSender(activeConversation, contextMenu.message, currentUserId);
              const senderName = String(contextMenu.message?.sender?._id || contextMenu.message?.sender) === String(currentUserId) ? 'You' : getUserName(sender);
              setReplyTo({ messageId: contextMenu.message._id, text: contextMenu.message.text || 'Attachment', senderName, senderId: contextMenu.message?.sender?._id || contextMenu.message?.sender });
              setContextMenu(null);
            }}
            className="flex w-full items-center gap-3 rounded-xl px-4 py-2.5 text-left text-sm font-semibold transition hover:bg-gray-50 dark:hover:bg-white/5"
          >
            Reply
          </button>
          {contextMenu?.message?.text && !contextMenu?.message?.isDeleted && (
            <button
              onClick={() => { navigator.clipboard.writeText(contextMenu.message.text).catch(() => {}); setContextMenu(null); }}
              className="flex w-full items-center gap-3 rounded-xl px-4 py-2.5 text-left text-sm font-semibold transition hover:bg-gray-50 dark:hover:bg-white/5"
            >
              Copy
            </button>
          )}
          {String(contextMenu.message?.sender?._id || contextMenu.message?.sender) === String(currentUserId) && (
            <button
              onClick={() => handleDelete(contextMenu.message)}
              className="flex w-full items-center gap-3 rounded-xl px-4 py-2.5 text-left text-sm font-bold text-red-500 transition hover:bg-red-50/80 dark:hover:bg-red-500/10"
            >
              Unsend
            </button>
          )}
        </div>
      )}

      {showTopbarLeaveConfirm ? (
        <div className="fixed inset-0 z-[136] flex items-center justify-center bg-black/70 px-4" onClick={() => setShowTopbarLeaveConfirm(false)}>
          <div
            className="w-full max-w-[620px] overflow-hidden rounded-[24px] border border-white/10 bg-[#1f222b] text-white shadow-2xl"
            onClick={(event) => event.stopPropagation()}
          >
            <div className="border-b border-white/10 px-6 py-5 text-center">
              <p className="text-3xl font-semibold leading-tight">Leave chat?</p>
              <p className="mx-auto mt-3 max-w-[560px] text-[14px] leading-7 text-white/60">
                You won't be able to send or receive messages unless someone adds you back to the chat. No one will be notified that you left the chat.
              </p>
            </div>
            <button
              type="button"
              disabled={groupActionLoading}
              onClick={() => {
                setShowTopbarLeaveConfirm(false);
                handleLeaveGroup();
              }}
              className="w-full border-b border-white/10 px-6 py-4 text-xl font-semibold text-red-400 transition hover:bg-white/5 disabled:opacity-50"
            >
              Leave
            </button>
            <button
              type="button"
              disabled={groupActionLoading}
              onClick={() => setShowTopbarLeaveConfirm(false)}
              className="w-full px-6 py-4 text-xl font-medium text-white/85 transition hover:bg-white/5 disabled:opacity-50"
            >
              Cancel
            </button>
          </div>
        </div>
      ) : null}

      <GroupCreateModal
        isOpen={showGroupModal}
        onClose={() => setShowGroupModal(false)}
        onSubmit={handleCreateGroup}
        users={groupMembers}
        loading={creatingGroup || loadingGroupMembers}
      />
      <GroupManageModal
        isOpen={showManageGroupModal}
        onClose={() => setShowManageGroupModal(false)}
        conversation={activeConversation}
        currentUserId={currentUserId}
        followingUsers={groupMembers}
        onSave={handleSaveGroup}
        onAddMember={handleAddGroupMember}
        onRemoveMember={handleRemoveGroupMember}
        onLeaveChat={handleLeaveGroup}
        onDeleteChat={handleDeleteGroupChat}
        loading={groupActionLoading || loadingGroupMembers}
      />
      <PostDetailModal
        isOpen={!!sharedDetailItem}
        post={sharedDetailItem}
        onClose={() => setSharedDetailItem(null)}
      />
    </div>
  );
}




