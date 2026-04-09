import React, { useEffect, useState } from 'react';
import StoryViewer from './StoryViewer';
import api from '../lib/api';
import { useSelector } from 'react-redux';
import { Plus } from 'lucide-react';

const StoryRail = () => {
  const [stories, setStories] = useState([]);
  const [selectedStoryIndex, setSelectedStoryIndex] = useState(null);
  const { userObject } = useSelector((state) => state.auth);

  useEffect(() => {
    const fetchStories = async () => {
      try {
        const token = localStorage.getItem('token');
        const response = await api.get('/stories/feed', {
          headers: token ? { Authorization: `Bearer ${token}` } : {},
        });

        const feedStories = (response.data || []).map((story) => {
          const media = story.preview_item?.media;
          const rawAvatarUrl = story.user?.avatar_url || '';
          const avatarUrl = rawAvatarUrl.trim() !== '' ? rawAvatarUrl : '';
          let previewUrl = '';
          let previewDurationSec = 5;
          if (Array.isArray(media) && media.length > 0) {
            const first = media[0];
            previewUrl = first.thumbnail || first.url || '';
            previewDurationSec = first.durationSec || 5;
          } else if (media) {
            previewUrl = media.thumbnail || media.url || '';
            previewDurationSec = media.durationSec || 5;
          }
          return {
            id: story._id,
            userId: story.user?._id || story.user_id,
            username: story.user?.username || 'User',
            avatarUrl,
            imageUrl: previewUrl,
            previewDurationSec,
            itemsCount: story.items_count || 0,
            seen: story.seen,
          };
        });

        const storiesWithItems = await Promise.all(
          feedStories.map(async (story) => {
            try {
              const res = await api.get(`/stories/${story.id}/items`);
              const items = Array.isArray(res.data) ? res.data : [];
              let imageUrl = story.imageUrl;
              let previewDurationSec = story.previewDurationSec;
              if (items.length > 0) {
                const firstItem = items[0];
                const mediaArr = firstItem.media;
                if (Array.isArray(mediaArr) && mediaArr.length > 0) {
                  const firstMedia = mediaArr[0];
                  imageUrl = firstMedia.thumbnail || firstMedia.url || imageUrl;
                  previewDurationSec = firstMedia.durationSec || previewDurationSec;
                }
              }
              return { ...story, imageUrl, previewDurationSec, itemsCount: items.length };
            } catch {
              return story;
            }
          })
        );

        let finalStories = storiesWithItems;
        if (userObject) {
          const currentUserId = userObject.id || userObject._id;
          const ownIndex = storiesWithItems.findIndex(
            (s) => (s.userId && s.userId === currentUserId) || (s.username && s.username === userObject.username)
          );
          if (ownIndex !== -1) {
            finalStories = [{ ...storiesWithItems[ownIndex], isUser: true }, ...storiesWithItems.filter((_, i) => i !== ownIndex)];
          } else {
            finalStories = [
              { id: 'your_story', username: userObject.username || 'Your Story', isUser: true, avatarUrl: userObject.avatar_url || '', imageUrl: userObject.avatar_url || '', previewDurationSec: 5, itemsCount: 0, seen: false },
              ...storiesWithItems,
            ];
          }
        } else {
          finalStories = [
            { id: 'your_story', username: 'Your Story', isUser: true, avatarUrl: '', imageUrl: '', previewDurationSec: 5, itemsCount: 0, seen: false },
            ...storiesWithItems,
          ];
        }
        setStories(finalStories);
      } catch (error) {
        console.error('Error fetching stories:', error);
        const avatarUrl = userObject?.avatar_url?.trim() || '';
        setStories([{ id: 'your_story', username: userObject?.username || 'Your Story', isUser: true, avatarUrl, imageUrl: avatarUrl, previewDurationSec: 5, itemsCount: 0, seen: false }]);
      }
    };
    fetchStories();
  }, [userObject]);

  const handleStoryClick = (index) => {
    const story = stories[index];
    if (!story) return;
    if (story.isUser && (!story.itemsCount || story.itemsCount === 0)) return;
    setSelectedStoryIndex(index);
  };

  return (
    <>
      {/* ── Story Rail ── */}
      <div className="bg-white dark:bg-black border-b border-gray-200 dark:border-gray-800 py-3">
        <div className="flex gap-3 overflow-x-auto px-4 no-scrollbar pb-1">
          {stories.map((story, index) => {
            const isYourStory  = story.isUser && (!story.itemsCount || story.itemsCount === 0);
            const hasSeen      = story.seen;
            const hasStory     = story.itemsCount > 0;
            const username     = story.isUser ? (story.username || 'Your Story') : story.username;
            const displayName  = username.length > 10 ? username.slice(0, 9) + '…' : username;

            return (
              <button
                key={story.id}
                className="flex flex-col items-center gap-1 min-w-[72px] cursor-pointer flex-shrink-0 group"
                onClick={() => handleStoryClick(index)}
              >
                {/* Avatar ring */}
                <div className="relative">
                  {/* Gradient ring: orange-pink for unseen, gray for seen / no story */}
                  <div className={`
                    w-[66px] h-[66px] rounded-full p-[2.5px] flex items-center justify-center
                    ${isYourStory
                      ? 'border-2 border-dashed border-gray-300 dark:border-gray-600 p-[2px]'
                      : hasStory && !hasSeen
                        ? 'bg-gradient-to-tr from-yellow-400 via-orange-500 to-pink-600'
                        : 'bg-gradient-to-tr from-gray-300 to-gray-400 dark:from-gray-600 dark:to-gray-700'
                    }
                  `}>
                    <div className="w-full h-full rounded-full bg-white dark:bg-black p-[2px]">
                      {story.avatarUrl ? (
                        <img
                          src={story.avatarUrl}
                          alt={username}
                          className="w-full h-full rounded-full object-cover"
                        />
                      ) : (
                        <div className="w-full h-full rounded-full bg-gradient-to-tr from-yellow-400 via-orange-500 to-pink-600 flex items-center justify-center text-sm font-bold text-white">
                          {username.charAt(0).toUpperCase()}
                        </div>
                      )}
                    </div>
                  </div>

                  {/* + badge for your story with no items */}
                  {isYourStory && (
                    <div className="absolute bottom-0 right-0 w-5 h-5 bg-blue-500 rounded-full border-2 border-white dark:border-black flex items-center justify-center shadow-sm">
                      <Plus size={11} strokeWidth={3} className="text-white" />
                    </div>
                  )}
                </div>

                {/* Username */}
                <span className={`text-[11px] leading-tight text-center w-[72px] truncate ${story.isUser ? 'font-semibold text-gray-900 dark:text-white' : 'text-gray-700 dark:text-gray-300'}`}>
                  {story.isUser ? 'Your Story' : displayName}
                </span>
              </button>
            );
          })}
        </div>
      </div>

      {selectedStoryIndex !== null && stories.length > 0 && (
        <StoryViewer
          initialStoryIndex={selectedStoryIndex}
          stories={stories}
          onClose={() => setSelectedStoryIndex(null)}
        />
      )}
    </>
  );
};

export default StoryRail;