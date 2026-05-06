import React, { useState, useEffect, useRef, useCallback } from 'react';
import {
  Heart, MessageCircle, Send, Bookmark, MoreHorizontal,
  ChevronLeft, ChevronRight, X,
  Volume2, VolumeX, UserPlus, UserCheck, ShoppingBag, Loader2
} from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useSelector } from 'react-redux';
import { Link } from 'react-router-dom';
import api from '../lib/api';
import {
  checkFollowStatus,
  followUser,
  unfollowUser,
  cancelFollowRequest,
  FOLLOW_STATUS_CHANGED_EVENT,
} from '../services/followService';
import ContentReportModal from './ContentReportModal';
import EditContentModal from './EditContentModal';
import OwnerContentOptionsModal from './OwnerContentOptionsModal';
import ShareContentModal from './ShareContentModal';

const BASE_URL = 'https://api.bebsmart.in';

const fmt = (n = 0) => {
  if (n >= 1_000_000) return (n / 1_000_000).toFixed(1) + 'M';
  if (n >= 1_000) return (n / 1_000).toFixed(1) + 'k';
  return String(n);
};

// ─── Helpers ──────────────────────────────────────────────────────────────────
const isAdItem = (item) => {
  if (!item || typeof item !== 'object') return false;
  if (item.item_type === 'ad' || item.type === 'ad' || item._type === 'ad') return true;
  return Boolean(item.vendor_id || item.ads_type || item.ad_type || item.product_offer || item.coins_per_view);
};
const isTweetItem = (item) => item?.item_type === 'tweet';
const getContentText = (item) => item?.content || item?.caption || '';
const getCommentsCount = (item) => {
  const explicit =
    item?.commentsCount
    ?? item?.comments_count
    ?? item?.commentCount
    ?? item?.comment_count;
  if (Number.isFinite(Number(explicit))) return Number(explicit);
  return Array.isArray(item?.comments) ? item.comments.length : 0;
};
const getLikeCount = (item) => item?.likesCount ?? item?.likes_count ?? (Array.isArray(item?.likes) ? item.likes.length : 0);

// ─── Delete Confirmation Modal ─────────────────────────────────────────────────
const DeleteModal = ({ isOpen, onClose, onConfirm, isDeleting }) => {
  if (!isOpen) return null;
  return (
    <div className="fixed inset-0 z-[150] flex items-start justify-center bg-black/50 backdrop-blur-sm p-4 pt-20 overflow-y-auto">
      <div className="absolute inset-0" onClick={onClose} />
      <div className="relative bg-white dark:bg-gray-900 rounded-xl p-6 w-full max-w-sm shadow-2xl border border-gray-100 dark:border-gray-800 mt-4 md:mt-8">
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
    if (!visible) setShowTags(false);
  }, [visible]);

  if (!tags?.length) return null;
  return (
    <>
      <button
        className="absolute bottom-3 left-3 z-10 w-8 h-8 rounded-full bg-black/50 backdrop-blur-sm flex items-center justify-center hover:bg-black/70 active:scale-90 transition-all"
        onClick={(e) => { e.stopPropagation(); setShowTags(s => !s); }}
      >
        <svg width="16" height="16" viewBox="0 0 24 24" fill="white">
          <path d="M12 12c2.7 0 4.8-2.1 4.8-4.8S14.7 2.4 12 2.4 7.2 4.5 7.2 7.2 9.3 12 12 12zm0 2.4c-3.2 0-9.6 1.6-9.6 4.8v2.4h19.2v-2.4c0-3.2-6.4-4.8-9.6-4.8z"/>
        </svg>
      </button>
      {showTags ? (
        <>
          <div className="absolute inset-0 z-20 bg-black/35" onClick={(e) => { e.stopPropagation(); setShowTags(false); }} />
          <div
            className="absolute left-1/2 top-4 z-30 w-[calc(100%-24px)] max-w-[620px] -translate-x-1/2 overflow-hidden rounded-[22px] border border-white/10 bg-[#1f222b]/95 text-white shadow-2xl backdrop-blur-md"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="relative border-b border-white/10 px-5 py-3 text-center">
              <p className="text-lg font-semibold">Tagged</p>
              <button
                type="button"
                className="absolute right-4 top-1/2 -translate-y-1/2 text-3xl leading-none text-white/90 hover:text-white"
                onClick={() => setShowTags(false)}
              >
                ×
              </button>
            </div>
            <div className="max-h-[48vh] overflow-y-auto">
              {tags.map((tag, idx) => {
                const profilePath = tag.role === 'vendor'
                  ? `/vendor/${tag.user_id || ''}/public`
                  : `/profile/${tag.user_id || ''}`;
                const username = tag.username || 'user';
                const fullName = tag.full_name || username;
                const avatar = tag.avatar_url || tag.profile_picture || tag.avatar || '';

                return (
                  <Link
                    key={tag._id || tag.user_id || idx}
                    to={profilePath}
                    onClick={() => setShowTags(false)}
                    className="flex items-center gap-3 px-5 py-3 hover:bg-white/5"
                  >
                    {avatar ? (
                      <img src={avatar} alt={username} className="h-11 w-11 rounded-full object-cover" />
                    ) : (
                      <div className="flex h-11 w-11 items-center justify-center rounded-full bg-white/15 text-sm font-bold">
                        {(username || 'U').charAt(0).toUpperCase()}
                      </div>
                    )}
                    <div className="min-w-0">
                      <p className="truncate text-sm font-semibold leading-tight">{username}</p>
                      <p className="truncate text-sm text-white/70 leading-tight">{fullName}</p>
                    </div>
                  </Link>
                );
              })}
            </div>
          </div>
        </>
      ) : null}
    </>
  );
};

