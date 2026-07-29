import { useEffect, useState, useRef, useCallback, useMemo } from 'react';
import bsmartLogo from '../assets/bsmart.png';
import { X, ChevronRight, Heart, Volume2, VolumeX, Pause, Play, MoreHorizontal, ChevronLeft, Eye } from 'lucide-react';
import { useSelector } from 'react-redux';
import { useNavigate } from 'react-router-dom';
import api from '../lib/api';
import ContentReportModal from './ContentReportModal';

const getTimeAgo = (dateStr) => {
  if (!dateStr) return '';
  const diff = Math.floor((Date.now() - new Date(dateStr)) / 1000);
  if (diff < 60) return `${diff}s`;
  if (diff < 3600) return `${Math.floor(diff / 60)}m`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h`;
  return `${Math.floor(diff / 86400)}d`;
};

const fmtRemaining = (secs) => {
  if (!secs || secs < 0) return '';
  const m = Math.floor(secs / 60);
  const s = Math.floor(secs % 60);
  return m > 0 ? `${m}:${String(s).padStart(2, '0')}` : `0:${String(s).padStart(2, '0')}`;
};

const DeleteStoryModal = ({ isOpen, onClose, onConfirm, isDeleting }) => {
  if (!isOpen) return null;
  return (
    <div className="fixed inset-0 z-[120] flex items-center justify-center bg-black/60 backdrop-blur-sm p-4">
      <div className="bg-white dark:bg-gray-900 rounded-2xl p-6 w-full max-w-sm shadow-2xl">
        {isDeleting ? (
          <div className="flex flex-col items-center py-6 gap-3">
            <div className="animate-spin w-10 h-10 border-4 border-gray-200 border-t-red-500 rounded-full" />
            <p className="text-gray-500 dark:text-gray-400 font-medium">Deleting story...</p>
          </div>
        ) : (
          <>
            <h3 className="text-lg font-bold text-gray-900 dark:text-white mb-2 text-center">Delete Story?</h3>
            <p className="text-gray-500 dark:text-gray-400 text-sm mb-6 text-center">This action cannot be undone.</p>
            <div className="flex gap-3">
              <button onClick={onClose} className="flex-1 py-2.5 rounded-xl border border-gray-200 dark:border-gray-700 text-gray-700 dark:text-gray-200 text-sm font-semibold">Cancel</button>
              <button onClick={onConfirm} className="flex-1 py-2.5 rounded-xl bg-red-500 text-white text-sm font-semibold hover:bg-red-600">Delete</button>
            </div>
          </>
        )}
      </div>
    </div>
  );
};

const PeekCard = ({ story, onNavigate, side }) => {
  if (!story) return null;
  return (
    <div
      className="w-[90px] h-[160px] rounded-2xl overflow-hidden cursor-pointer flex-shrink-0 opacity-60 hover:opacity-80 transition-opacity"
      onClick={onNavigate}
      style={{ transform: side === 'left' ? 'perspective(600px) rotateY(10deg)' : 'perspective(600px) rotateY(-10deg)' }}
    >
      {story.imageUrl
        ? <img src={story.imageUrl} alt={story.username} className="w-full h-full object-cover" />
        : <div className="w-full h-full bg-gray-800 flex items-center justify-center text-xl font-bold text-white">{story.username?.charAt(0).toUpperCase()}</div>
      }
      <div className="absolute inset-x-0 bottom-0 p-2 bg-gradient-to-t from-black/80 to-transparent">
        <p className="text-white text-[9px] font-semibold truncate text-center">{story.username}</p>
      </div>
    </div>
  );
};

const StoryViewer = ({ initialStoryIndex, stories, onClose }) => {
  const [currentIndex, setCurrentIndex]           = useState(initialStoryIndex);
  const [itemsByStoryId, setItemsByStoryId]       = useState({});
  const [currentItemIndex, setCurrentItemIndex]   = useState(0);
  const [progress, setProgress]                   = useState(0);
  const [isPaused, setIsPaused]                   = useState(false);
  const [isMuted, setIsMuted]                     = useState(true);
  const [showOptions, setShowOptions]             = useState(false);
  const [showDeleteModal, setShowDeleteModal]     = useState(false);
  const [isDeletingStory, setIsDeletingStory]     = useState(false);
  const [likedItems, setLikedItems]               = useState(new Set());
  const [showReportModal, setShowReportModal]     = useState(false);
  const [timeRemaining, setTimeRemaining]         = useState(null);
  const [showViewers, setShowViewers]             = useState(false);
  const [viewersData, setViewersData]             = useState(null); // { viewers, total_views, unique_viewers }
  const [loadingViewers, setLoadingViewers]       = useState(false);
  const [mediaLoaded, setMediaLoaded]             = useState(false);
  const viewedItems                               = useRef(new Set());
  const progressRef                               = useRef(0);

  const videoRef   = useRef(null);
  const touchX     = useRef(null);
  const touchY     = useRef(null);

  const { userObject } = useSelector((state) => state.auth);
  const navigate = useNavigate();

  const currentStory  = stories[currentIndex];
  const storyId       = currentStory?.id;
  const storyItems    = useMemo(
    () => (storyId && itemsByStoryId[storyId] ? itemsByStoryId[storyId] : []),
    [storyId, itemsByStoryId]
  );
  const currentItem   = storyItems[currentItemIndex] || null;
  const totalSegments = storyItems.length > 0 ? storyItems.length : 1;
  const currentUserId = userObject?.id || userObject?._id;
  const isOwner       = !!currentStory && !!currentUserId && currentStory.userId === currentUserId;

  const prevStory = stories[currentIndex - 1] || null;
  const nextStory = stories[currentIndex + 1] || null;

  const getItemMedia = (item) => {
    if (!item?.media) return null;
    if (Array.isArray(item.media) && item.media.length > 0) return item.media[0];
    return item.media;
  };

  const media    = getItemMedia(currentItem);
  const isVideo  = media?.media_type === 'video' || media?.type === 'video';
  const videoSrc = media?.fileUrl || media?.url || null;
  const thumbSrc = media?.thumbnail || media?.thumbnails?.[0]?.fileUrl || null;
  const imageSrc = (!isVideo && (media?.url || media?.fileUrl || currentStory?.imageUrl))
    || 'https://images.unsplash.com/photo-1611162617474-5b21e879e113?w=500&auto=format&fit=crop&q=60';

  const currentItemId = currentItem?._id ?? null;
  const viewsCount    = viewersData?.total_views ?? viewersData?.unique_viewers ?? currentItem?.views_count ?? currentItem?.viewsCount ?? null;
  const storyTime     = currentItem?.createdAt || currentStory?.createdAt || null;
  const isRealStory   = !!storyId && storyId !== 'your_story';
  const showLoader    = isRealStory && (storyItems.length === 0 || !mediaLoaded);

  // ── Fetch view count per item so the bottom bar shows the correct count ───
  useEffect(() => {
    if (!isOwner || !currentItemId) return;
    api.get(`/stories/items/${currentItemId}/views`)
      .then(r => { setViewersData(r.data || null); })
      .catch(() => {});
  }, [isOwner, currentItemId]);

  // ── Refresh viewer list when the panel opens ──────────────────────────────
  useEffect(() => {
    if (!showViewers || !isOwner || !currentItemId) return;
    queueMicrotask(() => setLoadingViewers(true));
    api.get(`/stories/items/${currentItemId}/views`)
      .then(r => { setViewersData(r.data || null); })
      .catch(() => {})
      .finally(() => { setLoadingViewers(false); });
  }, [showViewers, isOwner, currentItemId]);

  // ── Fetch story items ──────────────────────────────────────────────────────
  useEffect(() => {
    const story = stories[currentIndex];
    // Defer all setCurrentItemIndex calls into a microtask to satisfy
    // the react-hooks/set-state-in-effect rule (no sync setState in effect body)
    Promise.resolve().then(() => {
      if (!story?.id || story.id === 'your_story') { setCurrentItemIndex(0); return; }
      if (itemsByStoryId[story.id]) { setCurrentItemIndex(0); return; }
      api.get(`/stories/${story.id}/items`)
        .then(r => {
          const items = Array.isArray(r.data) ? r.data : [];
          setItemsByStoryId(p => ({ ...p, [story.id]: items }));
          setCurrentItemIndex(0);
        })
        .catch(() => {});
    });
  }, [currentIndex, stories, itemsByStoryId]);

  // ── Advance helper ────────────────────────────────────────────────────────
  const advanceItem = useCallback(() => {
    if (storyItems.length > 0 && currentItemIndex < storyItems.length - 1) {
      setCurrentItemIndex(p => p + 1);
    } else if (currentIndex < stories.length - 1) {
      setCurrentIndex(p => p + 1);
      setCurrentItemIndex(0);
    } else {
      onClose();
    }
  }, [storyItems.length, currentItemIndex, currentIndex, stories.length, onClose]);

  // ── Sync video ─────────────────────────────────────────────────────────────
  useEffect(() => {
    const vid = videoRef.current;
    if (!vid) return;
    vid.muted = isMuted;
    if (isPaused) vid.pause();
    else vid.play().catch(() => {});
  }, [isPaused, isMuted, currentItemIndex, currentIndex]);

  // ── Reset progress when item changes ─────────────────────────────────────
  // queueMicrotask defers setState out of the synchronous effect body,
  // satisfying react-hooks/set-state-in-effect while still running before paint.
  useEffect(() => {
    queueMicrotask(() => {
      progressRef.current = 0;
      setProgress(0);
      setTimeRemaining(null);
      setMediaLoaded(false);
      setViewersData(null);
    });
  }, [currentIndex, currentItemIndex]);

  // ── Progress bar: image rAF, video driven by onTimeUpdate ─────────────────
  useEffect(() => {
    if (!currentStory || isVideo || isPaused || !mediaLoaded) return;
    const item      = storyItems[currentItemIndex] || null;
    const itemMedia = getItemMedia(item);
    let dur = itemMedia?.durationSec || currentStory.previewDurationSec || 5;
    if (dur <= 0) dur = 5;
    let cancelled = false;
    let start = null;
    const ms = dur * 1000;
    const step = (now) => {
      if (cancelled) return;
      if (!start) start = now - (progressRef.current / 100) * ms;
      const pct = Math.min(100, ((now - start) / ms) * 100);
      progressRef.current = pct;
      setProgress(pct);
      setTimeRemaining(Math.max(0, dur - (pct / 100) * dur));
      if (pct >= 100) { progressRef.current = 0; advanceItem(); }
      else requestAnimationFrame(step);
    };
    const id = requestAnimationFrame(step);
    return () => { cancelled = true; cancelAnimationFrame(id); };
  }, [currentStory, storyItems, currentItemIndex, isPaused, isVideo, advanceItem, mediaLoaded]);

  // ── Navigation ─────────────────────────────────────────────────────────────
  const goNext = useCallback((e) => {
    e?.stopPropagation();
    setShowOptions(false);
    setIsPaused(false);
    advanceItem();
  }, [advanceItem]);

  const goPrev = useCallback((e) => {
    e?.stopPropagation();
    setShowOptions(false);
    setIsPaused(false);
    if (storyItems.length > 0 && currentItemIndex > 0) {
      setCurrentItemIndex(p => p - 1);
    } else if (currentIndex > 0) {
      setCurrentIndex(p => p - 1);
      const prev = stories[currentIndex - 1];
      const prevItems = prev?.id && itemsByStoryId[prev.id] ? itemsByStoryId[prev.id] : [];
      setCurrentItemIndex(prevItems.length > 0 ? prevItems.length - 1 : 0);
    }
  }, [storyItems.length, currentItemIndex, currentIndex, stories, itemsByStoryId]);

  // ── Keyboard ───────────────────────────────────────────────────────────────
  useEffect(() => {
    const onKey = (e) => {
      if (e.key === 'ArrowRight' || e.key === 'ArrowDown') goNext();
      else if (e.key === 'ArrowLeft' || e.key === 'ArrowUp') goPrev();
      else if (e.key === 'Escape') { if (showViewers) setShowViewers(false); else onClose(); }
      else if (e.key === ' ') { e.preventDefault(); setIsPaused(v => !v); }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [goNext, goPrev, onClose, showViewers]);

  // ── Touch swipe ────────────────────────────────────────────────────────────
  const onTouchStart = (e) => { touchX.current = e.touches[0].clientX; touchY.current = e.touches[0].clientY; };
  const onTouchEnd = (e) => {
    if (touchX.current === null) return;
    const dx = e.changedTouches[0].clientX - touchX.current;
    const dy = e.changedTouches[0].clientY - touchY.current;
    touchX.current = null;
    if (Math.abs(dx) > Math.abs(dy) && Math.abs(dx) > 40) { dx < 0 ? goNext() : goPrev(); }
  };

  // ── Mark viewed ────────────────────────────────────────────────────────────
  useEffect(() => {
    const itemId = currentItem?._id;
    if (!itemId || viewedItems.current.has(itemId)) return;
    viewedItems.current.add(itemId);
    api.post(`/stories/items/${itemId}/view`).catch(() => {});
  }, [currentItem]);

  // ── Like ───────────────────────────────────────────────────────────────────
  const handleLike = (e) => {
    e.stopPropagation();
    const itemId = currentItem?._id;
    if (!itemId || isOwner) return;
    api.post(`/stories/items/${itemId}/like`).catch(() => {});
    setLikedItems(prev => {
      const next = new Set(prev);
      next.has(itemId) ? next.delete(itemId) : next.add(itemId);
      return next;
    });
  };

  // ── Tap left/right halves ──────────────────────────────────────────────────
  const handleCardTap = (e) => {
    const rect = e.currentTarget.getBoundingClientRect();
    const x = e.clientX - rect.left;
    if (x < rect.width * 0.35) goPrev();
    else goNext();
  };

  const cardW = 'min(390px, calc((100vh - 20px) * 9 / 16))';
  const cardH = 'min(693px, calc(100vh - 20px))';

  return (
    <div
      className="fixed inset-0 z-[100] bg-black/95 flex items-center justify-center"
      onTouchStart={onTouchStart}
      onTouchEnd={onTouchEnd}
    >
      {/* b_smart brand — top left */}
      <div className="absolute top-5 left-6 z-50 select-none pointer-events-none">
        <img src={bsmartLogo} alt="b_smart" className="h-[50px] w-auto" />
      </div>

      {/* X close — top right */}
      <button className="absolute top-5 right-5 z-50 w-9 h-9 rounded-full bg-white/10 hover:bg-white/20 flex items-center justify-center text-white transition-colors" onClick={onClose}>
        <X size={20} strokeWidth={2.5} />
      </button>

      {/* Centered wrapper */}
      <div className="relative" style={{ width: cardW, height: cardH }}>

        {/* Left nav */}
        {prevStory && (
          <div className="hidden md:flex items-center gap-2 absolute top-1/2 -translate-y-1/2 z-20" style={{ right: 'calc(100% + 12px)' }}>
            <PeekCard story={prevStory} side="left" onNavigate={() => { setCurrentIndex(p => p - 1); setCurrentItemIndex(0); }} />
            <button onClick={goPrev} className="w-9 h-9 rounded-full bg-white/15 hover:bg-white text-white hover:text-black flex items-center justify-center transition-all shadow-lg">
              <ChevronLeft size={18} />
            </button>
          </div>
        )}

        {/* Right nav */}
        {currentIndex < stories.length - 1 && (
          <div className="hidden md:flex items-center gap-2 absolute top-1/2 -translate-y-1/2 z-20" style={{ left: 'calc(100% + 12px)' }}>
            <button onClick={goNext} className="w-9 h-9 rounded-full bg-white/15 hover:bg-white text-white hover:text-black flex items-center justify-center transition-all shadow-lg">
              <ChevronRight size={18} />
            </button>
            <PeekCard story={nextStory} side="right" onNavigate={() => { setCurrentIndex(p => p + 1); setCurrentItemIndex(0); }} />
          </div>
        )}

        {/* ── Story card ── */}
        <div
          className="relative w-full h-full bg-black overflow-hidden select-none"
          style={{ borderRadius: window.innerWidth >= 768 ? '20px' : '0' }}
          onClick={handleCardTap}
        >
          {/* ── Progress bars ── */}
          <div className="absolute top-3 left-3 right-3 flex gap-[3px] z-30 pointer-events-none">
            {Array.from({ length: totalSegments }).map((_, i) => (
              <div key={i} className="flex-1 h-[2px] rounded-full bg-white/30 overflow-hidden">
                <div
                  className="h-full bg-white rounded-full"
                  style={{ width: i < currentItemIndex ? '100%' : i === currentItemIndex ? `${progress}%` : '0%', transition: 'none' }}
                />
              </div>
            ))}
          </div>

          {/* ── Header bar ── */}
          <div className="absolute top-6 left-3 right-3 z-30 flex items-center justify-between pointer-events-none">
            {/* Left: avatar + info */}
            <button
              className="flex items-center gap-2.5 min-w-0 pointer-events-auto"
              onClick={(e) => { e.stopPropagation(); onClose(); navigate(currentStory?.userId ? `/profile/${currentStory.userId}` : '/profile'); }}
            >
              {/* Avatar — no ring */}
              <div className="w-9 h-9 rounded-full overflow-hidden bg-[#3a3a3c] flex-shrink-0 flex items-center justify-center">
                {currentStory?.avatarUrl
                  ? <img src={currentStory.avatarUrl} alt={currentStory.username} className="w-full h-full object-cover" />
                  : <span className="text-xs font-bold text-white">{currentStory?.username?.charAt(0).toUpperCase()}</span>
                }
              </div>
              <div className="flex flex-col leading-tight min-w-0">
                <span className="text-white font-semibold text-[13px] drop-shadow truncate">{currentStory?.username}</span>
                {storyTime && (
                  <span className="text-white/55 text-[11px]">{getTimeAgo(storyTime)}</span>
                )}
              </div>
            </button>

            {/* Right: time remaining + controls */}
            <div className="flex items-center gap-2.5 pointer-events-auto">
              {/* Time remaining badge */}
              {timeRemaining !== null && timeRemaining > 0 && (
                <span className="text-white/70 text-[11px] font-medium tabular-nums">{fmtRemaining(timeRemaining)}</span>
              )}
              {isVideo && (
                <button onClick={(e) => { e.stopPropagation(); setIsMuted(v => !v); }} className="text-white hover:opacity-75 transition-opacity drop-shadow">
                  {isMuted ? <VolumeX size={18} /> : <Volume2 size={18} />}
                </button>
              )}
              <button onClick={(e) => { e.stopPropagation(); setIsPaused(v => !v); }} className="text-white hover:opacity-75 transition-opacity drop-shadow">
                {isPaused ? <Play size={18} /> : <Pause size={18} />}
              </button>
              <div className="relative">
                <button
                  onClick={(e) => {
                    e.stopPropagation();
                    if (isOwner) { setShowOptions(v => !v); return; }
                    if (currentItem?._id) setShowReportModal(true);
                  }}
                  className="text-white hover:opacity-75 transition-opacity drop-shadow"
                >
                  <MoreHorizontal size={20} />
                </button>
                {showOptions && isOwner && storyItems.length > 0 && (
                  <div className="absolute right-0 mt-2 w-36 bg-white dark:bg-gray-900 rounded-xl shadow-xl py-1 z-50 overflow-hidden">
                    <button
                      onClick={(e) => { e.stopPropagation(); setShowOptions(false); setShowDeleteModal(true); }}
                      disabled={isDeletingStory}
                      className="w-full text-left px-4 py-2.5 text-sm text-red-500 hover:bg-red-50 dark:hover:bg-red-900/20 font-medium"
                    >
                      {isDeletingStory ? 'Deleting…' : 'Delete story'}
                    </button>
                  </div>
                )}
              </div>
            </div>
          </div>

          {/* ── Media ── */}
          {isVideo && videoSrc ? (
            <video
              ref={videoRef}
              key={videoSrc}
              src={videoSrc}
              className="absolute inset-0 w-full h-full object-cover"
              playsInline muted={isMuted} autoPlay
              poster={thumbSrc || undefined}
              onTimeUpdate={(e) => {
                const vid = e.currentTarget;
                if (!vid.duration) return;
                const pct = (vid.currentTime / vid.duration) * 100;
                setProgress(pct);
                setTimeRemaining(vid.duration - vid.currentTime);
              }}
              onCanPlay={() => setMediaLoaded(true)}
              onError={() => setMediaLoaded(true)}
              onEnded={advanceItem}
              onClick={(e) => { e.stopPropagation(); setIsPaused(v => !v); }}
            />
          ) : (
            <img
              src={imageSrc}
              alt="Story"
              className="absolute inset-0 w-full h-full object-cover"
              onLoad={() => setMediaLoaded(true)}
              onError={() => setMediaLoaded(true)}
            />
          )}

          {/* Top gradient overlay */}
          <div className="absolute inset-x-0 top-0 h-32 bg-gradient-to-b from-black/60 to-transparent pointer-events-none z-10" />

          {/* Bottom gradient overlay */}
          <div className="absolute inset-x-0 bottom-0 h-28 bg-gradient-to-t from-black/70 to-transparent pointer-events-none z-10" />

          {/* Loading overlay — shown until items fetched + media ready */}
          {showLoader && (
            <div className="absolute inset-0 z-40 bg-black flex items-center justify-center">
              <div className="w-9 h-9 rounded-full border-[3px] border-white/15 border-t-white/80 animate-spin" />
            </div>
          )}

          {/* Paused overlay */}
          {isPaused && (
            <div className="absolute inset-0 flex items-center justify-center z-20 pointer-events-none">
              <div className="w-14 h-14 rounded-full bg-black/40 flex items-center justify-center">
                <Pause size={26} className="text-white" />
              </div>
            </div>
          )}

          {/* ── Bottom bar ── */}
          <div className="absolute bottom-0 left-0 right-0 z-30 px-4 pb-5" onClick={(e) => e.stopPropagation()}>
            {isOwner ? (
              /* Owner: clickable "Seen by X" → opens viewers panel */
              <button
                className="flex items-center gap-2 hover:opacity-80 active:scale-95 transition-all"
                onClick={() => setShowViewers(true)}
              >
                <Eye size={16} className="text-white/70" />
                {loadingViewers ? (
                  <span className="text-white/50 text-xs">Loading…</span>
                ) : viewsCount !== null && viewsCount > 0 ? (
                  <span className="text-white text-sm font-medium">Seen by {viewsCount}</span>
                ) : (
                  <span className="text-white/50 text-xs">No views yet</span>
                )}
              </button>
            ) : (
              /* Viewer: like button */
              <div className="flex justify-end">
                <button onClick={handleLike} className="p-1.5 hover:scale-110 active:scale-95 transition-transform">
                  <Heart
                    size={26}
                    className={likedItems.has(currentItem?._id) ? 'fill-red-500 stroke-red-500' : 'text-white drop-shadow'}
                  />
                </button>
              </div>
            )}
          </div>

        </div>
      </div>

      {/* ── Viewers centered modal ── */}
      {showViewers && (
        <div
          className="absolute inset-0 z-[110] flex items-center justify-center"
          onClick={() => setShowViewers(false)}
          onTouchStart={(e) => e.stopPropagation()}
          onTouchEnd={(e) => e.stopPropagation()}
        >
          {/* scrim */}
          <div className="absolute inset-0 bg-black/60" />

          {/* Modal */}
          <div
            className="relative z-10 bg-[#1c1c1e] rounded-2xl w-[90%] max-w-sm flex flex-col shadow-2xl overflow-hidden"
            style={{ maxHeight: '70vh', animation: 'fadeScaleIn 0.22s cubic-bezier(0.32,0.72,0,1) forwards' }}
            onClick={(e) => e.stopPropagation()}
          >
            {/* Header */}
            <div className="flex items-center px-4 pt-4 pb-3 shrink-0">
              <button
                onClick={(e) => { e.stopPropagation(); setShowViewers(false); }}
                className="w-8 h-8 flex items-center justify-center rounded-full text-white hover:bg-white/10 transition-colors shrink-0"
              >
                <X size={20} strokeWidth={2.5} />
              </button>
              <span className="flex-1 text-center text-white font-semibold text-base" style={{ marginLeft: '-32px' }}>Viewers</span>
            </div>

            {/* Divider */}
            <div className="h-px bg-white/10 shrink-0" />

            {/* List */}
            <div className="flex-1 overflow-y-auto py-1">
              {loadingViewers && !viewersData?.viewers?.length && (
                <div className="flex justify-center py-12">
                  <div className="w-7 h-7 rounded-full border-[3px] border-white/20 border-t-white animate-spin" />
                </div>
              )}

              {!loadingViewers && !viewersData?.viewers?.length && (
                <div className="flex flex-col items-center justify-center py-12 gap-2 text-white/40">
                  <Eye size={30} />
                  <span className="text-sm">No viewers yet</span>
                </div>
              )}

              {!loadingViewers && viewersData?.viewers?.map((entry, i) => {
                const v        = entry.viewer || {};
                const username = v.username  || 'User';
                const fullName = v.full_name || v.fullName || null;
                const avatar   = v.avatar_url || null;
                return (
                  <div
                    key={v._id || i}
                    className="flex items-center gap-3 px-4 py-3 hover:bg-white/[0.04] transition-colors"
                  >
                    {/* Avatar — no ring, solid fallback */}
                    <div className="w-11 h-11 rounded-full overflow-hidden bg-[#3a3a3c] shrink-0 flex items-center justify-center">
                      {avatar
                        ? <img src={avatar} alt={username} className="w-full h-full object-cover" />
                        : <span className="text-white font-bold text-base">{username[0]?.toUpperCase()}</span>
                      }
                    </div>

                    {/* Text */}
                    <div className="min-w-0 flex-1">
                      <p className="text-white text-[15px] font-semibold leading-tight truncate">{username}</p>
                      {fullName && (
                        <p className="text-white/55 text-[13px] leading-tight truncate mt-0.5">{fullName}</p>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      )}

      <DeleteStoryModal
        isOpen={showDeleteModal}
        onClose={() => { if (!isDeletingStory) setShowDeleteModal(false); }}
        onConfirm={async () => {
          if (!isOwner || !storyId) return;
          try {
            setIsDeletingStory(true);
            const token = localStorage.getItem('token');
            await api.delete(`/stories/${storyId}`, { headers: token ? { Authorization: `Bearer ${token}` } : {} });
            setShowDeleteModal(false);
            onClose();
            window.location.reload();
          } catch { setIsDeletingStory(false); }
        }}
        isDeleting={isDeletingStory}
      />
      <ContentReportModal
        isOpen={showReportModal}
        onClose={() => setShowReportModal(false)}
        contentType="story"
        contentId={currentItem?._id}
        ownerUsername={currentStory?.username || ''}
        contentUrl={window.location.href}
      />

      <style>{`
        @keyframes fadeScaleIn {
          from { opacity: 0; transform: scale(0.93); }
          to   { opacity: 1; transform: scale(1); }
        }
      `}</style>
    </div>
  );
};

export default StoryViewer;
