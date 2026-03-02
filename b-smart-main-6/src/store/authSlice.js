import { createSlice, createAsyncThunk } from '@reduxjs/toolkit';
import authService from '../services/authService';

// Async Thunks
export const login = createAsyncThunk('auth/login', async (credentials, thunkAPI) => {
  try {
    const data = await authService.login(credentials);
    return data;
  } catch (error) {
    const message =
      (error.response && error.response.data && error.response.data.message) ||
      error.message ||
      error.toString();
    return thunkAPI.rejectWithValue(message);
  }
});

export const fetchMe = createAsyncThunk('auth/fetchMe', async (_, thunkAPI) => {
  try {
    return await authService.getMe();
  } catch (error) {
    const message =
      (error.response && error.response.data && error.response.data.message) ||
      error.message ||
      error.toString();
    return thunkAPI.rejectWithValue(message);
  }
});

export const logoutUser = createAsyncThunk('auth/logout', async () => {
  authService.logout();
});

const initialState = {
  userObject: null,
  isAuthenticated: false,
  loading: true,
  error: null,
};

const authSlice = createSlice({
  name: 'auth',
  initialState,
  reducers: {
    reset: (state) => {
      state.loading = false;
      state.error = null;
    },
    setUser: (state, action) => {
      state.userObject = action.payload;
      state.isAuthenticated = !!action.payload;
      state.loading = false;
    },
    setLoading: (state, action) => {
      state.loading = action.payload;
    },
  },
  extraReducers: (builder) => {
    builder
      .addCase(login.pending, (state) => {
        state.loading = true;
        state.error = null;
      })
      .addCase(login.fulfilled, (state, action) => {
        state.loading = false;
        state.isAuthenticated = true;
        state.userObject = action.payload?.user || action.payload;
      })
      .addCase(login.rejected, (state, action) => {
        state.loading = false;
        state.error = action.payload;
        state.isAuthenticated = false;
        state.userObject = null;
      })  
      .addCase(fetchMe.pending, (state) => {
        state.loading = true;
      })
      .addCase(fetchMe.fulfilled, (state, action) => {
        state.loading = false;
        state.isAuthenticated = true;
        state.userObject = action.payload?.user || action.payload;
      })
      .addCase(fetchMe.rejected, (state) => {
        state.loading = false;
        state.isAuthenticated = false;
        state.userObject = null;
      })
      .addCase(logoutUser.fulfilled, (state) => {
        state.userObject = null;
        state.isAuthenticated = false;
        state.loading = false;
      });
  },
});

export const { reset, setUser, setLoading } = authSlice.actions;
export default authSlice.reducer;
