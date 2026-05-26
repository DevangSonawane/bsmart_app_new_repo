import { Check, Search, Send, X } from 'lucide-react';
import { useEffect, useMemo, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { getFollowing } from '../services/followService';
import { getConversations, getOnlineUsers, shareContentToUsers } from '../services/chatService';
import { setConversations } from '../store/chatSlice';

const getUserId = (user) => String(user?._id || user?.id || '');
const getUserName = (user) => user?.full_name || user?.name || user?.username || 'User';
const getUserAvatar = (user) => user?.avatar_url || user?.profile_picture || user?.profilePicture || '';
const getInitial = (user) => getUserName(user).trim().charAt(0).toUpperCase() || 'U';
const normalizeId = (id) => String(id || '');

const getConversationId = (conversation) => normalizeId(conversation?._id || conversation?.id);
const getParticipantId = (participant) => normalizeId(participant?._id || participant?.id || participant);
const getConversationParticipants = (conversation, currentUserId) => {
  const participants = Array.isArray(conversation?.participants) ? conversation.participants : [];
  return participants.filter((participant) => getParticipantId(participant) !== normalizeId(currentUserId));
};
const getConversationName = (conversation, currentUserId) => {
  if (conversation?.isGroup) {
    const name = String(conversation?.groupName || '').trim();
    return name || 'Group chat';
  }
  const participants = getConversationParticipants(conversation, currentUserId);
  const other = participants[0];
  return getUserName(other);
};
const getConversationAvatar = (conversation, currentUserId) => {
  if (conversation?.isGroup) return conversation?.groupAvatar || '';
  const participants = getConversationParticipants(conversation, currentUserId);
  const other = participants[0];
  return getUserAvatar(other);
};
const getConversationOnlineUserId = (conversation, currentUserId) => {
  if (conversation?.isGroup) return '';
  const participants = getConversationParticipants(conversation, currentUserId);
  return getParticipantId(participants[0]);
};
const getLabelInitial = (label) => String(label || 'U').trim().charAt(0).toUpperCase() || 'U';
const isShareableConversation = (conversation, currentUserId) => {
  const participants = Array.isArray(conversation?.participants) ? conversation.participants : [];
  const includesMe = participants.some((participant) => getParticipantId(participant) === normalizeId(currentUserId));
  if (!includesMe) return false;
  if (
    conversation?.isRequest
    && conversation?.requestStatus === 'pending'
    && normalizeId(conversation?.requestedBy?._id || conversation?.requestedBy) !== normalizeId(currentUserId)
  ) {
    return false;
  }
  if (conversation?.isGroup) return true;
  return participants.length >= 2;
};
const mergeUniqueConversations = (...lists) => {
  const map = new Map();
  lists.flat().forEach((conversation) => {
    const id = getConversationId(conversation);
    if (!id || map.has(id)) return;
    map.set(id, conversation);
  });
  return Array.from(map.values());
};
const dedupeUsers = (users = []) => {
  const map = new Map();
  users.forEach((user) => {
    const id = getUserId(user);
    if (!id || map.has(id)) return;
    map.set(id, user);
  });
  return Array.from(map.values());
};
const sortConversationsByLastMessage = (items = []) => (
  [...items].sort((a, b) => new Date(b?.lastMessageAt || 0) - new Date(a?.lastMessageAt || 0))
);
const isOutgoingPendingRequest = (conversation, currentUserId) => (
  Boolean(conversation?.isRequest)
  && conversation?.requestStatus === 'pending'
  && normalizeId(conversation?.requestedBy?._id || conversation?.requestedBy) === normalizeId(currentUserId)
);

function AvatarCircle({ src, label, className }) {
  return src ? (
    <img src={src} alt={label} className={`${className} rounded-full object-cover`} />
  ) : (
    <div className={`${className} flex items-center justify-center rounded-full bg-gradient-to-br from-[#7C3AED] to-[#3B82F6] text-sm font-bold text-white`}>
      {getLabelInitial(label)}
    </div>
  );
}

function ShareTargetAvatar({ target, currentUserId }) {
  if (target.type === 'conversation' && target.conversation?.isGroup) {
    const members = getConversationParticipants(target.conversation, currentUserId).slice(0, 2);
    const primaryMember = members[0];
    const secondaryMember = members[1];
    const primarySrc = target.conversation?.groupAvatar || getUserAvatar(primaryMember);
    const secondarySrc = getUserAvatar(secondaryMember);
    const primaryLabel = target.label;
    const secondaryLabel = getUserName(secondaryMember);

    return (
      <div className="relative h-full w-full">
        <AvatarCircle src={primarySrc} label={primaryLabel} className="h-full w-full" />
        {secondaryMember ? (
          <div className="absolute -bottom-0.5 -right-0.5 h-5 w-5 overflow-hidden rounded-full ring-2 ring-[#1a1e28] md:h-6 md:w-6">
            <AvatarCircle src={secondarySrc} label={secondaryLabel} className="h-full w-full text-[10px]" />
          </div>
        ) : null}
      </div>
    );
  }

  return <AvatarCircle src={target.avatar} label={target.label} className="h-full w-full" />;
}

export default function ShareContentModal({
  isOpen,
  onClose,
  contentType,
  contentId,
}) {
  const dispatch = useDispatch();
  const { userObject } = useSelector((state) => state.auth);
  const sidebarConversations = useSelector((state) => state.chat?.conversations || []);
  const currentUserId = userObject?._id || userObject?.id || '';

  const [followingUsers, setFollowingUsers] = useState([]);
  const [conversations, setConversationList] = useState([]);
  const [selectedIds, setSelectedIds] = useState([]);
  const [selectedConversationIds, setSelectedConversationIds] = useState([]);
  const [search, setSearch] = useState('');
  const [loadingUsers, setLoadingUsers] = useState(false);
  const [loadingConversations, setLoadingConversations] = useState(false);
  const [onlineUserIds, setOnlineUserIds] = useState([]);
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    if (!isOpen) return;
    if (!currentUserId) return;

    let mounted = true;
    setLoadingUsers(true);
    setLoadingConversations(true);

    const fetchAllFollowingUsers = async () => {
      const pageLimit = 100;
      let page = 1;
      let allUsers = [];
      while (page <= 20) {
        const response = await getFollowing(currentUserId, { page, limit: pageLimit });
        const users = Array.isArray(response?.users) ? response.users : [];
        allUsers = [...allUsers, ...users];
        const total = Number(response?.total || 0);
        if ((total > 0 && allUsers.length >= total) || users.length < pageLimit) break;
        page += 1;
      }
      return dedupeUsers(allUsers);
    };

    Promise.all([
      fetchAllFollowingUsers().catch(() => []),
      getConversations('normal').catch(() => []),
      getConversations('requests').catch(() => []),
    ])
      .then(([followingUsersRes, normalConversationsRes, requestConversationsRes]) => {
        if (!mounted) return;
        const normalConversations = Array.isArray(normalConversationsRes) ? normalConversationsRes : [];
        const requestConversations = Array.isArray(requestConversationsRes) ? requestConversationsRes : [];
        const sidebar = Array.isArray(sidebarConversations) ? sidebarConversations : [];
        const allConversations = mergeUniqueConversations(sidebar, normalConversations, requestConversations);
        setFollowingUsers(Array.isArray(followingUsersRes) ? followingUsersRes : []);
        setConversationList(allConversations.filter((conversation) => isShareableConversation(conversation, currentUserId)));
      })
      .finally(() => {
        if (!mounted) return;
        setLoadingUsers(false);
        setLoadingConversations(false);
      });

    return () => {
      mounted = false;
    };
  }, [isOpen, currentUserId, sidebarConversations]);

  useEffect(() => {
    if (!isOpen) {
      setSelectedIds([]);
      setSelectedConversationIds([]);
      setSearch('');
      setSubmitting(false);
    }
  }, [isOpen]);

  useEffect(() => {
    if (!isOpen) return;

    const ids = [
      ...followingUsers.map((user) => getUserId(user)),
      ...conversations.map((conversation) => getConversationOnlineUserId(conversation, currentUserId)),
    ].filter(Boolean);
    const uniqueIds = [...new Set(ids.map((id) => String(id)))];

    if (!uniqueIds.length) {
      setOnlineUserIds([]);
      return;
    }

    let active = true;
    const fetchOnline = async () => {
      try {
        const response = await getOnlineUsers(uniqueIds);
        if (!active) return;
        const next = Array.isArray(response?.onlineUserIds) ? response.onlineUserIds.map((id) => String(id)) : [];
        setOnlineUserIds(next);
      } catch {
        if (!active) return;
        setOnlineUserIds([]);
      }
    };

    fetchOnline();
    const interval = setInterval(fetchOnline, 15000);

    return () => {
      active = false;
      clearInterval(interval);
    };
  }, [isOpen, followingUsers, conversations, currentUserId]);

  const filteredUsers = useMemo(() => {
    const query = search.trim().toLowerCase();
    if (!query) return followingUsers;
    return followingUsers.filter((user) => {
      const username = String(user?.username || '').toLowerCase();
      const name = String(getUserName(user)).toLowerCase();
      return username.includes(query) || name.includes(query);
    });
  }, [search, followingUsers]);
  const filteredConversations = useMemo(() => {
    const query = search.trim().toLowerCase();
    if (!query) return conversations;
    return conversations.filter((conversation) => {
      const name = String(getConversationName(conversation, currentUserId)).toLowerCase();
      return name.includes(query);
    });
  }, [search, conversations, currentUserId]);
  const displayTargets = useMemo(() => ([
    ...filteredConversations.map((conversation) => ({
      key: `conversation:${getConversationId(conversation)}`,
      id: getConversationId(conversation),
      type: 'conversation',
      conversation,
      onlineUserId: getConversationOnlineUserId(conversation, currentUserId),
      label: getConversationName(conversation, currentUserId),
      avatar: getConversationAvatar(conversation, currentUserId),
      selected: selectedConversationIds.includes(getConversationId(conversation)),
    })),
    ...filteredUsers.map((user) => ({
      key: `user:${getUserId(user)}`,
      id: getUserId(user),
      type: 'user',
      onlineUserId: getUserId(user),
      label: user?.username || getUserName(user),
      avatar: getUserAvatar(user),
      selected: selectedIds.includes(getUserId(user)),
    })),
  ]), [filteredConversations, filteredUsers, currentUserId, selectedConversationIds, selectedIds]);

  const toggleUser = (userId) => {
    setSelectedIds((prev) => (
      prev.includes(userId)
        ? prev.filter((id) => id !== userId)
        : [...prev, userId]
    ));
  };
  const toggleConversation = (conversationId) => {
    setSelectedConversationIds((prev) => (
      prev.includes(conversationId)
        ? prev.filter((id) => id !== conversationId)
        : [...prev, conversationId]
    ));
  };

  const handleSend = async () => {
    if ((!selectedIds.length && !selectedConversationIds.length) || !contentType || !contentId || submitting) return;
    setSubmitting(true);
    try {
      const shareResponse = await shareContentToUsers({
        recipientIds: selectedIds,
        conversationIds: selectedConversationIds,
        contentType,
        contentId,
      });
      const sentCount = Number(shareResponse?.sentCount || 0);
      const failures = Array.isArray(shareResponse?.failures) ? shareResponse.failures : [];
      const firstFailureReason = failures.length ? String(failures[0]?.reason || '').trim() : '';

      if (sentCount < 1) {
        window.alert(firstFailureReason || 'Share failed. No message was sent.');
        return;
      }

      const sentConversationIds = Array.isArray(shareResponse?.conversationIds)
        ? shareResponse.conversationIds.map((id) => String(id))
        : [];

      let refreshedConversations = [];
      for (let attempt = 0; attempt < 6; attempt += 1) {
        if (attempt > 0) {
          await new Promise((resolve) => setTimeout(resolve, 400));
        }
        const [normalConversationsRes, requestConversationsRes] = await Promise.all([
          getConversations('normal').catch(() => []),
          getConversations('requests').catch(() => []),
        ]);
        const normalConversations = Array.isArray(normalConversationsRes) ? normalConversationsRes : [];
        const requestConversations = Array.isArray(requestConversationsRes) ? requestConversationsRes : [];
        const outgoingRequests = requestConversations.filter((conversation) => isOutgoingPendingRequest(conversation, currentUserId));
        const allRequests = Array.isArray(requestConversationsRes) ? requestConversationsRes : [];
        refreshedConversations = sortConversationsByLastMessage(
          mergeUniqueConversations(normalConversations, allRequests)
        );
        const fetchedIds = refreshedConversations.map((c) => String(c._id));
        const allSentFound = sentConversationIds.length === 0
          || sentConversationIds.every((id) => fetchedIds.includes(id));
        if (refreshedConversations.length && allSentFound) break;
      }

      if (refreshedConversations.length) {
        dispatch(setConversations(refreshedConversations));
      }
      onClose?.();
    } catch (error) {
      const firstFailureReason = Array.isArray(error?.response?.data?.failures) && error.response.data.failures.length
        ? error.response.data.failures[0]?.reason
        : '';
      const message = error?.response?.data?.message || firstFailureReason || error?.message || 'Failed to share content';
      window.alert(message);
    } finally {
      setSubmitting(false);
    }
  };

  const selectedTotal = selectedIds.length + selectedConversationIds.length;

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-[140] flex items-center justify-center bg-black/70 px-4 backdrop-blur-sm" onClick={onClose}>
      <div
        className="flex w-full max-w-[480px] max-h-[72vh] flex-col overflow-hidden rounded-[24px] border border-white/10 bg-gradient-to-b from-[#1f2430] to-[#1a1e28] text-white shadow-2xl"
        onClick={(event) => event.stopPropagation()}
      >
        <div className="flex items-center justify-between px-5 py-3">
          <button onClick={onClose} className="rounded-full p-2 text-white/85 transition hover:bg-white/10 hover:text-white" aria-label="Close share">
            <X size={20} strokeWidth={2.1} />
          </button>
          <p className="text-[20px] font-semibold tracking-tight leading-none">Share</p>
          <div className="w-10" />
        </div>

        <div className="px-5 pb-3">
          <div className="flex items-center gap-3 rounded-xl bg-[#252b36] px-4 py-2">
            <Search size={16} className="text-white/50" />
            <input
              value={search}
              onChange={(event) => setSearch(event.target.value)}
              placeholder="Search"
              className="w-full bg-transparent text-[16px] text-white outline-none placeholder:text-white/50"
            />
          </div>
        </div>

        <div className="flex-1 overflow-y-auto px-5 py-2">
          {loadingUsers || loadingConversations ? (
            <div className="py-10 text-center text-sm text-white/60">Loading...</div>
          ) : null}

          {!loadingUsers && !loadingConversations && !displayTargets.length ? (
            <div className="py-10 text-center text-sm text-white/60">No results found.</div>
          ) : null}

          {!loadingUsers && !loadingConversations && displayTargets.length ? (
            <div className="grid grid-cols-3 gap-x-3 gap-y-4 sm:grid-cols-4 md:grid-cols-5 pb-4">
              {displayTargets.map((target) => (
                <button
                  key={target.key}
                  type="button"
                  onClick={() => (target.type === 'conversation' ? toggleConversation(target.id) : toggleUser(target.id))}
                  className="flex flex-col items-center gap-2 text-center transition hover:opacity-90"
                >
                  <div className="relative h-12 w-12 md:h-14 md:w-14">
                    <ShareTargetAvatar target={target} currentUserId={currentUserId} />
                    {target.onlineUserId && onlineUserIds.includes(String(target.onlineUserId)) ? (
                      <span className="absolute bottom-0 right-0 h-3 w-3 rounded-full border-2 border-[#1a1e28] bg-[#38d430]" />
                    ) : null}
                    {target.selected ? (
                      <span className="absolute -bottom-1 -right-1 flex h-5 w-5 items-center justify-center rounded-full bg-[#2a2f9f] text-white ring-2 ring-[#1a1e28]">
                        <Check size={12} />
                      </span>
                    ) : null}
                  </div>
                  <p className="line-clamp-2 text-xs leading-tight text-white/95">
                    {target.label}
                  </p>
                </button>
              ))}
            </div>
          ) : null}
        </div>

        <div className="border-t border-white/10 px-5 py-3 bg-[#1a1f2a]">
          <button
            type="button"
            disabled={!selectedTotal || submitting}
            onClick={handleSend}
            className="flex w-full items-center justify-center gap-2 rounded-full bg-[#4f58ff] px-5 py-2.5 text-sm font-semibold text-white transition hover:bg-[#626afc] disabled:cursor-not-allowed disabled:bg-[#3a3f5d] disabled:text-white/60"
          >
            <Send size={14} />
            {submitting ? 'Sharing...' : `Share (${selectedTotal})`}
          </button>
        </div>
      </div>
    </div>
  );
}