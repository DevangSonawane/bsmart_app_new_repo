import { createSlice, createAsyncThunk } from '@reduxjs/toolkit';
import api from '../lib/api';

// ─── Async Thunk: fetch wallet balance ───────────────────────────────────────
export const fetchWallet = createAsyncThunk(
  'wallet/fetchWallet',
  async (_, thunkAPI) => {
    // Try multiple endpoint shapes the backend might expose
    const endpoints = ['/wallet/me', '/wallet', '/users/wallet'];
    for (const ep of endpoints) {
      try {
        const res = await api.get(ep, {
          headers: { 'Cache-Control': 'no-cache, no-store' },
        });
        const data = res?.data;
        const bal =
          data?.wallet?.balance ??
          data?.balance ??
          data?.data?.wallet?.balance ??
          data?.data?.balance ??
          data?.user?.wallet?.balance ??
          data?.coins ??
          data?.coin_balance;
        if (bal !== undefined && bal !== null) {
          return Math.floor(Number(bal));
        }
      } catch {
        // try next endpoint
      }
    }
    // Return current state value if all fail (no change)
    return thunkAPI.getState().wallet.balance;
  }
);

// ─── Slice ────────────────────────────────────────────────────────────────────
const walletSlice = createSlice({
  name: 'wallet',
  initialState: {
    balance: 0,
    loading: false,
    lastFetched: null,
  },
  reducers: {
    // Directly set balance (e.g. from API response inline)
    setWalletBalance: (state, action) => {
      state.balance = Math.floor(Number(action.payload) || 0);
      state.lastFetched = Date.now();
    },
    // Optimistically add/subtract coins
    adjustBalance: (state, action) => {
      state.balance = Math.max(0, state.balance + Number(action.payload));
    },
  },
  extraReducers: (builder) => {
    builder
      .addCase(fetchWallet.pending, (state) => {
        state.loading = true;
      })
      .addCase(fetchWallet.fulfilled, (state, action) => {
        state.loading = false;
        if (action.payload !== undefined && action.payload !== null) {
          state.balance = action.payload;
        }
        state.lastFetched = Date.now();
      })
      .addCase(fetchWallet.rejected, (state) => {
        state.loading = false;
      });
  },
});

export const { setWalletBalance, adjustBalance } = walletSlice.actions;
export default walletSlice.reducer;