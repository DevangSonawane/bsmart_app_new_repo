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
          const avatarUrl =
            rawAvatarUrl && rawAvatarUrl.trim() !== '' ? rawAvatarUrl : '';

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
                  imageUrl =
                    firstMedia.thumbnail || firstMedia.url || imageUrl;
                  previewDurationSec =
                    firstMedia.durationSec || previewDurationSec;
                }
              }

              return {
                ...story,
                imageUrl,
                previewDurationSec,
                itemsCount: items.length,
              };
            } catch (err) {
              console.error('Error fetching story items for rail:', err);
              return story;
            }
          })
        );

        let finalStories = storiesWithItems;

        if (userObject) {
          const currentUserId = userObject.id || userObject._id;
          const ownIndex = storiesWithItems.findIndex(
            (s) =>
              (s.userId && s.userId === currentUserId) ||
              (s.username && s.username === userObject.username)
          );

          if (ownIndex !== -1) {
            const ownStory = {
              ...storiesWithItems[ownIndex],
              isUser: true,
            };
            finalStories = [
              ownStory,
              ...storiesWithItems.filter((_, i) => i !== ownIndex),
            ];
          } else {
            const yourStory = {
              id: 'your_story',
              username: 'Your Story',
              isUser: true,
              avatarUrl: userObject.avatar_url || '',
              imageUrl: userObject.avatar_url || '',
              previewDurationSec: 5,
              itemsCount: 0,
              seen: false,
            };
            finalStories = [yourStory, ...storiesWithItems];
          }
        } else {
          const yourStory = {
            id: 'your_story',
            username: 'Your Story',
            isUser: true,
            avatarUrl: '',
            imageUrl:
              'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=500&auto=format&fit=crop&q=60',
            previewDurationSec: 5,
            itemsCount: 0,
            seen: false,
          };
          finalStories = [yourStory, ...storiesWithItems];
        }

        setStories(finalStories);
      } catch (error) {
        console.error('Error fetching stories:', error);
        const rawAvatar = userObject?.avatar_url || '';
        const avatarUrl =
          rawAvatar && rawAvatar.trim() !== '' ? rawAvatar : '';
        const fallbackStories = [
          {
            id: 'your_story',
            username: 'Your Story',
            isUser: true,
            avatarUrl,
            imageUrl: avatarUrl,
            previewDurationSec: 5,
            itemsCount: 0,
            seen: false,
          },
        ];
        setStories(fallbackStories);
      }
    };

    fetchStories();
  }, [userObject]);

  const handleStoryClick = (index) => {
    const story = stories[index];
    if (!story) return;
    if (!story.itemsCount || story.itemsCount === 0) {
      return;
    }
    setSelectedStoryIndex(index);
  };

  return (
    <>
      <div className="bg-white dark:bg-black border-b border-gray-200 dark:border-gray-800 py-4 mb-2">
        <div className="flex gap-4 overflow-x-auto px-4 no-scrollbar">
          {stories.map((story, index) => (
            <button
              key={story.id}
              className="flex flex-col items-center min-w-[70px] cursor-pointer"
              onClick={() => handleStoryClick(index)}
            >
              <div
                className={`w-16 h-16 rounded-full p-[2px] ${story.isUser && story.itemsCount === 0
                  ? 'border-2 border-gray-300 dark:border-gray-700'
                  : 'bg-gradient-to-tr from-insta-yellow via-insta-orange to-insta-pink'
                  }`}
              >
                <div className="w-full h-full rounded-full bg-white dark:bg-black p-[2px] overflow-hidden flex items-center justify-center">
                  {story.isUser ? (
                    <div className="w-full h-full rounded-full bg-gradient-to-tr from-insta-yellow via-insta-orange to-insta-pink flex items-center justify-center text-xs font-bold text-white">
                      {story.username ? story.username.charAt(0).toUpperCase() : 'U'}
                    </div>
                  ) : story.avatarUrl ? (
                    <img
                      src={story.avatarUrl}
                      alt={story.username}
                      className="w-full h-full rounded-full object-cover"
                    />
                  ) : (
                    <div className="w-full h-full rounded-full bg-gradient-to-tr from-insta-yellow via-insta-orange to-insta-pink flex items-center justify-center text-xs font-bold text-white">
                      {story.username ? story.username.charAt(0).toUpperCase() : 'U'}
                    </div>
                  )}
                </div>
              </div>
              <span className="text-xs mt-1 truncate w-full text-center text-gray-700 dark:text-gray-200">
                {story.isUser ? 'Your Story' : story.username}
              </span>
            </button>
          ))}
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
