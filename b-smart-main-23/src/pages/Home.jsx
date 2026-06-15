import { useEffect, useState, useCallback, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { useSelector, useDispatch } from 'react-redux';
import { fetchUserStory } from '../store/storySlice';
import { ChevronDown, MapPin, X, MoreHorizontal, Search } from 'lucide-react';
import PostCard from '../components/PostCard';
import PostDetailModal from '../components/PostDetailModal';
import TweetDetailModal from '../components/TweetDetailModal';
import PromoteCard from '../components/PromoteCard';
import PromoteDetailModal from '../components/PromoteDetailModal';
import StoryRail from '../components/StoryRail';
import StoryViewer from '../components/StoryViewer';
import api from '../lib/api';
import bsmartLogo from '../assets/bsmart.png';
import bsmartIcon from '../assets/bsmart_logo.png';
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
    // saved posts
    value.saved, value.savedPosts, value.saved_posts, value.savedItems, value.saved_items,
    // saved reels
    value.savedReels, value.saved_reels,
    // saved ads
    value.savedAds, value.saved_ads,
    // saved promote reels (all naming conventions)
    value.savedPromoteReels, value.saved_promote_reels,
    value.promote_reels, value.promoteReels,
    value.promotedReels, value.promoted_reels,
    value.savePromoteReels, value.save_promote_reels,
    // data.* variants
    value?.data?.posts, value?.data?.feed, value?.data?.items, value?.data?.results,
    value?.data?.ads, value?.data?.users, value?.data?.reels,
    value?.data?.saved,
    value?.data?.savedPosts, value?.data?.saved_posts,
    value?.data?.savedItems, value?.data?.saved_items,
    value?.data?.savedReels, value?.data?.saved_reels,
    value?.data?.savedAds, value?.data?.saved_ads,
    value?.data?.savedPromoteReels, value?.data?.saved_promote_reels,
    value?.data?.promote_reels, value?.data?.promoteReels,
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

// ── Location Selector ────────────────────────────────────────────────────────
const LocationSelector = ({ className = "" }) => (
  <div className={`flex items-center justify-between gap-2 bg-gray-100 dark:bg-gray-900 px-3 py-2 rounded-lg cursor-pointer group hover:bg-gray-200 dark:hover:bg-gray-800 transition-colors w-full ${className}`}>
    <div className="flex items-center gap-2 flex-1 min-w-0">
      <div className="p-1.5 bg-white dark:bg-black rounded-full shadow-sm shrink-0">
        <MapPin size={14} className="text-red-500" />
      </div>
      <span className="text-sm font-bold text-gray-900 dark:text-white truncate">Plat No.20, 2nd Floor, Shivaram Nivas, Sri...</span>
    </div>
    <ChevronDown size={16} className="text-gray-400 shrink-0 ml-2" />
  </div>
);

// ── Location Bar — logo + search + location ───────────────────────────────────
const LocationBar = ({ searchQuery, onSearchChange, searchLoading, searchResults }) => {
  const navigate = useNavigate();
  const [sidebarOpen, setSidebarOpen] = useState(false);
  useEffect(() => {
    const handler = (e) => setSidebarOpen(e.detail.isOpen);
    window.addEventListener('sidebar:toggle', handler);
    return () => window.removeEventListener('sidebar:toggle', handler);
  }, []);
  return (
    <div className="hidden md:block fixed top-0 left-0 right-0 h-14 z-[55] bg-white dark:bg-black">
      <div className="h-full flex items-center px-4 gap-4">
        <div className="shrink-0 flex items-center gap-2 w-64 overflow-hidden">
          <img src={bsmartIcon} alt="bs" className="w-9 h-9 object-contain flex-shrink-0" />
          <div className={`overflow-hidden transition-all duration-300 ease-in-out ${sidebarOpen ? 'max-w-[200px] opacity-100' : 'max-w-0 opacity-0'}`}>
            <img src={bsmartLogo} alt="b_smart" className="h-[70px] w-auto object-contain block" />
          </div>
        </div>

        <div className="flex-1 flex justify-center">
          <div className="relative w-full max-w-[500px]">
            <div className="flex items-center gap-3 bg-gray-100 dark:bg-gray-900 px-4 py-2.5 rounded-xl border border-transparent focus-within:border-gray-200 dark:focus-within:border-gray-700 transition-all">
              <Search size={17} className="text-gray-400 shrink-0" />
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => onSearchChange(e.target.value)}
                placeholder="Search"
                className="bg-transparent border-none outline-none text-sm w-full dark:text-white"
              />
              {searchLoading && (
                <div className="animate-spin rounded-full h-4 w-4 border-2 border-gray-300 border-t-insta-pink shrink-0" />
              )}
            </div>

            {searchQuery.trim() && (
              <div className="absolute left-0 right-0 top-full mt-1 bg-white dark:bg-[#1c1c1c] rounded-2xl border border-gray-100 dark:border-white/10 shadow-2xl z-[100] max-h-[400px] overflow-y-auto animate-in fade-in slide-in-from-top-2 duration-200">
                {searchLoading && searchResults.users.length === 0 && searchResults.posts.length === 0 && (
                  <div className="p-8 text-center text-gray-400">Searching...</div>
                )}
                {!searchLoading && searchResults.users.length === 0 && searchResults.posts.length === 0 && searchResults.reels.length === 0 && (
                  <div className="p-8 text-center text-gray-400">No results found for "{searchQuery}"</div>
                )}
                {searchResults.users.length > 0 && (
                  <div className="p-2 border-b border-gray-50 dark:border-white/5">
                    <p className="px-3 py-2 text-[10px] font-bold text-gray-400 uppercase tracking-wider">People</p>
                    {searchResults.users.map(u => (
                      <button
                        key={u._id || u.id}
                        onClick={() => {
                          const profilePath = u.role === 'vendor' ? `/vendor/${u._id || u.id}/public` : `/profile/${u._id || u.id}`;
                          navigate(profilePath);
                          onSearchChange('');
                        }}
                        className="w-full flex items-center gap-3 px-3 py-2 hover:bg-gray-50 dark:hover:bg-white/5 rounded-xl transition-colors text-left"
                      >
                        <div className="w-9 h-9 rounded-full overflow-hidden bg-gray-100 dark:bg-gray-800 shrink-0">
                          {u.avatar_url || u.profile_picture
                            ? <img src={u.avatar_url || u.profile_picture} alt="" className="w-full h-full object-cover" />
                            : <div className="w-full h-full flex items-center justify-center text-xs font-bold text-gray-400">{(u.username || u.full_name || '?')[0].toUpperCase()}</div>
                          }
                        </div>
                        <div className="min-w-0 flex-1">
                          <p className="text-sm font-semibold text-gray-900 dark:text-white truncate">{u.full_name || u.username}</p>
                          {u.username && <p className="text-xs text-gray-500 truncate">@{u.username}</p>}
                        </div>
                      </button>
                    ))}
                  </div>
                )}
              </div>
            )}
          </div>
        </div>

        <div className="hidden xl:flex items-center">
          <div className="w-[300px]">
            <LocationSelector />
          </div>
        </div>
      </div>
    </div>
  );
};


