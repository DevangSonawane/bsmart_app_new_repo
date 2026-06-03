import React, { useEffect, useState } from 'react';
import StoryViewer from './StoryViewer';
import api from '../lib/api';
import { useSelector } from 'react-redux';

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
          finalStories = storiesWithItems.filter(
            (s) => s.userId !== currentUserId && s.username !== userObject.username
          );
        }
        setStories(finalStories);
      } catch (error) {
        console.error('Error fetching stories:', error);
        setStories([]);
      }
    };
    fetchStories();
  }, [userObject]);

  const handleStoryClick = (index) => {
    const story = stories[index];
    if (!story || story.itemsCount === 0) return;
    setSelectedStoryIndex(index);
  };

  return (
    <>
      {/* ── Story Rail ── */}
      <div className="bg-white dark:bg-black py-3">
        <div className="flex gap-3 overflow-x-auto px-4 no-scrollbar pb-1 xl:px-0">
          {stories.map((story, index) => {
            const hasSeen     = story.seen;
            const hasStory    = story.itemsCount > 0;
            const username    = story.username || 'User';
            const displayName = username.length > 10 ? username.slice(0, 9) + '…' : username;

            return (
              <button
                key={story.id}
                className="flex flex-col items-center gap-1 min-w-[72px] cursor-pointer flex-shrink-0 group"
                onClick={() => handleStoryClick(index)}
              >
                {/* Avatar ring */}
                <div className="relative">
                  <div className={`
                    w-[66px] h-[66px] rounded-full p-[2.5px] flex items-center justify-center
                    ${hasStory && !hasSeen ? 'bg-orange-500' : 'bg-gray-200 dark:bg-gray-800'}
                  `}>
                    <div className="w-full h-full rounded-full bg-white dark:bg-black p-[2px]">
                      {story.avatarUrl ? (
                        <img
                          src={story.avatarUrl}
                          alt={username}
                          className="w-full h-full rounded-full object-cover"
                        />
                      ) : (
                        <div className="w-full h-full rounded-full bg-gray-100 dark:bg-gray-800 flex items-center justify-center text-sm font-bold text-gray-500">
                          {username.charAt(0).toUpperCase()}
                        </div>
                      )}
                    </div>
                  </div>
                </div>

                {/* Username */}
                <span className="text-[11px] leading-tight text-center w-[72px] truncate text-gray-700 dark:text-gray-300">
                  {displayName}
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
