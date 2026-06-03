import React, { useEffect, useState, useRef, useCallback } from 'react';
import { X, ChevronRight, Heart, Volume2, VolumeX, Pause, Play, MoreHorizontal, ChevronLeft } from 'lucide-react';
import { useSelector } from 'react-redux';
import { useNavigate } from 'react-router-dom';
import api from '../lib/api';
import ContentReportModal from './ContentReportModal';

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

// ── Small preview card used for side stories ───────────────────────────────────
const SideStoryCard = ({ story, onClick }) => {
  if (!story) return null;
  return (
    <div
      className="relative cursor-pointer select-none flex-shrink-0 rounded-2xl overflow-hidden bg-gray-900"
      style={{ width: 'clamp(90px, 10vw, 130px)', aspectRatio: '9/16', opacity: 0.65 }}
      onClick={onClick}
    >
      {story.imageUrl ? (
        <img src={story.imageUrl} alt={story.username} className="w-full h-full object-cover" />
      ) : (
        <div className="w-full h-full bg-gradient-to-br from-gray-700 to-gray-900 flex items-center justify-center text-2xl font-bold text-white">
          {story.username?.charAt(0).toUpperCase()}
        </div>
      )}
      <div className="absolute bottom-0 left-0 right-0 p-2.5 bg-gradient-to-t from-black/80 to-transparent">
        <div className="flex items-center gap-1.5">
          <div className="w-5 h-5 rounded-full bg-gray-700 overflow-hidden flex-shrink-0">
            {story.avatarUrl
              ? <img src={story.avatarUrl} alt={story.username} className="w-full h-full object-cover" />
              : <div className="w-full h-full flex items-center justify-center text-[7px] font-bold text-white bg-gray-600">{story.username?.charAt(0).toUpperCase()}</div>
            }
          </div>
          <span className="text-white text-[10px] font-semibold truncate">{story.username}</span>
        </div>
      </div>
    </div>
  );
};

