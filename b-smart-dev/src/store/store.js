import { configureStore } from '@reduxjs/toolkit';
import authReducer from './authSlice';
import themeReducer from './themeSlice';
import walletReducer from './walletSlice';
import chatReducer from './chatSlice';
import storyReducer from './storySlice';
import cartReducer from './cartSlice';
import productsReducer from './productsSlice';
import servicesReducer from './servicesSlice';
import ordersReducer from './ordersSlice';
import bookingsReducer from './bookingsSlice';
import wishlistReducer, { WISHLIST_STORAGE_KEY } from './wishlistSlice';

export const store = configureStore({
  reducer: {
    auth: authReducer,
    theme: themeReducer,
    wallet: walletReducer,
    chat: chatReducer,
    story: storyReducer,
    cart: cartReducer,
    products: productsReducer,
    services: servicesReducer,
    orders: ordersReducer,
    bookings: bookingsReducer,
    wishlist: wishlistReducer,
  },
});

if (typeof window !== 'undefined') {
  let previousWishlist = store.getState().wishlist;
  store.subscribe(() => {
    const wishlist = store.getState().wishlist;
    if (wishlist === previousWishlist) return;
    previousWishlist = wishlist;
    try {
      window.localStorage.setItem(WISHLIST_STORAGE_KEY, JSON.stringify(wishlist.byUser));
    } catch {
      // The wishlist still works for this session when browser storage is unavailable.
    }
  });
}
