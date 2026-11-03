import { createAsyncThunk, createSlice } from '@reduxjs/toolkit';
import wishlistService from '../services/wishlistService';

export const fetchWishlist = createAsyncThunk('wishlist/fetch', async (_, thunkAPI) => {
  try {
    return await wishlistService.list();
  } catch (error) {
    return thunkAPI.rejectWithValue(error?.response?.data?.message || 'Could not load wishlist.');
  }
});

const wishlistArg = (value) => (
  value && typeof value === 'object'
    ? { productId: value.productId ?? value.id, product: value.product }
    : { productId: value, product: null }
);

export const addWishlistItem = createAsyncThunk('wishlist/addItem', async (value, thunkAPI) => {
  const { productId } = wishlistArg(value);
  try {
    return await wishlistService.addItem(productId);
  } catch (error) {
    return thunkAPI.rejectWithValue(error?.response?.data?.message || 'Could not add to wishlist.');
  }
});

export const removeWishlistItem = createAsyncThunk('wishlist/removeItem', async (value, thunkAPI) => {
  const { productId } = wishlistArg(value);
  try {
    return await wishlistService.removeItem(productId);
  } catch (error) {
    return thunkAPI.rejectWithValue(error?.response?.data?.message || 'Could not remove from wishlist.');
  }
});

export const clearWishlist = createAsyncThunk('wishlist/clear', async (_, thunkAPI) => {
  try {
    return await wishlistService.clear();
  } catch (error) {
    return thunkAPI.rejectWithValue(error?.response?.data?.message || 'Could not clear wishlist.');
  }
});

const wishlistSlice = createSlice({
  name: 'wishlist',
  initialState: {
    products: [],
    loading: false,
    error: '',
  },
  reducers: {},
  extraReducers: (builder) => {
    const pending = (state) => {
      state.loading = true;
      state.error = '';
    };
    const fulfilled = (state, action) => {
      state.loading = false;
      state.products = action.payload || [];
      state.error = '';
    };
    const rejected = (state, action) => {
      state.loading = false;
      state.error = action.payload || 'Wishlist update failed.';
    };

    builder
      .addCase(fetchWishlist.pending, pending)
      .addCase(fetchWishlist.fulfilled, fulfilled)
      .addCase(fetchWishlist.rejected, rejected)
      .addCase(addWishlistItem.pending, (state, action) => {
        state.loading = true;
        state.error = '';
        const { productId, product } = wishlistArg(action.meta.arg);
        if (productId != null && !state.products.some((item) => String(item.id) === String(productId))) {
          state.products.unshift({ ...(product || {}), id: productId, optimistic: true });
        }
      })
      .addCase(addWishlistItem.fulfilled, (state, action) => {
        state.loading = false;
        state.error = '';
        const productId = action.payload?.productId;
        const item = state.products.find((product) => String(product.id) === String(productId));
        if (item) item.optimistic = false;
      })
      .addCase(addWishlistItem.rejected, (state, action) => {
        state.loading = false;
        state.error = action.payload || 'Wishlist update failed.';
        const { productId } = wishlistArg(action.meta.arg);
        state.products = state.products.filter((item) => String(item.id) !== String(productId));
      })
      .addCase(removeWishlistItem.pending, (state, action) => {
        state.loading = true;
        state.error = '';
        const { productId } = wishlistArg(action.meta.arg);
        state.products = state.products.filter((item) => String(item.id) !== String(productId));
      })
      .addCase(removeWishlistItem.fulfilled, (state) => {
        state.loading = false;
        state.error = '';
      })
      .addCase(removeWishlistItem.rejected, (state, action) => {
        state.loading = false;
        state.error = action.payload || 'Wishlist update failed.';
        const { productId, product } = wishlistArg(action.meta.arg);
        if (productId != null && product && !state.products.some((item) => String(item.id) === String(productId))) {
          state.products.unshift({ ...product, id: productId });
        }
      })
      .addCase(clearWishlist.pending, pending)
      .addCase(clearWishlist.fulfilled, fulfilled)
      .addCase(clearWishlist.rejected, rejected);
  },
});

export default wishlistSlice.reducer;