const PeekCard = ({ story, onNavigate }) => {
  if (!story) return null;
  return (
    <div
      className="w-[90px] h-[160px] rounded-2xl overflow-hidden cursor-pointer flex-shrink-0"
      onClick={onNavigate}
    >
      {story.imageUrl
        ? <img src={story.imageUrl} alt={story.username} className="w-full h-full object-cover" />
        : <div className="w-full h-full bg-gray-800 flex items-center justify-center text-xl font-bold text-white">{story.username?.charAt(0).toUpperCase()}</div>
      }
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
  const viewedItems                               = useRef(new Set());
  const progressRef                               = useRef(0);

  const videoRef   = useRef(null);
  const touchX     = useRef(null);
  const touchY     = useRef(null);

  const { userObject } = useSelector((state) => state.auth);
  const navigate = useNavigate();

  const currentStory  = stories[currentIndex];
  const storyId       = currentStory?.id;
  const storyItems    = storyId && itemsByStoryId[storyId] ? itemsByStoryId[storyId] : [];
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

  // ── Fetch story items ─────────────────────────────────────────────────────
  useEffect(() => {
    const story = stories[currentIndex];
    if (!story?.id || story.id === 'your_story') {
      setCurrentItemIndex(0);
      return;
    }
    if (itemsByStoryId[story.id]) {
      setCurrentItemIndex(0);
      return;
    }
    api.get(`/stories/${story.id}/items`)
      .then(r => {
        const items = Array.isArray(r.data) ? r.data : [];
        setItemsByStoryId(p => ({ ...p, [story.id]: items }));
        setCurrentItemIndex(0);
      })
      .catch(err => console.error('Error fetching story items:', err));
  }, [currentIndex, stories]);

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

  // ── Sync video play/pause/mute ────────────────────────────────────────────
  useEffect(() => {
    const vid = videoRef.current;
    if (!vid) return;
    vid.muted = isMuted;
    if (isPaused) vid.pause();
    else vid.play().catch(() => {});
  }, [isPaused, isMuted, currentItemIndex, currentIndex]);

  // ── Reset progress when item changes (not on pause/unpause) ─────────────
  useEffect(() => {
    progressRef.current = 0;
    setProgress(0);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [currentIndex, currentItemIndex]);

  // ── Progress bar: image = rAF timer, video = driven by onTimeUpdate ───────
  useEffect(() => {
    if (!currentStory || isVideo || isPaused) return;

    const item      = storyItems[currentItemIndex] || null;
    const itemMedia = getItemMedia(item);
    let dur = itemMedia?.durationSec || currentStory.previewDurationSec || 5;
    if (dur <= 0) dur = 5;

    let cancelled = false;
    let start = null;
    const ms = dur * 1000;

    const step = (now) => {
      if (cancelled) return;
      // offset start so animation resumes from saved position
      if (!start) start = now - (progressRef.current / 100) * ms;
      const pct = Math.min(100, ((now - start) / ms) * 100);
      progressRef.current = pct;
      setProgress(pct);
      if (pct >= 100) { progressRef.current = 0; advanceItem(); }
      else requestAnimationFrame(step);
    };
    const id = requestAnimationFrame(step);
    return () => { cancelled = true; cancelAnimationFrame(id); };
  }, [currentStory, storyItems, currentItemIndex, isPaused, isVideo, advanceItem]);

  // ── Navigation ────────────────────────────────────────────────────────────
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

  // ── Keyboard ──────────────────────────────────────────────────────────────
  useEffect(() => {
    const onKey = (e) => {
      if (e.key === 'ArrowRight' || e.key === 'ArrowDown') goNext();
      else if (e.key === 'ArrowLeft' || e.key === 'ArrowUp') goPrev();
      else if (e.key === 'Escape') onClose();
      else if (e.key === ' ') { e.preventDefault(); setIsPaused(v => !v); }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [goNext, goPrev, onClose]);

  // ── Touch swipe (mobile) ──────────────────────────────────────────────────
  const onTouchStart = (e) => {
    touchX.current = e.touches[0].clientX;
    touchY.current = e.touches[0].clientY;
  };
  const onTouchEnd = (e) => {
    if (touchX.current === null) return;
    const dx = e.changedTouches[0].clientX - touchX.current;
    const dy = e.changedTouches[0].clientY - touchY.current;
    touchX.current = null;
    if (Math.abs(dx) > Math.abs(dy) && Math.abs(dx) > 40) {
      dx < 0 ? goNext() : goPrev();
    }
  };

  // ── Mark item as viewed ───────────────────────────────────────────────────
  useEffect(() => {
    const itemId = currentItem?._id;
    if (!itemId || viewedItems.current.has(itemId)) return;
    viewedItems.current.add(itemId);
    api.post(`/stories/items/${itemId}/view`).catch(() => {});
  }, [currentItem]);

  // ── Like / unlike item ────────────────────────────────────────────────────
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

  // ── Tap left/right halves of card ─────────────────────────────────────────
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
      className="fixed inset-0 z-[100] bg-black flex items-center justify-center"
      onTouchStart={onTouchStart}
      onTouchEnd={onTouchEnd}
    >
      {/* Bsmart branding — top left */}
      <div className="absolute top-5 left-6 z-50 select-none pointer-events-none">
        <span className="text-3xl font-normal italic text-[#bc1888]" style={{ fontFamily: 'cursive' }}>b_smart</span>
      </div>

      {/* X close — top right */}
      <button
        className="absolute top-5 right-5 z-50 text-white hover:opacity-70 transition-opacity"
        onClick={onClose}
      >
        <X size={28} strokeWidth={2} />
      </button>

      {/* Wrapper matches card size — nav buttons hang outside via absolute */}
      <div className="relative" style={{ width: cardW, height: cardH }}>

        {/* Left nav — only shown when a previous story exists */}
        {prevStory && (
          <div
            className="hidden md:flex group items-center absolute top-1/2 -translate-y-1/2 z-20"
            style={{ right: 'calc(100% + 14px)' }}
          >
            <div className="overflow-hidden transition-all duration-300 max-w-0 opacity-0 group-hover:max-w-[90px] group-hover:opacity-65">
              <PeekCard
                story={prevStory}
                onNavigate={() => { setCurrentIndex(p => p - 1); setCurrentItemIndex(0); }}
              />
            </div>
            <button
              onClick={goPrev}
              className="ml-2 w-10 h-10 rounded-full bg-white/15 hover:bg-white text-white hover:text-black flex items-center justify-center transition-all duration-200 shadow-lg flex-shrink-0"
            >
              <ChevronLeft size={20} />
            </button>
          </div>
        )}

        {/* Right nav — only shown when a next story exists */}
        {currentIndex < stories.length - 1 && (
          <div
            className="hidden md:flex group items-center absolute top-1/2 -translate-y-1/2 z-20"
            style={{ left: 'calc(100% + 14px)' }}
          >
            <button
              onClick={goNext}
              className="mr-2 w-10 h-10 rounded-full bg-white/15 hover:bg-white text-white hover:text-black flex items-center justify-center transition-all duration-200 shadow-lg flex-shrink-0"
            >
              <ChevronRight size={20} />
            </button>
            <div className="overflow-hidden transition-all duration-300 max-w-0 opacity-0 group-hover:max-w-[90px] group-hover:opacity-65">
              <PeekCard
                story={nextStory}
                onNavigate={() => { setCurrentIndex(p => p + 1); setCurrentItemIndex(0); }}
              />
            </div>
          </div>
        )}

        {/* Story card — fills the wrapper */}
        <div
          className="relative w-full h-full bg-black overflow-hidden select-none"
          style={{ borderRadius: window.innerWidth >= 768 ? '18px' : '0' }}
          onClick={handleCardTap}
        >
          {/* Progress bars */}
          <div className="absolute top-3 left-3 right-3 flex gap-[3px] z-30 pointer-events-none">
            {Array.from({ length: totalSegments }).map((_, i) => (
              <div key={i} className="flex-1 h-[2.5px] rounded-full bg-white/30 overflow-hidden">
                <div
                  className="h-full bg-white rounded-full"
                  style={{
                    width: i < currentItemIndex ? '100%' : i === currentItemIndex ? `${progress}%` : '0%',
                    transition: i === currentItemIndex ? 'none' : undefined,
                  }}
                />
              </div>
            ))}
          </div>

          {/* Top bar */}
          <div className="absolute top-7 left-3 right-3 flex items-center justify-between z-30 pointer-events-none">
            <button
              className="flex items-center gap-2.5 pointer-events-auto"
              onClick={(e) => {
                e.stopPropagation();
                onClose();
                navigate(currentStory?.userId ? `/profile/${currentStory.userId}` : '/profile');
              }}
            >
              <div className="w-9 h-9 rounded-full ring-2 ring-white/30 overflow-hidden flex-shrink-0">
                {currentStory?.avatarUrl
                  ? <img src={currentStory.avatarUrl} alt={currentStory.username} className="w-full h-full object-cover" />
                  : <div className="w-full h-full flex items-center justify-center text-xs font-bold text-white bg-gradient-to-tr from-orange-400 to-pink-500">{currentStory?.username?.charAt(0).toUpperCase()}</div>
                }
              </div>
              <div className="flex items-center gap-2">
                <span className="text-white font-semibold text-sm drop-shadow">{currentStory?.username}</span>
                <span className="text-white/55 text-xs">2h</span>
              </div>
            </button>

            <div className="flex items-center gap-3 pointer-events-auto">
              {isVideo && (
                <button onClick={(e) => { e.stopPropagation(); setIsMuted(v => !v); }}
                  className="text-white hover:opacity-75 transition-opacity drop-shadow">
                  {isMuted ? <VolumeX size={19} /> : <Volume2 size={19} />}
                </button>
              )}
              <button onClick={(e) => { e.stopPropagation(); setIsPaused(v => !v); }}
                className="text-white hover:opacity-75 transition-opacity drop-shadow">
                {isPaused ? <Play size={19} /> : <Pause size={19} />}
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
                  <MoreHorizontal size={21} />
                </button>
                {showOptions && isOwner && storyItems.length > 0 && (
                  <div className="absolute right-0 mt-2 w-32 bg-white dark:bg-gray-900 rounded-xl shadow-xl py-1 z-50">
                    <button
                      onClick={(e) => { e.stopPropagation(); setShowOptions(false); setShowDeleteModal(true); }}
                      disabled={isDeletingStory}
                      className="w-full text-left px-3 py-2 text-xs text-red-500 hover:bg-red-50 dark:hover:bg-red-900/20 disabled:opacity-60"
                    >
                      {isDeletingStory ? 'Deleting…' : 'Delete story'}
                    </button>
                  </div>
                )}
              </div>
            </div>
          </div>

          {/* Media */}
          {isVideo && videoSrc ? (
            <video
              ref={videoRef}
              key={videoSrc}
              src={videoSrc}
              className="absolute inset-0 w-full h-full object-cover"
              playsInline
              muted={isMuted}
              autoPlay
              poster={thumbSrc || undefined}
              onTimeUpdate={(e) => {
                const vid = e.currentTarget;
                if (!vid.duration) return;
                setProgress((vid.currentTime / vid.duration) * 100);
              }}
              onEnded={advanceItem}
              onClick={(e) => { e.stopPropagation(); setIsPaused(v => !v); }}
            />
          ) : (
            <img src={imageSrc} alt="Story" className="absolute inset-0 w-full h-full object-cover" />
          )}

          {/* Paused overlay */}
          {isPaused && (
            <div className="absolute inset-0 flex items-center justify-center z-20 pointer-events-none">
              <div className="w-14 h-14 rounded-full bg-black/40 flex items-center justify-center">
                <Pause size={26} className="text-white" />
              </div>
            </div>
          )}

          {/* Like button */}
          {!isOwner && (
            <div
              className="absolute bottom-0 left-0 right-0 pb-7 pr-4 flex items-end justify-end z-30"
              onClick={(e) => e.stopPropagation()}
            >
              <button onClick={handleLike} className="p-1 hover:scale-110 active:scale-95 transition-transform">
                <Heart
                  size={26}
                  className={likedItems.has(currentItem?._id) ? 'fill-red-500 stroke-red-500' : 'text-white'}
                />
              </button>
            </div>
          )}
        </div>
      </div>

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
          } catch (err) {
            console.error('Error deleting story:', err);
            setIsDeletingStory(false);
          }
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
    </div>
  );
};

export default StoryViewer;
