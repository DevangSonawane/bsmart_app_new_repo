import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Check, ChevronLeft, ChevronRight, Loader2, MoreHorizontal, Pencil, Plus, Trash2, X } from 'lucide-react';
import { useSelector } from 'react-redux';
import api from '../lib/api';

const getUserId = (user) => user?._id || user?.id || '';
const getUserName = (user) => user?.username || user?.full_name || user?.name || 'User';
const getUserAvatar = (user) => user?.avatar_url || user?.profilePicture || user?.profile_picture || '';
const isHighlightOwner = (highlight, currentUserId) => String(highlight?.user_id || '') === String(currentUserId || '');
const getMedia = (item) => (Array.isArray(item?.media) ? item.media[0] : item?.media) || null;
const formatAgo = (dateValue) => {
  if (!dateValue) return '';
  const diff = Date.now() - new Date(dateValue).getTime();
  const mins = Math.max(1, Math.floor(diff / 60000));
  if (mins < 60) return `${mins}m`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 24) return `${hrs}h`;
  const days = Math.floor(hrs / 24);
  if (days < 7) return `${days}d`;
  return new Date(dateValue).toLocaleDateString('en-IN', { day: 'numeric', month: 'short' });
};

const CircleImage = ({ src, alt, fallback }) => (
  src
    ? <img src={src} alt={alt} className="h-full w-full rounded-full object-cover" />
    : (
      <div className="flex h-full w-full items-center justify-center rounded-full bg-gradient-to-br from-[#f59e0b] via-[#ef4444] to-[#8b5cf6] text-sm font-bold text-white">
        {(fallback || 'U').trim().charAt(0).toUpperCase()}
      </div>
    )
);

const getCover = (highlight) => {
  if (highlight?.cover_url) return highlight.cover_url;
  const media = getMedia(highlight?.items?.[0]);
  return media?.thumbnail || media?.url || '';
};

const getPreviewUrl = (item) => {
  const media = getMedia(item);
  return media?.thumbnail || media?.url || '';
};

const formatTileDate = (dateValue) => {
  if (!dateValue) return { day: '', month: '' };
  const date = new Date(dateValue);
  return {
    day: String(date.getDate()),
    month: date.toLocaleDateString('en-IN', { month: 'short' }),
  };
};

const HighlightTitleModal = ({ open, title, setTitle, saving, onClose, onNext }) => {
  if (!open) return null;
  return (
    <div className="fixed inset-0 z-[135] flex items-center justify-center bg-black/70 p-4 backdrop-blur-sm">
      <div className="w-full max-w-[620px] overflow-hidden rounded-[28px] bg-[#26272b] text-white shadow-2xl">
        <div className="relative border-b border-white/10 px-6 py-5 text-center">
          <button type="button" onClick={onClose} className="absolute left-6 top-1/2 -translate-y-1/2 text-white/90 transition hover:text-white">
            <X size={20} />
          </button>
          <h3 className="text-[15px] font-semibold">New highlight</h3>
        </div>
        <div className="border-b border-white/10 px-6 py-5">
          <input
            value={title}
            onChange={(event) => setTitle(event.target.value)}
            maxLength={30}
            placeholder="Enter a title"
            className="w-full rounded-xl border border-white/10 bg-transparent px-4 py-3 text-sm text-white outline-none transition placeholder:text-white/35 focus:border-white/20"
          />
        </div>
        <button type="button" onClick={onNext} disabled={saving || !title.trim()} className="flex h-[54px] w-full items-center justify-center text-sm font-semibold text-[#5b73ff] transition hover:bg-white/5 disabled:opacity-40">
          {saving ? <Loader2 size={16} className="animate-spin" /> : 'Next'}
        </button>
      </div>
    </div>
  );
};

