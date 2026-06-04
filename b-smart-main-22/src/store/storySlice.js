import { createSlice } from '@reduxjs/toolkit';

const BASE_URL = 'https://api.bebsmart.in';

const storySlice = createSlice({
  name: 'story',
  initialState: {
    storyMap: {}, // { [userId]: storyObj | null }
  },
  reducers: {
    setUserStory(state, action) {
      const { userId, story } = action.payload;
      state.storyMap[userId] = story;
    },
    clearStories(state) {
      state.storyMap = {};
    },
  },
});

export const { setUserStory, clearStories } = storySlice.actions;
export default storySlice.reducer;

// ── Thunk: fetch story for a user and cache in Redux ─────────────────────────
export const fetchUserStory = (userId, { avatarUrl = '', username = '' } = {}) =>
  async (dispatch, getState) => {
    if (!userId) return;
    // Skip if already fetched (null means "no story", object means "has story")
    const cached = getState().story.storyMap[userId];
    if (cached !== undefined) return;

    const token = localStorage.getItem('token');
    const headers = {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    };
    try {
      const res = await fetch(`${BASE_URL}/api/stories/user/${userId}`, { headers });
      if (!res.ok) { dispatch(setUserStory({ userId, story: null })); return; }
      const data = await res.json();
      const list = Array.isArray(data) ? data : (data.stories || data.data || []);
      if (!list.length) { dispatch(setUserStory({ userId, story: null })); return; }

      const s = list[0];
      const rawMedia = s.preview_item?.media;
      let imageUrl = '';
      if (Array.isArray(rawMedia) && rawMedia.length > 0) {
        imageUrl = rawMedia[0].thumbnail || rawMedia[0].url || '';
      } else if (rawMedia) {
        imageUrl = rawMedia.thumbnail || rawMedia.url || '';
      }

      dispatch(setUserStory({
        userId,
        story: {
          id: s._id,
          userId: s.user?._id || s.user_id || userId,
          username: s.user?.username || username || 'User',
          avatarUrl,
          imageUrl,
          previewDurationSec: 5,
          itemsCount: s.items_count || 1,
          seen: s.seen || false,
          createdAt: s.createdAt || null,
        },
      }));
    } catch {
      dispatch(setUserStory({ userId, story: null }));
    }
  };
