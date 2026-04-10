import React, { useState, useRef, useEffect, useCallback } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import { useDispatch, useSelector } from 'react-redux';
import { Home, PlusSquare, Clapperboard, User, Menu, Image, Video, Target, Megaphone, Moon, Sun, Search, Heart, Bell, MessageCircle, LayoutDashboard, FileText, CreditCard, Settings, CheckCheck, Trash2, Eye, Clock, X, Play, Loader2 } from 'lucide-react';
import { toggleTheme } from '../store/themeSlice';
import { logoutUser } from '../store/authSlice';
import {
  setTypingUser,
  setUnreadCount,
  updateLastMessage,
  setConversations,
  markConversationRead,
} from '../store/chatSlice';
import { useNotificationSocket } from '../hooks/useNotificationSocket';
import { initChatSocket, removeChatSocketCallbacks } from '../socket/chatSocket';
import { getConversations as getChatConversations } from '../services/chatService';
import { store } from '../store/store';
import PostDetailModal from './PostDetailModal';

const BASE_URL = 'https://api.bebsmart.in';

const authHeaders = () => {
  const token = localStorage.getItem('token');
  return { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) };
};

const getMediaUrl = (item) => {
  const fileUrl = item?.media?.[0]?.fileUrl;
  if (fileUrl) {
    if (fileUrl.startsWith('http')) return fileUrl;
    return `${BASE_URL}/uploads/${fileUrl}`;
  }
  return (
    item?.media?.[0]?.thumbnails?.[0]?.fileUrl ||
    item?.media?.[0]?.thumbnail_url ||
    item?.media?.[0]?.url ||
    item?.image_url ||
    item?.thumbnail_url ||
    null
  );
};

// ── Mini Post card (2-col in sidebar) ────────────────────────────────────────
const SidebarPostCard = ({ post, onClick }) => {
  const thumb = getMediaUrl(post);
  const user = post.user_id || {};
  const username = user.username || post.username || '';
  return (
    <button onClick={() => onClick(post)}
      className="group relative aspect-square overflow-hidden rounded-xl bg-gray-100 dark:bg-gray-800 w-full transition-opacity active:opacity-75">
      {thumb
        ? <img src={thumb} alt="" className="w-full h-full object-cover" />
        : <div className="w-full h-full flex items-center justify-center text-gray-300 dark:text-gray-600">
            <Image size={20} />
          </div>
      }
      <div className="absolute inset-0 bg-black/50 opacity-0 group-hover:opacity-100 transition-opacity flex flex-col justify-between p-1.5">
        {username && <span className="text-white text-[9px] font-bold truncate">@{username}</span>}
        <div className="flex items-center gap-1.5">
          <span className="flex items-center gap-0.5 text-white text-[9px] font-semibold">
            <Heart size={8} className="fill-white" /> {post.likes_count ?? 0}
          </span>
          <span className="flex items-center gap-0.5 text-white text-[9px] font-semibold">
            <MessageCircle size={8} className="fill-white" /> {post.comments_count ?? 0}
          </span>
        </div>
      </div>
    </button>
  );
};

// ── Mini Reel card (2-col in sidebar, hover plays 5s) ────────────────────────
const SidebarReelCard = ({ reel, onClick }) => {
  const videoRef = useRef(null);
  const hoverTimer = useRef(null);
  const [isPlaying, setIsPlaying] = useState(false);
  const thumb = reel?.media?.[0]?.thumbnail?.[0]?.fileUrl || reel?.media?.[0]?.thumbnail_url || null;
  const user = reel.user_id || {};
  const username = user.username || reel.username || '';
  const fileName = reel?.media?.[0]?.fileName || reel?.media?.[0]?.fileUrl || '';
  const isVideo = /\.(mp4|mov|webm|ogg)$/i.test(fileName) || reel?.media?.[0]?.type === 'video';
  const videoSrc = isVideo ? (fileName.startsWith('http') ? fileName : `${BASE_URL}/uploads/${reel?.media?.[0]?.fileName || ''}`) : null;

  const handleMouseEnter = () => {
    if (!videoRef.current || !videoSrc) return;
    hoverTimer.current = setTimeout(() => {
      videoRef.current.currentTime = 0;
      videoRef.current.play().catch(() => {});
      setIsPlaying(true);
      setTimeout(() => {
        if (videoRef.current) { videoRef.current.pause(); videoRef.current.currentTime = 0; }
        setIsPlaying(false);
      }, 5000);
    }, 200);
  };

  const handleMouseLeave = () => {
    clearTimeout(hoverTimer.current);
    if (videoRef.current) { videoRef.current.pause(); videoRef.current.currentTime = 0; }
    setIsPlaying(false);
  };

  return (
    <button
      onClick={() => onClick(reel)}
      onMouseEnter={handleMouseEnter}
      onMouseLeave={handleMouseLeave}
      className="group relative aspect-square overflow-hidden rounded-xl bg-gray-100 dark:bg-gray-800 w-full transition-opacity active:opacity-75"
    >
      {thumb && !isPlaying && <img src={thumb} alt="" className="w-full h-full object-cover" />}
      {videoSrc && (
        <video ref={videoRef} src={videoSrc} muted playsInline preload="none"
          className={`absolute inset-0 w-full h-full object-cover transition-opacity duration-200 ${isPlaying ? 'opacity-100' : 'opacity-0'}`} />
      )}
      {!thumb && !isPlaying && (
        <div className="w-full h-full flex items-center justify-center text-gray-300 dark:text-gray-600">
          <Clapperboard size={20} />
        </div>
      )}
      {!isPlaying && (
        <div className="absolute top-1 right-1 bg-black/60 rounded-sm p-0.5">
          <svg width="7" height="7" viewBox="0 0 24 24" fill="white"><polygon points="5 3 19 12 5 21 5 3"/></svg>
        </div>
      )}
      {isPlaying && (
        <div className="absolute top-1 right-1 bg-pink-600 rounded-sm px-1 py-0.5">
          <span className="text-white text-[7px] font-bold leading-none">▶</span>
        </div>
      )}
      <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity flex flex-col justify-between p-1.5">
        {username && <span className="text-white text-[9px] font-bold truncate">@{username}</span>}
        <div className="flex items-center gap-1.5">
          <span className="flex items-center gap-0.5 text-white text-[9px] font-semibold"><Heart size={8} className="fill-white" /> {reel.likes_count ?? 0}</span>
          <span className="flex items-center gap-0.5 text-white text-[9px] font-semibold"><Eye size={8} /> {reel.views_count ?? 0}</span>
        </div>
      </div>
      {videoSrc && !isPlaying && (
        <div className="absolute inset-0 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none">
          <div className="w-8 h-8 rounded-full bg-black/50 flex items-center justify-center">
            <Play size={12} fill="white" className="text-white ml-0.5" />
          </div>
        </div>
      )}
    </button>
  );
};

