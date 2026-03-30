import React, { useEffect, useState, useRef, useCallback } from 'react';
import { X, ChevronLeft, ChevronRight, Heart, Send, Volume2, VolumeX, Pause, Play, MoreHorizontal } from 'lucide-react';
import { useSelector } from 'react-redux';
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
const SideStoryCard = ({ story, side, onClick }) => {
  if (!story) return <div className="w-[120px] md:w-[160px]" />;
  return (
    <div
      className="relative cursor-pointer select-none"
      style={{ width: 'clamp(100px, 14vw, 160px)' }}
      onClick={onClick}
    >
      {/* card */}
      <div className="relative rounded-2xl overflow-hidden bg-gray-900 shadow-2xl"
        style={{ aspectRatio: '9/16', opacity: 0.6 }}>
        {story.imageUrl ? (
          <img src={story.imageUrl} alt={story.username} className="w-full h-full object-cover" />
        ) : (
          <div className="w-full h-full bg-gradient-to-br from-gray-700 to-gray-900 flex items-center justify-center text-2xl font-bold text-white">
            {story.username?.charAt(0).toUpperCase()}
          </div>
        )}
        {/* bottom user info */}
        <div className="absolute bottom-0 left-0 right-0 p-3 bg-gradient-to-t from-black/80 to-transparent">
          <div className="flex items-center gap-1.5 mb-1">
            <div className="w-6 h-6 rounded-full bg-gradient-to-tr from-yellow-400 via-orange-500 to-pink-600 p-[1.5px] flex-shrink-0">
              <div className="w-full h-full rounded-full bg-black overflow-hidden">
                {story.avatarUrl
                  ? <img src={story.avatarUrl} alt={story.username} className="w-full h-full object-cover" />
                  : <div className="w-full h-full flex items-center justify-center text-[8px] font-bold text-white bg-gradient-to-br from-orange-400 to-pink-600">{story.username?.charAt(0).toUpperCase()}</div>
                }
              </div>
            </div>
            <span className="text-white text-[10px] font-semibold truncate">{story.username}</span>
          </div>
          <div className="flex items-center justify-between">
            <span className="text-white/60 text-[9px]">Tap to view</span>
            {side === 'right'
              ? <ChevronRight size={14} className="text-white/80" />
              : <ChevronLeft size={14} className="text-white/80" />
            }
          </div>
        </div>
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
  const [replyText, setReplyText]                 = useState('');
  const [showReportModal, setShowReportModal]     = useState(false);

  const videoRef   = useRef(null);
  const touchX     = useRef(null);
  const touchY     = useRef(null);

  const { userObject } = useSelector((state) => state.auth);

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

  // ── Progress bar: image = rAF timer, video = driven by onTimeUpdate ───────
  useEffect(() => {
    setProgress(0);
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
      if (!start) start = now;
      const pct = Math.min(100, ((now - start) / ms) * 100);
      setProgress(pct);
      if (pct >= 100) advanceItem();
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

  // ── Tap left/right halves of card ─────────────────────────────────────────
  const handleCardTap = (e) => {
    const rect = e.currentTarget.getBoundingClientRect();
    const x = e.clientX - rect.left;
    if (x < rect.width * 0.35) goPrev();
    else goNext();
  };

  return (
    <div
      className="fixed inset-0 z-[100] bg-black flex items-center justify-center"
      onTouchStart={onTouchStart}
      onTouchEnd={onTouchEnd}
    >
      {/* ── Side story previews (desktop only) ── */}
      <div className="hidden md:flex absolute left-0 top-1/2 -translate-y-1/2 pl-4 lg:pl-10 z-10 items-center">
        {prevStory && (
          <SideStoryCard
            story={prevStory}
            side="left"
            onClick={() => { setCurrentIndex(p => p - 1); setCurrentItemIndex(0); }}
          />
        )}
      </div>
      <div className="hidden md:flex absolute right-0 top-1/2 -translate-y-1/2 pr-4 lg:pr-10 z-10 items-center">
        {nextStory && (
          <SideStoryCard
            story={nextStory}
            side="right"
            onClick={() => { setCurrentIndex(p => p + 1); setCurrentItemIndex(0); }}
          />
        )}
      </div>

      {/* ── Main story card ── */}
      <div
        className="relative bg-black overflow-hidden select-none"
        style={{
          width: 'min(100vw, 430px)',
          height: 'min(100vh, calc(430px * 16/9))',
          maxHeight: '100vh',
          borderRadius: window.innerWidth >= 768 ? '16px' : '0',
        }}
        onClick={handleCardTap}
      >
        {/* ── Progress bars ── */}
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

        {/* ── Top bar: avatar + username + time + controls ── */}
        <div className="absolute top-7 left-3 right-3 flex items-center justify-between z-30 pointer-events-none">
          {/* Left: avatar + username + time */}
          <div className="flex items-center gap-2.5 pointer-events-auto">
            <div className="w-9 h-9 rounded-full bg-gradient-to-tr from-yellow-400 via-orange-500 to-pink-600 p-[1.5px] flex-shrink-0">
              <div className="w-full h-full rounded-full bg-black overflow-hidden">
                {currentStory?.avatarUrl
                  ? <img src={currentStory.avatarUrl} alt={currentStory.username} className="w-full h-full object-cover" />
                  : <div className="w-full h-full flex items-center justify-center text-xs font-bold text-white bg-gradient-to-tr from-orange-400 to-pink-500">{currentStory?.username?.charAt(0).toUpperCase()}</div>
                }
              </div>
            </div>
            <div className="flex items-center gap-2">
              <span className="text-white font-semibold text-sm drop-shadow">{currentStory?.username}</span>
              <span className="text-white/60 text-xs">2h</span>
            </div>
          </div>

          {/* Right: mute + pause + options + close */}
          <div className="flex items-center gap-3 pointer-events-auto">
            {isVideo && (
              <button onClick={(e) => { e.stopPropagation(); setIsMuted(v => !v); }}
                className="text-white hover:opacity-80 transition-opacity drop-shadow">
                {isMuted ? <VolumeX size={20} /> : <Volume2 size={20} />}
              </button>
            )}
            <button onClick={(e) => { e.stopPropagation(); setIsPaused(v => !v); }}
              className="text-white hover:opacity-80 transition-opacity drop-shadow">
              {isPaused ? <Play size={20} /> : <Pause size={20} />}
            </button>
            <div className="relative">
              <button
                onClick={(e) => {
                  e.stopPropagation();
                  if (isOwner) {
                    setShowOptions(v => !v);
                    return;
                  }
                  if (currentItem?._id) setShowReportModal(true);
                }}
                className="text-white hover:opacity-80 transition-opacity drop-shadow"
              >
                <MoreHorizontal size={22} />
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
            <button onClick={(e) => { e.stopPropagation(); onClose(); }}
              className="text-white hover:opacity-80 transition-opacity drop-shadow">
              <X size={26} strokeWidth={2.5} />
            </button>
          </div>
        </div>

        {/* ── Media ── */}
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
          <img
            src={imageSrc}
            alt="Story"
            className="absolute inset-0 w-full h-full object-cover"
          />
        )}

        {/* Paused overlay */}
        {isPaused && (
          <div className="absolute inset-0 flex items-center justify-center z-20 pointer-events-none">
            <div className="w-16 h-16 rounded-full bg-black/40 flex items-center justify-center">
              <Pause size={28} className="text-white" />
            </div>
          </div>
        )}

        {/* ── Bottom reply bar ── */}
        <div className="absolute bottom-0 left-0 right-0 p-4 pb-6 bg-gradient-to-t from-black/60 to-transparent flex items-center gap-3 z-30"
          onClick={(e) => e.stopPropagation()}>
          <input
            type="text"
            value={replyText}
            onChange={(e) => setReplyText(e.target.value)}
            placeholder={`Reply to ${currentStory?.username}…`}
            className="flex-1 bg-transparent border border-white/40 rounded-full px-4 py-2.5 text-white placeholder-white/60 focus:outline-none focus:border-white/70 text-sm"
          />
          <button className="text-white p-1 hover:scale-110 active:scale-95 transition-transform">
            <Heart size={26} />
          </button>
          <button className="text-white p-1 hover:scale-110 active:scale-95 transition-transform">
            <Send size={24} />
          </button>
        </div>

        {/* ── Prev / Next tap zones (invisible, only for desktop arrow nav) ── */}
        {/* Desktop prev arrow */}
        <button
          className="hidden md:flex absolute left-3 top-1/2 -translate-y-1/2 z-30 w-8 h-8 rounded-full bg-white/20 hover:bg-white/30 items-center justify-center transition-colors"
          onClick={(e) => { e.stopPropagation(); goPrev(e); }}
        >
          <ChevronLeft size={18} className="text-white" />
        </button>
        <button
          className="hidden md:flex absolute right-3 top-1/2 -translate-y-1/2 z-30 w-8 h-8 rounded-full bg-white/20 hover:bg-white/30 items-center justify-center transition-colors"
          onClick={(e) => { e.stopPropagation(); goNext(e); }}
        >
          <ChevronRight size={18} className="text-white" />
        </button>
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
