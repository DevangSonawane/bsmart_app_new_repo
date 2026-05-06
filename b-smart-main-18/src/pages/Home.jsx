import React, { useEffect, useState, useCallback } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { useSelector } from 'react-redux';
import { ChevronDown, MapPin, UserPlus, Play, X, MoreHorizontal } from 'lucide-react';
import StoryRail from '../components/StoryRail';
import PostCard from '../components/PostCard';
import PostDetailModal from '../components/PostDetailModal';
import TweetDetailModal from '../components/TweetDetailModal';
import api from '../lib/api';
import {
  checkFollowStatus,
  bulkCheckFollowStatus,
  followUser,
  unfollowUser,
  cancelFollowRequest,
  FOLLOW_STATUS_CHANGED_EVENT,
} from '../services/followService';

const BASE_URL = 'https://api.bebsmart.in';

const normalizeApiArray = (value) => {
  if (Array.isArray(value)) return value;
  if (!value || typeof value !== 'object') return [];
  const candidates = [
    value.data, value?.data?.data, value.posts, value.feed, value.items,
    value.results, value.ads, value.users, value.reels,
    value?.data?.posts, value?.data?.feed, value?.data?.items, value?.data?.results,
    value?.data?.ads, value?.data?.users, value?.data?.reels,
    value?.data?.data?.posts, value?.data?.data?.feed, value?.data?.data?.items,
    value?.data?.data?.results, value?.data?.data?.ads,
  ];
  for (const c of candidates) { if (Array.isArray(c)) return c; }
  return [];
};

const adAuthHeaders = () => {
  const token = localStorage.getItem('token');
  return { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) };
};

const normalizeAssetUrl = (value) => {
  if (!value) return null;
  if (/^http:\/\/api\.bebsmart\.in/i.test(String(value))) return String(value).replace(/^http:\/\//i, 'https://');
  if (String(value).startsWith('http')) return value;
  const normalized = String(value).replace(/^\/+/, '');
  if (normalized.startsWith('uploads/')) return `${BASE_URL}/${normalized}`;
  return `${BASE_URL}/uploads/${normalized}`;
};

const getAuthorFromItem = (item) => item?.user_id || item?.user || null;
const getAuthorId = (author) => author?._id || author?.id || author?.userId || null;

const filterPrivateItemsForViewer = async (items, viewerId) => {
  const safeItems = normalizeApiArray(items);
  if (!viewerId || safeItems.length === 0) return safeItems;

  const privateAuthorIds = Array.from(new Set(
    safeItems
      .map((item) => getAuthorFromItem(item))
      .filter((author) => Boolean(author?.isPrivate))
      .map((author) => String(getAuthorId(author) || ''))
      .filter((authorId) => authorId && authorId !== String(viewerId))
  ));

  if (privateAuthorIds.length === 0) return safeItems;

  let followingSet = new Set();
  try {
    const statuses = await bulkCheckFollowStatus(privateAuthorIds);
    followingSet = new Set(
      normalizeApiArray(statuses)
        .filter((status) => Boolean(status?.isFollowing))
        .map((status) => String(status?.userId || ''))
    );
  } catch {
    followingSet = new Set();
  }

  return safeItems.filter((item) => {
    const author = getAuthorFromItem(item);
    const authorId = String(getAuthorId(author) || '');
    if (!author?.isPrivate) return true;
    if (!authorId) return false;
    if (authorId === String(viewerId)) return true;
    if (item?.is_author_followed_by_me || item?.can_view_by_me) return true;
    return followingSet.has(authorId);
  });
};

const DesktopFollowButton = ({ targetUserId }) => {
  const { userObject } = useSelector(s => s.auth);
  const [followState, setFollowState] = useState('not_following');
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    let isMounted = true;
    const loadStatus = async () => {
      const currentUserId = userObject?._id || userObject?.id;
      if (!currentUserId || !targetUserId || String(currentUserId) === String(targetUserId)) {
        if (isMounted) setFollowState('not_following');
        return;
      }
      try {
        const status = await checkFollowStatus(targetUserId);
        if (!isMounted) return;
        if (status?.isFollowing || status?.status === 'following') {
          setFollowState('following');
        } else if (status?.isPending || status?.requestPending || status?.requested || status?.status === 'pending') {
          setFollowState('requested');
        } else {
          setFollowState('not_following');
        }
      } catch {
        if (isMounted) setFollowState('not_following');
      }
    };
    loadStatus();
    return () => { isMounted = false; };
  }, [targetUserId, userObject]);

  useEffect(() => {
    const onFollowStatusChanged = (event) => {
      const detail = event?.detail || {};
      if (String(detail.userId || '') !== String(targetUserId || '')) return;
      if (detail.state === 'following' || detail.state === 'requested' || detail.state === 'not_following') {
        setFollowState(detail.state);
      }
    };
    window.addEventListener(FOLLOW_STATUS_CHANGED_EVENT, onFollowStatusChanged);
    return () => window.removeEventListener(FOLLOW_STATUS_CHANGED_EVENT, onFollowStatusChanged);
  }, [targetUserId]);

  const handleClick = async () => {
    if (!userObject || !targetUserId || loading) return;
    const prev = followState;
    setLoading(true);
    try {
      if (followState === 'following') {
        await unfollowUser(targetUserId);
        setFollowState('not_following');
      } else if (followState === 'requested') {
        await cancelFollowRequest(targetUserId);
        setFollowState('not_following');
      } else {
        const result = await followUser(targetUserId);
        if (result?.status === 'pending' || result?.pending || result?.requested || result?.requestPending || result?.isPending) {
          setFollowState('requested');
        } else {
          setFollowState('following');
        }
      }
    } catch {
      setFollowState(prev);
    } finally {
      setLoading(false);
    }
  };

  return (
    <button
      type="button"
      onClick={handleClick}
      disabled={loading}
      className="min-w-[56px] text-right text-xs font-semibold text-[#3b82f6] hover:text-[#1d4ed8] dark:text-[#60a5fa] dark:hover:text-white transition-colors disabled:opacity-50"
    >
      {loading ? '...' : followState === 'following' ? 'Following' : followState === 'requested' ? 'Requested' : 'Follow'}
    </button>
  );
};