// ─── Follow Button ─────────────────────────────────────────────────────────────
const FollowButton = ({ targetUserId }) => {
  const { userObject } = useSelector(s => s.auth);
  const [followState, setFollowState] = useState('not_following');
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    let isMounted = true;
    const loadStatus = async () => {
      if (!userObject || !targetUserId || String(userObject._id || userObject.id) === String(targetUserId)) {
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

  const handleClick = useCallback(async (e) => {
    e.stopPropagation();
    if (!userObject || loading) return;
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
        const res = await followUser(targetUserId);
        if (res?.status === 'pending' || res?.pending || res?.requested || res?.requestPending || res?.isPending) {
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
  }, [userObject, loading, followState, targetUserId]);

  const isFollowing = followState === 'following';
  const isRequested = followState === 'requested';

  return (
    <button onClick={handleClick} disabled={loading}
      className={`flex items-center gap-1.5 text-xs font-bold px-3 py-1 rounded-full border-2 transition-all duration-200 ${loading ? 'opacity-50 cursor-not-allowed' : ''} ${
        isFollowing || isRequested
          ? 'border-gray-300 dark:border-gray-600 text-gray-500 dark:text-gray-400 hover:border-red-400 hover:text-red-400'
          : 'border-white text-black dark:text-white bg-white dark:bg-transparent dark:border-white hover:bg-gray-100 dark:hover:bg-white/10'
      }`}>
      {loading ? <Loader2 size={11} className="animate-spin" /> : isFollowing ? <UserCheck size={11} /> : <UserPlus size={11} />}
      <span>{isFollowing ? 'Following' : isRequested ? 'Requested' : 'Follow'}</span>
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
  
  const profilePath = isAd ? `/vendor/${userId}/public` : `/profile/${userId}`;

  return (
    <p className="text-sm dark:text-white leading-snug mb-1">
      <Link to={profilePath} className="font-semibold mr-1 hover:underline dark:text-white">{username}</Link>
      {expanded || !isLong ? (
        <>
          {text}
          {expanded && isLong && (
            <button onClick={() => setExpanded(false)} className="text-gray-400 ml-1.5 text-sm font-semibold">less</button>
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

  const toAbsoluteUrl = (value) => {
    if (!value) return '';
    const str = String(value);
    if (str.startsWith('http')) return str;
    const normalized = str.replace(/^\/+/, '');
    return `${BASE_URL}/${normalized.startsWith('uploads/') ? normalized : `uploads/${normalized}`}`;
  };

  const currentItem = mediaItems[currentIndex] || {};
  const mediaSrc = toAbsoluteUrl(currentItem.fileUrl || currentItem.url || currentItem.fileName);
  const isVideo = currentItem.type === 'video'
    || currentItem.media_type === 'video'
    || /\.(mp4|mov|webm|ogg|mkv|m4v|m3u8)(\?.*)?$/i.test(String(mediaSrc));

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
            key={`${mediaSrc}-${currentIndex}`}
            src={mediaSrc}
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
            src={mediaSrc || currentItem.image}
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

// ─── TweetImageGrid ────────────────────────────────────────────────────────────
// Inline tweet image gallery: 1=compact, 2=side-by-side, 3+=stacked with +N overlay
const TweetImageGrid = ({ images, onImageClick }) => {
  if (!images.length) return null;
  const count = images.length;

  if (count === 1) {
    return (
      <div
        className="mt-2 overflow-hidden rounded-2xl border border-gray-200 dark:border-white/10 cursor-pointer max-w-[260px]"
        style={{ aspectRatio: '1/1' }}
        onClick={() => onImageClick(0)}
      >
        <img src={images[0]} alt="media" className="w-full h-full object-cover hover:opacity-90 transition-opacity" />
      </div>
    );
  }

  if (count === 2) {
    return (
      <div className="mt-2 flex gap-1.5 max-w-[440px]">
        {images.map((src, idx) => (
          <div
            key={idx}
            className="flex-1 overflow-hidden rounded-2xl border border-gray-200 dark:border-white/10 cursor-pointer"
            style={{ aspectRatio: '1/1' }}
            onClick={() => onImageClick(idx)}
          >
            <img src={src} alt={`media ${idx + 1}`} className="w-full h-full object-cover hover:opacity-90 transition-opacity" />
          </div>
        ))}
      </div>
    );
  }

  // 3+ images: first full width, second below with +N overlay
  const remaining = count - 2;
  return (
    <div className="mt-2 flex flex-col gap-1.5 max-w-[440px]">
      <div
        className="w-full overflow-hidden rounded-2xl border border-gray-200 dark:border-white/10 cursor-pointer"
        style={{ aspectRatio: '1/1' }}
        onClick={() => onImageClick(0)}
      >
        <img src={images[0]} alt="media 1" className="w-full h-full object-cover hover:opacity-90 transition-opacity" />
      </div>
      <div
        className="relative w-full overflow-hidden rounded-2xl border border-gray-200 dark:border-white/10 cursor-pointer"
        style={{ aspectRatio: '1/1' }}
        onClick={() => onImageClick(1)}
      >
        <img src={images[1]} alt="media 2" className="w-full h-full object-cover hover:opacity-90 transition-opacity" />
        {remaining > 0 && (
          <div className="absolute inset-0 bg-black/60 flex items-center justify-center">
            <span className="text-white text-3xl font-bold drop-shadow-lg">+{remaining}</span>
          </div>
        )}
      </div>
    </div>
  );
};

// ─── TweetImagePreviewModal ─────────────────────────────────────────────────────
const TweetImagePreviewModal = ({ images, initialIndex, isOpen, onClose }) => {
  const [index, setIndex] = useState(initialIndex);
  useEffect(() => { setIndex(initialIndex); }, [initialIndex]);
  useEffect(() => {
    if (!isOpen) return;
    const handleKey = (e) => {
      if (e.key === 'Escape') onClose();
      if (e.key === 'ArrowRight') setIndex(i => (i + 1) % images.length);
      if (e.key === 'ArrowLeft') setIndex(i => (i - 1 + images.length) % images.length);
    };
    window.addEventListener('keydown', handleKey);
    return () => window.removeEventListener('keydown', handleKey);
  }, [isOpen, images.length, onClose]);

  if (!isOpen || !images.length) return null;
  return (
    <div className="fixed inset-0 z-[200] bg-black/95 flex items-center justify-center" onClick={onClose}>
      <button
        className="absolute top-4 right-4 w-10 h-10 rounded-full bg-white/10 hover:bg-white/20 flex items-center justify-center text-white z-10"
        onClick={(e) => { e.stopPropagation(); onClose(); }}
      >
        <X size={20} />
      </button>
      {images.length > 1 && (
        <button
          className="absolute left-4 top-1/2 -translate-y-1/2 w-10 h-10 rounded-full bg-white/10 hover:bg-white/20 flex items-center justify-center text-white z-10"
          onClick={(e) => { e.stopPropagation(); setIndex(i => (i - 1 + images.length) % images.length); }}
        >
          <ChevronLeft size={22} />
        </button>
      )}
      <img
        src={images[index]}
        alt="Preview"
        className="max-w-[90vw] max-h-[85vh] object-contain rounded-xl shadow-2xl"
        onClick={(e) => e.stopPropagation()}
      />
      {images.length > 1 && (
        <button
          className="absolute right-4 top-1/2 -translate-y-1/2 w-10 h-10 rounded-full bg-white/10 hover:bg-white/20 flex items-center justify-center text-white z-10"
          onClick={(e) => { e.stopPropagation(); setIndex(i => (i + 1) % images.length); }}
        >
          <ChevronRight size={22} />
        </button>
      )}
      {images.length > 1 && (
        <div className="absolute bottom-6 left-1/2 -translate-x-1/2 flex gap-2">
          {images.map((_, i) => (
            <div key={i} className={`w-2 h-2 rounded-full transition-all ${i === index ? 'bg-white' : 'bg-white/40'}`} />
          ))}
        </div>
      )}
    </div>
  );
};

// ─── PostCard ──────────────────────────────────────────────────────────────────
const PostCard = ({ post, onCommentClick, onDelete }) => {
  const { userObject } = useSelector(s => s.auth);
  const isAd = isAdItem(post);
  const isTweet = isTweetItem(post);

  // ── Derived: normalize post & ad shapes to one interface ──────────────────
  const user       = post.author || post.user_id || post.users || post.user || {};
  const vendor     = post.vendor_id || {};
  const username   = user.username || vendor.business_name || post.username || 'User';
  const fullName   = vendor.business_name && vendor.business_name !== username
    ? vendor.business_name
    : (user.full_name || user.name || '');
  const avatar     = user.avatar_url || user.profilePicture || post.userAvatar || '';
  const userId     = user._id || user.id || (typeof post.user_id === 'string' ? post.user_id : null);
  const postId     = post._id || post.id;
  const peopleTags = post.people_tags || [];
  const viewerId   = userObject?._id || userObject?.id || null;
  const isOwner    = !!(viewerId && userId && String(viewerId) === String(userId));
  const contentText = getContentText(post);
  const commentsCount = getCommentsCount(post);

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
  const [showShareModal, setShowShareModal] = useState(false);

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
        setLikeCount(getLikeCount(post));
      } else if (typeof post.isLiked !== 'undefined') {
        setIsLiked(post.isLiked);
        setLikeCount(getLikeCount(post));
      } else if (Array.isArray(post.likes)) {
        const myId = userObject?._id || userObject?.id;
        const liked = myId ? post.likes.some(l =>
          typeof l === 'string' ? String(l) === String(myId) : String(l.user_id || l._id || l.id) === String(myId)
        ) : false;
        setIsLiked(liked);
        setLikeCount(getLikeCount(post));
      }
      setIsSaved(post.is_saved_by_me || false);

      // Latest comment preview (posts only)
      if (!isAd && !isTweet) {
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
  }, [post, userObject, isAd, isTweet]);

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
        const ep = wasLiked ? `/ads/${postId}/dislike` : `/ads/${postId}/like`;
        await api.post(ep);
      } else if (isTweet) {
        await api.post(`/tweets/${postId}/${wasLiked ? 'unlike' : 'like'}`);
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
    if (!userObject || !postId || isAd || isTweet) return;
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
      await api.delete(isAd ? `/ads/${postId}` : isTweet ? `/tweets/${postId}` : `/posts/${postId}`);
      await new Promise(r => setTimeout(r, 900));
      onDelete?.(postId);
    } catch (err) {
      alert(err.response?.data?.message || `Failed to delete ${isAd ? 'ad' : isTweet ? 'tweet' : 'post'}`);
      setIsDeleting(false);
      setShowDeleteModal(false);
    }
  };

  const offer = isAd ? (post.product_offer?.[0] || null) : null;
  const shareContentType = isTweet ? 'tweet' : isAd ? 'ad' : (post.type === 'reel' ? 'reel' : 'post');
  const canShareInChat = Boolean(postId && ['post', 'reel', 'ad', 'tweet'].includes(shareContentType));
  const reportContentType = isAd ? 'ad' : isTweet ? 'tweet' : (post.type === 'reel' ? 'reel' : 'post');
  const reportContentUrl = isAd
    ? `${window.location.origin}/ads`
    : isTweet
      ? `${window.location.origin}/post/${postId}?type=tweet`
    : post.type === 'reel'
      ? `${window.location.origin}/reels/${postId}`
      : `${window.location.origin}/posts/${postId}`;

  const profilePath = isAd ? `/vendor/${userId}/public` : `/profile/${userId}`;

  if (isTweet) {
    const tweetImages = mediaItems
      .map(item => {
        const raw = item?.fileUrl || item?.url || item?.fileName;
        if (!raw) return null;
        const s = String(raw);
        if (s.startsWith('http')) return s;
        return `${BASE_URL}/uploads/${s.replace(/^\/+/, '').replace(/^uploads\//, '')}`;
      })
      .filter(Boolean);

    // eslint-disable-next-line react-hooks/rules-of-hooks
    const [tweetPreviewOpen, setTweetPreviewOpen] = useState(false);
    // eslint-disable-next-line react-hooks/rules-of-hooks
    const [tweetPreviewIdx, setTweetPreviewIdx] = useState(0);

    const handleTweetImageClick = (idx) => {
      setTweetPreviewIdx(idx);
      setTweetPreviewOpen(true);
    };

    return (
      <div className="max-w-[640px] mx-auto bg-white dark:bg-black border border-gray-200 dark:border-white/10 rounded-2xl px-4 py-3 mb-3">
        <div className="flex gap-3">
          <div className="flex flex-col items-center shrink-0">
            <Link to={profilePath} className="w-10 h-10 rounded-full overflow-hidden block bg-gray-100 dark:bg-gray-800">
              {avatar ? (
                <img src={avatar} alt={username} className="w-full h-full object-cover" />
              ) : (
                <div className="w-full h-full flex items-center justify-center text-sm font-bold text-gray-600 dark:text-gray-300">
                  {username.charAt(0).toUpperCase()}
                </div>
              )}
            </Link>
            
          </div>

          <div className="flex-1 min-w-0">
            <div className="flex items-start justify-between gap-3">
              <div className="min-w-0">
                <div className="flex items-center gap-1.5 flex-wrap">
                  <Link to={profilePath} className="text-[15px] font-semibold text-gray-900 dark:text-white hover:underline truncate">
                    {username}
                  </Link>
                  {fullName && fullName !== username && (
                    <span className="text-xs text-gray-400 truncate">{fullName}</span>
                  )}
                </div>
              </div>
              <div className="flex items-center gap-3 shrink-0">
                <span className="text-xs text-gray-400">{formattedDate}</span>
                <button
                  onClick={() => {
                    if (isOwner) {
                      setShowDeleteModal(true);
                      return;
                    }
                    setShowReportModal(true);
                  }}
                  className="text-gray-500 dark:text-gray-400 hover:text-gray-800 dark:hover:text-white"
                >
                  <MoreHorizontal size={18} />
                </button>
              </div>
            </div>

            {contentText && (
              <p className="mt-0.5 text-[15px] leading-6 text-gray-900 dark:text-white whitespace-pre-wrap break-words">
                {contentText}
              </p>
            )}

            {tweetImages.length > 0 && (
              <TweetImageGrid images={tweetImages} onImageClick={handleTweetImageClick} />
            )}

            <div className="mt-3 flex items-center gap-4 text-gray-900 dark:text-white">
              <button onClick={handleLike} className="active:scale-90 transition-transform opacity-85 hover:opacity-100" aria-label="Like">
                <Heart size={20} className={isLiked ? 'fill-red-500 text-red-500' : ''} />
              </button>
              <button onClick={() => onCommentClick?.(post)} className="active:scale-90 transition-transform opacity-85 hover:opacity-100" aria-label="Reply">
                <MessageCircle size={20} />
              </button>
              
              <button
                onClick={() => { if (canShareInChat) setShowShareModal(true); }}
                className="active:scale-90 transition-transform opacity-85 hover:opacity-100"
                aria-label="Share"
              >
                <Send size={20} />
              </button>
            </div>

            <div className="mt-2 flex items-center gap-3 text-[14px] text-gray-500 dark:text-gray-400">
              <span className="cursor-default">
                {fmt(likeCount)} {likeCount === 1 ? 'like' : 'likes'}
              </span>
              <button onClick={() => onCommentClick?.(post)} className="hover:text-gray-700 dark:hover:text-gray-200 transition-colors">
                {fmt(commentsCount)} {commentsCount === 1 ? 'comment' : 'comments'}
              </button>
            </div>
          </div>
        </div>

        <DeleteModal isOpen={showDeleteModal} onClose={() => setShowDeleteModal(false)} onConfirm={handleConfirmDelete} isDeleting={isDeleting} />
        <ContentReportModal
          isOpen={showReportModal}
          onClose={() => setShowReportModal(false)}
          contentType={reportContentType}
          contentId={postId}
          contentUrl={reportContentUrl}
        />
        <ShareContentModal
          isOpen={showShareModal}
          onClose={() => setShowShareModal(false)}
          contentType={shareContentType}
          contentId={postId}
        />
        <TweetImagePreviewModal
          images={tweetImages}
          initialIndex={tweetPreviewIdx}
          isOpen={tweetPreviewOpen}
          onClose={() => setTweetPreviewOpen(false)}
        />
      </div>
    );
  }

  return (
    <div className="relative overflow-hidden bg-white dark:bg-black mb-4 border-b border-gray-200 dark:border-gray-800 pb-4 md:rounded-lg md:border max-w-[470px] mx-auto">

      {/* ── Header ────────────────────────────────────────────────────────── */}
      <div className="relative z-10 flex items-center justify-between bg-white dark:bg-black p-3">
        <div className="flex items-center gap-2.5 min-w-0">
          <Link to={profilePath} className="flex-shrink-0 w-9 h-9 rounded-full block">
            <div className="w-full h-full rounded-full bg-gray-100 dark:bg-gray-800">
              {avatar ? (
                <img src={avatar} alt={username} className="w-full h-full rounded-full object-cover" />
              ) : (
                <div className="w-full h-full rounded-full bg-gradient-to-br from-gray-200 to-gray-300 dark:from-gray-700 dark:to-gray-800 flex items-center justify-center text-xs font-bold text-gray-600 dark:text-gray-300">
                  {username.charAt(0).toUpperCase()}
                </div>
              )}
            </div>
          </Link>

          <div className="flex flex-col min-w-0 leading-tight">
            <Link to={profilePath} className="font-semibold text-sm dark:text-white hover:underline truncate">
              {username}
            </Link>
            <div className="flex items-center gap-1.5">
              {fullName && <span className="text-[11px] text-gray-400 truncate">{fullName}</span>}
              {isAd && <span className="text-[10px] text-gray-400 font-medium">· Sponsored</span>}
              {!isAd && !isTweet && post.location && <span className="text-[11px] text-gray-400 truncate">{post.location}</span>}
              {isTweet && <span className="text-[11px] text-gray-400 truncate">Tweet</span>}
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
                if (isTweet) {
                  setShowDeleteModal(true);
                } else {
                  setShowOptions(true);
                }
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
      {!isTweet && (
        <>
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
        </>
      )}

      {/* ── Media ─────────────────────────────────────────────────────────── */}
      {isTweet && (
        <ContentReportModal
          isOpen={showReportModal}
          onClose={() => setShowReportModal(false)}
          contentType={reportContentType}
          contentId={postId}
          contentUrl={reportContentUrl}
        />
      )}
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
            <button
              onClick={() => { if (canShareInChat) setShowShareModal(true); }}
              className="hover:opacity-60 transition-opacity"
              aria-label="Share"
            >
              <Send size={24} className="text-black dark:text-white" />
            </button>
          </div>

          <div className="flex items-center gap-3">
            {/* Follow — for non-owner posts/reels AND for ads */}
            {!isOwner && userId && userObject && (
              <FollowButton targetUserId={String(userId)} />
            )}
            {/* Save */}
            {!isTweet && (
              <button onClick={isAd ? (e) => { e.stopPropagation(); setIsSaved(s => !s); } : handleSave}
                className="active:scale-90 transition-transform" aria-label={isSaved ? 'Unsave' : 'Save'}>
                <Bookmark size={24} className={`transition-all duration-200 ${isSaved ? 'fill-black text-black dark:fill-white dark:text-white' : 'text-black dark:text-white'}`} />
              </button>
            )}
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
        <ExpandCaption username={username} userId={userId} text={contentText} isAd={isAd} />

        {/* Hashtags */}
        {post.hashtags?.length > 0 && (
          <div className="flex flex-wrap gap-x-1.5 gap-y-0.5 mb-1">
            {post.hashtags.map((h, i) => (
              <span key={i} className="text-sm text-blue-500">#{h}</span>
            ))}
          </div>
        )}

        {/* People tag mentions — posts only */}
        {!isAd && !isTweet && peopleTags.length > 0 && (
          <div className="flex flex-wrap gap-x-2 gap-y-0.5 mb-1">
            {peopleTags.map((tag, i) => {
              const profilePath = tag.role === 'vendor' 
                ? `/vendor/${tag.user_id || ''}/public` 
                : `/profile/${tag.user_id || ''}`;
              return (
                <Link key={tag._id || i} to={profilePath}
                  className="text-sm text-[#0095f6] hover:underline font-semibold">@{tag.username}</Link>
              );
            })}
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
        {commentsCount > 0 && (
          <button onClick={() => onCommentClick?.(post)}
            className="block text-sm text-gray-400 dark:text-gray-500 hover:text-gray-600 dark:hover:text-gray-400 mb-1 mt-0.5 transition-colors">
            View all {fmt(commentsCount)} comments
          </button>
        )}

        {/* Latest comment preview — posts only */}
        {!isAd && !isTweet && latestComment && (
          <p className="text-sm dark:text-white mb-1 leading-snug">
            <span className="font-semibold mr-1 dark:text-white">{latestComment.username}</span>
            <span className="text-gray-700 dark:text-gray-300">{latestComment.text}</span>
          </p>
        )}

        {/* Ad: views */}
        {isAd && post.views_count > 0 && (
          <p className="text-[11px] text-gray-400 dark:text-gray-500 mt-0.5">{fmt(post.views_count)} views</p>
        )}
        {isTweet && (post.viewsCount || 0) > 0 && (
          <p className="text-[11px] text-gray-400 dark:text-gray-500 mt-0.5">{fmt(post.viewsCount)} views</p>
        )}

        <p className="text-gray-400 dark:text-gray-500 text-[11px] uppercase tracking-wider mt-1">{formattedDate}</p>
      </div>

      <ShareContentModal
        isOpen={showShareModal}
        onClose={() => setShowShareModal(false)}
        contentType={shareContentType}
        contentId={postId}
      />
    </div>
  );
};

export default PostCard;