const StoryPickerModal = ({ open, items, selectedIds, setSelectedIds, loading, onBack, onClose, onNext }) => {
  if (!open) return null;
  const toggle = (id) => setSelectedIds((prev) => (prev.includes(id) ? prev.filter((x) => x !== id) : [...prev, id]));

  return (
    <div className="fixed inset-0 z-[136] flex items-center justify-center bg-black/70 p-4 backdrop-blur-sm">
      <div className="flex h-[min(88vh,820px)] w-full max-w-[680px] flex-col overflow-hidden rounded-[28px] bg-[#26272b] text-white shadow-2xl">
        <div className="relative flex items-center justify-center border-b border-white/10 px-6 py-5">
          <button type="button" onClick={onBack} className="absolute left-6 top-1/2 -translate-y-1/2 text-white/90 transition hover:text-white">
            <ChevronLeft size={24} />
          </button>
          <h3 className="text-[15px] font-semibold">Stories</h3>
          <button type="button" onClick={onClose} className="absolute right-6 top-1/2 -translate-y-1/2 text-white/90 transition hover:text-white">
            <X size={24} />
          </button>
        </div>
        <div className="min-h-0 flex-1 overflow-y-auto p-0.5">
          {loading ? (
            <div className="flex h-full min-h-[360px] items-center justify-center"><Loader2 size={28} className="animate-spin text-white/70" /></div>
          ) : (
            <div className="grid grid-cols-3 gap-[1px] bg-black/20">
              {items.map((item) => {
                const preview = getPreviewUrl(item);
                const selected = selectedIds.includes(item._id);
                const dateInfo = formatTileDate(item.createdAt);
                return (
                  <button key={item._id} type="button" onClick={() => toggle(item._id)} className="relative aspect-[3/4] overflow-hidden bg-[#1d1e22] text-left">
                    {preview ? <img src={preview} alt="" className="h-full w-full object-cover" /> : <div className="h-full w-full bg-black" />}
                    <div className="absolute left-8 top-2 rounded-xl bg-white px-2 py-1 text-center leading-none text-[#1b1b1b] shadow">
                      <div className="text-[11px] font-bold">{dateInfo.day}</div>
                      <div className="mt-1 text-[10px]">{dateInfo.month}</div>
                    </div>
                    <div className={`absolute bottom-3 right-3 flex h-6 w-6 items-center justify-center rounded-full border ${selected ? 'border-[#1d9bf0] bg-[#1d9bf0]' : 'border-white bg-black/20'}`}>
                      {selected ? <Check size={14} className="text-white" /> : null}
                    </div>
                  </button>
                );
              })}
            </div>
          )}
        </div>
        <button type="button" onClick={onNext} disabled={selectedIds.length === 0 || loading} className="flex h-[54px] w-full items-center justify-center border-t border-white/10 text-sm font-semibold text-[#5b73ff] transition hover:bg-white/5 disabled:opacity-40">
          Next
        </button>
      </div>
    </div>
  );
};

const CoverPickerModal = ({ open, selectedItems, coverId, setCoverId, saving, onBack, onClose, onDone }) => {
  if (!open) return null;
  const activeItem = selectedItems.find((item) => item._id === coverId) || selectedItems[0] || null;
  const activePreview = getPreviewUrl(activeItem);

  return (
    <div className="fixed inset-0 z-[137] flex items-center justify-center bg-black/70 p-4 backdrop-blur-sm">
      <div className="flex h-[min(88vh,820px)] w-full max-w-[540px] flex-col overflow-hidden rounded-[28px] bg-[#26272b] text-white shadow-2xl">
        <div className="relative flex items-center justify-center border-b border-white/10 px-6 py-5">
          <button type="button" onClick={onBack} className="absolute left-6 top-1/2 -translate-y-1/2 text-white/90 transition hover:text-white">
            <ChevronLeft size={24} />
          </button>
          <h3 className="text-[15px] font-semibold">Select cover</h3>
          <button type="button" onClick={onClose} className="absolute right-6 top-1/2 -translate-y-1/2 text-white/90 transition hover:text-white">
            <X size={24} />
          </button>
        </div>
        <div className="flex flex-1 flex-col overflow-hidden">
          <div className="flex items-center justify-center px-6 py-6">
            <div className="h-[320px] w-[320px] overflow-hidden rounded-full bg-black">
              {activePreview ? <img src={activePreview} alt="" className="h-full w-full object-cover" /> : null}
            </div>
          </div>
          <div className="min-h-0 flex-1 overflow-x-auto overflow-y-hidden border-t border-white/10">
            <div className="flex h-full min-w-full items-stretch">
              {selectedItems.map((item) => {
                const preview = getPreviewUrl(item);
                const selected = item._id === coverId;
                return (
                  <button key={item._id} type="button" onClick={() => setCoverId(item._id)} className="relative h-full min-w-[160px] overflow-hidden border-r border-white/10 bg-[#1d1e22]">
                    {preview ? <img src={preview} alt="" className="h-full w-full object-cover" /> : null}
                    <div className={`absolute bottom-3 right-3 flex h-6 w-6 items-center justify-center rounded-full border ${selected ? 'border-[#1d9bf0] bg-[#1d9bf0]' : 'border-white bg-black/20'}`}>
                      {selected ? <Check size={14} className="text-white" /> : null}
                    </div>
                  </button>
                );
              })}
            </div>
          </div>
        </div>
        <button type="button" onClick={onDone} disabled={saving || !coverId} className="flex h-[54px] w-full items-center justify-center border-t border-white/10 text-sm font-semibold text-[#5b73ff] transition hover:bg-white/5 disabled:opacity-40">
          {saving ? <Loader2 size={16} className="animate-spin" /> : 'Done'}
        </button>
      </div>
    </div>
  );
};

