import React, { useState, useRef, useEffect, useCallback } from 'react';
import { useSelector } from 'react-redux';
import {
  Heart, MessageCircle, Send, MoreHorizontal,
  ChevronLeft, ChevronRight, Volume2, VolumeX,
  ShoppingBag, Zap, ExternalLink, UserPlus, UserCheck, Loader2
} from 'lucide-react';
import { Link } from 'react-router-dom';
import promoteReelService from '../services/promoteReelService';
import {
  checkFollowStatus,
  followUser,
  unfollowUser,
  cancelFollowRequest,
  FOLLOW_STATUS_CHANGED_EVENT,
} from '../services/followService';
import Avatar from './Avatar';
import ShareContentModal from './ShareContentModal';

const BASE_URL = 'https://api.bebsmart.in';

const fmt = (n = 0) => {
  if (n >= 1_000_000) return (n / 1_000_000).toFixed(1) + 'M';
  if (n >= 1_000) return (n / 1_000).toFixed(1) + 'k';
  return String(n);
};

const toAbsUrl = (val) => {
  if (!val) return null;
  const s = String(val);
  if (/^http:\/\/api\.bebsmart\.in/i.test(s)) return s.replace(/^http:\/\//i, 'https://');
  if (s.startsWith('http')) return s;
  const n = s.replace(/^\/+/, '');
  return `${BASE_URL}/${n.startsWith('uploads/') ? n : `uploads/${n}`}`;
};

const getMediaUrl = (m) => {
  if (!m) return null;
  if (m.url && String(m.url).startsWith('http')) return m.url;
  return toAbsUrl(m.fileUrl || m.fileName);
};

const getThumbUrl = (m) => {
  if (!m) return null;
  const thumbs = m.thumbnails || m.thumbnail;
  const first = Array.isArray(thumbs) ? thumbs[0] : thumbs;
  if (!first) return null;
  return toAbsUrl(first.fileUrl || first.fileName);
};

const timeAgo = (raw) => {
  if (!raw) return '';
  const diff = Math.floor((Date.now() - new Date(raw).getTime()) / 1000);
  if (diff < 60) return 'Just now';
  if (diff < 3600) return `${Math.floor(diff / 60)}m`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h`;
  if (diff < 604800) return `${Math.floor(diff / 86400)}d`;
  return new Date(raw).toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
};

// ── Product Card — matches the Promote.jsx / detail card style exactly ─────────
const ProductCard = ({ product }) => {
  const finalPrice = Math.max(0, (product.product_price || 0) - (product.discount_amount || 0));
  const discountPct = product.product_price && product.discount_amount
    ? Math.round((product.discount_amount / product.product_price) * 100) : 0;
  const href = product.visit_link && !['', '#'].includes(product.visit_link) ? product.visit_link : null;

  return (
    <div className="flex-shrink-0 w-[160px] rounded-2xl overflow-hidden border border-gray-100 dark:border-gray-800 bg-white dark:bg-[#1a1a1a] shadow-sm">
      {/* Image */}
      <div className="w-full h-[90px] bg-gray-100 dark:bg-gray-800 overflow-hidden">
        {product.promote_img
          ? <img src={toAbsUrl(product.promote_img)} alt={product.product_name} className="w-full h-full object-cover" onError={e => { e.target.style.display = 'none'; }} />
          : <div className="w-full h-full flex items-center justify-center"><ShoppingBag size={24} className="text-gray-300" /></div>}
      </div>
      {/* Info */}
      <div className="p-2.5">
        <p className="text-[11px] font-bold text-gray-900 dark:text-white line-clamp-1 leading-tight">{product.product_name}</p>
        {product.product_description && (
          <p className="text-[9px] text-gray-400 line-clamp-1 mt-0.5">{product.product_description}</p>
        )}
        {/* Price row */}
        <div className="flex items-baseline gap-1 flex-wrap mt-1">
          <span className="text-[13px] font-black text-orange-600 dark:text-orange-400">&#8377;{finalPrice.toLocaleString()}</span>
          {discountPct > 0 && (
            <>
              <span className="text-[9px] text-gray-400 line-through">&#8377;{product.product_price}</span>
              <span className="text-[9px] font-bold text-green-500">{discountPct}% off</span>
            </>
          )}
        </div>
        {/* Visit Website button */}
        {href ? (
          <a href={href} target="_blank" rel="noopener noreferrer"
            onClick={e => e.stopPropagation()}
            className="mt-2 flex items-center justify-center w-full py-1.5 rounded-lg bg-blue-500 text-white text-[10px] font-bold hover:bg-blue-600 active:scale-95 transition-all gap-1">
            <ExternalLink size={9} />
            Visit Website
          </a>
        ) : (
          <div className="mt-2 w-full py-1.5 rounded-lg bg-gray-100 dark:bg-gray-800 text-gray-400 text-[10px] text-center">No link</div>
        )}
      </div>
    </div>
  );
};

// ── Media renderer — mirrors PostCard's MediaRenderer exactly ─────────────────
const CardMedia = ({ item }) => {
  const mediaItems = Array.isArray(item?.media) && item.media.length > 0 ? item.media : [];
  const [currentIndex, setCurrentIndex] = useState(0);
  const [videoReady, setVideoReady] = useState(false);
  const [videoPlaying, setVideoPlaying] = useState(false);
  const [isMuted, setIsMuted] = useState(true);
  const [userPaused, setUserPaused] = useState(false);

  const videoRef = useRef(null);
  const containerRef = useRef(null);
  const isVisibleRef = useRef(false);

  const currentMedia = mediaItems[currentIndex] || {};
  const mediaSrc = getMediaUrl(currentMedia);
  const thumbSrc = getThumbUrl(currentMedia);

  const isVideo = currentMedia.type === 'video' || currentMedia.media_type === 'video'
    || /\.(mp4|mov|webm|ogg|mkv|m4v|m3u8)(\?.*)?$/i.test(String(mediaSrc || ''));

  const showThumb = thumbSrc && !videoReady;

  // IntersectionObserver — play when visible, pause when scrolled away
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
          if (!userPaused) {
            vid.play().catch(() => {});
          }
        } else {
          vid.pause();
        }
      },
      { threshold: 0.1 }
    );
    observer.observe(container);
    return () => observer.disconnect();
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isVideo, currentIndex, userPaused]);

  const goNext = (e) => { e.stopPropagation(); setCurrentIndex(i => (i + 1) % mediaItems.length); setVideoReady(false); setVideoPlaying(false); setUserPaused(false); };
  const goPrev = (e) => { e.stopPropagation(); setCurrentIndex(i => (i - 1 + mediaItems.length) % mediaItems.length); setVideoReady(false); setVideoPlaying(false); setUserPaused(false); };

  const toggleMute = (e) => {
    e.stopPropagation();
    if (videoRef.current) videoRef.current.muted = !isMuted;
    setIsMuted(m => !m);
  };
  const togglePlayPause = (e) => {
    e.stopPropagation();
    const vid = videoRef.current;
    if (!vid) return;
    if (vid.paused) { vid.play().catch(() => {}); setUserPaused(false); }
    else { vid.pause(); setUserPaused(true); }
  };

  if (!mediaItems.length) return (
    <div className="w-full bg-gradient-to-br from-orange-900/20 to-pink-900/20 flex items-center justify-center" style={{ minHeight: 280 }}>
      <Zap size={40} className="text-orange-400/40" />
    </div>
  );

  return (
    <div ref={containerRef} className="w-full bg-black overflow-hidden relative group">
      {/* Promoted badge */}
      <div className="absolute top-2 left-2 z-20">
        <span className="inline-flex items-center gap-1 bg-gradient-to-r from-orange-500 to-pink-500 text-white text-[10px] font-bold px-2.5 py-1 rounded-full shadow">
          <Zap size={9} /> Promoted
        </span>
      </div>

      {isVideo ? (
        <div className="relative w-full">
          {/* Thumbnail shown until video ready */}
          {thumbSrc && (
            <img src={thumbSrc} alt="thumbnail"
              className="w-full h-auto max-h-[600px] object-contain"
              style={{ display: showThumb ? 'block' : 'none', minHeight: 300 }} />
          )}
          <video
            ref={videoRef}
            key={`${mediaSrc}-${currentIndex}`}
            src={mediaSrc}
            className={`w-full h-auto max-h-[600px] object-contain ${videoReady ? 'block' : 'hidden'}`}
            autoPlay
            muted={isMuted}
            playsInline
            loop
            poster={thumbSrc || undefined}
            onLoadedMetadata={(e) => {
              setVideoReady(true);
              if (isVisibleRef.current && !userPaused) {
                e.currentTarget.play().catch(() => {});
              }
            }}
            onCanPlay={() => setVideoReady(true)}
            onPlay={() => setVideoPlaying(true)}
            onPause={() => setVideoPlaying(false)}
          />
          {/* Tap overlay */}
          <div className="absolute inset-0 z-[5] cursor-pointer flex items-center justify-center" onClick={togglePlayPause}>
            {!videoPlaying && (
              <div className="w-14 h-14 rounded-full bg-black/40 flex items-center justify-center pointer-events-none">
                <svg className="w-7 h-7 text-white ml-1" fill="currentColor" viewBox="0 0 24 24"><path d="M8 5v14l11-7z" /></svg>
              </div>
            )}
          </div>
          {/* Mute */}
          <button onClick={toggleMute}
            className="absolute bottom-3 right-3 z-20 bg-black/55 hover:bg-black/75 text-white p-2 rounded-full transition-all">
            {isMuted ? <VolumeX size={15} /> : <Volume2 size={15} />}
          </button>
        </div>
      ) : (
        <div className="relative w-full">
          <img src={mediaSrc} alt="media" className="w-full h-auto max-h-[600px] object-contain" />
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
    </div>
  );
};

// ── Follow Button — exact copy of PostCard's FollowButton ─────────────────────
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
        if (status?.isFollowing || status?.status === 'following') setFollowState('following');
        else if (status?.isPending || status?.requestPending || status?.requested || status?.status === 'pending') setFollowState('requested');
        else setFollowState('not_following');
      } catch { if (isMounted) setFollowState('not_following'); }
    };
    loadStatus();
    return () => { isMounted = false; };
  }, [targetUserId, userObject]);

  useEffect(() => {
    const onChange = (e) => {
      const d = e?.detail || {};
      if (String(d.userId || '') !== String(targetUserId || '')) return;
      if (['following','requested','not_following'].includes(d.state)) setFollowState(d.state);
    };
    window.addEventListener(FOLLOW_STATUS_CHANGED_EVENT, onChange);
    return () => window.removeEventListener(FOLLOW_STATUS_CHANGED_EVENT, onChange);
  }, [targetUserId]);

  const handleClick = useCallback(async (e) => {
    e.stopPropagation();
    if (!userObject || loading) return;
    const prev = followState;
    setLoading(true);
    try {
      if (followState === 'following') { await unfollowUser(targetUserId); setFollowState('not_following'); }
      else if (followState === 'requested') { await cancelFollowRequest(targetUserId); setFollowState('not_following'); }
      else {
        const res = await followUser(targetUserId);
        setFollowState(res?.status === 'pending' || res?.pending || res?.requested ? 'requested' : 'following');
      }
    } catch { setFollowState(prev); }
    finally { setLoading(false); }
  }, [userObject, loading, followState, targetUserId]);

  const isFollowing = followState === 'following';
  const isRequested = followState === 'requested';

  return (
    <button onClick={handleClick} disabled={loading}
      className={`flex items-center gap-1.5 text-xs font-bold px-3 py-1 rounded-full border transition-all duration-200 ${loading ? 'opacity-50 cursor-not-allowed' : ''} ${
        isFollowing || isRequested
          ? 'border-gray-300 dark:border-gray-600 text-gray-500 dark:text-gray-400'
          : 'border-gray-900 dark:border-white text-gray-900 dark:text-white hover:bg-gray-100 dark:hover:bg-white/10'
      }`}>
      {loading ? <Loader2 size={11} className="animate-spin" /> : isFollowing ? <UserCheck size={11} /> : <UserPlus size={11} />}
      <span>{isFollowing ? 'Following' : isRequested ? 'Requested' : 'Follow'}</span>
    </button>
  );
};

// ── PromoteCard — same structure as PostCard ───────────────────────────────────
const PromoteCard = ({ item, onOpenDetail }) => {
  const { userObject } = useSelector(s => s.auth);
  const currentUserId = userObject?._id || userObject?.id;

  const [isLiked, setIsLiked] = useState(item?.is_liked_by_me || false);
  const [likeCount, setLikeCount] = useState(item?.likes_count ?? (Array.isArray(item?.likes) ? item.likes.length : 0));
  const [showShareModal, setShowShareModal] = useState(false);
  const [productsOpen, setProductsOpen] = useState(true);

  const handleToggleProducts = useCallback(() => {
    setProductsOpen(prev => !prev);
  }, []);

  const id = item?._id || item?.promote_reel_id;
  const author = item?.user_id || {};
  const username = author?.username || 'User';
  const avatar = author?.avatar_url || '';
  const authorId = author?._id || author?.id || (typeof item?.user_id === 'string' ? item?.user_id : null);
  const profilePath = `/profile/${authorId}`;

  const caption = item?.caption || '';
  const commentsCount = item?.comments_count ?? item?.commentsCount ?? 0;
  const products = Array.isArray(item?.products) ? item.products : [];
  const createdAt = item?.createdAt || item?.created_at;

  useEffect(() => {
    setIsLiked(item?.is_liked_by_me || false);
    setLikeCount(item?.likes_count ?? (Array.isArray(item?.likes) ? item.likes.length : 0));
  }, [item]);

  const handleLike = async (e) => {
    e.stopPropagation();
    if (!currentUserId || !id) return;
    const wasLiked = isLiked;
    setIsLiked(!wasLiked);
    setLikeCount(c => !wasLiked ? c + 1 : Math.max(0, c - 1));
    try {
      wasLiked ? await promoteReelService.unlikePromoteReel(id) : await promoteReelService.likePromoteReel(id);
    } catch {
      setIsLiked(wasLiked);
      setLikeCount(c => wasLiked ? c + 1 : Math.max(0, c - 1));
    }
  };

  return (
    <div className="relative bg-white dark:bg-black mb-4 border-b border-gray-200 dark:border-gray-800 pb-4 md:rounded-lg md:border max-w-[470px] mx-auto">

      {/* ── Header — same as PostCard ── */}
      <div className="relative z-10 flex items-center justify-between bg-white dark:bg-black p-3">
        <div className="flex items-center gap-2.5 min-w-0">
          <Link to={profilePath} className="flex-shrink-0 w-9 h-9 rounded-full block">
            <div className="w-full h-full rounded-full bg-gray-100 dark:bg-gray-800">
              {avatar ? (
                <img src={toAbsUrl(avatar)} alt={username} className="w-full h-full rounded-full object-cover" />
              ) : (
                <div className="w-full h-full rounded-full bg-gradient-to-br from-gray-200 to-gray-300 dark:from-gray-700 dark:to-gray-800 flex items-center justify-center text-xs font-bold text-gray-600 dark:text-gray-300">
                  {username.charAt(0).toUpperCase()}
                </div>
              )}
            </div>
          </Link>

          <div className="flex flex-col min-w-0 leading-tight">
            <div className="flex items-center gap-2 flex-wrap">
              <Link to={profilePath} className="font-semibold text-sm dark:text-white hover:underline truncate">
                {username}
              </Link>
              <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-gradient-to-r from-orange-400 to-pink-500 text-white text-[9px] font-bold shrink-0">
                <Zap size={8} /> Promoted
              </span>
            </div>
            <span className="text-[11px] text-gray-400">{timeAgo(createdAt)}</span>
          </div>
        </div>

        <button className="p-1 text-gray-500 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-full transition-colors">
          <MoreHorizontal size={20} />
        </button>
      </div>

      {/* ── Media ── */}
      <CardMedia item={item} />

      {/* ── Action Bar ── */}
      <div className="px-3 pt-2">

        {/* Products toggle + panel */}
        {products.length > 0 && (
          <div className="mb-3 border-b border-gray-100 dark:border-gray-800">
            {/* Toggle row */}
            <button
              type="button"
              onClick={handleToggleProducts}
              className="flex items-center gap-2 w-full py-2"
            >
              <ShoppingBag size={13} className="text-orange-500 shrink-0" />
              <span className="text-xs font-semibold text-gray-700 dark:text-gray-300">Products</span>
              <span className="text-[10px] text-gray-400">({products.length})</span>
              <svg
                className="ml-auto text-gray-400"
                style={{ transform: productsOpen ? 'rotate(180deg)' : 'rotate(0deg)', transition: 'transform 0.3s ease' }}
                width="14" height="14" viewBox="0 0 24 24" fill="none"
                stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"
              >
                <polyline points="6 9 12 15 18 9" />
              </svg>
            </button>

            {/* Products panel — always rendered, display toggled via CSS */}
            <div
              style={{
                display: productsOpen ? 'flex' : 'none',
                gap: '12px',
                paddingBottom: '12px',
                overflowX: 'auto',
                scrollbarWidth: 'none',
                msOverflowStyle: 'none',
                WebkitOverflowScrolling: 'touch',
              }}
            >
              {products.map((p, i) => <ProductCard key={p._id || i} product={p} />)}
            </div>
          </div>
        )}

        {/* Like | Comment | Send  ···  Follow */}
        <div className="flex items-center justify-between mb-1.5">
          <div className="flex items-center gap-4">
            <button onClick={handleLike} className="active:scale-90 transition-transform group" aria-label="Like">
              <Heart size={24} className={`transition-all duration-200 group-active:scale-125 ${isLiked ? 'fill-red-500 text-red-500' : 'text-black dark:text-white'}`} />
            </button>
            <button onClick={() => onOpenDetail && onOpenDetail(item)} className="hover:opacity-60 transition-opacity" aria-label="Comment">
              <MessageCircle size={24} className="text-black dark:text-white" />
            </button>
            <button onClick={() => setShowShareModal(true)} className="hover:opacity-60 transition-opacity" aria-label="Share">
              <Send size={24} className="text-black dark:text-white" />
            </button>
          </div>
          {authorId && userObject && String(currentUserId) !== String(authorId) && (
            <FollowButton targetUserId={String(authorId)} />
          )}
        </div>

        {/* Like count */}
        {likeCount > 0 && (
          <p className="font-semibold text-sm dark:text-white mb-1">
            {fmt(likeCount)} {likeCount === 1 ? 'like' : 'likes'}
          </p>
        )}

        {/* Caption */}
        {caption && (
          <p className="text-sm text-gray-900 dark:text-white leading-snug mb-1">
            <Link to={profilePath} className="font-semibold mr-1 hover:opacity-70">{username}</Link>
            {caption}
          </p>
        )}

        {/* Comments count */}
        {commentsCount > 0 && (
          <button className="text-sm text-gray-400 dark:text-gray-500 mb-1"
            onClick={() => onOpenDetail && onOpenDetail(item)}>
            View all {commentsCount} comment{commentsCount !== 1 ? 's' : ''}
          </button>
        )}
      </div>

      <ShareContentModal isOpen={showShareModal} onClose={() => setShowShareModal(false)}
        contentType="promote_reel" contentId={id} />
    </div>
  );
};

export default PromoteCard;