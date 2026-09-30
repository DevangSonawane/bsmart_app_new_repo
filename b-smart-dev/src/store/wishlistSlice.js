import { createAsyncThunk, createSlice } from '@reduxjs/toolkit';
import wishlistService from '../services/wishlistService';

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

// ── Server-backed wishlist (GET /wishlist + /wishlist/items) ────────────────
// Products live on the backend; services stay local-only (API is product-only).

export const fetchWishlist = createAsyncThunk(
  'wishlist/fetchWishlist',
  async (_, thunkAPI) => {
    try {
      return await wishlistService.getWishlist();
    } catch (error) {
      const message =
        (error.response && error.response.data && (error.response.data.message || error.response.data.error)) ||
        error.message ||
        'Failed to load wishlist';
      return thunkAPI.rejectWithValue(message);
    }
  },
);

export const addWishlistItem = createAsyncThunk(
  'wishlist/addItem',
  async (productId, thunkAPI) => {
    try {
      const updated = await wishlistService.addItem(productId);
      if (updated) return updated;
      return await wishlistService.getWishlist();
    } catch (error) {
      if (error?.response?.status === 404) return thunkAPI.rejectWithValue('Product not found');
      const message =
        (error.response && error.response.data && (error.response.data.message || error.response.data.error)) ||
        error.message ||
        'Failed to add to wishlist';
      return thunkAPI.rejectWithValue(message);
    }
  },
);

export const removeWishlistItem = createAsyncThunk(
  'wishlist/removeItem',
  async (productId, thunkAPI) => {
    try {
      const updated = await wishlistService.removeItem(productId);
      if (updated) return updated;
      return await wishlistService.getWishlist();
    } catch (error) {
      const message =
        (error.response && error.response.data && (error.response.data.message || error.response.data.error)) ||
        error.message ||
        'Failed to remove from wishlist';
      return thunkAPI.rejectWithValue(message);
    }
  },
);

export const clearWishlist = createAsyncThunk(
  'wishlist/clear',
  async (_, thunkAPI) => {
    try {
      return await wishlistService.clear();
    } catch (error) {
      const message =
        (error.response && error.response.data && (error.response.data.message || error.response.data.error)) ||
        error.message ||
        'Failed to clear wishlist';
      return thunkAPI.rejectWithValue(message);
    }
  },
);

const wishlistSlice = createSlice({
  name: 'wishlist',
  initialState: {
    ...loadWishlist(),
    // Server state — full product objects, newest first
    serverItems: [],
    serverStatus: 'idle', // idle | loading | succeeded | failed
    serverError: null,
    mutatingId: null,
    clearing: false,
  },
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
    resetWishlistServer: (state) => {
      state.serverItems = [];
      state.serverStatus = 'idle';
      state.serverError = null;
    },
  },
  extraReducers: (builder) => {
    builder
      .addCase(fetchWishlist.pending, (state) => {
        state.serverStatus = 'loading';
        state.serverError = null;
      })
      .addCase(fetchWishlist.fulfilled, (state, action) => {
        state.serverStatus = 'succeeded';
        state.serverItems = action.payload;
      })
      .addCase(fetchWishlist.rejected, (state, action) => {
        state.serverStatus = 'failed';
        state.serverError = action.payload;
      })
      .addCase(addWishlistItem.pending, (state, action) => {
        state.mutatingId = String(action.meta.arg);
        state.serverError = null;
      })
      .addCase(addWishlistItem.fulfilled, (state, action) => {
        state.mutatingId = null;
        state.serverItems = action.payload;
        state.serverStatus = 'succeeded';
      })
      .addCase(addWishlistItem.rejected, (state, action) => {
        state.mutatingId = null;
        state.serverError = action.payload;
      })
      .addCase(removeWishlistItem.pending, (state, action) => {
        state.mutatingId = String(action.meta.arg);
        state.serverError = null;
      })
      .addCase(removeWishlistItem.fulfilled, (state, action) => {
        state.mutatingId = null;
        state.serverItems = action.payload;
        state.serverStatus = 'succeeded';
      })
      .addCase(removeWishlistItem.rejected, (state, action) => {
        state.mutatingId = null;
        state.serverError = action.payload;
      })
      .addCase(clearWishlist.pending, (state) => {
        state.clearing = true;
        state.serverError = null;
      })
      .addCase(clearWishlist.fulfilled, (state, action) => {
        state.clearing = false;
        state.serverItems = action.payload;
        state.serverStatus = 'succeeded';
      })
      .addCase(clearWishlist.rejected, (state, action) => {
        state.clearing = false;
        state.serverError = action.payload;
      });
  },
});

export const { toggleWishlistItem, resetWishlistServer } = wishlistSlice.actions;
export default wishlistSlice.reducer;