const RenameModal = ({ open, title, setTitle, saving, onClose, onSave }) => {
  if (!open) return null;
  return (
    <div className="fixed inset-0 z-[135] flex items-center justify-center bg-black/70 p-4 backdrop-blur-sm">
      <div className="w-full max-w-[620px] overflow-hidden rounded-[28px] bg-[#26272b] text-white shadow-2xl">
        <div className="relative border-b border-white/10 px-6 py-5 text-center">
          <button type="button" onClick={onClose} className="absolute left-6 top-1/2 -translate-y-1/2 text-white/90 transition hover:text-white">
            <X size={20} />
          </button>
          <h3 className="text-[15px] font-semibold">Edit highlight</h3>
        </div>
        <div className="border-b border-white/10 px-6 py-5">
          <input
            value={title}
            onChange={(event) => setTitle(event.target.value)}
            maxLength={30}
            placeholder="Enter a title"
            className="w-full rounded-xl border border-white/10 bg-transparent px-4 py-3 text-sm text-white outline-none transition placeholder:text-white/35 focus:border-white/20"
          />
        </div>
        <button type="button" onClick={onSave} disabled={saving || !title.trim()} className="flex h-[54px] w-full items-center justify-center text-sm font-semibold text-[#5b73ff] transition hover:bg-white/5 disabled:opacity-40">
          {saving ? <Loader2 size={16} className="animate-spin" /> : 'Save'}
        </button>
      </div>
    </div>
  );
};