const Sidebar = ({ onOpenCreateModal }) => {
  const location = useLocation();
  const navigate = useNavigate();
  const dispatch = useDispatch();
  const { mode } = useSelector((state) => state.theme);
  const { userObject } = useSelector((state) => state.auth);
  const chatUnreadCount = useSelector((state) =>
    Object.values(state.chat?.unreadCounts || {})
      .reduce((sum, count) => sum + Number(count || 0), 0)
  );
  const userId = userObject?._id || userObject?.id;
  const token = localStorage.getItem('token');
  const isVendorValidated = Boolean(
    userObject?.vendor_validated ??
    userObject?.validated ??
    userObject?.vendor?.validated
  );
  const [isHovered, setIsHovered] = useState(false);
  const [isCreateDropdownOpen, setIsCreateDropdownOpen] = useState(false);
  const [isMoreDropdownOpen, setIsMoreDropdownOpen] = useState(false);
  const [showNotifications, setShowNotifications] = useState(false);
  const [showVendorNotValidated, setShowVendorNotValidated] = useState(false);
  const [nowTs, setNowTs] = useState(() => Date.now());
  const dropdownRef = useRef(null);
  const moreDropdownRef = useRef(null);
  const notificationsRef = useRef(null);

  // ── Sidebar Search state ─────────────────────────────────────────────────────
  const [showSearch, setShowSearch] = useState(false);
  const [sidebarSearchQuery, setSidebarSearchQuery] = useState('');
  const [sidebarSearchResults, setSidebarSearchResults] = useState({ users: [], posts: [], reels: [] });
  const [sidebarSearchLoading, setSidebarSearchLoading] = useState(false);
  const [sidebarSelectedPost, setSidebarSelectedPost] = useState(null);
  const [searchActiveTab, setSearchActiveTab] = useState('all');
  const [searchHistory, setSearchHistory] = useState([]);
  const [historyLoading, setHistoryLoading] = useState(false);
  const [sidebarPostLimit, setSidebarPostLimit] = useState(10);
  const [sidebarReelLimit, setSidebarReelLimit] = useState(10);
  const [sidebarUserLimit, setSidebarUserLimit] = useState(10);
  const [sidebarLoadingMore, setSidebarLoadingMore] = useState(false);
  const sidebarSearchRef = useRef(null);
  const sidebarSearchInputRef = useRef(null);
  const sidebarSearchDebounce = useRef(null);
  const sidebarSocketCallbacksRef = useRef(null);

  // ── Notifications via shared WS hook ────────────────────────────────────────
  const isVendor = userObject?.role === 'vendor';
  const notifPage = isVendor ? '/vendor/notifications' : '/notifications';

  const {
    notifications, unreadCount, loading: notifLoading,
    markRead, markAllRead, deleteNotif,
  } = useNotificationSocket({ limit: 8, page: 1 });

  const timeAgo = (d) => {
    if (!d) return "";
    const diff = nowTs - new Date(d).getTime();
    const m = Math.floor(diff / 60000);
    if (m < 1) return "just now";
    if (m < 60) return `${m}m ago`;
    const h = Math.floor(m / 60);
    if (h < 24) return `${h}h ago`;
    return `${Math.floor(h / 24)}d ago`;
  };

  const NOTIF_ICON = { like: <Heart size={12} className="text-pink-500" />, comment: <MessageCircle size={12} className="text-orange-500" />, follow: <User size={12} className="text-blue-500" />, mention: <Bell size={12} className="text-purple-500" />, ad_approved: <Megaphone size={12} className="text-green-500" />, ad_rejected: <Megaphone size={12} className="text-red-500" />, ad_spend: <CreditCard size={12} className="text-amber-500" />, wallet_credit: <CreditCard size={12} className="text-emerald-500" /> };
  const NOTIF_BG   = { like: "bg-pink-50 dark:bg-pink-900/20", comment: "bg-orange-50 dark:bg-orange-900/20", follow: "bg-blue-50 dark:bg-blue-900/20", mention: "bg-purple-50 dark:bg-purple-900/20", ad_approved: "bg-green-50 dark:bg-green-900/20", ad_rejected: "bg-red-50 dark:bg-red-900/20", ad_spend: "bg-amber-50 dark:bg-amber-900/20", wallet_credit: "bg-emerald-50 dark:bg-emerald-900/20" };
  const notifTypeIcon = (type) => NOTIF_ICON[type] || <Bell size={12} className="text-gray-500" />;
  const notifTypeBg   = (type) => NOTIF_BG[type]   || "bg-gray-100 dark:bg-gray-800";

  const syncChatConversations = useCallback(async () => {
    if (!userId) return;
    try {
      const conversations = await getChatConversations();
      dispatch(setConversations(Array.isArray(conversations) ? conversations : []));
    } catch (error) {
      console.error('Failed to sync chat conversations:', error);
    }
  }, [dispatch, userId]);

  useEffect(() => {
    if (!userId || !token) return;

    const onNewMessage = (message) => {
      const incomingConversationId = String(
        message?.conversationId?._id ||
        message?.conversationId || ''
      );
      if (!incomingConversationId) return;

      dispatch(updateLastMessage({
        conversationId: incomingConversationId,
        lastMessage: message,
        lastMessageAt: message.createdAt || new Date().toISOString(),
      }));

      const currentPath = window.location.pathname;
      const isViewingThisChat =
        currentPath === `/messages/${incomingConversationId}`;

      if (!isViewingThisChat) {
        const freshState = store.getState();
        const currentCount =
          freshState.chat?.unreadCounts?.[incomingConversationId] || 0;
        dispatch(setUnreadCount({
          conversationId: incomingConversationId,
          count: currentCount + 1,
        }));

        const conversationExists = freshState.chat?.conversations?.some(
          (c) => String(c._id) === incomingConversationId
        );
        if (!conversationExists) {
          getChatConversations()
            .then((data) => {
              if (Array.isArray(data)) dispatch(setConversations(data));
            })
            .catch(() => {});
        }
      }
    };

    const onUserTyping = ({ conversationId, userId: typingUserId }) => {
      dispatch(setTypingUser({
        conversationId,
        userId: typingUserId,
        isTyping: true,
      }));
    };

    const onUserStopTyping = ({ conversationId, userId: typingUserId }) => {
      dispatch(setTypingUser({
        conversationId,
        userId: typingUserId,
        isTyping: false,
      }));
    };

    const callbacks = {
      onNewMessage,
      onUserTyping,
      onUserStopTyping,
      onMessageSeenUpdate: () => {},
      onMessageRemoved: () => {},
    };

    sidebarSocketCallbacksRef.current = callbacks;
    initChatSocket(token, callbacks, userId);

    return () => {
      if (sidebarSocketCallbacksRef.current) {
        removeChatSocketCallbacks(sidebarSocketCallbacksRef.current);
      }
    };
  }, [userId, token, dispatch]);

  useEffect(() => {
    const handleClickOutside = (event) => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target)) {
        setIsCreateDropdownOpen(false);
      }
      if (moreDropdownRef.current && !moreDropdownRef.current.contains(event.target)) {
        setIsMoreDropdownOpen(false);
      }
      if (notificationsRef.current && !notificationsRef.current.contains(event.target)) {
        setShowNotifications(false);
      }
      if (sidebarSearchRef.current && !sidebarSearchRef.current.contains(event.target)) {
        setShowSearch(false);
        setSidebarSearchQuery('');
        setSidebarSearchResults({ users: [], posts: [], reels: [] });
        setSearchActiveTab('all');
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, []);

  useEffect(() => {
    const timer = setInterval(() => setNowTs(Date.now()), 60000);
    return () => clearInterval(timer);
  }, []);

  useEffect(() => {
    if (!userId) return undefined;

    syncChatConversations();

    const interval = setInterval(() => {
      if (document.visibilityState === 'visible') {
        syncChatConversations();
      }
    }, 15000);

    const handleVisibility = () => {
      if (document.visibilityState === 'visible') {
        syncChatConversations();
      }
    };

    document.addEventListener('visibilitychange', handleVisibility);
    return () => {
      clearInterval(interval);
      document.removeEventListener('visibilitychange', handleVisibility);
    };
  }, [syncChatConversations, userId]);

  // ── Search History ───────────────────────────────────────────────────────────
  const loadHistory = useCallback(async () => {
    if (!userId) return;
    setHistoryLoading(true);
    try {
      const res = await fetch(`${BASE_URL}/api/search/history/${userId}`, { headers: authHeaders() });
      if (res.ok) {
        const data = await res.json();
        setSearchHistory(Array.isArray(data) ? data : (data.history || data.data || []));
      }
    } catch { /* silent */ } finally { setHistoryLoading(false); }
  }, [userId]);

  const clearAllHistory = async () => {
    if (!userId) return;
    try {
      await fetch(`${BASE_URL}/api/search/history/${userId}`, { method: 'DELETE', headers: authHeaders() });
      setSearchHistory([]);
    } catch { /* silent */ }
  };

  const deleteHistoryItem = async (historyId, e) => {
    e.stopPropagation();
    try {
      await fetch(`${BASE_URL}/api/search/history/${userId}/${historyId}`, { method: 'DELETE', headers: authHeaders() });
      setSearchHistory(prev => prev.filter(h => (h._id || h.id) !== historyId));
    } catch { /* silent */ }
  };

  const handleHistoryClick = (item) => {
    const q = typeof item === 'string' ? item : (item.query || item.keyword || item.text || '');
    if (!q) return;
    setSidebarSearchQuery(q);
    setSearchActiveTab('all');
    runSidebarSearch(q);
  };

  // ── Sidebar search fetch ─────────────────────────────────────────────────────
  const runSidebarSearch = async (q, { uLimit = 10, pLimit = 10, rLimit = 10, showLoader = true } = {}) => {
    const query = q.trim();
    if (!query) { setSidebarSearchResults({ users: [], posts: [], reels: [] }); return; }
    if (showLoader) setSidebarSearchLoading(true);
    else setSidebarLoadingMore(true);
    try {
      const maxLimit = Math.max(uLimit, pLimit, rLimit);
      const res = await fetch(`${BASE_URL}/api/search?q=${encodeURIComponent(query)}&limit=${maxLimit}`, { headers: authHeaders() });
      if (res.ok) {
        const data = await res.json();
        const r = data.results || {};
        setSidebarSearchResults({
          users: (r.users || []).slice(0, uLimit),
          posts: (r.posts || []).slice(0, pLimit),
          reels: (r.reels || []).slice(0, rLimit),
        });
      } else {
        setSidebarSearchResults({ users: [], posts: [], reels: [] });
      }
    } catch { setSidebarSearchResults({ users: [], posts: [], reels: [] }); }
    finally { setSidebarSearchLoading(false); setSidebarLoadingMore(false); }
  };

  const handleSidebarLoadMore = async () => {
    const newPostLimit = sidebarPostLimit + 10;
    const newReelLimit = sidebarReelLimit + 10;
    const newUserLimit = sidebarUserLimit + 10;
    setSidebarPostLimit(newPostLimit);
    setSidebarReelLimit(newReelLimit);
    setSidebarUserLimit(newUserLimit);
    await runSidebarSearch(sidebarSearchQuery, {
      uLimit: newUserLimit, pLimit: newPostLimit, rLimit: newReelLimit, showLoader: false,
    });
  };

  const handleSidebarSearchInput = (e) => {
    const q = e.target.value;
    setSidebarSearchQuery(q);
    setSearchActiveTab('all');
    setSidebarPostLimit(10); setSidebarReelLimit(10); setSidebarUserLimit(10);
    clearTimeout(sidebarSearchDebounce.current);
    if (!q.trim()) { setSidebarSearchResults({ users: [], posts: [], reels: [] }); return; }
    sidebarSearchDebounce.current = setTimeout(() => runSidebarSearch(q), 350);
  };

  const openSidebarSearch = () => {
    setShowSearch(true);
    setShowNotifications(false);
    loadHistory();
    setTimeout(() => sidebarSearchInputRef.current?.focus(), 80);
  };

  const closeSidebarSearch = () => {
    setShowSearch(false);
    setSidebarSearchQuery('');
    setSidebarSearchResults({ users: [], posts: [], reels: [] });
    setSearchActiveTab('all');
    setSidebarPostLimit(10); setSidebarReelLimit(10); setSidebarUserLimit(10);
  };

  // ── Derived tab data ─────────────────────────────────────────────────────────
  const hasResults = sidebarSearchResults.users.length + sidebarSearchResults.posts.length + sidebarSearchResults.reels.length > 0;
  const results = sidebarSearchResults;

  const filteredUsers = searchActiveTab === 'posts' || searchActiveTab === 'reels' ? [] : results.users;
  const filteredPosts = searchActiveTab === 'people' || searchActiveTab === 'reels' ? [] : results.posts;
  const filteredReels = searchActiveTab === 'people' || searchActiveTab === 'posts' ? [] : results.reels;

  const hasMoreSidebar = sidebarSearchQuery.trim() && hasResults && (
    results.users.length >= sidebarUserLimit ||
    results.posts.length >= sidebarPostLimit ||
    results.reels.length >= sidebarReelLimit
  );

  const searchTabs = [
    { key: 'all',    label: 'All' },
    { key: 'people', label: `People${sidebarSearchQuery ? ` (${results.users.length})` : ''}` },
    { key: 'posts',  label: `Posts${sidebarSearchQuery ? ` (${results.posts.length})` : ''}` },
    { key: 'reels',  label: `Reels${sidebarSearchQuery ? ` (${results.reels.length})` : ''}` },
  ];

  const navItems = isVendor ? [
    { icon: LayoutDashboard, label: 'Dashboard', path: '/vendor/dashboard' },
    { icon: User, label: 'Vendor Profile', path: '/vendor/profile' },
    { icon: Target, label: 'Ads Management', path: '/vendor/ads-management' },
    { icon: PlusSquare, label: 'Create', path: null, action: () => setIsCreateDropdownOpen(!isCreateDropdownOpen) },
    { icon: FileText, label: 'Reports & Analytics', path: '/vendor/analytics' },
    { icon: CreditCard, label: 'Coins & Billing', path: '/vendor/billing' },
    { icon: Settings, label: 'Settings', path: '/vendor/settings' },
  ] : [
    { icon: Home, label: 'Home', path: '/' },
    { icon: Search, label: 'Search', path: null, action: openSidebarSearch },
    { icon: PlusSquare, label: 'Create', path: null, action: () => setIsCreateDropdownOpen(!isCreateDropdownOpen) },
    { icon: Clapperboard, label: 'Reels', path: '/reels' },
    { icon: MessageCircle, label: 'Messages', path: '/messages' },
    { icon: Target, label: 'Ads', path: '/ads' },
    { icon: User, label: 'Profile', path: '/profile' },
  ];

  return (
    <>
      <div
        className={`hidden md:flex flex-col fixed left-0 top-0 h-full bg-white dark:bg-black border-r border-gray-200 dark:border-gray-800 z-50 transition-all duration-300 ease-in-out ${isHovered ? 'w-64' : 'w-20'}`}
        onMouseEnter={() => setIsHovered(true)}
        onMouseLeave={() => setIsHovered(false)}
      >
        <div className="p-6 mb-2">
          {isHovered ? (
            <div className="flex items-center gap-2">
              <div className="w-8 h-8 rounded-lg bg-gradient-to-tr from-insta-yellow via-insta-orange to-insta-pink flex items-center justify-center text-white font-bold text-lg shadow-md">
                b
              </div>
              <h1 className="text-2xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange transition-opacity duration-300" style={{ fontFamily: 'cursive' }}>
                B-Smart
              </h1>
            </div>
          ) : (
            <div className="w-10 h-10 rounded-lg bg-gradient-to-tr from-insta-yellow via-insta-orange to-insta-pink flex items-center justify-center text-white font-bold text-xl shadow-md transition-transform hover:scale-105">
              b
            </div>
          )}
        </div>

        <div className="flex-1 flex flex-col gap-2 px-3">
          {navItems.map((item) => {
            const Icon = item.icon;
            const isActive = item.path
              ? (item.path === '/' ? location.pathname === '/' : location.pathname.startsWith(item.path))
              : item.label === 'Create' && isCreateDropdownOpen;

            if (item.label === 'Search') {
              return (
                <div key={item.label} className="relative" ref={sidebarSearchRef}>
                  <button
                    onClick={openSidebarSearch}
                    className={`group w-full flex items-center gap-4 p-3 rounded-xl transition-all duration-200 ${showSearch ? 'bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange text-white shadow-md' : 'hover:bg-gray-50 dark:hover:bg-gray-900 text-gray-900 dark:text-white'}`}
                  >
                    <div className="min-w-[24px]">
                      <Icon
                        size={24}
                        className={`${showSearch ? 'text-white' : 'text-gray-900 dark:text-white'} transition-transform duration-150 group-hover:scale-110 ${!showSearch && 'group-hover:text-black dark:group-hover:text-white'}`}
                        strokeWidth={showSearch ? 2.5 : 2}
                      />
                    </div>
                    <span className={`text-base font-medium whitespace-nowrap overflow-hidden transition-all duration-300 ${!showSearch && 'group-hover:text-black dark:group-hover:text-white'} ${isHovered ? 'opacity-100 w-auto' : 'opacity-0 w-0'} ${showSearch ? 'text-white font-bold' : 'dark:text-white'}`}>
                      Search
                    </span>
                  </button>
                </div>
              );
            }

            if (item.label === 'Create') {
              return (
                <div key={item.label} className="relative" ref={dropdownRef}>
                  <button
                    onClick={item.action}
                    className={`group w-full flex items-center gap-4 p-3 rounded-lg transition-colors duration-200 ${isActive ? 'bg-gradient-to-r from-insta-purple/10 to-insta-orange/10 dark:from-insta-purple/20 dark:to-insta-orange/20' : 'hover:bg-gray-50 dark:hover:bg-gray-900'}`}
                  >
                    <div className="min-w-[24px]">
                      <Icon
                        size={24}
                        className={`${isActive ? 'text-[#fa3f5e]' : 'text-gray-900 dark:text-white'} transition-transform duration-150 group-hover:scale-110 group-hover:text-black dark:group-hover:text-white`}
                        strokeWidth={isActive ? 2.5 : 2}
                      />
                    </div>
                    <span
                      className={`text-base font-medium whitespace-nowrap overflow-hidden transition-all duration-300 group-hover:text-black dark:group-hover:text-white ${isHovered ? 'opacity-100 w-auto' : 'opacity-0 w-0'} ${isActive ? 'text-[#fa3f5e] font-bold' : 'dark:text-white'}`}
                    >
                      {item.label}
                    </span>
                  </button>

                  {isCreateDropdownOpen && (
                    <div className={`absolute left-0 top-full mt-2 w-48 bg-white dark:bg-[#262626] rounded-lg shadow-lg border border-gray-100 dark:border-gray-800 py-2 z-[60] overflow-hidden ${isHovered ? 'translate-x-0' : 'translate-x-14'}`}>
                      {!isVendor && (
                        <>
                          <button
                            onClick={() => { onOpenCreateModal('post'); setIsCreateDropdownOpen(false); }}
                            className="w-full text-left px-4 py-3 hover:bg-gray-50 dark:hover:bg-gray-800 flex items-center gap-3 text-sm font-medium text-gray-700 dark:text-gray-200"
                          >
                            <Image size={18} /> Create Post
                          </button>
                          <button
                            onClick={() => { onOpenCreateModal('reel'); setIsCreateDropdownOpen(false); }}
                            className="w-full text-left px-4 py-3 hover:bg-gray-50 dark:hover:bg-gray-800 flex items-center gap-3 text-sm font-medium text-gray-700 dark:text-gray-200"
                          >
                            <Video size={18} /> Upload Reel
                          </button>
                        </>
                      )}
                      {isVendor && (
                        <button
                          onClick={() => {
                            if (!isVendorValidated) { setShowVendorNotValidated(true); }
                            else { onOpenCreateModal('ad'); }
                            setIsCreateDropdownOpen(false);
                          }}
                          className="w-full text-left px-4 py-3 hover:bg-gray-50 dark:hover:bg-gray-800 flex items-center gap-3 text-sm font-medium text-gray-700 dark:text-gray-200"
                        >
                          <Megaphone size={18} /> Upload Ad
                        </button>
                      )}
                    </div>
                  )}
                </div>
              );
            }

            return (
              <Link
                key={item.label}
                to={item.path}
                className={`group flex items-center gap-4 p-3 rounded-xl transition-all duration-200 ${isActive ? 'bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange text-white shadow-md' : 'hover:bg-gray-50 dark:hover:bg-gray-900 text-gray-900 dark:text-white'}`}
              >
                <div className="min-w-[24px] relative">
                  <Icon
                    size={24}
                    className={`${isActive ? 'text-white' : 'text-gray-900 dark:text-white'} transition-transform duration-150 group-hover:scale-110 ${!isActive && 'group-hover:text-black dark:group-hover:text-white'}`}
                    strokeWidth={isActive ? 2.5 : 2}
                  />
                  {item.label === 'Messages' && chatUnreadCount > 0 && (
                    <span className="absolute -top-1 -right-1 min-w-[16px] h-4 px-1 rounded-full bg-blue-500 text-white text-[9px] font-black flex items-center justify-center leading-none border border-white dark:border-black">
                      {chatUnreadCount > 99 ? '99+' : chatUnreadCount}
                    </span>
                  )}
                </div>
                <span className={`text-base font-medium whitespace-nowrap overflow-hidden transition-all duration-300 ${!isActive && 'group-hover:text-black dark:group-hover:text-white'} ${isHovered ? 'opacity-100 w-auto' : 'opacity-0 w-0'} ${isActive ? 'text-white font-bold' : ''}`}>
                  {item.label}
                </span>
              </Link>
            );
          })}

          {/* Notifications */}
          <div className="relative" ref={notificationsRef}>
            <button
              onClick={() => setShowNotifications(!showNotifications)}
              className={`group w-full flex items-center gap-4 p-3 rounded-xl transition-all duration-200 ${showNotifications ? 'bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange text-white shadow-md' : 'hover:bg-gray-50 dark:hover:bg-gray-900 text-gray-900 dark:text-white'}`}
            >
              <div className="min-w-[24px] relative">
                <Bell size={24} className={`${showNotifications ? 'text-white' : 'text-gray-900 dark:text-white'} transition-transform duration-150 group-hover:scale-110 ${!showNotifications && 'group-hover:text-black dark:group-hover:text-white'}`} strokeWidth={showNotifications ? 2.5 : 2} />
                {unreadCount > 0 && (
                  <span className="absolute -top-1 -right-1 min-w-[16px] h-4 px-1 rounded-full bg-red-500 text-white text-[9px] font-black flex items-center justify-center leading-none border border-white dark:border-black">
                    {unreadCount > 99 ? "99+" : unreadCount}
                  </span>
                )}
              </div>
              <span className={`text-base font-medium whitespace-nowrap overflow-hidden transition-all duration-300 ${!showNotifications && 'group-hover:text-black dark:group-hover:text-white'} ${isHovered ? 'opacity-100 w-auto' : 'opacity-0 w-0'} ${showNotifications ? 'text-white font-bold' : ''}`}>
                Notifications
              </span>
            </button>
            {showNotifications && (
              <div className={`absolute left-full top-1/2 -translate-y-1/2 ml-3 w-80 z-[60] animate-fade-in ${isHovered ? 'translate-x-0' : 'translate-x-2'}`}>
                <div className="bg-white dark:bg-[#262626] rounded-xl shadow-xl border border-gray-100 dark:border-gray-800 py-2 overflow-hidden">
                  <div className="px-4 py-3 border-b border-gray-50 dark:border-gray-800 flex justify-between items-center">
                    <div className="flex items-center gap-2">
                      <h3 className="font-semibold text-sm dark:text-white">Notifications</h3>
                      {unreadCount > 0 && <span className="text-[10px] font-black px-1.5 py-0.5 rounded-full bg-blue-600 text-white leading-none">{unreadCount}</span>}
                    </div>
                    <div className="flex items-center gap-2">
                      {unreadCount > 0 && (
                        <button onClick={markAllRead} className="text-xs text-blue-500 font-semibold hover:underline flex items-center gap-1">
                          <CheckCheck size={12} /> All read
                        </button>
                      )}
                      <button onClick={() => { setShowNotifications(false); navigate(notifPage); }} className="text-xs text-[#fa3f5e] font-medium hover:underline">See all</button>
                    </div>
                  </div>
                  <div className="max-h-80 overflow-y-auto">
                    {notifLoading && notifications.length === 0 ? (
                      <div className="flex items-center justify-center py-8 text-gray-400 gap-2 text-xs">
                        <span className="w-4 h-4 border-2 border-gray-300 border-t-pink-500 rounded-full animate-spin" /> Loading…
                      </div>
                    ) : notifications.length === 0 ? (
                      <div className="flex flex-col items-center justify-center py-8 text-gray-400 gap-2">
                        <Bell size={20} className="opacity-30" /><span className="text-xs">No notifications yet</span>
                      </div>
                    ) : (
                      notifications.map(n => (
                        <div key={n._id}
                          onClick={() => { markRead(n._id); setShowNotifications(false); if (n.link) navigate(n.link); }}
                          className={`group px-4 py-3 hover:bg-gray-50 dark:hover:bg-gray-800 flex gap-3 items-start cursor-pointer transition-colors relative ${!n.isRead ? 'bg-blue-50/50 dark:bg-blue-900/10' : ''}`}
                        >
                          {!n.isRead && <div className="absolute left-1.5 top-1/2 -translate-y-1/2 w-1.5 h-1.5 rounded-full bg-blue-500 flex-shrink-0" />}
                          <div className="relative flex-shrink-0">
                            {n.sender?.avatar_url
                              ? <img src={n.sender.avatar_url} alt="" className="w-8 h-8 rounded-full object-cover" />
                              : <div className="w-8 h-8 rounded-full bg-gradient-to-br from-purple-500 to-pink-500 flex items-center justify-center text-white text-[10px] font-bold">{(n.sender?.full_name || n.sender?.username || "U")[0]?.toUpperCase()}</div>}
                            <div className={`absolute -bottom-0.5 -right-0.5 w-4 h-4 rounded-full ${notifTypeBg(n.type)} flex items-center justify-center ring-1 ring-white dark:ring-[#262626]`}>{notifTypeIcon(n.type)}</div>
                          </div>
                          <div className="flex-1 min-w-0">
                            <p className={`text-xs leading-snug ${!n.isRead ? 'font-semibold text-gray-900 dark:text-white' : 'text-gray-600 dark:text-gray-300'}`}>{n.message}</p>
                            <p className="text-[10px] text-gray-400 dark:text-gray-500 mt-0.5">{timeAgo(n.createdAt)}</p>
                          </div>
                          <button onClick={e => { e.stopPropagation(); deleteNotif(n._id); }}
                            className="opacity-0 group-hover:opacity-100 transition-opacity p-1 rounded hover:bg-red-100 dark:hover:bg-red-900/30">
                            <Trash2 size={11} className="text-red-400" />
                          </button>
                        </div>
                      ))
                    )}
                  </div>
                  <div className="px-4 py-2 border-t border-gray-50 dark:border-gray-800">
                    <button onClick={() => { setShowNotifications(false); navigate(notifPage); }}
                      className="w-full text-xs font-semibold text-center text-gray-500 dark:text-gray-400 hover:text-gray-800 dark:hover:text-white transition-colors py-1">
                      View all notifications →
                    </button>
                  </div>
                </div>
              </div>
            )}
          </div>

          {/* More dropdown */}
          <div className={`mt-auto pb-4 relative`} ref={moreDropdownRef}>
            {isMoreDropdownOpen && (
              <div className={`absolute bottom-full left-0 mb-2 w-64 bg-white dark:bg-[#262626] rounded-xl shadow-xl border border-gray-100 dark:border-gray-800 py-2 z-[60] overflow-hidden ${isHovered ? 'translate-x-0' : 'translate-x-14'}`}>
                {isVendor && (
                  <>
                    <button
                      onClick={() => { setIsMoreDropdownOpen(false); dispatch(logoutUser()); navigate('/login'); }}
                      className="w-full text-left px-4 py-3 hover:bg-red-50 dark:hover:bg-red-900/20 flex items-center gap-3 text-sm font-medium text-red-500 dark:text-red-400 transition-colors"
                    >
                      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" y1="12" x2="9" y2="12"/></svg>
                      Log Out
                    </button>
                    <div className="border-t border-gray-100 dark:border-gray-800 my-1" />
                  </>
                )}
                <button
                  onClick={() => dispatch(toggleTheme())}
                  className="w-full text-left px-4 py-3 hover:bg-gray-50 dark:hover:bg-gray-800 flex items-center justify-between text-sm font-medium text-gray-700 dark:text-gray-200 transition-colors"
                >
                  <div className="flex items-center gap-3">{mode === 'dark' ? <Moon size={18} /> : <Sun size={18} />} Switch Appearance</div>
                  {mode === 'dark' && <div className="w-2 h-2 rounded-full bg-blue-500"></div>}
                </button>
                {!isVendor && (
                  <Link to="/settings" className="w-full text-left px-4 py-3 hover:bg-gray-50 dark:hover:bg-gray-800 flex items-center gap-3 text-sm font-medium text-gray-700 dark:text-gray-200" onClick={() => setIsMoreDropdownOpen(false)}>
                    <Target size={18} /> Settings
                  </Link>
                )}
              </div>
            )}
            <button
              onClick={() => setIsMoreDropdownOpen(!isMoreDropdownOpen)}
              className="w-full group flex items-center gap-4 p-3 rounded-xl hover:bg-gray-50 dark:hover:bg-gray-900 transition-colors"
            >
              <div className="min-w-[24px]"><Menu size={24} className="text-gray-900 dark:text-white transition-transform duration-150 group-hover:scale-110 group-hover:text-black dark:group-hover:text-white" /></div>
              <span className={`text-base font-medium whitespace-nowrap overflow-hidden transition-all duration-300 group-hover:text-black dark:group-hover:text-white ${isHovered ? 'opacity-100 w-auto' : 'opacity-0 w-0'} dark:text-white`}>More</span>
            </button>
          </div>
        </div>
      </div>

      {/* ── Instagram-style Search Panel (desktop only, member only) ── */}
      {showSearch && !isVendor && (
        <>
          <div className="hidden md:block fixed inset-0 z-[45]" onClick={closeSidebarSearch} />
          <div
            ref={sidebarSearchRef}
            className="hidden md:flex flex-col fixed top-0 left-20 h-full w-[400px] bg-white dark:bg-[#0a0a0a] border-r border-gray-200 dark:border-gray-800 z-[46] shadow-2xl"
            style={{ animation: 'slideInSearch 0.22s cubic-bezier(0.4,0,0.2,1)' }}
          >
            {/* Header */}
            <div className="px-6 pt-8 pb-4 flex-shrink-0">
              <div className="flex items-center justify-between mb-5">
                <h2 className="text-2xl font-bold text-gray-900 dark:text-white">Search</h2>
                <button onClick={closeSidebarSearch} className="p-1.5 rounded-full hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors text-gray-500 dark:text-gray-400">
                  <X size={18} />
                </button>
              </div>
              {/* Search input */}
              <div className="flex items-center gap-3 bg-gray-100 dark:bg-[#1c1c1e] rounded-xl px-4 py-2.5">
                <Search size={16} className="text-gray-400 shrink-0" />
                <input
                  ref={sidebarSearchInputRef}
                  value={sidebarSearchQuery}
                  onChange={handleSidebarSearchInput}
                  placeholder="Search"
                  className="flex-1 bg-transparent text-sm outline-none text-gray-900 dark:text-white placeholder-gray-400"
                />
                {sidebarSearchLoading ? (
                  <svg className="animate-spin w-4 h-4 text-gray-400 shrink-0" viewBox="0 0 24 24" fill="none">
                    <circle cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="3" className="opacity-20"/>
                    <path d="M4 12a8 8 0 018-8" stroke="currentColor" strokeWidth="3" strokeLinecap="round"/>
                  </svg>
                ) : sidebarSearchQuery ? (
                  <button
                    onClick={() => { setSidebarSearchQuery(''); setSidebarSearchResults({ users: [], posts: [], reels: [] }); setSearchActiveTab('all'); sidebarSearchInputRef.current?.focus(); }}
                    className="w-5 h-5 rounded-full bg-gray-400 dark:bg-gray-600 flex items-center justify-center shrink-0 hover:bg-gray-500 transition-colors"
                  >
                    <X size={10} color="white" strokeWidth={3} />
                  </button>
                ) : null}
              </div>

              {/* Filter Tabs — show when results exist */}
              {sidebarSearchQuery.trim() && hasResults && (
                <div className="flex gap-1.5 mt-3 overflow-x-auto scrollbar-none">
                  {searchTabs.map(tab => (
                    <button key={tab.key} onClick={() => setSearchActiveTab(tab.key)}
                      className={`px-3 py-1.5 rounded-full text-xs font-semibold whitespace-nowrap transition-all flex-shrink-0 ${
                        searchActiveTab === tab.key
                          ? 'bg-gray-900 dark:bg-white text-white dark:text-black shadow-sm'
                          : 'bg-gray-100 dark:bg-gray-800 text-gray-600 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-gray-700'
                      }`}>
                      {tab.label}
                    </button>
                  ))}
                </div>
              )}
            </div>

            {/* Results / Recent */}
            <div className="flex-1 overflow-y-auto">

              {/* ── Recent History (when no query) ── */}
              {!sidebarSearchQuery.trim() && (
                <div>
                  {historyLoading ? (
                    <div className="flex items-center justify-center py-16">
                      <svg className="animate-spin w-5 h-5 text-gray-300 dark:text-gray-700" viewBox="0 0 24 24" fill="none">
                        <circle cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="3" className="opacity-20"/>
                        <path d="M4 12a8 8 0 018-8" stroke="currentColor" strokeWidth="3" strokeLinecap="round"/>
                      </svg>
                    </div>
                  ) : searchHistory.length > 0 ? (
                    <>
                      <div className="flex items-center justify-between px-6 pt-4 pb-2">
                        <span className="text-sm font-bold text-gray-900 dark:text-white">Recent</span>
                        <button onClick={clearAllHistory} className="text-xs font-semibold text-[#fa3f5e] hover:opacity-80 transition-opacity">Clear all</button>
                      </div>
                      {searchHistory.map((item) => {
                        const hId = item._id || item.id;
                        const label = typeof item === 'string' ? item : (item.query || item.keyword || item.text || '');
                        if (!label) return null;
                        return (
                          <div key={hId || label} onClick={() => handleHistoryClick(item)}
                            className="flex items-center gap-3 px-6 py-3 hover:bg-gray-50 dark:hover:bg-white/5 transition-colors cursor-pointer">
                            <div className="w-9 h-9 rounded-full bg-gray-100 dark:bg-gray-800 flex items-center justify-center shrink-0">
                              <Clock size={15} className="text-gray-400" />
                            </div>
                            <span className="flex-1 text-sm text-gray-900 dark:text-white">{label}</span>
                            {hId && (
                              <button onClick={(e) => deleteHistoryItem(hId, e)}
                                className="p-1.5 text-gray-400 hover:text-gray-700 dark:hover:text-white rounded-full hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors">
                                <X size={13} />
                              </button>
                            )}
                          </div>
                        );
                      })}
                    </>
                  ) : (
                    <div className="px-6 pt-4">
                      <p className="text-sm font-semibold text-gray-900 dark:text-white mb-3">Recent</p>
                      <div className="flex flex-col items-center justify-center py-14 gap-2 text-gray-400 dark:text-gray-600">
                        <Search size={28} className="opacity-30" />
                        <p className="text-sm">No recent searches.</p>
                      </div>
                    </div>
                  )}
                </div>
              )}

              {/* No results */}
              {sidebarSearchQuery.trim() && !sidebarSearchLoading && !hasResults && (
                <div className="flex flex-col items-center justify-center py-16 gap-2 text-gray-400">
                  <Search size={24} className="opacity-30" />
                  <p className="text-sm">No results for "{sidebarSearchQuery}"</p>
                </div>
              )}

              {/* ── People ── */}
              {filteredUsers.length > 0 && (
                <div className="pt-1">
                  <p className="px-6 py-2 text-[11px] font-bold uppercase tracking-wider text-gray-400">People · {results.users.length}</p>
                  {filteredUsers.map(u => (
                    <button
                      key={u._id || u.id}
                      onClick={() => { 
                        const profilePath = u.role === 'vendor' 
                          ? `/vendor/${u._id || u.id}/public` 
                          : `/profile/${u._id || u.id}`;
                        navigate(profilePath); 
                        closeSidebarSearch(); 
                      }}
                      className="w-full flex items-center gap-3 px-6 py-3 hover:bg-gray-50 dark:hover:bg-white/5 transition-colors text-left"
                    >
                      <div className="w-11 h-11 rounded-full overflow-hidden bg-gradient-to-tr from-yellow-400 via-orange-500 to-pink-500 p-[2px] shrink-0">
                        <div className="w-full h-full rounded-full bg-white dark:bg-black overflow-hidden flex items-center justify-center">
                          {u.avatar_url || u.profile_picture
                            ? <img src={u.avatar_url || u.profile_picture} alt="" className="w-full h-full object-cover" />
                            : <span className="text-sm font-bold text-gray-700 dark:text-white">{(u.username || u.full_name || '?')[0].toUpperCase()}</span>
                          }
                        </div>
                      </div>
                      <div className="min-w-0 flex-1">
                        <p className="text-sm font-semibold text-gray-900 dark:text-white truncate">{u.full_name || u.name || u.username}</p>
                        {u.username && <p className="text-xs text-gray-500 dark:text-gray-400 truncate">@{u.username}</p>}
                        {u.followers_count !== undefined && (
                          <p className="text-[10px] text-gray-400 dark:text-gray-500">{u.followers_count} followers</p>
                        )}
                      </div>
                      {u.role && (
                        <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full shrink-0 ${u.role === 'vendor' ? 'bg-orange-100 dark:bg-orange-900/30 text-orange-600 dark:text-orange-400' : 'bg-gray-100 dark:bg-gray-800 text-gray-500 dark:text-gray-400'}`}>
                          {u.role === 'vendor' ? 'Vendor' : 'Member'}
                        </span>
                      )}
                    </button>
                  ))}
                </div>
              )}

              {/* ── Posts — 2-col grid ── */}
              {filteredPosts.length > 0 && (
                <div className="pt-1">
                  <p className="px-6 py-2 text-[11px] font-bold uppercase tracking-wider text-gray-400">Posts · {results.posts.length}</p>
                  <div className="grid grid-cols-2 gap-1.5 px-3">
                    {filteredPosts.map(post => (
                      <SidebarPostCard key={post._id} post={post} onClick={setSidebarSelectedPost} />
                    ))}
                  </div>
                </div>
              )}

              {/* ── Reels — 2-col grid with hover-to-play ── */}
              {filteredReels.length > 0 && (
                <div className="pt-1">
                  <p className="px-6 py-2 text-[11px] font-bold uppercase tracking-wider text-gray-400">Reels · {results.reels.length}</p>
                  <div className="grid grid-cols-2 gap-1.5 px-3">
                    {filteredReels.map(reel => (
                      <SidebarReelCard key={reel._id} reel={reel} onClick={(r) => navigate(`/reels?id=${r._id}`)} />
                    ))}
                  </div>
                </div>
              )}

              {/* ── Load More ── */}
              {hasMoreSidebar && (
                <div className="px-4 py-4">
                  <button
                    onClick={handleSidebarLoadMore}
                    disabled={sidebarLoadingMore}
                    className="w-full py-2.5 rounded-2xl border border-gray-200 dark:border-gray-800 text-sm font-semibold text-gray-600 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-900 transition-colors flex items-center justify-center gap-2 disabled:opacity-60"
                  >
                    {sidebarLoadingMore
                      ? <><Loader2 size={13} className="animate-spin" /> Loading more…</>
                      : 'Load more results'}
                  </button>
                </div>
              )}
            </div>
          </div>
          <style>{`@keyframes slideInSearch { from { transform: translateX(-100%); opacity: 0; } to { transform: translateX(0); opacity: 1; } }`}</style>
        </>
      )}

      {/* PostDetailModal for sidebar search results */}
      <PostDetailModal isOpen={!!sidebarSelectedPost} post={sidebarSelectedPost} onClose={() => setSidebarSelectedPost(null)} />

      {showVendorNotValidated && (
        <div className="fixed inset-0 z-[70] flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
          <div className="bg-white dark:bg-gray-900 rounded-xl p-6 w-full max-w-sm shadow-2xl border border-gray-100 dark:border-gray-800">
            <h3 className="text-lg font-bold text-gray-900 dark:text-white mb-2 text-center">Vendor verification pending</h3>
            <p className="text-gray-500 dark:text-gray-400 text-sm mb-6 text-center">Your vendor account is not yet validated. Please wait for approval before uploading ads.</p>
            <div className="flex justify-center">
              <button onClick={() => setShowVendorNotValidated(false)} className="px-4 py-2.5 rounded-lg bg-insta-pink text-white font-medium hover:bg-insta-purple transition-colors">OK</button>
            </div>
          </div>
        </div>
      )}
    </>
  );
};

export default Sidebar;
