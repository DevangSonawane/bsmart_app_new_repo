import { configureStore } from '@reduxjs/toolkit';
import authReducer from './authSlice';
import themeReducer from './themeSlice';
import walletReducer from './walletSlice';
import chatReducer from './chatSlice';
import storyReducer from './storySlice';

export const store = configureStore({
  reducer: {
    auth: authReducer,
    theme: themeReducer,
    wallet: walletReducer,
    chat: chatReducer,
    story: storyReducer,
  },
});
