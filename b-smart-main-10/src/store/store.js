import { configureStore } from '@reduxjs/toolkit';
import authReducer from './authSlice';
import themeReducer from './themeSlice';
import walletReducer from './walletSlice';

export const store = configureStore({
  reducer: {
    auth: authReducer,
    theme: themeReducer,
    wallet: walletReducer,
  },
});