// ── Location Bar ──────────────────────────────────────────────────────────────
const LocationBar = () => (
  <div className="hidden md:block sticky top-0 z-30 bg-white dark:bg-black mb-4">
    <div className="max-w-[1280px] mx-auto xl:px-6">
      <div className="flex items-center justify-between px-4 py-3 gap-4">
        <h1 className="text-2xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange" style={{ fontFamily: 'cursive' }}>
          B-Smart
        </h1>
        <div className="flex items-center justify-between gap-2 bg-gray-100 dark:bg-gray-900 px-3 py-2 rounded-lg cursor-pointer group hover:bg-gray-200 dark:hover:bg-gray-800 transition-colors w-auto min-w-[300px]">
          <div className="flex items-center gap-2 flex-1 min-w-0">
            <div className="p-1.5 bg-white dark:bg-black rounded-full shadow-sm shrink-0">
              <MapPin size={14} className="text-red-500" />
            </div>
            <span className="text-sm font-bold text-gray-900 dark:text-white truncate">Plat No.20, 2nd Floor, Shivaram Nivas, Sri...</span>
          </div>
          <ChevronDown size={16} className="text-gray-400 shrink-0 ml-2" />
        </div>
      </div>
    </div>
  </div>
);

// ── Skeleton Loader ───────────────────────────────────────────────────────────
const FeedSkeleton = () => (
  <div className="max-w-[470px] mx-auto">
    {[1, 2, 3].map(i => (
      <div key={i} className="bg-white dark:bg-black mb-4 border-b border-gray-200 dark:border-gray-800 pb-4 md:rounded-lg md:border animate-pulse">
        <div className="flex items-center gap-2.5 p-3">
          <div className="w-9 h-9 rounded-full bg-gray-200 dark:bg-gray-800" />
          <div className="flex flex-col gap-1.5 flex-1">
            <div className="w-32 h-3 rounded-full bg-gray-200 dark:bg-gray-800" />
            <div className="w-20 h-2.5 rounded-full bg-gray-100 dark:bg-gray-800" />
          </div>
        </div>
        <div className="w-full bg-gray-200 dark:bg-gray-800" style={{ height: 300 }} />
        <div className="px-3 pt-3 flex flex-col gap-2">
          <div className="w-16 h-3 rounded-full bg-gray-200 dark:bg-gray-800" />
          <div className="w-48 h-3 rounded-full bg-gray-100 dark:bg-gray-800" />
          <div className="w-32 h-2.5 rounded-full bg-gray-100 dark:bg-gray-800" />
        </div>
      </div>
    ))}
  </div>
);

