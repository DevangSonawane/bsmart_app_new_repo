import React, { useEffect, useState } from 'react';
import { X, ChevronLeft, ChevronRight, Heart, Send, Volume2, VolumeX, Pause, Play, MoreHorizontal } from 'lucide-react';
import { useSelector } from 'react-redux';
import api from '../lib/api';

const DeleteStoryModal = ({ isOpen, onClose, onConfirm, isDeleting }) => {
  if (!isOpen) return null;
  return (
    <div className="fixed inset-0 z-[120] flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
      <div className="bg-white dark:bg-gray-900 rounded-xl p-6 w-full max-w-sm shadow-2xl border border-gray-100 dark:border-gray-800">
        {isDeleting ? (
          <div className="flex flex-col items-center justify-center py-6">
            <div className="animate-spin w-10 h-10 border-4 border-gray-200 border-t-red-500 rounded-full mb-4"></div>
            <p className="text-gray-500 dark:text-gray-400 font-medium">Deleting story...</p>
          </div>
        ) : (
          <>
            <h3 className="text-lg font-bold text-gray-900 dark:text-white mb-2 text-center">Delete Story?</h3>
            <p className="text-gray-500 dark:text-gray-400 text-sm mb-6 text-center">
              Are you sure you want to delete this story? This action cannot be undone.
            </p>
            <div className="flex gap-3">
              <button
                onClick={onClose}
                className="flex-1 py-2 rounded-lg border border-gray-300 dark:border-gray-700 text-gray-700 dark:text-gray-200 text-sm font-semibold hover:bg-gray-50 dark:hover:bg-gray-800"
              >
                Cancel
              </button>
              <button
                onClick={onConfirm}
                className="flex-1 py-2 rounded-lg bg-red-500 text-white text-sm font-semibold hover:bg-red-600"
              >
                Delete
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  );
};

const StoryViewer = ({ initialStoryIndex, stories, onClose }) => {
  const [currentIndex, setCurrentIndex] = useState(initialStoryIndex);
  const [itemsByStoryId, setItemsByStoryId] = useState({});
  const [currentItemIndex, setCurrentItemIndex] = useState(0);
  const [progress, setProgress] = useState(0);
  const [isPaused, setIsPaused] = useState(false);
  const [isMuted, setIsMuted] = useState(true);
  const [showOptions, setShowOptions] = useState(false);
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [isDeletingStory, setIsDeletingStory] = useState(false);

  const { userObject } = useSelector((state) => state.auth);

  const currentStory = stories[currentIndex];
  const storyId = currentStory?.id;
  const storyItems = storyId && itemsByStoryId[storyId] ? itemsByStoryId[storyId] : [];
  const currentItem = storyItems[currentItemIndex] || null;
  const totalSegments = storyItems.length > 0 ? storyItems.length : 1;
  const currentUserId = userObject?.id || userObject?._id;
  const isOwner = !!currentStory && !!currentUserId && currentStory.userId === currentUserId;

  const getItemMedia = (item) => {
    if (!item || !item.media) return null;
    if (Array.isArray(item.media) && item.media.length > 0) {
      return item.media[0];
    }
    return item.media;
  };

  useEffect(() => {
    const story = stories[currentIndex];
    if (!story || !story.id || story.id === 'your_story') {
      setCurrentItemIndex(0);
      return;
    }

    if (itemsByStoryId[story.id]) {
      setCurrentItemIndex(0);
      return;
    }

    const fetchItems = async () => {
      try {
        const response = await api.get(`/stories/${story.id}/items`);
        const items = Array.isArray(response.data) ? response.data : [];
        setItemsByStoryId((prev) => ({
          ...prev,
          [story.id]: items,
        }));
        setCurrentItemIndex(0);
      } catch (error) {
        console.error('Error fetching story items:', error);
      }
    };

    fetchItems();
  }, [currentIndex, stories, itemsByStoryId]);

  useEffect(() => {
    setProgress(0);
    if (!currentStory) return;

    const items = storyItems;
    const item = items.length > 0 ? items[currentItemIndex] : null;
    const media = getItemMedia(item);

    let durationSec = 5;
    if (media && media.durationSec) {
      durationSec = media.durationSec;
    } else if (currentStory.previewDurationSec) {
      durationSec = currentStory.previewDurationSec;
    }
    if (!durationSec || durationSec <= 0) durationSec = 5;

    if (isPaused) {
      return;
    }

    let cancelled = false;
    const start = performance.now();
    const durationMs = durationSec * 1000;

    const step = (now) => {
      if (cancelled) return;
      const elapsed = now - start;
      const pct = Math.min(100, (elapsed / durationMs) * 100);
      setProgress(pct);

      if (elapsed >= durationMs) {
        if (items.length > 0 && currentItemIndex < items.length - 1) {
          setCurrentItemIndex((prev) => prev + 1);
        } else {
          if (currentIndex < stories.length - 1) {
            setCurrentIndex((prev) => prev + 1);
            setCurrentItemIndex(0);
          } else {
            onClose();
          }
        }
      } else {
        requestAnimationFrame(step);
      }
    };

    const frameId = requestAnimationFrame(step);
    return () => {
      cancelled = true;
      cancelAnimationFrame(frameId);
    };
  }, [currentStory, storyItems, currentItemIndex, currentIndex, stories.length, onClose, isPaused]);

  const handleNext = (e) => {
    if (e && e.stopPropagation) {
      e.stopPropagation();
    }
    setShowOptions(false);
    setIsPaused(false);
    if (storyItems.length > 0 && currentItemIndex < storyItems.length - 1) {
      setCurrentItemIndex((prev) => prev + 1);
    } else if (currentIndex < stories.length - 1) {
      setCurrentIndex((prev) => prev + 1);
      setCurrentItemIndex(0);
    } else {
      onClose();
    }
  };

  const handlePrev = (e) => {
    if (e && e.stopPropagation) {
      e.stopPropagation();
    }
    setShowOptions(false);
    setIsPaused(false);
    if (storyItems.length > 0 && currentItemIndex > 0) {
      setCurrentItemIndex((prev) => prev - 1);
    } else if (currentIndex > 0) {
      setCurrentIndex((prev) => prev - 1);
      const prevStory = stories[currentIndex - 1];
      const prevItems =
        prevStory && prevStory.id && itemsByStoryId[prevStory.id]
          ? itemsByStoryId[prevStory.id]
          : [];
      setCurrentItemIndex(prevItems.length > 0 ? prevItems.length - 1 : 0);
    }
  };

  const handleDeleteCurrentItem = () => {
    if (!isOwner || !storyId) return;
    setShowOptions(false);
    setShowDeleteModal(true);
  };

  useEffect(() => {
    const handleKeyDown = (event) => {
      if (event.key === 'ArrowRight') {
        handleNext();
      } else if (event.key === 'ArrowLeft') {
        handlePrev();
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => {
      window.removeEventListener('keydown', handleKeyDown);
    };
  }, [handleNext, handlePrev]);

  const goNextStory = () => {
    if (currentIndex < stories.length - 1) {
      setCurrentIndex((prev) => prev + 1);
      setCurrentItemIndex(0);
    } else {
      onClose();
    }
  };

  const goPrevStory = () => {
    if (currentIndex > 0) {
      setCurrentIndex((prev) => prev - 1);
      const prevStory = stories[currentIndex - 1];
      const prevItems =
        prevStory && prevStory.id && itemsByStoryId[prevStory.id]
          ? itemsByStoryId[prevStory.id]
          : [];
      setCurrentItemIndex(prevItems.length > 0 ? prevItems.length - 1 : 0);
    }
  };

  return (
    <div className="fixed inset-0 z-[100] bg-black flex items-center justify-center animate-in fade-in duration-200">
      {/* Top Controls */}
      <div className="absolute top-0 left-0 right-0 p-4 flex justify-between items-start z-10 bg-gradient-to-b from-black/50 to-transparent h-24">
        <div className="flex items-center gap-2 text-white">
          <span className="font-semibold text-sm">{currentStory.username}</span>
          <span className="text-white/60 text-xs">12 h</span>
        </div>

        <div className="flex items-center gap-3">
          <button
            onClick={() => setIsMuted((prev) => !prev)}
            className="text-white hover:opacity-80 transition-opacity"
          >
            {isMuted ? <VolumeX size={20} /> : <Volume2 size={20} />}
          </button>
          <button
            onClick={() => setIsPaused((prev) => !prev)}
            className="text-white hover:opacity-80 transition-opacity"
          >
            {isPaused ? <Play size={20} /> : <Pause size={20} />}
          </button>
          {isOwner && storyItems.length > 0 && (
            <div className="relative">
              <button
                onClick={() => setShowOptions((prev) => !prev)}
                className="text-white hover:opacity-80 transition-opacity"
              >
                <MoreHorizontal size={22} />
              </button>
              {showOptions && (
                <div className="absolute right-0 mt-2 w-32 bg-white text-black text-xs rounded-lg shadow-lg py-1 z-50">
                  <button
                    onClick={handleDeleteCurrentItem}
                    disabled={isDeletingStory}
                    className="w-full text-left px-3 py-2 hover:bg-white/10 disabled:opacity-60 disabled:cursor-not-allowed"
                  >
                    {isDeletingStory ? 'Deleting…' : 'Delete'}
                  </button>
                </div>
              )}
            </div>
          )}
          <button onClick={onClose} className="text-white hover:opacity-80 transition-opacity">
            <X size={28} strokeWidth={2.5} />
          </button>
        </div>
        <DeleteStoryModal
          isOpen={showDeleteModal}
          onClose={() => {
            if (!isDeletingStory) setShowDeleteModal(false);
          }}
          onConfirm={async () => {
            if (!isOwner || !storyId) return;
            try {
              setIsDeletingStory(true);
              const token = localStorage.getItem('token');
              await api.delete(`/stories/${storyId}`, {
                headers: token ? { Authorization: `Bearer ${token}` } : {},
              });
              setShowDeleteModal(false);
              onClose();
              window.location.reload();
            } catch (error) {
              console.error('Error deleting story:', error);
              setIsDeletingStory(false);
            }
          }}
          isDeleting={isDeletingStory}
        />
      </div>

      {/* Main Content Area */}
      <div className="relative w-full h-full md:w-[400px] md:h-[85vh] flex items-center justify-center">

        {/* Navigation Arrows (Desktop) */}
        {currentIndex > 0 && (
          <button
            onClick={handlePrev}
            className="absolute -left-16 top-1/2 -translate-y-1/2 bg-white/10 hover:bg-white/20 p-2 rounded-full text-white hidden md:block transition-colors"
          >
            <ChevronLeft size={24} />
          </button>
        )}

        {/* Story Image */}
        <div className="w-full h-full relative bg-gray-900 md:rounded-xl overflow-hidden" onClick={handleNext}>
          {/* Progress Bar */}
          <div className="absolute top-2 left-2 right-2 flex gap-1 z-10">
            {Array.from({ length: totalSegments }).map((_, index) => {
              let width = '0%';
              if (index < currentItemIndex) {
                width = '100%';
              } else if (index === currentItemIndex) {
                width = `${progress}%`;
              }
              return (
                <div
                  key={index}
                  className="h-0.5 flex-1 bg-white/30 rounded-full overflow-hidden"
                >
                  <div className="h-full bg-white" style={{ width }} />
                </div>
              );
            })}
          </div>

          <img
            src={
              (() => {
                const media = getItemMedia(currentItem);
                if (media && (media.thumbnail || media.url)) {
                  return media.thumbnail || media.url;
                }
                if (currentStory.imageUrl) return currentStory.imageUrl;
                return 'https://images.unsplash.com/photo-1611162617474-5b21e879e113?w=500&auto=format&fit=crop&q=60';
              })()
            }
            alt="Story"
            className="w-full h-full object-cover"
          />

          {/* Bottom Actions */}
          <div className="absolute bottom-0 left-0 right-0 p-4 bg-gradient-to-t from-black/60 to-transparent flex items-center gap-4">
            <input
              type="text"
              placeholder={`Reply to ${currentStory.username}...`}
              className="flex-1 bg-transparent border border-white/30 rounded-full px-4 py-2.5 text-white placeholder-white/70 focus:outline-none focus:border-white/60 text-sm backdrop-blur-sm"
              onClick={(e) => e.stopPropagation()}
            />
            <button className="text-white p-1 hover:scale-110 transition-transform" onClick={(e) => e.stopPropagation()}>
              <Heart size={28} />
            </button>
            <button className="text-white p-1 hover:scale-110 transition-transform" onClick={(e) => e.stopPropagation()}>
              <Send size={28} />
            </button>
          </div>
        </div>

        {/* Next Arrow (Desktop) */}
        <button
          onClick={handleNext}
          className="absolute -right-16 top-1/2 -translate-y-1/2 bg-white/10 hover:bg-white/20 p-2 rounded-full text-white hidden md:block transition-colors"
        >
          <ChevronRight size={24} />
        </button>

        {/* Side Previews (Desktop) */}
        <div
          className="absolute -right-[220px] top-1/2 -translate-y-1/2 w-[180px] h-[320px] opacity-40 scale-90 hidden lg:block"
          onClick={(e) => {
            e.stopPropagation();
            goNextStory();
          }}
        >
          {stories[currentIndex + 1] && (
            <div className="w-full h-full bg-gray-800 rounded-xl overflow-hidden relative">
              <img
                src={
                  stories[currentIndex + 1].imageUrl ||
                  `https://images.unsplash.com/photo-1526947425960-945c6e72858f?w=500&auto=format&fit=crop&q=60`
                }
                className="w-full h-full object-cover opacity-50"
              />
              <div className="absolute bottom-4 left-0 right-0 text-center text-white text-sm font-semibold">
                {stories[currentIndex + 1].username}
              </div>
            </div>
          )}
        </div>
        <div
          className="absolute -left-[220px] top-1/2 -translate-y-1/2 w-[180px] h-[320px] opacity-40 scale-90 hidden lg:block"
          onClick={(e) => {
            e.stopPropagation();
            goPrevStory();
          }}
        >
          {stories[currentIndex - 1] && (
            <div className="w-full h-full bg-gray-800 rounded-xl overflow-hidden relative">
              <img
                src={
                  stories[currentIndex - 1].imageUrl ||
                  `https://images.unsplash.com/photo-1526947425960-945c6e72858f?w=500&auto=format&fit=crop&q=60`
                }
                className="w-full h-full object-cover opacity-50"
              />
              <div className="absolute bottom-4 left-0 right-0 text-center text-white text-sm font-semibold">
                {stories[currentIndex - 1].username}
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default StoryViewer;
