import React, { useEffect } from 'react';
import { BrowserRouter, Routes, Route } from 'react-router-dom';
import { useDispatch, useSelector } from 'react-redux';
import { fetchMe, setLoading } from './store/authSlice';
import socketService from './services/socketService';

import Layout from './components/Layout';
import Home from './pages/Home';
import CreatePost from './pages/CreatePost';
import Reels from './pages/Reels';
import Promote from './pages/Promote';
import Ads from './pages/Ads';
import VendorAds from './pages/VendorAds';
import AdPublicDetail from './pages/AdPublicDetail';
import Profile from './pages/Profile';
import Settings from './pages/Settings';
import Login from './pages/Login';
import Signup from './pages/Signup';
import VendorSignup from './pages/VendorSignup';
import ForgotPassword from './pages/ForgotPassword';
import VerifyOtp from './pages/VerifyOtp';
import EditProfile from './pages/EditProfile';
import WalletDetails from './pages/WalletDetails';
import MobilePostDetail from './pages/MobilePostDetail';
import AuthCallback from './pages/AuthCallback';
import Notifications from './pages/Notifications';
import VendorNotifications from './pages/vendor-pages/VendorNotifications';
import ProtectedRoute from './components/ProtectedRoute';
import Search from './pages/Search';
import ChatPage from './pages/ChatPage';

import VendorPublicProfile from './pages/VendorPublicProfile';
import VendorLayout from './components/VendorLayout';
import VendorDashboard from './pages/vendor-pages/Dashboard';
import VendorProfile from './pages/vendor-pages/VendorProfile';
import AdsManagement from './pages/vendor-pages/AdsManagement';
import AdDetails from './pages/vendor-pages/AdDetails';
import ReportsAnalytics from './pages/vendor-pages/ReportsAnalytics';
import CoinsBilling from './pages/vendor-pages/CoinsBilling';
import VendorSettings from './pages/vendor-pages/Settings';

function App() {
  const dispatch = useDispatch();
  const { mode } = useSelector((state) => state.theme);
  const { isAuthenticated } = useSelector((state) => state.auth);

  // ── Theme ────────────────────────────────────────────────────────────────
  useEffect(() => {
    if (mode === 'dark') {
      document.documentElement.classList.add('dark');
    } else {
      document.documentElement.classList.remove('dark');
    }
  }, [mode]);

  // ── Auth — fetch user on app load ────────────────────────────────────────
  useEffect(() => {
    const token = localStorage.getItem('token');
    if (token) {
      dispatch(fetchMe());
    } else {
      dispatch(setLoading(false));
    }
  }, [dispatch]);

  // ── Socket.IO — connect when authenticated, disconnect on logout ─────────
  // This is the SINGLE place where the socket connects for the whole app.
  // Both Sidebar and Notifications page share this one connection via
  // the socketService singleton.
  useEffect(() => {
    const token = localStorage.getItem('token');
    if (isAuthenticated && token) {
      socketService.connect(token);
    } else {
      socketService.disconnect();
    }

    // Cleanup on unmount (page close / refresh)
    return () => {
      socketService.disconnect();
    };
  }, [isAuthenticated]);

  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login"              element={<Login />} />
        <Route path="/signup"             element={<Signup />} />
        <Route path="/vendor-signup"      element={<VendorSignup />} />
        <Route path="/auth/google/success" element={<AuthCallback />} />
        <Route path="/forgot-password"    element={<ForgotPassword />} />
        <Route path="/verify-otp"         element={<VerifyOtp />} />

        <Route path="/" element={
          <ProtectedRoute>
            <Layout />
          </ProtectedRoute>
        }>
          <Route index                    element={<Home />} />
          <Route path="/create"           element={<CreatePost />} />
          <Route path="/reels"            element={<Reels />} />
          <Route path="/promote"          element={<Promote />} />
          <Route path="/ads"              element={<Ads />} />
          <Route path="/vendor-ads"       element={<VendorAds />} />
          <Route path="/profile"          element={<Profile />} />
          <Route path="/profile/:userId"  element={<Profile />} />
          <Route path="/edit-profile"     element={<EditProfile />} />
          <Route path="/wallet"           element={<WalletDetails />} />
          <Route path="/settings"         element={<Settings />} />
          <Route path="/notifications"    element={<Notifications />} />
          <Route path="/search"           element={<Search />} />
          <Route path="/messages"         element={<ChatPage />} />
          <Route path="/messages/:conversationId" element={<ChatPage />} />
          <Route path="/vendor/:userId/public" element={<VendorPublicProfile />} />
          <Route path="/ads/:adId/details" element={<AdPublicDetail />} />

        </Route>

        <Route path="/vendor" element={
          <ProtectedRoute>
            <VendorLayout />
          </ProtectedRoute>
        }>
          <Route path="dashboard"              element={<VendorDashboard />} />
          <Route path="profile"                element={<VendorProfile />} />
          <Route path="ads-management"         element={<AdsManagement />} />
          <Route path="ads-management/:adId"   element={<AdDetails />} />
          <Route path="analytics"              element={<ReportsAnalytics />} />
          <Route path="billing"                element={<CoinsBilling />} />
          <Route path="settings"               element={<VendorSettings />} />
          <Route path="notifications"          element={<VendorNotifications />} />
        </Route>

        <Route path="/post/:postId" element={
          <ProtectedRoute>
            <MobilePostDetail />
          </ProtectedRoute>
        } />
      </Routes>
    </BrowserRouter>
  );
}

export default App;