// ── Mobile Suggested Users Card (horizontal scroll, Instagram-style) ──────────
const MobileSuggestedUsersCard = ({ users, onDismiss }) => {
  const navigate = useNavigate();
  const [dismissed, setDismissed] = useState({});
  if (!users || users.length === 0) return null;
  const visible = users.filter((_, i) => !dismissed[i]);
  if (visible.length === 0) return null;

  return (
    <div className="bg-white dark:bg-black border-b border-t border-gray-200 dark:border-gray-800 py-3 mb-0 lg:hidden">
      <div className="flex items-center justify-between px-4 mb-3">
        <span className="text-sm font-bold text-gray-900 dark:text-white">Suggested for you</span>
        <button 
          onClick={() => navigate('/suggestions')}
          className="text-xs font-bold text-blue-500 hover:text-blue-600 transition-colors"
        >
          See all
        </button>
      </div>
      <div className="flex gap-3 overflow-x-auto px-4 scrollbar-hide pb-1">
        {users.map((user, i) => {
          if (dismissed[i]) return null;
          const u = user.user || user;
          const username = u.username || u.name || 'User';
          const userId = u._id || u.id;
          const avatar = u.avatar_url || u.avatar || u.profile_picture || null;
          const reason = u.mutual_friends_count
            ? `${u.mutual_friends_count} mutual`
            : u.followed_by ? `Followed by ${u.followed_by}` : 'Suggested for you';
          return (
            <div key={userId || i}
              onClick={() => navigate(`/profile/${userId}`)}
              className="relative flex-shrink-0 flex flex-col items-center bg-white dark:bg-[#1a1a1a] border border-gray-200 dark:border-gray-800 rounded-xl p-4 w-[160px] gap-2 shadow-sm cursor-pointer hover:bg-gray-50 dark:hover:bg-[#222] transition-colors">
              {/* Dismiss button */}
              <button
                className="absolute top-2 right-2 w-5 h-5 rounded-full bg-gray-100 dark:bg-gray-700 flex items-center justify-center text-gray-500 hover:text-gray-700 dark:hover:text-gray-300 z-10"
                onClick={(e) => {
                  e.stopPropagation();
                  setDismissed(p => ({ ...p, [i]: true }));
                }}
              >
                <X size={11} />
              </button>
              {/* Avatar */}
              <div
                className="w-14 h-14 rounded-full overflow-hidden bg-gradient-to-br from-pink-400 to-purple-500 flex items-center justify-center ring-2 ring-offset-1 ring-pink-300/40"
              >
                {avatar
                  ? <img src={avatar} alt={username} className="w-full h-full object-cover" />
                  : <span className="text-white font-bold text-lg">{username.slice(0,1).toUpperCase()}</span>
                }
              </div>
              <p className="text-xs font-bold text-gray-900 dark:text-white text-center truncate w-full">{username}</p>
              <p className="text-[10px] text-gray-400 text-center truncate w-full">{reason}</p>
              <div onClick={(e) => e.stopPropagation()}>
                <DesktopFollowButton targetUserId={String(userId || '')} />
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
};

const MobileSuggestedReelsCard = ({ reels }) => {
  const navigate = useNavigate();
  if (!reels || reels.length === 0) return null;

  return (
    <div className="bg-white dark:bg-[#0d0d0f] border-b border-t border-gray-200 dark:border-gray-800 py-3 mb-0 lg:hidden">
      <div className="flex items-center justify-between px-4 mb-3">
        <span className="text-sm font-bold text-gray-900 dark:text-white">Suggested reels</span>
        <button type="button" className="p-1 rounded-full text-gray-400 dark:text-white/80">
          <MoreHorizontal size={18} />
        </button>
      </div>

      <div className="flex gap-3 overflow-x-auto px-4 pb-1 [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden">
        {reels.map((reel, i) => {
          const media = reel.media?.[0];
          const thumb = normalizeAssetUrl(media?.thumbnails?.[0]?.fileUrl || media?.thumbnails?.[0]?.fileName || media?.thumbnail_url || media?.fileUrl || media?.fileName);
          const username = reel.user_id?.username || reel.user_id?.full_name || 'reel';
          const avatar = normalizeAssetUrl(reel.user_id?.avatar_url);
          const caption = reel.caption || username;

          return (
            <button
              key={reel._id || reel.id || i}
              onClick={() => navigate(`/reels?id=${reel._id || reel.id}`)}
              className="group relative flex-shrink-0 w-[160px] overflow-hidden rounded-3xl border border-white/10 bg-black text-left shadow-[0_12px_30px_rgba(0,0,0,0.35)]"
              style={{ aspectRatio: '9/16' }}
            >
              {thumb ? (
                <img src={thumb} alt={caption} className="w-full h-full object-cover" />
              ) : (
                <div className="w-full h-full bg-gradient-to-br from-gray-800 to-gray-950" />
              )}

              <div className="absolute inset-x-0 top-0 flex justify-end p-2.5">
                <div className="w-7 h-7 rounded-full bg-black/45 backdrop-blur-sm flex items-center justify-center text-white">
                  <MoreHorizontal size={14} />
                </div>
              </div>

              <div className="absolute inset-x-0 bottom-0 p-3 bg-gradient-to-t from-black via-black/45 to-transparent">
                <div className="flex items-center gap-2 mb-2">
                  {avatar ? (
                    <img src={avatar} alt={username} className="w-7 h-7 rounded-full object-cover border border-white/20" />
                  ) : (
                    <div className="w-7 h-7 rounded-full bg-white/15 border border-white/15" />
                  )}
                  <span className="text-[11px] font-semibold text-white truncate">{username}</span>
                </div>
                <p className="text-[11px] leading-4 text-white/95 line-clamp-2">{caption}</p>
              </div>
            </button>
          );
        })}
      </div>
    </div>
  );
};

const DesktopSuggestionsRail = ({ currentUser, suggestedUsers }) => {
  const navigate = useNavigate();
  const currentUserId = currentUser?._id || currentUser?.id;
  const visibleUsers = (suggestedUsers || []).filter((user) => {
    const candidate = user.user || user;
    const candidateId = candidate?._id || candidate?.id;
    return candidateId && String(candidateId) !== String(currentUserId);
  }).slice(0, 5);

  if (!currentUser || visibleUsers.length === 0) return null;

  const currentAvatar = normalizeAssetUrl(currentUser.avatar_url || currentUser.avatar);
  const currentName = currentUser.full_name || currentUser.username || 'User';

  return (
    <aside className="hidden xl:block w-[350px] shrink-0 z-0">
      <div className="sticky top-20">
        <div className="mb-6">
          <button
            type="button"
            onClick={() => navigate(`/profile/${currentUserId}`)}
            className="flex items-center gap-3 min-w-0 text-left"
          >
            {currentAvatar ? (
              <img src={currentAvatar} alt={currentName} className="w-11 h-11 rounded-full object-cover" />
            ) : (
              <div className="w-11 h-11 rounded-full bg-gradient-to-br from-orange-400 to-pink-600 flex items-center justify-center text-white font-bold">
                {currentName[0]?.toUpperCase() || 'U'}
              </div>
            )}
            <div className="min-w-0 leading-tight">
              <p className="text-sm font-semibold text-gray-900 dark:text-white truncate">{currentUser.username || currentName}</p>
              <p className="mt-0.5 text-sm text-gray-500 dark:text-gray-400 truncate">{currentName}</p>
            </div>
          </button>
        </div>

        <div className="flex items-center justify-between mb-4">
          <p className="text-sm font-semibold text-gray-500 dark:text-gray-400">Suggested for you</p>
          <button 
            type="button" 
            onClick={() => navigate('/suggestions')}
            className="text-xs font-semibold text-gray-900 dark:text-white hover:opacity-80 transition-opacity"
          >
            See all
          </button>
        </div>

        <div className="space-y-4">
          {visibleUsers.map((entry, idx) => {
            const user = entry.user || entry;
            const userId = user._id || user.id;
            const username = user.username || user.full_name || `user-${idx}`;
            const fullName = user.full_name || user.name || username;
            const avatar = normalizeAssetUrl(user.avatar_url || user.avatar || user.profile_picture);
            const reason = user.mutual_friends_count
              ? `${user.mutual_friends_count} mutual connections`
              : user.followed_by
                ? `Followed by ${user.followed_by}`
                : 'Suggested for you';

            return (
              <div key={userId || idx} className="flex items-center gap-3">
                <button
                  type="button"
                  onClick={() => navigate(`/profile/${userId}`)}
                  className="flex items-center gap-3 flex-1 min-w-0 text-left"
                >
                  {avatar ? (
                    <img src={avatar} alt={username} className="w-11 h-11 rounded-full object-cover" />
                  ) : (
                    <div className="w-11 h-11 rounded-full bg-gradient-to-br from-pink-400 to-purple-500 flex items-center justify-center text-white font-bold">
                      {username[0]?.toUpperCase() || 'U'}
                    </div>
                  )}
                  <div className="min-w-0 leading-tight">
                    <p className="text-sm font-semibold text-gray-900 dark:text-white truncate">{username}</p>
                    <p className="mt-0.5 text-xs text-gray-500 dark:text-gray-400 truncate">{reason}</p>
                  </div>
                </button>
                <DesktopFollowButton targetUserId={String(userId)} />
              </div>
            );
          })}
        </div>

        <div className="mt-9 pr-6 text-[11px] leading-[1.45] text-gray-500 dark:text-gray-500">
          <p>About · Help · Press · API · Jobs · Privacy · Terms</p>
          <p>Locations · Language · Meta Verified</p>
          <p className="mt-4 uppercase">© 2026 B-Smart from Meta</p>
        </div>
      </div>
    </aside>
  );
};

// ── Build feed with ads + mobile suggestions ──────────────────────────────────
const AD_INTERVAL = 4;

const buildFeed = (posts, ads, suggestedUsers, suggestedReels) => {
  const safePosts = normalizeApiArray(posts);
  const safeAds   = normalizeApiArray(ads);

  // Pick a random position between index 2 and 5 for suggestion block
  const suggPos = safePosts.length > 2 ? 2 + Math.floor(Math.random() * Math.min(3, safePosts.length - 2)) : -1;

  const feed = [];
  let adIdx = 0;
  let suggInserted = false;
  let reelsInserted = false;

  safePosts.forEach((post, i) => {
    feed.push(post);
    // Insert ad
    if (safeAds.length > 0 && (i + 1) % AD_INTERVAL === 0 && adIdx < safeAds.length) {
      feed.push({ ...safeAds[adIdx % safeAds.length], item_type: 'ad' });
      adIdx++;
      if (!reelsInserted && suggestedReels.length > 0) {
        feed.push({ item_type: 'mobile_reels_suggestion', reels: suggestedReels });
        reelsInserted = true;
      }
    }
    // Insert suggestion block (mobile only — hidden on lg via CSS)
    if (!suggInserted && i === suggPos && suggestedUsers.length > 0) {
      feed.push({ item_type: 'mobile_suggestion', users: suggestedUsers });
      suggInserted = true;
    }
  });

  if (!reelsInserted && suggestedReels.length > 0) {
    feed.splice(Math.min(feed.length, 2), 0, { item_type: 'mobile_reels_suggestion', reels: suggestedReels });
  }
  return feed;
};

// ── Home ──────────────────────────────────────────────────────────────────────
const Home = () => {
  const navigate = useNavigate();
  const { userObject } = useSelector(s => s.auth);
  const [activeTab, setActiveTab] = useState('all');

  const [posts,          setPosts]          = useState([]);
  const [suggestedUsers, setSuggestedUsers] = useState([]);
  const [suggestedReels, setSuggestedReels] = useState([]);
  const [feed,           setFeed]           = useState([]);
  const [loading,        setLoading]        = useState(true);
  const [selectedItem,   setSelectedItem]   = useState(null);
  const [selectedTweet,  setSelectedTweet]  = useState(null);

  const fetchPosts = useCallback(async () => {
    try {
      const { data } = await api.get('/posts/feed', {
        params: { tab: activeTab },
      });
      return normalizeApiArray(data);
    }
    catch (e) { console.error('Error fetching posts:', e); return []; }
  }, [activeTab]);

  const fetchSuggestedUsers = useCallback(async () => {
    try {
      const res = await fetch(`${BASE_URL}/api/suggestions/users`, { headers: adAuthHeaders() });
      if (!res.ok) return [];
      return normalizeApiArray(await res.json());
    } catch (e) { return []; }
  }, []);

  const fetchSuggestedReels = useCallback(async () => {
    try {
      const res = await fetch(`${BASE_URL}/api/suggestions/reels?limit=10`, { headers: adAuthHeaders() });
      if (!res.ok) return [];
      return normalizeApiArray(await res.json());
    } catch (e) { return []; }
  }, []);

  const loadFeed = useCallback(async () => {
    setLoading(true);
    const [fetchedPosts, fetchedUsers, fetchedReels] = await Promise.all([
      fetchPosts(),
      fetchSuggestedUsers(),
      activeTab === 'tweets' ? Promise.resolve([]) : fetchSuggestedReels(),
    ]);
    const viewerId = userObject?._id || userObject?.id;
    const [visiblePosts, visibleReels] = await Promise.all([
      filterPrivateItemsForViewer(fetchedPosts, viewerId),
      filterPrivateItemsForViewer(fetchedReels, viewerId),
    ]);
    setPosts(visiblePosts);
    setSuggestedUsers(fetchedUsers);
    setSuggestedReels(visibleReels);
    setFeed(activeTab === 'tweets' ? visiblePosts : buildFeed(visiblePosts, [], fetchedUsers, visibleReels));
    setLoading(false);
  }, [activeTab, fetchPosts, fetchSuggestedUsers, fetchSuggestedReels, userObject]);

  useEffect(() => { loadFeed(); }, [loadFeed]);
  useEffect(() => {
    setFeed(activeTab === 'tweets' ? posts : buildFeed(posts, [], suggestedUsers, suggestedReels));
  }, [activeTab, posts, suggestedUsers, suggestedReels]);

  useEffect(() => {
    if (userObject?.role === 'vendor') navigate('/vendor/dashboard');
  }, [userObject, navigate]);

  const handlePostDeleted = (postId) => {
    setPosts(prev => prev.filter(p => (p._id || p.id) !== postId));
  };

  const handleCommentClick = (item) => {
    if (item.item_type === 'tweet') {
      setSelectedTweet(item);
      setSelectedItem(null); // Ensure PostDetailModal is closed
    } else if (window.innerWidth < 768) {
      if (item.item_type === 'ad') { setSelectedItem(item); }
      else {
        const itemId = item._id || item.id;
        const suffix = item.item_type === 'tweet' ? '?type=tweet' : '';
        navigate(`/post/${itemId}${suffix}`);
      }
    } else {
      setSelectedItem(item);
    }
  };

  return (
    <div>
      <LocationBar />
      <div className="max-w-[1280px] mx-auto xl:px-6">
        <div className="xl:flex xl:items-start xl:justify-between xl:gap-16">
          <div className="w-full max-w-[630px]">
            <StoryRail />
            <div className="mx-auto mb-4 flex w-full max-w-[470px] items-center gap-2 px-2 xl:mx-0">
              {[
                { key: 'all', label: 'All' },
                { key: 'following', label: 'Following' },
                { key: 'tweets', label: 'Tweets' },
              ].map((tab) => (
                <button
                  key={tab.key}
                  type="button"
                  onClick={() => setActiveTab(tab.key)}
                  className={`rounded-full px-4 py-2 text-sm font-semibold transition ${
                    activeTab === tab.key
                      ? 'bg-gray-900 text-white dark:bg-white dark:text-black'
                      : 'bg-gray-100 text-gray-600 hover:bg-gray-200 dark:bg-[#121212] dark:text-gray-300 dark:hover:bg-[#1b1b1b]'
                  }`}
                >
                  {tab.label}
                </button>
              ))}
            </div>
            <div className="w-full max-w-[470px] mx-auto xl:mx-0 pb-4">
            {loading ? (
              <FeedSkeleton />
            ) : feed.length === 0 ? (
              <div className="flex flex-col items-center justify-center py-16 text-gray-400">
                <p className="text-lg font-semibold mb-1">Your feed is empty</p>
                <p className="text-sm">Follow people to see their posts here.</p>
              </div>
            ) : (
              feed.map((item, idx) => {
                if (item.item_type === 'mobile_suggestion') {
                  return <MobileSuggestedUsersCard key={`sugg-${idx}`} users={item.users} />;
                }
                if (item.item_type === 'mobile_reels_suggestion') {
                  return <MobileSuggestedReelsCard key={`reels-${idx}`} reels={item.reels} />;
                }
                return (
                  <PostCard
                    key={item._id || item.id || `item-${idx}`}
                    post={item}
                    onCommentClick={handleCommentClick}
                    onDelete={handlePostDeleted}
                  />
                );
              })
            )}
            </div>
          </div>

          <DesktopSuggestionsRail currentUser={userObject} suggestedUsers={suggestedUsers} />
        </div>
      </div>
      <PostDetailModal
        isOpen={!!selectedItem}
        post={selectedItem}
        onClose={() => setSelectedItem(null)}
      />
      <TweetDetailModal
        isOpen={!!selectedTweet}
        tweet={selectedTweet}
        onClose={() => setSelectedTweet(null)}
      />
    </div>
  );
};

export default Home;
