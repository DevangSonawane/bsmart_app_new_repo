import { createSlice } from '@reduxjs/toolkit';

export const WISHLIST_STORAGE_KEY = 'bsmart_marketplace_wishlist';

const loadWishlist = () => {
  try {
    const saved = JSON.parse(window.localStorage.getItem(WISHLIST_STORAGE_KEY) || '{}');
    if (!saved || typeof saved !== 'object' || Array.isArray(saved)) return { byUser: {} };
    const byUser = {};
    for (const [userId, items] of Object.entries(saved)) {
      if (!Array.isArray(items)) continue;
      byUser[userId] = items.filter((item) => item && ['product', 'service'].includes(item.type) && item.id != null)
        .map((item) => ({ type: item.type, id: String(item.id) }));
    }
    return { byUser };
  } catch {
    return { byUser: {} };
  }
};

const wishlistSlice = createSlice({
  name: 'wishlist',
  initialState: loadWishlist,
  reducers: {
    toggleWishlistItem: (state, { payload }) => {
      const { userId, type, id } = payload;
      if (!userId || !['product', 'service'].includes(type) || id == null) return;
      const items = state.byUser[userId] || (state.byUser[userId] = []);
      const itemId = String(id);
      const index = items.findIndex((item) => item.type === type && item.id === itemId);
      if (index === -1) items.push({ type, id: itemId });
      else items.splice(index, 1);
    },
  },
});

export const { toggleWishlistItem } = wishlistSlice.actions;
export default wishlistSlice.reducer;
