import React, { useState, useEffect, useRef, useCallback } from 'react';
import {
  Heart, MessageCircle, Send, Bookmark, MoreHorizontal,
  ChevronLeft, ChevronRight,
  Volume2, VolumeX, UserPlus, UserCheck, ShoppingBag, Loader2
} from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useSelector } from 'react-redux';
import { Link } from 'react-router-dom';
import api from '../lib/api';
import ContentReportModal from './ContentReportModal';
import EditContentModal from './EditContentModal';
import OwnerContentOptionsModal from './OwnerContentOptionsModal';

const BASE_URL = 'https://api.bebsmart.in';

const fmt = (n = 0) => {
  if (n >= 1_000_000) return (n / 1_000_000).toFixed(1) + 'M';
  if (n >= 1_000) return (n / 1_000).toFixed(1) + 'k';
  return String(n);
};

// ─── Helpers ──────────────────────────────────────────────────────────────────
const isAdItem = (item) => item?.item_type === 'ad' || (item?.vendor_id && !item?.user_id?.username?.includes);

const adAuthHeaders = () => {
  const token = localStorage.getItem('token');
  return {
    'Content-Type': 'application/json',
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
  };
};

// ─── Delete Confirmation Modal ─────────────────────────────────────────────────
const DeleteModal = ({ isOpen, onClose, onConfirm, isDeleting }) => {
  if (!isOpen) return null;
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
      <div className="bg-white dark:bg-gray-900 rounded-xl p-6 w-full max-w-sm shadow-2xl border border-gray-100 dark:border-gray-800">
        {isDeleting ? (
          <div className="flex flex-col items-center justify-center py-8">
            <div className="animate-spin w-12 h-12 border-4 border-gray-200 border-t-red-500 rounded-full mb-4" />
            <p className="text-gray-500 dark:text-gray-400 font-medium animate-pulse">Deleting post...</p>
          </div>
        ) : (
          <>
            <h3 className="text-lg font-bold text-gray-900 dark:text-white mb-2 text-center">Delete Post?</h3>
            <p className="text-gray-500 dark:text-gray-400 text-sm mb-6 text-center">
              This action cannot be undone.
            </p>
            <div className="flex gap-3">
              <button onClick={onClose} className="flex-1 px-4 py-2.5 rounded-lg border border-gray-200 dark:border-gray-700 font-medium text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors">
                Cancel
              </button>
              <button onClick={onConfirm} className="flex-1 px-4 py-2.5 rounded-lg bg-red-500 text-white font-medium hover:bg-red-600 transition-colors">
                Delete
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  );
};

// ─── People Tag Overlay ────────────────────────────────────────────────────────
const PeopleTagsOverlay = ({ tags, visible }) => {
  const [showTags, setShowTags] = useState(false);
  useEffect(() => {
    if (visible && tags?.length > 0) {
      const showT = setTimeout(() => setShowTags(true), 0);
      const hideT = setTimeout(() => setShowTags(false), 2600);
      return () => { clearTimeout(showT); clearTimeout(hideT); };
    }
  }, [visible, tags]);
  if (!tags?.length) return null;
  return (
    <>
      <style>{`
        @keyframes igTagPop {
          0%   { opacity: 0; transform: translate(-50%,-50%) scale(0.5); }
          70%  { transform: translate(-50%,-50%) scale(1.08); }
          100% { opacity: 1; transform: translate(-50%,-50%) scale(1); }
        }
      `}</style>
      <button
        className="absolute bottom-3 left-3 z-10 w-8 h-8 rounded-full bg-black/50 backdrop-blur-sm flex items-center justify-center hover:bg-black/70 active:scale-90 transition-all"
        onClick={(e) => { e.stopPropagation(); setShowTags(s => !s); }}
      >
        <svg width="16" height="16" viewBox="0 0 24 24" fill="white">
          <path d="M12 12c2.7 0 4.8-2.1 4.8-4.8S14.7 2.4 12 2.4 7.2 4.5 7.2 7.2 9.3 12 12 12zm0 2.4c-3.2 0-9.6 1.6-9.6 4.8v2.4h19.2v-2.4c0-3.2-6.4-4.8-9.6-4.8z"/>
        </svg>
      </button>
      {showTags && tags.map((tag, idx) => {
        const x = Math.min(88, Math.max(12, tag.x));
        const y = Math.min(88, Math.max(12, tag.y));
        const inBottom = y > 55;
        return (
          <div key={tag._id || idx} className="absolute z-30 pointer-events-auto"
            style={{ left: `${x}%`, top: `${y}%`, transform: 'translate(-50%,-50%)', animation: `igTagPop 0.28s ${idx * 0.07}s cubic-bezier(0.34,1.56,0.64,1) both` }}>
            <div className="flex flex-col items-center">
              {!inBottom && <div className="w-0 h-0 border-l-[6px] border-l-transparent border-r-[6px] border-r-transparent border-b-[6px] border-b-white/90 -mb-[1px]" />}
              <Link to={`/profile/${tag.user_id || ''}`} onClick={e => e.stopPropagation()}
                className="block bg-white/90 backdrop-blur-sm text-black text-xs font-bold px-3 py-1.5 rounded-full whitespace-nowrap shadow-xl hover:bg-white">
                @{tag.username}
              </Link>
              {inBottom && <div className="w-0 h-0 border-l-[6px] border-l-transparent border-r-[6px] border-r-transparent border-t-[6px] border-t-white/90 -mt-[1px]" />}
            </div>
          </div>
        );
      })}
    </>
  );
};

// ─── Follow Button ─────────────────────────────────────────────────────────────
const FollowButton = ({ targetUserId }) => {
  const { userObject } = useSelector(s => s.auth);
  const [following, setFollowing] = useState(false);
  const [loading, setLoading] = useState(false);

  const handleClick = useCallback(async (e) => {
    e.stopPropagation();
    if (!userObject || loading) return;
    const was = following;
    setFollowing(!was);
    setLoading(true);
    try {
      await api.post(was ? '/unfollow' : '/follow', { followedUserId: targetUserId });
    } catch {
      setFollowing(was);
    } finally {
      setLoading(false);
    }
  }, [userObject, loading, following, targetUserId]);

  return (
    <button onClick={handleClick} disabled={loading}
      className={`flex items-center gap-1.5 text-xs font-bold px-3 py-1 rounded-full border-2 transition-all duration-200 ${loading ? 'opacity-50 cursor-not-allowed' : ''} ${
        following
          ? 'border-gray-300 dark:border-gray-600 text-gray-500 dark:text-gray-400 hover:border-red-400 hover:text-red-400'
          : 'border-white text-black dark:text-white bg-white dark:bg-transparent dark:border-white hover:bg-gray-100 dark:hover:bg-white/10'
      }`}>
      {loading ? <Loader2 size={11} className="animate-spin" /> : following ? <UserCheck size={11} /> : <UserPlus size={11} />}
      <span>{following ? 'Following' : 'Follow'}</span>
    </button>
  );
};

// ─── Coin Icon ─────────────────────────────────────────────────────────────────
const CoinIcon = ({ size = 13 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
    <circle cx="12" cy="12" r="10" fill="#F59E0B" stroke="#D97706" strokeWidth="1.5" />
    <text x="12" y="16.5" textAnchor="middle" fontSize="11" fontWeight="bold" fill="#7C2D12">B</text>
  </svg>
);

// ─── Shop CTA (ads only) ───────────────────────────────────────────────────────
const ShopCTA = ({ offer }) => {
  if (!offer) return null;
  const href = offer.link && !['daasda', '', '#'].includes(offer.link) ? offer.link : '#';
  return (
    <a href={href} target="_blank" rel="noopener noreferrer" onClick={e => e.stopPropagation()}
      className="flex items-center justify-between gap-2 w-full mt-2 px-3 py-2 rounded-lg bg-gray-100 dark:bg-gray-800 hover:bg-gray-200 dark:hover:bg-gray-700 border border-gray-200 dark:border-gray-700 transition-colors">
      <div className="flex items-center gap-2 min-w-0">
        <ShoppingBag size={14} className="text-gray-600 dark:text-gray-300 shrink-0" />
        <div className="min-w-0">
          <p className="text-xs font-semibold text-gray-900 dark:text-white truncate">{offer.title || 'Shop Now'}</p>
          {offer.description && <p className="text-[10px] text-gray-500 dark:text-gray-400 truncate">{offer.description}</p>}
        </div>
      </div>
      <div className="flex items-center gap-1 shrink-0">
        {offer.price > 0 && <span className="text-xs font-bold text-amber-600 dark:text-amber-400">₹{offer.price.toLocaleString()}</span>}
        <span className="text-[10px] font-semibold text-white bg-blue-500 rounded-full px-2 py-0.5">Shop</span>
      </div>
    </a>
  );
};

// ─── Caption with expand ───────────────────────────────────────────────────────
const ExpandCaption = ({ username, userId, text, isAd }) => {
  const [expanded, setExpanded] = useState(false);
  if (!text) return null;
  const words = text.trim().split(/\s+/);
  const isLong = words.length > (isAd ? 10 : 15);
  const preview = isLong ? words.slice(0, isAd ? 10 : 15).join(' ') : text;
  return (
    <p className="text-sm dark:text-white leading-snug mb-1">
      <Link to={`/profile/${userId}`} className="font-semibold mr-1 hover:underline dark:text-white">{username}</Link>
      {expanded || !isLong ? (
        <>
          {text}
          {expanded && isLong && (
            <button onClick={() => setExpanded(false)} className="text-gray-400 ml-1.5 text-xs font-semibold">less</button>
          )}
        </>
      ) : (
        <>
          {preview}
          <button onClick={() => setExpanded(true)} className="text-gray-400 ml-1 font-medium">... more</button>
        </>
      )}
    </p>
  );
};

// ─── Media Renderer ────────────────────────────────────────────────────────────
const MediaRenderer = ({ mediaItems, isAdType, peopleTags = [] }) => {
  const [currentIndex, setCurrentIndex] = useState(0);
  const [videoReady, setVideoReady]     = useState(false);
  const [videoPlaying, setVideoPlaying] = useState(false);
  const [isMuted, setIsMuted]           = useState(true);
  // userPaused: true when the user manually tapped to pause — prevents IntersectionObserver
  // from auto-resuming until they scroll away and back
  const [userPaused, setUserPaused]     = useState(false);

  const videoRef      = useRef(null);
  const containerRef  = useRef(null);
  const isVisibleRef  = useRef(false);

  const currentItem = mediaItems[currentIndex] || {};
  const isVideo = currentItem.type === 'video' || currentItem.media_type === 'video';

  const getThumbnailUrl = (item) => {
    if (!item) return null;
    if (Array.isArray(item.thumbnails) && item.thumbnails[0]?.fileUrl) return item.thumbnails[0].fileUrl;
    if (Array.isArray(item.thumbnail) && item.thumbnail[0]?.fileUrl) return item.thumbnail[0].fileUrl;
    if (typeof item.thumbnail === 'string') return item.thumbnail;
    if (typeof item.poster === 'string') return item.poster;
    return null;
  };

  const getVideoTiming = (item) => {
    const n = v => (typeof v === 'number' && isFinite(v)) ? v : (parseFloat(v) || 0);
    if (item?.video_meta || item?.timing_window) {
      const meta = item.video_meta || {};
      const tw   = item.timing_window || {};
      return { start: n(meta.selected_start ?? tw.start ?? 0), end: n(meta.selected_end ?? tw.end ?? 0) };
    }
    const t = item?.timing || {};
    let start = n(t.start ?? item?.['finalLength-start'] ?? 0);
    let end   = n(t.end   ?? item?.['finallength-end']   ?? 0);
    const dur = n(item?.videoLength ?? item?.totalLenght ?? item?.duration ?? 0);
    if (start < 0) start = 0;
    if (!end && dur > 0) end = dur;
    if (dur > 0 && end > dur) end = dur;
    if (end > 0 && end <= start) end = 0;
    return { start, end };
  };

  const thumbnailUrl = getThumbnailUrl(currentItem);
  const { start: trimStart, end: trimEnd } = getVideoTiming(currentItem);
  const showThumb = thumbnailUrl && !videoReady;

  // ── IntersectionObserver: auto play when ≥50% visible, pause when not ───────
  useEffect(() => {
    if (!isVideo) return;
    const container = containerRef.current;
    if (!container) return;

    const observer = new IntersectionObserver(
      ([entry]) => {
        isVisibleRef.current = entry.isIntersecting;
        const vid = videoRef.current;
        if (!vid) return;
        if (entry.isIntersecting) {
          // Only auto-play if the user hasn't manually paused
          if (!userPaused) {
            vid.play().catch(() => {});
          }
        } else {
          // Always pause when scrolled out of view, and reset userPaused
          // so it auto-resumes next time they scroll back
          vid.pause();
          setUserPaused(false);
        }
      },
      { threshold: 0.5 }
    );

    observer.observe(container);
    return () => observer.disconnect();
  }, [isVideo, userPaused, currentIndex]);

  // ── When carousel slide changes, reset state ─────────────────────────────────
  const goNext = (e) => {
    e.stopPropagation();
    setCurrentIndex(i => (i + 1) % mediaItems.length);
    setVideoReady(false);
    setVideoPlaying(false);
    setUserPaused(false);
  };
  const goPrev = (e) => {
    e.stopPropagation();
    setCurrentIndex(i => (i - 1 + mediaItems.length) % mediaItems.length);
    setVideoReady(false);
    setVideoPlaying(false);
    setUserPaused(false);
  };
  const toggleMute = (e) => {
    e.stopPropagation();
    if (videoRef.current) videoRef.current.muted = !isMuted;
    setIsMuted(m => !m);
  };
  const togglePlayPause = (e) => {
    e.stopPropagation();
    const vid = videoRef.current;
    if (!vid) return;
    if (vid.paused) {
      vid.play().catch(() => {});
      setUserPaused(false);
    } else {
      vid.pause();
      setUserPaused(true);
    }
  };

  if (!mediaItems.length) return (
    <div className="flex items-center justify-center bg-gradient-to-br from-purple-900 to-pink-900" style={{ minHeight: 280 }}>
      <div className="text-center px-6 py-8">
        <div className="text-5xl mb-3">🛍️</div>
        <p className="text-white font-bold text-lg">Sponsored Content</p>
      </div>
    </div>
  );

  return (
    <div ref={containerRef} className="w-full bg-black overflow-hidden relative group">
      {isVideo ? (
        <div className="relative w-full">
          {/* Thumbnail shown until video is ready */}
          {thumbnailUrl && (
            <img src={thumbnailUrl} alt="thumbnail"
              className="w-full h-auto max-h-[600px] object-contain"
              style={{ display: showThumb ? 'block' : 'none', minHeight: 300 }} />
          )}
          <video
            ref={videoRef}
            key={`${currentItem.fileUrl || currentItem.url}-${currentIndex}`}
            src={currentItem.fileUrl || currentItem.url}
            className="w-full h-auto max-h-[600px] object-contain"
            style={{ display: videoReady ? 'block' : 'none' }}
            muted={isMuted}
            playsInline
            loop={false}
            poster={thumbnailUrl || undefined}
            data-start={trimStart}
            data-end={trimEnd}
            onLoadedMetadata={(e) => {
              setVideoReady(true);
              const s = Number(e.currentTarget.dataset.start || 0);
              if (s > 0 && isFinite(s)) e.currentTarget.currentTime = s;
              // Auto-play if visible and not user-paused
              if (isVisibleRef.current && !userPaused) {
                e.currentTarget.play().catch(() => {});
              }
            }}
            onCanPlay={() => setVideoReady(true)}
            onPlay={() => setVideoPlaying(true)}
            onPause={() => setVideoPlaying(false)}
            onEnded={() => {
              setVideoPlaying(false);
              // Loop back to trim start
              const s = trimStart > 0 ? trimStart : 0;
              if (videoRef.current) { videoRef.current.currentTime = s; videoRef.current.play().catch(() => {}); }
            }}
            onTimeUpdate={(e) => {
              const v = e.currentTarget;
              const eVal = Number(v.dataset.end || 0);
              const s    = Number(v.dataset.start || 0);
              if (eVal > 0 && isFinite(eVal) && v.currentTime >= eVal) {
                v.currentTime = isFinite(s) && s > 0 ? s : 0;
                v.play().catch(() => {});
              }
            }}
          />
          {/* Tap to play/pause overlay */}
          <div className="absolute inset-0 z-[5] cursor-pointer flex items-center justify-center" onClick={togglePlayPause}>
            {!videoPlaying && (
              <div className="w-14 h-14 rounded-full bg-black/40 flex items-center justify-center pointer-events-none">
                <svg className="w-7 h-7 text-white ml-1" fill="currentColor" viewBox="0 0 24 24"><path d="M8 5v14l11-7z"/></svg>
              </div>
            )}
          </div>
          {/* Mute button */}
          <button onClick={toggleMute}
            className="absolute bottom-3 right-3 z-20 bg-black/55 hover:bg-black/75 text-white p-2 rounded-full transition-all opacity-0 group-hover:opacity-100">
            {isMuted ? <VolumeX size={15} /> : <Volume2 size={15} />}
          </button>
          <PeopleTagsOverlay tags={peopleTags} visible={videoReady || !!thumbnailUrl} />
        </div>
      ) : (
        <div className="relative w-full">
          <img
            src={currentItem.fileUrl || currentItem.image}
            alt="Post"
            className="w-full h-auto max-h-[600px] object-contain"
            style={currentItem.image_editing?.filter?.css ? { filter: currentItem.image_editing.filter.css } : {}}
          />
          <PeopleTagsOverlay tags={peopleTags} visible={true} />
        </div>
      )}

      {/* Carousel navigation */}
      {mediaItems.length > 1 && (
        <>
          {currentIndex > 0 && (
            <button onClick={goPrev} className="absolute left-2 top-1/2 -translate-y-1/2 bg-black/50 hover:bg-black/70 text-white p-1.5 rounded-full opacity-0 group-hover:opacity-100 transition-opacity z-20">
              <ChevronLeft size={20} />
            </button>
          )}
          {currentIndex < mediaItems.length - 1 && (
            <button onClick={goNext} className="absolute right-2 top-1/2 -translate-y-1/2 bg-black/50 hover:bg-black/70 text-white p-1.5 rounded-full opacity-0 group-hover:opacity-100 transition-opacity z-20">
              <ChevronRight size={20} />
            </button>
          )}
          <div className="absolute bottom-3 left-1/2 -translate-x-1/2 flex gap-1.5 z-20">
            {mediaItems.map((_, idx) => (
              <div key={idx} className={`rounded-full transition-all duration-300 ${idx === currentIndex ? 'w-2 h-2 bg-white' : 'w-1.5 h-1.5 bg-white/50'}`} />
            ))}
          </div>
        </>
      )}

      {/* Ad badge overlay */}
      {isAdType && (
        <div className="absolute top-2 left-2 z-20">
          <span className="bg-black/55 backdrop-blur-sm text-white text-[10px] font-bold px-2 py-0.5 rounded-full tracking-wide">AD</span>
        </div>
      )}
    </div>
  );
};

// ─── PostCard ──────────────────────────────────────────────────────────────────
const PostCard = ({ post, onCommentClick, onDelete }) => {
  const { userObject } = useSelector(s => s.auth);
  const isAd = isAdItem(post);

  // ── Derived: normalize post & ad shapes to one interface ──────────────────
  const user       = post.user_id || post.users || post.user || {};
  const vendor     = post.vendor_id || {};
  const username   = user.username || vendor.business_name || post.username || 'User';
  const fullName   = vendor.business_name && vendor.business_name !== username
    ? vendor.business_name
    : (user.full_name || '');
  const avatar     = user.avatar_url || post.userAvatar || '';
  const userId     = user._id || user.id || (typeof post.user_id === 'string' ? post.user_id : null);
  const postId     = post._id || post.id;
  const peopleTags = post.people_tags || [];
  const viewerId   = userObject?._id || userObject?.id || null;
  const isOwner    = !!(viewerId && userId && String(viewerId) === String(userId));

  const mediaItems = post.media?.length > 0
    ? post.media
    : (post.imageUrl ? [{ fileUrl: post.imageUrl, type: 'image' }] : []);

  // ── State ──────────────────────────────────────────────────────────────────
  const [isLiked, setIsLiked] = useState(false);
  const [likeCount, setLikeCount] = useState(0);
  const [isDisliked, setIsDisliked] = useState(false);
  const [isSaved, setIsSaved] = useState(false);
  const [latestComment, setLatestComment] = useState(null);
  const [showOptions, setShowOptions] = useState(false);
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);
  const [showReportModal, setShowReportModal] = useState(false);
  const [showEditModal, setShowEditModal] = useState(false);

  // ── Time formatting ────────────────────────────────────────────────────────
  const [nowTs, setNowTs] = useState(0);
  useEffect(() => {
    const t = setTimeout(() => setNowTs(Date.now()), 0);
    return () => clearTimeout(t);
  }, []);

  const formattedDate = (() => {
    const raw = post.createdAt || post.created_at;
    if (!raw || !nowTs) return 'Just now';
    const diff = Math.floor((nowTs - new Date(raw).getTime()) / 1000);
    if (diff < 60) return 'Just now';
    if (diff < 3600) return `${Math.floor(diff / 60)}m`;
    if (diff < 86400) return `${Math.floor(diff / 3600)}h`;
    if (diff < 604800) return `${Math.floor(diff / 86400)}d`;
    return new Date(raw).toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
  })();

  // ── Init from item data ────────────────────────────────────────────────────
  useEffect(() => {
    if (!post) return;
    const t = setTimeout(() => {
      if (typeof post.is_liked_by_me !== 'undefined') {
        setIsLiked(post.is_liked_by_me);
        setLikeCount(post.likes_count || 0);
      } else if (Array.isArray(post.likes)) {
        const myId = userObject?._id || userObject?.id;
        const liked = myId ? post.likes.some(l =>
          typeof l === 'string' ? String(l) === String(myId) : String(l.user_id || l._id || l.id) === String(myId)
        ) : false;
        setIsLiked(liked);
        setLikeCount(post.likes.length);
      }
      setIsSaved(post.is_saved_by_me || false);

      // Latest comment preview (posts only)
      if (!isAd) {
        if (post.latest_comments?.length > 0) {
          const c = post.latest_comments[0];
          setLatestComment({ username: c.username || c.user?.username, text: c.text || c.content });
        } else if (post.comments?.length > 0) {
          const c = post.comments[0];
          setLatestComment({ username: c.user?.username, text: c.text || c.content });
        } else if (!post._id) {
          supabase.from('comments')
            .select('id, content, created_at, users(username)')
            .eq('post_id', post.id)
            .order('created_at', { ascending: false })
            .limit(1).single()
            .then(({ data }) => { if (data) setLatestComment({ username: data.users?.username, text: data.content }); })
            .catch(() => {});
        }
      }
    }, 0);
    return () => clearTimeout(t);
  }, [post, userObject, isAd]);

  // ── Like handler ──────────────────────────────────────────────────────────
  const handleLike = async () => {
    if (!userObject) return;
    const wasLiked = isLiked;
    const wasDisliked = isDisliked;
    setIsLiked(!wasLiked);
    setLikeCount(c => !wasLiked ? c + 1 : Math.max(0, c - 1));
    if (!wasLiked && wasDisliked) setIsDisliked(false);

    try {
      if (isAd) {
        const ep = wasLiked ? `/api/ads/${postId}/dislike` : `/api/ads/${postId}/like`;
        const res = await fetch(`${BASE_URL}${ep}`, {
          method: 'POST', headers: adAuthHeaders(),
          body: JSON.stringify({ user: { id: String(userObject._id || userObject.id || '') } }),
        });
        if (!res.ok) throw new Error();
      } else if (post._id) {
        await api.post(`/posts/${postId}/${wasLiked ? 'unlike' : 'like'}`);
      } else {
        const likes = post.likes || [];
        const updated = wasLiked
          ? likes.filter(l => l.user_id !== userObject.id)
          : [...likes, { user_id: userObject.id }];
        await supabase.from('posts').update({ likes: updated }).eq('id', post.id);
      }
    } catch {
      setIsLiked(wasLiked);
      setLikeCount(c => wasLiked ? c + 1 : Math.max(0, c - 1));
      if (!wasLiked && wasDisliked) setIsDisliked(wasDisliked);
    }
  };

  // ── Dislike handler (ads only) ─────────────────────────────────────────────

  // ── Save handler ──────────────────────────────────────────────────────────
  const handleSave = async (e) => {
    e.stopPropagation();
    if (!userObject || !postId || isAd) return;
    const was = isSaved;
    setIsSaved(!was);
    try {
      await api.post(`/posts/${postId}/${was ? 'unsave' : 'save'}`);
    } catch { setIsSaved(was); }
  };

  // ── Delete handler ─────────────────────────────────────────────────────────
  const handleConfirmDelete = async () => {
    setIsDeleting(true);
    try {
      await api.delete(isAd ? `/ads/${postId}` : `/posts/${postId}`);
      await new Promise(r => setTimeout(r, 900));
      onDelete?.(postId);
    } catch (err) {
      alert(err.response?.data?.message || `Failed to delete ${isAd ? 'ad' : 'post'}`);
      setIsDeleting(false);
      setShowDeleteModal(false);
    }
  };

  const offer = isAd ? (post.product_offer?.[0] || null) : null;
  const reportContentType = isAd ? 'ad' : (post.type === 'reel' ? 'reel' : 'post');
  const reportContentUrl = isAd
    ? `${window.location.origin}/ads`
    : post.type === 'reel'
      ? `${window.location.origin}/reels/${postId}`
      : `${window.location.origin}/posts/${postId}`;

  return (
    <div className="bg-white dark:bg-black mb-4 border-b border-gray-200 dark:border-gray-800 pb-4 md:rounded-lg md:border max-w-[470px] mx-auto">

      {/* ── Header ────────────────────────────────────────────────────────── */}
      <div className="flex items-center justify-between p-3">
        <div className="flex items-center gap-2.5 min-w-0">
          <Link to={`/profile/${userId}`} className="flex-shrink-0 w-9 h-9 rounded-full bg-gradient-to-tr from-yellow-400 via-orange-500 to-pink-500 p-[2px] block">
            <div className="w-full h-full rounded-full bg-white dark:bg-black p-[1px]">
              {avatar ? (
                <img src={avatar} alt={username} className="w-full h-full rounded-full object-cover" />
              ) : (
                <div className="w-full h-full rounded-full bg-gradient-to-tr from-yellow-400 via-orange-500 to-pink-500 flex items-center justify-center text-xs font-bold text-white">
                  {username.charAt(0).toUpperCase()}
                </div>
              )}
            </div>
          </Link>

          <div className="flex flex-col min-w-0 leading-tight">
            <Link to={`/profile/${userId}`} className="font-semibold text-sm dark:text-white hover:underline truncate">
              {username}
            </Link>
            <div className="flex items-center gap-1.5">
              {fullName && <span className="text-[11px] text-gray-400 truncate">{fullName}</span>}
              {isAd && <span className="text-[10px] text-gray-400 font-medium">· Sponsored</span>}
              {!isAd && post.location && <span className="text-[11px] text-gray-400 truncate">{post.location}</span>}
            </div>
          </div>
        </div>

        <div className="flex items-center gap-1.5 flex-shrink-0">
          {/* Ad: budget badge */}
          {isAd && post.total_budget_coins > 0 && (
            <div className="flex items-center gap-1 bg-amber-50 dark:bg-amber-500/10 border border-amber-200 dark:border-amber-500/30 rounded-full px-2 py-0.5">
              <CoinIcon size={11} />
              <span className="text-amber-600 dark:text-amber-400 text-[10px] font-bold">{fmt(post.total_budget_coins)}</span>
            </div>
          )}
          <span className="text-[11px] text-gray-400 dark:text-gray-500">{formattedDate}</span>

          <button
            onClick={() => {
              if (isOwner) {
                setShowOptions(true);
                return;
              }
              setShowReportModal(true);
            }}
            className="p-1 text-gray-500 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-full transition-colors"
          >
            <MoreHorizontal size={20} />
          </button>

        </div>
      </div>

      <DeleteModal isOpen={showDeleteModal} onClose={() => setShowDeleteModal(false)} onConfirm={handleConfirmDelete} isDeleting={isDeleting} />
      <OwnerContentOptionsModal
        isOpen={showOptions && isOwner}
        onClose={() => setShowOptions(false)}
        item={post}
        contentType={isAd ? 'ad' : (post.type === 'reel' ? 'reel' : 'post')}
        contentUrl={reportContentUrl}
        onEdit={() => {
          setShowOptions(false);
          setShowEditModal(true);
        }}
        onDelete={() => {
          setShowOptions(false);
          setShowDeleteModal(true);
        }}
        onUpdated={() => window.location.reload()}
      />
      <EditContentModal
        isOpen={showEditModal}
        onClose={() => setShowEditModal(false)}
        item={post}
        contentType={isAd ? 'ad' : (post.type === 'reel' ? 'reel' : 'post')}
        onSaved={() => window.location.reload()}
      />
      <ContentReportModal
        isOpen={showReportModal}
        onClose={() => setShowReportModal(false)}
        contentType={reportContentType}
        contentId={postId}
        ownerUsername={username}
        contentUrl={reportContentUrl}
      />

      {/* ── Media ─────────────────────────────────────────────────────────── */}
      <MediaRenderer mediaItems={mediaItems} isAdType={isAd} peopleTags={peopleTags} />

      {/* ── Action Bar ────────────────────────────────────────────────────── */}
      <div className="px-3 pt-2">
        <div className="flex items-center justify-between mb-1.5">
          <div className="flex items-center gap-4">
            {/* Like */}
            <button onClick={handleLike} className="active:scale-90 transition-transform group" aria-label="Like">
              <Heart size={24} className={`transition-all duration-200 group-active:scale-125 ${isLiked ? 'fill-red-500 text-red-500' : 'text-black dark:text-white'}`} />
            </button>

            {/* Comment */}
            <button onClick={() => onCommentClick?.(post)} className="hover:opacity-60 transition-opacity" aria-label="Comment">
              <MessageCircle size={24} className="text-black dark:text-white" />
            </button>

            {/* Share */}
            <button className="hover:opacity-60 transition-opacity" aria-label="Share">
              <Send size={24} className="text-black dark:text-white" />
            </button>
          </div>

          <div className="flex items-center gap-3">
            {/* Follow — for non-owner posts/reels AND for ads */}
            {!isOwner && userId && userObject && (
              <FollowButton targetUserId={String(userId)} />
            )}
            {/* Save */}
            <button onClick={isAd ? (e) => { e.stopPropagation(); setIsSaved(s => !s); } : handleSave}
              className="active:scale-90 transition-transform" aria-label={isSaved ? 'Unsave' : 'Save'}>
              <Bookmark size={24} className={`transition-all duration-200 ${isSaved ? 'fill-black text-black dark:fill-white dark:text-white' : 'text-black dark:text-white'}`} />
            </button>
          </div>
        </div>

        {/* Like count */}
        {!post.engagement_controls?.hide_likes_count && !post.hide_likes_count && (
          <p className="font-semibold text-sm dark:text-white mb-1">
            {fmt(likeCount)} {likeCount === 1 ? 'like' : 'likes'}
          </p>
        )}

        {/* Ad: category badge */}
        {isAd && post.category && (
          <div className="mb-1">
            <span className="text-[10px] font-semibold text-blue-600 dark:text-blue-400 bg-blue-50 dark:bg-blue-500/10 border border-blue-100 dark:border-blue-500/20 rounded-full px-2 py-0.5">
              {post.category}
            </span>
          </div>
        )}

        {/* Caption */}
        <ExpandCaption username={username} userId={userId} text={post.caption} isAd={isAd} />

        {/* Hashtags */}
        {post.hashtags?.length > 0 && (
          <div className="flex flex-wrap gap-x-1.5 gap-y-0.5 mb-1">
            {post.hashtags.map((h, i) => (
              <span key={i} className="text-sm text-blue-500">#{h}</span>
            ))}
          </div>
        )}

        {/* People tag mentions — posts only */}
        {!isAd && peopleTags.length > 0 && (
          <div className="flex flex-wrap gap-x-2 gap-y-0.5 mb-1">
            {peopleTags.map((tag, i) => (
              <Link key={tag._id || i} to={`/profile/${tag.user_id || ''}`}
                className="text-sm text-[#0095f6] hover:underline font-semibold">@{tag.username}</Link>
            ))}
          </div>
        )}

        {/* Ad: shop CTA */}
        {isAd && offer && <ShopCTA offer={offer} />}

        {/* Ad: target info */}
        {isAd && (post.target_location?.length > 0 || post.target_language?.length > 0) && (
          <div className="mt-1 text-[11px] text-gray-400 dark:text-gray-500 flex flex-wrap gap-x-3">
            {post.target_location?.length > 0 && <span>📍 {post.target_location.slice(0, 3).join(', ')}{post.target_location.length > 3 ? '…' : ''}</span>}
            {post.target_language?.length > 0 && <span>🌐 {post.target_language.slice(0, 3).join(', ')}{post.target_language.length > 3 ? '…' : ''}</span>}
          </div>
        )}

        {/* Comments link */}
        {(post.comments_count || 0) > 1 && (
          <button onClick={() => onCommentClick?.(post)}
            className="block text-sm text-gray-400 dark:text-gray-500 hover:text-gray-600 dark:hover:text-gray-400 mb-1 mt-0.5 transition-colors">
            View all {fmt(post.comments_count)} comments
          </button>
        )}

        {/* Latest comment preview — posts only */}
        {!isAd && latestComment && (
          <p className="text-sm dark:text-white mb-1 leading-snug">
            <span className="font-semibold mr-1 dark:text-white">{latestComment.username}</span>
            <span className="text-gray-700 dark:text-gray-300">{latestComment.text}</span>
          </p>
        )}

        {/* Ad: views */}
        {isAd && post.views_count > 0 && (
          <p className="text-[11px] text-gray-400 dark:text-gray-500 mt-0.5">{fmt(post.views_count)} views</p>
        )}

        <p className="text-gray-400 dark:text-gray-500 text-[11px] uppercase tracking-wider mt-1">{formattedDate}</p>
      </div>
    </div>
  );
};

export default PostCard;