// ── Skeleton Loader ───────────────────────────────────────────────────────────
const FeedSkeleton = () => (
  <div className="lg:max-w-[650px] max-w-[430px] ml-0">
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
const MobileSuggestedUsersCard = ({ users }) => {
  const navigate = useNavigate();
  const [dismissed, setDismissed] = useState({});
  if (!users || users.length === 0) return null;
  const visible = users.filter((_, i) => !dismissed[i]);
  if (visible.length === 0) return null;

  return (
    <div className="bg-white dark:bg-black border-b border-t border-gray-200 dark:border-gray-800 py-4 mb-0 lg:hidden">
      <div className="flex items-center justify-between px-4 mb-4">
        <span className="text-[15px] font-bold text-gray-900 dark:text-white">Suggested for you</span>
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
              className="relative flex-shrink-0 flex flex-col items-center bg-white dark:bg-[#1a1a1a] border border-gray-200 dark:border-gray-800 rounded-2xl px-3 pt-4 pb-3 w-[140px] gap-2 shadow-sm cursor-pointer hover:bg-gray-50 dark:hover:bg-[#222] transition-colors">
              {/* Dismiss button */}
              <button
                className="absolute top-2 right-2 w-5 h-5 rounded-full bg-gray-100 dark:bg-gray-700 flex items-center justify-center text-gray-400 hover:text-gray-700 dark:hover:text-gray-300 z-10"
                onClick={(e) => {
                  e.stopPropagation();
                  setDismissed(p => ({ ...p, [i]: true }));
                }}
              >
                <X size={10} />
              </button>
              {/* Avatar */}
              <div className="w-14 h-14 rounded-full overflow-hidden bg-gradient-to-br from-pink-400 to-purple-500 flex items-center justify-center ring-2 ring-offset-1 ring-pink-300/40 shrink-0">
                {avatar
                  ? <img src={avatar} alt={username} className="w-full h-full object-cover" />
                  : <span className="text-white font-bold text-lg">{username.slice(0,1).toUpperCase()}</span>
                }
              </div>
              <div className="w-full text-center min-w-0">
                <p className="text-[12px] font-bold text-gray-900 dark:text-white truncate">{username}</p>
                <p className="text-[10px] text-gray-400 truncate mt-0.5">{reason}</p>
              </div>
              <div onClick={(e) => e.stopPropagation()} className="w-full">
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
              className="group relative flex-shrink-0 w-[110px] overflow-hidden rounded-2xl border border-white/10 bg-black text-left shadow-[0_8px_20px_rgba(0,0,0,0.25)]"
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

              <div className="absolute inset-x-0 bottom-0 p-2 bg-gradient-to-t from-black via-black/45 to-transparent">
                <div className="flex items-center gap-1.5 mb-1">
                  {avatar ? (
                    <img src={avatar} alt={username} className="w-5 h-5 rounded-full object-cover border border-white/20 shrink-0" />
                  ) : (
                    <div className="w-5 h-5 rounded-full bg-white/15 border border-white/15 shrink-0" />
                  )}
                  <span className="text-[9px] font-semibold text-white truncate">{username}</span>
                </div>
                <p className="text-[9px] leading-3 text-white/90 line-clamp-2">{caption}</p>
              </div>
            </button>
          );
        })}
      </div>
    </div>
  );
};