const HighlightViewer = ({ highlight, items, loading, currentIndex, setCurrentIndex, optionsOpen, setOptionsOpen, onClose, onAddStories, onEdit, onDeleteHighlight, onDeleteCurrentItem }) => {
  const [progress, setProgress] = useState(0);
  const [isPaused, setIsPaused] = useState(false);
  const [isMuted, setIsMuted] = useState(true);
  const videoRef = useRef(null);
  const touchStartRef = useRef(null);
  const currentItem = items[currentIndex] || null;
  const media = getMedia(currentItem);
  const isVideo = media?.type === 'video' || media?.media_type === 'video';
  const mediaUrl = media?.url || media?.fileUrl || '';
  const durationSec = Math.max(3, Number(media?.durationSec || 5));

  const goNext = useCallback(() => {
    setOptionsOpen(false);
    if (currentIndex < items.length - 1) setCurrentIndex((prev) => prev + 1);
    else onClose();
  }, [currentIndex, items.length, onClose, setCurrentIndex, setOptionsOpen]);

  const goPrev = useCallback(() => {
    setOptionsOpen(false);
    if (currentIndex > 0) setCurrentIndex((prev) => prev - 1);
  }, [currentIndex, setCurrentIndex, setOptionsOpen]);

  useEffect(() => {
    setProgress(0);
    setIsPaused(false);
    setOptionsOpen(false);
  }, [currentIndex, highlight?._id, setOptionsOpen]);

  useEffect(() => {
    setProgress(0);
    if (!currentItem || isVideo || isPaused) return undefined;
    let rafId = 0;
    let start = 0;
    const totalMs = durationSec * 1000;
    const step = (now) => {
      if (!start) start = now;
      const next = Math.min(100, ((now - start) / totalMs) * 100);
      setProgress(next);
      if (next >= 100) goNext();
      else rafId = window.requestAnimationFrame(step);
    };
    rafId = window.requestAnimationFrame(step);
    return () => window.cancelAnimationFrame(rafId);
  }, [currentItem, durationSec, goNext, isPaused, isVideo]);

  useEffect(() => {
    const video = videoRef.current;
    if (!video) return;
    video.muted = isMuted;
    if (isPaused) video.pause();
    else video.play().catch(() => {});
  }, [currentIndex, isMuted, isPaused]);

  useEffect(() => {
    const onKeyDown = (event) => {
      if (event.key === 'Escape') onClose();
      if (event.key === 'ArrowRight') goNext();
      if (event.key === 'ArrowLeft') goPrev();
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [goNext, goPrev, onClose]);

  if (!highlight) return null;

  return (
    <div
      className="fixed inset-0 z-[130] flex items-center justify-center bg-black"
      onTouchStart={(event) => { touchStartRef.current = event.touches[0].clientX; }}
      onTouchEnd={(event) => {
        if (touchStartRef.current == null) return;
        const dx = event.changedTouches[0].clientX - touchStartRef.current;
        touchStartRef.current = null;
        if (Math.abs(dx) > 40) (dx < 0 ? goNext : goPrev)();
      }}
    >
      <div
        className="relative h-full w-full overflow-hidden bg-black md:h-[min(92vh,780px)] md:w-[min(100vw,430px)] md:rounded-[28px]"
        onClick={(event) => {
          const rect = event.currentTarget.getBoundingClientRect();
          const x = event.clientX - rect.left;
          if (x < rect.width * 0.35) goPrev();
          else goNext();
        }}
      >
        <div className="absolute left-3 right-3 top-3 z-30 flex gap-[3px]">
          {(items.length ? items : [null]).map((_, index) => (
            <div key={`${highlight._id}-${index}`} className="h-[2.5px] flex-1 overflow-hidden rounded-full bg-white/25">
              <div className="h-full rounded-full bg-white" style={{ width: index < currentIndex ? '100%' : index === currentIndex ? `${progress}%` : '0%' }} />
            </div>
          ))}
        </div>
        <div className="absolute left-3 right-3 top-7 z-30 flex items-start justify-between">
          <div className="pointer-events-auto flex items-center gap-3">
            <div className="h-10 w-10 overflow-hidden rounded-full border border-white/20 bg-white/10">
              <CircleImage src={highlight.avatarUrl} alt={highlight.username} fallback={highlight.username} />
            </div>
            <div>
              <p className="text-sm font-semibold text-white">{highlight.title || 'Highlight'}</p>
              <p className="text-xs text-white/65">
                {highlight.isOwner ? 'Your highlights' : highlight.username}
                {currentItem?.createdAt ? ` - ${formatAgo(currentItem.createdAt)}` : ''}
              </p>
            </div>
          </div>
          <div className="pointer-events-auto flex items-center gap-2">
            {isVideo ? (
              <button type="button" onClick={(event) => { event.stopPropagation(); setIsMuted((prev) => !prev); }} className="rounded-full bg-black/35 px-3 py-2 text-xs font-semibold text-white transition hover:bg-black/50">
                {isMuted ? 'Unmute' : 'Mute'}
              </button>
            ) : null}
            {highlight.isOwner ? (
              <div className="relative">
                <button type="button" onClick={(event) => { event.stopPropagation(); setOptionsOpen((prev) => !prev); }} className="rounded-full bg-black/35 p-2 text-white transition hover:bg-black/50">
                  <MoreHorizontal size={18} />
                </button>
                {optionsOpen ? (
                  <div className="absolute right-0 mt-2 w-44 rounded-2xl bg-white p-1.5 shadow-2xl dark:bg-[#111111]" onClick={(event) => event.stopPropagation()}>
                    <button type="button" onClick={onEdit} className="flex w-full items-center gap-2 rounded-xl px-3 py-2 text-left text-sm font-medium text-gray-800 transition hover:bg-gray-100 dark:text-gray-200 dark:hover:bg-white/5"><Pencil size={14} />Edit title</button>
                    <button type="button" onClick={onAddStories} className="flex w-full items-center gap-2 rounded-xl px-3 py-2 text-left text-sm font-medium text-gray-800 transition hover:bg-gray-100 dark:text-gray-200 dark:hover:bg-white/5"><Plus size={14} />Add stories</button>
                    {currentItem?._itemId ? <button type="button" onClick={() => onDeleteCurrentItem(currentItem._itemId)} className="flex w-full items-center gap-2 rounded-xl px-3 py-2 text-left text-sm font-medium text-red-500 transition hover:bg-red-50 dark:hover:bg-red-500/10"><Trash2 size={14} />Remove item</button> : null}
                    <button type="button" onClick={onDeleteHighlight} className="flex w-full items-center gap-2 rounded-xl px-3 py-2 text-left text-sm font-medium text-red-500 transition hover:bg-red-50 dark:hover:bg-red-500/10"><Trash2 size={14} />Delete highlight</button>
                  </div>
                ) : null}
              </div>
            ) : null}
            <button type="button" onClick={(event) => { event.stopPropagation(); onClose(); }} className="rounded-full bg-black/35 p-2 text-white transition hover:bg-black/50">
              <X size={18} />
            </button>
          </div>
        </div>
        {loading ? (
          <div className="flex h-full items-center justify-center"><Loader2 size={30} className="animate-spin text-white/80" /></div>
        ) : currentItem && mediaUrl ? (
          isVideo ? (
            <video
              ref={videoRef}
              key={mediaUrl}
              src={mediaUrl}
              className="absolute inset-0 h-full w-full object-cover"
              poster={media?.thumbnail || undefined}
              playsInline
              autoPlay
              muted={isMuted}
              onTimeUpdate={(event) => {
                const video = event.currentTarget;
                if (!video.duration) return;
                setProgress((video.currentTime / video.duration) * 100);
              }}
              onEnded={goNext}
            />
          ) : <img src={mediaUrl} alt={highlight.title} className="absolute inset-0 h-full w-full object-cover" />
        ) : (
          <div className="flex h-full flex-col items-center justify-center bg-[#050505] px-8 text-center">
            <div className="flex h-16 w-16 items-center justify-center rounded-full bg-white/10"><Plus size={24} className="text-white/75" /></div>
            <h4 className="mt-4 text-lg font-bold text-white">No items in this highlight</h4>
            <p className="mt-2 text-sm leading-6 text-white/60">Add stories to this highlight to keep it visible.</p>
          </div>
        )}
        <button type="button" onClick={(event) => { event.stopPropagation(); goPrev(); }} className="absolute left-3 top-1/2 z-30 hidden h-9 w-9 -translate-y-1/2 items-center justify-center rounded-full bg-white/15 text-white transition hover:bg-white/25 md:flex"><ChevronLeft size={18} /></button>
        <button type="button" onClick={(event) => { event.stopPropagation(); goNext(); }} className="absolute right-3 top-1/2 z-30 hidden h-9 w-9 -translate-y-1/2 items-center justify-center rounded-full bg-white/15 text-white transition hover:bg-white/25 md:flex"><ChevronRight size={18} /></button>
      </div>
    </div>
  );
};

export default function HighlightsRail({ users = [], variant = 'chat', allowCreate = true }) {
  const { userObject } = useSelector((state) => state.auth);
  const currentUserId = getUserId(userObject);
  const isProfileVariant = variant === 'profile';
  const [highlights, setHighlights] = useState([]);
  const [loading, setLoading] = useState(false);
  const [viewerHighlight, setViewerHighlight] = useState(null);
  const [viewerItems, setViewerItems] = useState([]);
  const [viewerLoading, setViewerLoading] = useState(false);
  const [viewerIndex, setViewerIndex] = useState(0);
  const [viewerOptionsOpen, setViewerOptionsOpen] = useState(false);
  const [createStep, setCreateStep] = useState('closed');
  const [draftTitle, setDraftTitle] = useState('');
  const [pickerLoading, setPickerLoading] = useState(false);
  const [submittingCreate, setSubmittingCreate] = useState(false);
  const [availableItems, setAvailableItems] = useState([]);
  const [selectedIds, setSelectedIds] = useState([]);
  const [coverId, setCoverId] = useState('');
  const [editingHighlight, setEditingHighlight] = useState(null);
  const [renameOpen, setRenameOpen] = useState(false);
  const [renameTitle, setRenameTitle] = useState('');
  const [renameSaving, setRenameSaving] = useState(false);

  const relevantUsers = useMemo(() => {
    const map = new Map();
    if (!isProfileVariant && userObject && currentUserId) {
      map.set(String(currentUserId), { userId: currentUserId, username: getUserName(userObject), avatarUrl: getUserAvatar(userObject), isOwner: true });
    }
    users.forEach((user) => {
      const userId = getUserId(user);
      if (!userId || map.has(String(userId))) return;
      map.set(String(userId), { userId, username: getUserName(user), avatarUrl: getUserAvatar(user), isOwner: String(userId) === String(currentUserId) });
    });
    return Array.from(map.values());
  }, [currentUserId, isProfileVariant, userObject, users]);

  const fetchHighlights = useCallback(async () => {
    if (!relevantUsers.length) {
      setHighlights([]);
      return;
    }
    setLoading(true);
    try {
      const results = await Promise.all(relevantUsers.map(async (user) => {
        try {
          const response = await api.get(`/highlights/user/${user.userId}`);
          const list = Array.isArray(response.data) ? response.data : [];
          return list.map((highlight) => ({
            ...highlight,
            username: user.username,
            avatarUrl: user.avatarUrl,
            isOwner: isHighlightOwner(highlight, currentUserId),
          }));
        } catch {
          return [];
        }
      }));
      setHighlights(results.flat().filter((item) => Number(item.items_count || 0) > 0));
    } finally {
      setLoading(false);
    }
  }, [currentUserId, relevantUsers]);

  useEffect(() => { fetchHighlights(); }, [fetchHighlights]);

  const fetchSelectableStoryItems = useCallback(async () => {
    if (!currentUserId) return [];
    const [activeRes, archiveRes] = await Promise.all([
      api.get(`/stories/user/${currentUserId}`).catch(() => ({ data: [] })),
      api.get('/stories/archive').catch(() => ({ data: { stories: [] } })),
    ]);
    const activeStories = Array.isArray(activeRes.data) ? activeRes.data : [];
    const archivedStories = Array.isArray(archiveRes.data?.stories) ? archiveRes.data.stories : [];
    const storySources = [
      ...activeStories.map((story) => ({ ...story, _sourceLabel: 'Active story' })),
      ...archivedStories.map((story) => ({ ...story, _sourceLabel: 'Archive' })),
    ];
    const itemResults = await Promise.all(storySources.map(async (story) => {
      try {
        const response = await api.get(`/stories/${story._id}/items`);
        const items = Array.isArray(response.data) ? response.data : [];
        return items.map((item) => ({ ...item, _sourceLabel: story._sourceLabel }));
      } catch {
        return [];
      }
    }));
    const map = new Map();
    itemResults.flat().forEach((item) => { if (item?._id && !map.has(item._id)) map.set(item._id, item); });
    return Array.from(map.values()).sort((a, b) => new Date(b.createdAt || 0).getTime() - new Date(a.createdAt || 0).getTime());
  }, [currentUserId]);

  const loadSelectableItems = useCallback(async () => {
    setPickerLoading(true);
    try {
      setAvailableItems(await fetchSelectableStoryItems());
    } finally {
      setPickerLoading(false);
    }
  }, [fetchSelectableStoryItems]);

  const openCreateFlow = async () => {
    setEditingHighlight(null);
    setDraftTitle('');
    setSelectedIds([]);
    setCoverId('');
    setCreateStep('title');
    setAvailableItems([]);
  };

  const closeCreateFlow = () => {
    if (!submittingCreate) {
      setCreateStep('closed');
      setEditingHighlight(null);
      setSelectedIds([]);
      setCoverId('');
      setAvailableItems([]);
    }
  };

  const refreshViewerItems = async (highlightId) => {
    const response = await api.get(`/highlights/${highlightId}/items`);
    const items = Array.isArray(response.data) ? response.data : [];
    setViewerItems(items);
    setViewerIndex((prev) => Math.min(prev, Math.max(items.length - 1, 0)));
    return items;
  };

  const goToStoryPicker = async () => {
    if (!draftTitle.trim()) return;
    setCreateStep('stories');
    await loadSelectableItems();
  };

  const goToCoverPicker = () => {
    if (!selectedIds.length) return;
    setCoverId((prev) => (prev && selectedIds.includes(prev) ? prev : selectedIds[0]));
    setCreateStep('cover');
  };

  const selectedStoryItems = useMemo(
    () => availableItems.filter((item) => selectedIds.includes(item._id)),
    [availableItems, selectedIds]
  );

  const saveCreatedHighlight = async () => {
    if (!draftTitle.trim() || !selectedIds.length) return;
    setSubmittingCreate(true);
    try {
      if (editingHighlight?._id) {
        if (!isHighlightOwner(editingHighlight, currentUserId)) {
          throw new Error('You can only edit your own highlight.');
        }
        await api.post(`/highlights/${editingHighlight._id}/items`, { title: draftTitle.trim(), story_item_ids: selectedIds });
        if (coverId) {
          const coverItem = availableItems.find((item) => item._id === coverId);
          await api.patch(`/highlights/${editingHighlight._id}`, {
            title: draftTitle.trim(),
            cover_url: getPreviewUrl(coverItem),
          });
        }
      } else {
        const created = await api.post('/highlights', { title: draftTitle.trim() });
        const highlightId = created.data?._id;
        if (highlightId) {
          await api.post(`/highlights/${highlightId}/items`, { title: draftTitle.trim(), story_item_ids: selectedIds });
          if (coverId) {
            const coverItem = availableItems.find((item) => item._id === coverId);
            await api.patch(`/highlights/${highlightId}`, {
              cover_url: getPreviewUrl(coverItem),
            });
          }
        }
      }
      closeCreateFlow();
      await fetchHighlights();
      if (editingHighlight?._id && viewerHighlight?._id === editingHighlight._id) {
        setViewerHighlight((prev) => (prev ? { ...prev, title: draftTitle.trim() } : prev));
        await refreshViewerItems(editingHighlight._id);
      }
    } catch (error) {
      window.alert(error?.response?.data?.message || error?.message || 'Unable to save highlight.');
    } finally {
      setSubmittingCreate(false);
    }
  };

  const openAddStoriesFlow = async (highlight) => {
    if (!isHighlightOwner(highlight, currentUserId)) return;
    setEditingHighlight(highlight);
    setDraftTitle(highlight?.title || '');
    setSelectedIds([]);
    setCoverId('');
    setCreateStep('stories');
    await loadSelectableItems();
  };

  const openRenameModal = (highlight) => {
    if (!isHighlightOwner(highlight, currentUserId)) return;
    setEditingHighlight(highlight);
    setRenameTitle(highlight?.title || '');
    setRenameOpen(true);
  };

  const saveRename = async () => {
    if (!editingHighlight?._id || !renameTitle.trim()) return;
    setRenameSaving(true);
    try {
      if (!isHighlightOwner(editingHighlight, currentUserId)) {
        throw new Error('You can only edit your own highlight.');
      }
      await api.patch(`/highlights/${editingHighlight._id}`, { title: renameTitle.trim() });
      setRenameOpen(false);
      setHighlights((prev) => prev.map((item) => (
        item._id === editingHighlight._id ? { ...item, title: renameTitle.trim() } : item
      )));
      setViewerHighlight((prev) => (prev && prev._id === editingHighlight._id ? { ...prev, title: renameTitle.trim() } : prev));
    } catch (error) {
      window.alert(error?.response?.data?.message || error?.message || 'Unable to update highlight.');
    } finally {
      setRenameSaving(false);
    }
  };

  const openHighlight = async (highlight) => {
    setViewerHighlight(highlight);
    setViewerItems([]);
    setViewerIndex(0);
    setViewerLoading(true);
    setViewerOptionsOpen(false);
    try {
      await refreshViewerItems(highlight._id);
    } finally {
      setViewerLoading(false);
    }
  };

  const deleteHighlight = async () => {
    if (!viewerHighlight?._id || !window.confirm('Delete this highlight?')) return;
    try {
      if (!isHighlightOwner(viewerHighlight, currentUserId)) {
        throw new Error('You can only delete your own highlight.');
      }
      await api.delete(`/highlights/${viewerHighlight._id}`);
      setViewerHighlight(null);
      setViewerItems([]);
      await fetchHighlights();
    } catch (error) {
      window.alert(error?.response?.data?.message || error?.message || 'Unable to delete highlight.');
    }
  };

  const deleteHighlightItem = async (itemId) => {
    if (!viewerHighlight?._id || !itemId || !window.confirm('Remove this story from the highlight?')) return;
    try {
      if (!isHighlightOwner(viewerHighlight, currentUserId)) {
        throw new Error('You can only edit your own highlight.');
      }
      await api.delete(`/highlights/${viewerHighlight._id}/items/${itemId}`);
      const items = await refreshViewerItems(viewerHighlight._id);
      await fetchHighlights();
      if (items.length === 0) setViewerHighlight(null);
    } catch (error) {
      window.alert(error?.response?.data?.message || error?.message || 'Unable to remove item from highlight.');
    }
  };

  useEffect(() => {
    if (coverId && !selectedIds.includes(coverId)) {
      setCoverId(selectedIds[0] || '');
    }
  }, [coverId, selectedIds]);

  const ownHighlights = highlights.filter((item) => item.isOwner);
  const otherHighlights = highlights.filter((item) => !item.isOwner);

  return (
    <>
      <div className={isProfileVariant ? 'px-0 pb-2 pt-1' : 'border-b border-white/10 px-4 pb-3 pt-1 md:border-b-gray-100 md:px-5 md:py-4 md:dark:border-white/10'}>
        {!isProfileVariant ? (
          <div className="mb-3 flex items-center justify-between">
            <div>
              <p className="text-[13px] font-bold uppercase tracking-[0.22em] text-white/40 md:text-[11px] md:text-gray-400">Highlights</p>
              <p className="mt-1 text-xs text-white/55 md:text-gray-500 md:dark:text-gray-400">Instagram-style saved stories for you and your chats.</p>
            </div>
            {loading ? <Loader2 size={16} className="animate-spin text-white/50 md:text-gray-400" /> : null}
          </div>
        ) : null}
        <div className="flex gap-4 overflow-x-auto [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden">
          {allowCreate ? (
            <button type="button" onClick={openCreateFlow} className="flex min-w-[78px] shrink-0 flex-col items-center gap-2">
              <div className={`relative rounded-full p-[3px] ${isProfileVariant ? 'border border-gray-300 dark:border-gray-700' : 'border border-dashed border-white/20 md:border-gray-300 md:dark:border-white/15'}`}>
                <div className={`flex h-[66px] w-[66px] items-center justify-center rounded-full ${isProfileVariant ? 'bg-gray-100 text-gray-500 dark:bg-[#1a1a1d] dark:text-gray-300' : 'bg-[#1a1a1d] text-white md:bg-gray-100 md:text-gray-700 md:dark:bg-[#111111] md:dark:text-white'}`}><Plus size={22} /></div>
              </div>
              <span className={`max-w-[84px] truncate text-center text-[11px] font-medium ${isProfileVariant ? 'text-gray-700 dark:text-gray-300' : 'text-white/75 md:text-gray-600 md:dark:text-gray-300'}`}>New</span>
            </button>
          ) : null}
          {[...ownHighlights, ...otherHighlights].map((highlight) => (
            <button key={highlight._id} type="button" onClick={() => openHighlight(highlight)} className="flex min-w-[78px] shrink-0 flex-col items-center gap-2">
              <div className={`rounded-full ${isProfileVariant ? 'bg-gray-300 dark:bg-gray-700 p-[2px]' : 'bg-gradient-to-tr from-[#facc15] via-[#f43f5e] to-[#8b5cf6] p-[2px]'}`}>
                <div className={`rounded-full p-[2px] ${isProfileVariant ? 'bg-white dark:bg-black' : 'bg-black md:bg-white md:dark:bg-black'}`}>
                  <div className={`h-[66px] w-[66px] overflow-hidden rounded-full ${isProfileVariant ? 'bg-gray-100 dark:bg-[#111111]' : 'bg-[#1a1a1d] md:bg-gray-100 md:dark:bg-[#111111]'}`}>
                    <CircleImage src={getCover(highlight)} alt={highlight.title} fallback={highlight.title} />
                  </div>
                </div>
              </div>
              <div className="max-w-[84px] text-center">
                <p className={`truncate text-[11px] font-medium ${isProfileVariant ? 'text-gray-700 dark:text-gray-300' : 'text-white/80 md:text-gray-600 md:dark:text-gray-300'}`}>{highlight.title}</p>
                {!highlight.isOwner && !isProfileVariant ? <p className="truncate text-[10px] text-white/40 md:text-gray-400">{highlight.username}</p> : null}
              </div>
            </button>
          ))}
        </div>
      </div>

      <HighlightTitleModal
        open={createStep === 'title'}
        title={draftTitle}
        setTitle={setDraftTitle}
        saving={submittingCreate}
        onClose={closeCreateFlow}
        onNext={goToStoryPicker}
      />

      <StoryPickerModal
        open={createStep === 'stories'}
        items={availableItems}
        selectedIds={selectedIds}
        setSelectedIds={setSelectedIds}
        loading={pickerLoading}
        onBack={() => setCreateStep(editingHighlight ? 'closed' : 'title')}
        onClose={closeCreateFlow}
        onNext={goToCoverPicker}
      />

      <CoverPickerModal
        open={createStep === 'cover'}
        selectedItems={selectedStoryItems}
        coverId={coverId}
        setCoverId={setCoverId}
        saving={submittingCreate}
        onBack={() => setCreateStep('stories')}
        onClose={closeCreateFlow}
        onDone={saveCreatedHighlight}
      />

      <RenameModal
        open={renameOpen}
        title={renameTitle}
        setTitle={setRenameTitle}
        saving={renameSaving}
        onClose={() => { if (!renameSaving) setRenameOpen(false); }}
        onSave={saveRename}
      />

      {viewerHighlight ? (
        <HighlightViewer
          highlight={viewerHighlight}
          items={viewerItems}
          loading={viewerLoading}
          currentIndex={viewerIndex}
          setCurrentIndex={setViewerIndex}
          optionsOpen={viewerOptionsOpen}
          setOptionsOpen={setViewerOptionsOpen}
          onClose={() => { setViewerHighlight(null); setViewerItems([]); setViewerOptionsOpen(false); }}
          onAddStories={() => { setViewerOptionsOpen(false); openAddStoriesFlow(viewerHighlight); }}
          onEdit={() => { setViewerOptionsOpen(false); openRenameModal(viewerHighlight); }}
          onDeleteHighlight={() => { setViewerOptionsOpen(false); deleteHighlight(); }}
          onDeleteCurrentItem={(itemId) => { setViewerOptionsOpen(false); deleteHighlightItem(itemId); }}
        />
      ) : null}
    </>
  );
}
