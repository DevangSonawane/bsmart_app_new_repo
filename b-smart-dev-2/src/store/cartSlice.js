import { createSlice } from '@reduxjs/toolkit';

const CART_STORAGE_KEY = 'cart_items';

// Cart lives client-side only (no per-action backend sync — items are pushed
// to the server in one batch right before checkout, via cartService.syncItems).
// Persisted to localStorage so a page refresh doesn't wipe it; cleared on
// checkout success (setCartItems([])) or clearCart(), which also clears storage.
const getInitialCartItems = () => {
  if (typeof window === 'undefined' || !window.localStorage) return [];
  try {
    const stored = window.localStorage.getItem(CART_STORAGE_KEY);
    const parsed = stored ? JSON.parse(stored) : [];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
};

const persistCartItems = (items) => {
  if (typeof window === 'undefined' || !window.localStorage) return;
  try {
    window.localStorage.setItem(CART_STORAGE_KEY, JSON.stringify(items));
  } catch {
    // Storage unavailable (private browsing, quota, etc.) — cart still works for this session.
  }
};

const cartSlice = createSlice({
  name: 'cart',
  initialState: {
    items: getInitialCartItems(), // { id, name, subtitle, brand, price, qty, category }
  },
  reducers: {
    setCartItems: (state, action) => {
      state.items = action.payload || [];
      persistCartItems(state.items);
    },
    addItem: (state, action) => {
      const { id, qty = 1 } = action.payload;
      const existing = state.items.find((i) => i.id === id);
      if (existing) {
        existing.qty += qty;
        existing.saved = false;
        existing.selected = true;
      } else {
        state.items.push({ ...action.payload, qty });
      }
      persistCartItems(state.items);
    },
    removeItem: (state, action) => {
      state.items = state.items.filter((i) => i.id !== action.payload);
      persistCartItems(state.items);
    },
    incrementQty: (state, action) => {
      const item = state.items.find((i) => i.id === action.payload);
      if (item) item.qty += 1;
      persistCartItems(state.items);
    },
    decrementQty: (state, action) => {
      const item = state.items.find((i) => i.id === action.payload);
      if (item && item.qty > 1) item.qty -= 1;
      persistCartItems(state.items);
    },
    clearCart: (state) => {
      state.items = [];
      persistCartItems(state.items);
    },
    toggleSelection: (state, action) => {
      const item = state.items.find((i) => i.id === action.payload);
      if (item && !item.saved) item.selected = item.selected === false;
      persistCartItems(state.items);
    },
    selectAll: (state, action) => {
      state.items.forEach((item) => { if (!item.saved) item.selected = action.payload; });
      persistCartItems(state.items);
    },
    toggleSaved: (state, action) => {
      const item = state.items.find((i) => i.id === action.payload);
      if (item) { item.saved = !item.saved; item.selected = !item.saved; }
      persistCartItems(state.items);
    },
    checkoutSelected: (state) => {
      state.items = state.items.filter((item) => item.saved || item.selected === false);
      persistCartItems(state.items);
    },
  },
});

export const { setCartItems, addItem, removeItem, incrementQty, decrementQty, clearCart, toggleSelection, selectAll, toggleSaved, checkoutSelected } = cartSlice.actions;
export default cartSlice.reducer;