const DesktopSuggestionsRail = ({ currentUser, suggestedUsers }) => {
  const navigate  = useNavigate();
  const dispatch  = useDispatch();
  const storyMap  = useSelector((state) => state.story?.storyMap ?? {});
  const currentUserId = currentUser?._id || currentUser?.id;
  const [viewerStory, setViewerStory] = useState(null);

  const visibleUsers = (suggestedUsers || []).filter((user) => {
    const candidate = user.user || user;
    const candidateId = candidate?._id || candidate?.id;
    return candidateId && String(candidateId) !== String(currentUserId);
  }).slice(0, 5);

  // Fetch stories for current user + all visible suggested users via Redux thunk
  useEffect(() => {
    // Current user's own story
    if (currentUserId) {
      dispatch(fetchUserStory(currentUserId, {
        avatarUrl: normalizeAssetUrl(currentUser?.avatar_url || currentUser?.avatar) || '',
        username: currentUser?.username || '',
      }));
    }
    // Suggested users
    visibleUsers.forEach((entry) => {
      const user = entry.user || entry;
      const userId = user._id || user.id;
      if (!userId) return;
      dispatch(fetchUserStory(userId, {
        avatarUrl: normalizeAssetUrl(user.avatar_url || user.avatar || user.profile_picture) || '',
        username: user.username || user.full_name || '',
      }));
    });
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [suggestedUsers, currentUserId]);

  if (!currentUser || visibleUsers.length === 0) return null;

  const currentAvatar = normalizeAssetUrl(currentUser.avatar_url || currentUser.avatar);
  const currentName = currentUser.full_name || currentUser.username || 'User';

  return (
    <>
      <aside className="hidden xl:flex xl:flex-col w-[350px] shrink-0 z-0">
        <div className="h-full overflow-y-auto pt-6 pb-20 scrollbar-hide">
          <div className="mb-6">
            <div className="flex items-center gap-3 min-w-0">
              {/* Avatar — orange ring if current user has a story */}
              {(() => {
                const ownStory = storyMap[currentUserId];
                const hasStory = !!ownStory;
                return (
                  <button
                    type="button"
                    onClick={() => hasStory ? setViewerStory(ownStory) : navigate(`/profile/${currentUserId}`)}
                    className="shrink-0"
                  >
                    <div className={`rounded-full p-[2px] ${hasStory ? 'bg-gradient-to-tr from-yellow-400 via-orange-500 to-pink-600' : 'bg-transparent'}`}>
                      <div className={`rounded-full p-[1.5px] ${hasStory ? 'bg-white dark:bg-black' : ''}`}>
                        {currentAvatar ? (
                          <img src={currentAvatar} alt={currentName} className="w-10 h-10 rounded-full object-cover block" />
                        ) : (
                          <div className="w-10 h-10 rounded-full bg-gradient-to-br from-orange-400 to-pink-600 flex items-center justify-center text-white font-bold">
                            {currentName[0]?.toUpperCase() || 'U'}
                          </div>
                        )}
                      </div>
                    </div>
                  </button>
                );
              })()}
              <button
                type="button"
                onClick={() => navigate(`/profile/${currentUserId}`)}
                className="min-w-0 text-left"
              >
                <div className="min-w-0 leading-tight">
                  <p className="text-sm font-semibold text-gray-900 dark:text-white truncate">{currentUser.username || currentName}</p>
                  <p className="mt-0.5 text-sm text-gray-500 dark:text-gray-400 truncate">{currentName}</p>
                </div>
              </button>
            </div>
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
              const avatar = normalizeAssetUrl(user.avatar_url || user.avatar || user.profile_picture);
              const reason = user.mutual_friends_count
                ? `${user.mutual_friends_count} mutual connections`
                : user.followed_by
                  ? `Followed by ${user.followed_by}`
                  : 'Suggested for you';
              const story = storyMap[userId];
              const hasStory = !!story;

              return (
                <div key={userId || idx} className="flex items-center gap-3">
                  <button
                    type="button"
                    onClick={() => hasStory ? setViewerStory(story) : navigate(`/profile/${userId}`)}
                    className="flex items-center gap-3 flex-1 min-w-0 text-left"
                  >
                    {/* Avatar — orange gradient ring when user has a story */}
                    <div className={`shrink-0 rounded-full p-[2px] ${hasStory ? 'bg-gradient-to-tr from-yellow-400 via-orange-500 to-pink-500' : 'bg-transparent'}`}>
                      <div className="rounded-full p-[1.5px] bg-white dark:bg-black">
                        {avatar ? (
                          <img src={avatar} alt={username} className="w-9 h-9 rounded-full object-cover block" />
                        ) : (
                          <div className="w-9 h-9 rounded-full bg-gradient-to-br from-pink-400 to-purple-500 flex items-center justify-center text-white font-bold text-sm">
                            {username[0]?.toUpperCase() || 'U'}
                          </div>
                        )}
                      </div>
                    </div>
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
        </div>
      </aside>

      {viewerStory && (
        <StoryViewer
          initialStoryIndex={0}
          stories={[viewerStory]}
          onClose={() => setViewerStory(null)}
        />
      )}
    </>
  );
};

// ── Footer ──────────────────────────────────────────────────────────────────
const Footer = () => (
  <footer className="hidden md:block w-full border-t border-gray-100 dark:border-gray-800 py-12 mt-12 bg-white dark:bg-black">
    <div className="max-w-[1200px] mx-auto px-6 text-center text-[12px] text-gray-500 dark:text-gray-400">
      <div className="flex flex-wrap justify-center gap-x-4 gap-y-2 mb-4 font-medium">
        <span className="hover:underline cursor-pointer">About</span>
        <span className="hover:underline cursor-pointer">Help</span>
        <span className="hover:underline cursor-pointer">Press</span>
        <span className="hover:underline cursor-pointer">API</span>
        <span className="hover:underline cursor-pointer">Jobs</span>
        <span className="hover:underline cursor-pointer">Privacy</span>
        <span className="hover:underline cursor-pointer">Terms</span>
        <span className="hover:underline cursor-pointer">Locations</span>
        <span className="hover:underline cursor-pointer">Language</span>
        <span className="hover:underline cursor-pointer">Meta Verified</span>
      </div>
      <p className="uppercase tracking-widest font-semibold opacity-80">© 2026 B-Smart from Meta</p>
    </div>
  </footer>
);

// Feed order is determined by the API. Frontend only injects the mobile
// suggested-users card once at position 2 (a UI-only widget, not content).
const injectSuggestionCard = (posts, suggestedUsers) => {
  const feed = [...posts];
  if (suggestedUsers.length > 0 && feed.length > 2) {
    feed.splice(2, 0, { item_type: 'mobile_suggestion', users: suggestedUsers });
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
  const [feed,           setFeed]           = useState([]);
  const [loading,        setLoading]        = useState(true);
  const [selectedItem,   setSelectedItem]   = useState(null);
  const [selectedTweet,  setSelectedTweet]  = useState(null);
  const [selectedPromoteReel, setSelectedPromoteReel] = useState(null);

  // Search state
  const [searchQuery, setSearchQuery] = useState('');
  const [searchResults, setSearchResults] = useState({ users: [], posts: [], reels: [] });
  const [searchLoading, setSearchLoading] = useState(false);
  const searchDebounce = useRef(null);

  const runSearch = async (q) => {
    const query = q.trim();
    if (!query) { setSearchResults({ users: [], posts: [], reels: [] }); return; }
    setSearchLoading(true);
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${BASE_URL}/api/search?q=${encodeURIComponent(query)}&limit=10`, {
        headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) }
      });
      if (res.ok) {
        const data = await res.json();
        setSearchResults(data.results || { users: [], posts: [], reels: [] });
      }
    } catch (e) { console.error('Search error:', e); }
    finally { setSearchLoading(false); }
  };

  const handleSearchChange = (q) => {
    setSearchQuery(q);
    clearTimeout(searchDebounce.current);
    if (!q.trim()) { setSearchResults({ users: [], posts: [], reels: [] }); return; }
    searchDebounce.current = setTimeout(() => runSearch(q), 350);
  };

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
    } catch { return []; }
  }, []);

  // Returns a Set of saved IDs, or null when format is unknown (caller falls back to item.is_saved_by_me).
  // Returning null is intentional: an empty Set is truthy and suppresses the fallback.
  const fetchSavedPostIds = useCallback(async () => {
    try {
      const { data } = await api.get('/saved/posts');
      if (!data) return null;
      const arr = Array.isArray(data) ? data
        : Array.isArray(data.data) ? data.data
        : Array.isArray(data.savedPosts) ? data.savedPosts
        : Array.isArray(data.saved_posts) ? data.saved_posts
        : Array.isArray(data.posts) ? data.posts
        : Array.isArray(data.saved) ? data.saved
        : null;
      if (arr === null) return null;
      return new Set(arr.map(i => String(i.post?._id || i.post_id || i._id || i.id || '')).filter(Boolean));
    } catch { return null; }
  }, []);

  const fetchSavedPromoteReelIds = useCallback(async () => {
    try {
      const { data } = await api.get('/saved/promote-reels');
      if (!data) return null;
      const arr = Array.isArray(data) ? data
        : Array.isArray(data.data) ? data.data
        : Array.isArray(data.savedPromoteReels) ? data.savedPromoteReels
        : Array.isArray(data.saved_promote_reels) ? data.saved_promote_reels
        : Array.isArray(data.promote_reels) ? data.promote_reels
        : Array.isArray(data.promoteReels) ? data.promoteReels
        : Array.isArray(data.saved) ? data.saved
        : null;
      if (arr === null) return null;
      return new Set(arr.map(i => String(i.promote_reel?._id || i.promote_reel_id || i._id || i.id || '')).filter(Boolean));
    } catch { return null; }
  }, []);

  const fetchSavedAdIds = useCallback(async () => {
    try {
      const { data } = await api.get('/saved/ads');
      if (!data) return null;
      const arr = Array.isArray(data) ? data
        : Array.isArray(data.data) ? data.data
        : Array.isArray(data.savedAds) ? data.savedAds
        : Array.isArray(data.saved_ads) ? data.saved_ads
        : Array.isArray(data.ads) ? data.ads
        : Array.isArray(data.saved) ? data.saved
        : null;
      if (arr === null) return null;
      return new Set(arr.map(i => String(i.ad?._id || i.ad_id || i._id || i.id || '')).filter(Boolean));
    } catch { return null; }
  }, []);

  const loadFeed = useCallback(async () => {
    setLoading(true);
    const [fetchedPosts, fetchedUsers, savedPostIds, savedPromoteIds, savedAdIds] = await Promise.all([
      fetchPosts(),
      fetchSuggestedUsers(),
      fetchSavedPostIds(),
      fetchSavedPromoteReelIds(),
      fetchSavedAdIds(),
    ]);
    const viewerId = userObject?._id || userObject?.id;
    const visiblePosts = await filterPrivateItemsForViewer(fetchedPosts, viewerId);

    // Bulk follow check — one request for all unique authors in the feed
    let followingSet = new Set();
    if (viewerId && visiblePosts.length > 0) {
      const authorIds = [...new Set(
        visiblePosts.map(item => {
          const a = item.user_id || item.user || item.author;
          const id = typeof a === 'string' ? a : (a?._id || a?.id || '');
          return id && id !== String(viewerId) ? String(id) : '';
        }).filter(Boolean)
      )];
      if (authorIds.length > 0) {
        try {
          const statuses = await bulkCheckFollowStatus(authorIds);
          followingSet = new Set(
            normalizeApiArray(statuses)
              .filter(s => Boolean(s?.isFollowing))
              .map(s => String(s?.userId || ''))
          );
        } catch { /* keep empty set */ }
      }
    }

    const enriched = visiblePosts.map(item => {
      const itemId = String(item._id || item.id || '');
      const a = item.user_id || item.user || item.author;
      const authorId = String(typeof a === 'string' ? a : (a?._id || a?.id || ''));
      const isAuthorFollowed = authorId && authorId !== 'undefined'
        ? followingSet.has(authorId)
        : !!(item.is_author_followed_by_me);

      let isSaved;
      if (item.item_type === 'promote_reel') {
        isSaved = savedPromoteIds ? savedPromoteIds.has(itemId) : !!(item.is_saved_by_me);
      } else if (item.item_type === 'ad') {
        isSaved = savedAdIds ? savedAdIds.has(itemId) : !!(item.is_saved_by_me);
      } else {
        isSaved = savedPostIds ? savedPostIds.has(itemId) : !!(item.is_saved_by_me);
      }

      return { ...item, is_saved_by_me: isSaved, is_author_followed_by_me: isAuthorFollowed };
    });
    setPosts(enriched);
    setSuggestedUsers(fetchedUsers);
    setFeed(injectSuggestionCard(enriched, fetchedUsers));
    setLoading(false);
  }, [fetchPosts, fetchSuggestedUsers, fetchSavedPostIds, fetchSavedPromoteReelIds, fetchSavedAdIds, userObject]);

  useEffect(() => { loadFeed(); }, [loadFeed]);
  useEffect(() => {
    setFeed(injectSuggestionCard(posts, suggestedUsers));
  }, [activeTab, posts, suggestedUsers]);

  useEffect(() => {
    if (userObject?.role === 'vendor') navigate('/vendor/dashboard');
  }, [userObject, navigate]);

  const handlePostDeleted = (postId) => {
    setPosts(prev => prev.filter(p => (p._id || p.id) !== postId));
  };

  const handleCommentClick = (item) => {
    if (item?.turn_off_commenting || item?.engagement_controls?.turn_off_commenting) return;
    const itemId = item._id || item.id;
    if (window.innerWidth < 768) {
      if (item.item_type === 'tweet') navigate(`/tweet/${itemId}`);
      else if (item.item_type === 'ad') navigate(`/ad/${itemId}`);
      else navigate(`/post/${itemId}`);
    } else {
      if (item.item_type === 'tweet') {
        setSelectedTweet(item);
        setSelectedItem(null);
      } else {
        setSelectedItem(item);
      }
    }
  };

  return (
    <div className="relative md:pt-14 bg-white dark:bg-black overflow-x-hidden">

      <LocationBar
        searchQuery={searchQuery}
        onSearchChange={handleSearchChange}
        searchLoading={searchLoading}
        searchResults={searchResults}
      />

      <div className="w-full md:h-[calc(100vh-56px)] md:overflow-hidden overflow-x-hidden">
        <div className="w-full md:max-w-[1280px] md:ml-auto md:px-4 xl:pr-6 xl:flex xl:items-stretch xl:justify-between xl:gap-8 md:h-full">
          <div className="w-full max-w-[700px] md:overflow-y-auto scrollbar-hide overflow-x-hidden">
            <StoryRail />
            <div className="flex items-center gap-2 px-3 pt-1 pb-2 overflow-x-auto scrollbar-none">
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
            <div className="max-w-[430px] lg:max-w-[650px] pb-4">
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
                if (item.item_type === 'promote_reel') {
                  return (
                    <PromoteCard
                      key={item._id || item.promote_reel_id || `pr-${idx}`}
                      item={item}
                      onOpenDetail={(pr) => {
                        if (window.innerWidth < 768) {
                          navigate(`/promote-reel/${pr._id || pr.id || pr.promote_reel_id}`);
                        } else {
                          setSelectedPromoteReel(pr);
                        }
                      }}
                    />
                  );
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
            <Footer />
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
      <PromoteDetailModal
        isOpen={!!selectedPromoteReel}
        promoteReel={selectedPromoteReel}
        onClose={() => setSelectedPromoteReel(null)}
      />
    </div>
  );
};

export default Home;