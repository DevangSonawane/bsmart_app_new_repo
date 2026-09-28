import React, { useEffect } from 'react';
import { BrowserRouter, Routes, Route } from 'react-router-dom';
import { useDispatch, useSelector } from 'react-redux';
import { fetchMe, setLoading } from './store/authSlice';
import socketService from './services/socketService';
import { registerWebPush } from './services/pushService';

import Layout from './components/Layout';
import Home from './pages/Home';
import CreatePost from './pages/CreatePost';
import Reels from './pages/Reels';
import Promote from './pages/Promote';
import Ads from './pages/Ads';
import Market from './pages/Market';
import MyOrders from './pages/MyOrders';
import Wishlist from './pages/Wishlist';
import AddProduct from './pages/AddProduct';
import EditProduct from './pages/EditProduct';
import AddService from './pages/AddService';
import EditService from './pages/EditService';
import StoreLayout from './myStore/components/StoreLayout';
import StoreDashboard from './myStore/pages/Dashboard';
import StoreOrders from './myStore/pages/Orders';
import StoreBookings from './myStore/pages/Bookings';
import StoreProfile from './myStore/pages/Profile';
import StoreProducts from './myStore/pages/Products';
import StoreServices from './myStore/pages/Services';
import ProductDetail from './pages/ProductDetail';
import ServiceDetail from './pages/ServiceDetail';
import Cart from './pages/Cart';
import Checkout from './pages/Checkout';
import VendorAds from './pages/VendorAds';
import AdPublicDetail from './pages/AdPublicDetail';
import VendorPublicProfile from './pages/VendorPublicProfile';
import Profile from './pages/Profile';
import Settings from './pages/Settings';
import Login from './pages/Login';
import Signup from './pages/Signup';
import VendorSignup from './pages/VendorSignup';
import ForgotPassword from './pages/ForgotPassword';
import VerifyOtp from './pages/VerifyOtp';
import EditProfile from './pages/EditProfile';
import WalletDetails from './pages/WalletDetails';
import GiftCards from './pages/GiftCards';
import GiftCardOrders from './pages/GiftCardOrders';
import MobilePostDetail from './pages/MobilePostDetail';
import MobileAdsDetail from './pages/MobileAdsDetail';
import MobilePromoteDetail from './pages/MobilePromoteDetail';
import MobileTweetDetail from './pages/MobileTweetDetail';
import AccountSettings from './pages/settingpages/AccountSettings';
import PrivacySettings from './pages/settingpages/PrivacySettings';
import SecuritySettings from './pages/settingpages/SecuritySettings';
import HelpSettings from './pages/settingpages/HelpSettings';
import MessagingSettings from './pages/settingpages/MessagingSettings';
import ContentSettings from './pages/settingpages/ContentSettings';
import BlockedSettings from './pages/settingpages/BlockedSettings';
import AppearanceSettings from './pages/settingpages/AppearanceSettings';
import StorageSettings from './pages/settingpages/StorageSettings';
import LegalSettings from './pages/settingpages/LegalSettings';
import AboutSettings from './pages/settingpages/AboutSettings';
import AccountActionsSettings from './pages/settingpages/AccountActionsSettings';
import NotificationSettings from './pages/settingpages/NotificationSettings';
import SavedPosts from './pages/settingpages/SavedPosts';
import AuthCallback from './pages/AuthCallback';
import PublicPolicyPage from './pages/PublicPolicyPage';
import Notifications from './pages/Notifications';
import VendorNotifications from './pages/vendor-pages/VendorNotifications';
import ProtectedRoute from './components/ProtectedRoute';
import Search from './pages/Search';
import ChatPage from './pages/ChatPage';
import Suggestions from './pages/Suggestions';
import GlobalLoader from './components/GlobalLoader';

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

    // Register service worker for push notifications (web)
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.register('/sw.js').catch((err) => {
        console.error('[SW] Registration failed:', err);
      });
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
      // Register web push subscription after login
      registerWebPush();
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
      <GlobalLoader />
      <Routes>
        <Route path="/login"              element={<Login />} />
          <Route path="/signup"             element={<Signup />} />
          <Route path="/vendor-signup"      element={<VendorSignup />} />
          <Route path="/auth/google/success" element={<AuthCallback />} />
          <Route path="/auth/apple/success"  element={<AuthCallback />} />
          <Route path="/forgot-password"    element={<ForgotPassword />} />
          <Route path="/verify-otp"         element={<VerifyOtp />} />
          <Route path="/legal/:type"        element={<PublicPolicyPage />} />

          {/* Layout itself is guest-accessible so Home / Reels / Promote can render
              without login. Every other child route stays behind ProtectedRoute
              individually — only those three are meant to be publicly viewable. */}
          <Route path="/" element={<Layout />}>
            <Route index                    element={<Home />} />
            <Route path="/reels"            element={<Reels />} />
            <Route path="/promote"          element={<Promote />} />
            <Route path="/create"           element={<ProtectedRoute><CreatePost /></ProtectedRoute>} />
            <Route path="/ads"              element={<ProtectedRoute><Ads /></ProtectedRoute>} />
            <Route path="/market"           element={<ProtectedRoute><Market /></ProtectedRoute>} />
            <Route path="/market/my-orders" element={<ProtectedRoute><MyOrders /></ProtectedRoute>} />
            <Route path="/market/wishlist" element={<ProtectedRoute><Wishlist /></ProtectedRoute>} />
            <Route path="/market/add-product" element={<ProtectedRoute><AddProduct /></ProtectedRoute>} />
            <Route path="/market/edit-product/:productId" element={<ProtectedRoute><EditProduct /></ProtectedRoute>} />
            <Route path="/market/add-service" element={<ProtectedRoute><AddService /></ProtectedRoute>} />
            <Route path="/market/edit-service/:serviceId" element={<ProtectedRoute><EditService /></ProtectedRoute>} />
            <Route path="/market/product/:productId" element={<ProtectedRoute><ProductDetail /></ProtectedRoute>} />
            <Route path="/market/service/:serviceId" element={<ProtectedRoute><ServiceDetail /></ProtectedRoute>} />
            <Route path="/cart"             element={<ProtectedRoute><Cart /></ProtectedRoute>} />
            <Route path="/checkout"         element={<ProtectedRoute><Checkout /></ProtectedRoute>} />
            <Route path="/vendor-ads"       element={<ProtectedRoute><VendorAds /></ProtectedRoute>} />
            <Route path="/profile"          element={<ProtectedRoute><Profile /></ProtectedRoute>} />
            <Route path="/profile/:userId"  element={<ProtectedRoute><Profile /></ProtectedRoute>} />
            <Route path="/edit-profile"     element={<ProtectedRoute><EditProfile /></ProtectedRoute>} />
            <Route path="/wallet"           element={<ProtectedRoute><WalletDetails /></ProtectedRoute>} />
            <Route path="/gift-cards"       element={<ProtectedRoute><GiftCards /></ProtectedRoute>} />
            <Route path="/gift-card-orders" element={<ProtectedRoute><GiftCardOrders /></ProtectedRoute>} />
            <Route path="/settings" element={<ProtectedRoute><Settings /></ProtectedRoute>}>
              <Route path="account"        element={<AccountSettings />} />
              <Route path="privacy"        element={<PrivacySettings />} />
              <Route path="security"       element={<SecuritySettings />} />
              <Route path="help"           element={<HelpSettings />} />
              <Route path="messaging"      element={<MessagingSettings />} />
              <Route path="content"        element={<ContentSettings />} />
              <Route path="blocked"        element={<BlockedSettings />} />
              <Route path="notifications"  element={<NotificationSettings />} />
              <Route path="appearance"     element={<AppearanceSettings />} />
              <Route path="storage"        element={<StorageSettings />} />
              <Route path="legal"          element={<LegalSettings />} />
              <Route path="about"          element={<AboutSettings />} />
              <Route path="saved"           element={<SavedPosts />} />
              <Route path="account-actions" element={<AccountActionsSettings />} />
            </Route>
            <Route path="/notifications"    element={<ProtectedRoute><Notifications /></ProtectedRoute>} />
            <Route path="/search"           element={<ProtectedRoute><Search /></ProtectedRoute>} />
            <Route path="/messages"         element={<ProtectedRoute><ChatPage /></ProtectedRoute>} />
            <Route path="/suggestions"      element={<ProtectedRoute><Suggestions /></ProtectedRoute>} />
            <Route path="/messages/:conversationId" element={<ProtectedRoute><ChatPage /></ProtectedRoute>} />
            <Route path="/ads/:adId/details" element={<ProtectedRoute><AdPublicDetail /></ProtectedRoute>} />
            <Route path="/vendor/:vendorId/public" element={<ProtectedRoute><VendorPublicProfile /></ProtectedRoute>} />

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

          <Route path="/market/my-store" element={
            <ProtectedRoute>
              <StoreLayout />
            </ProtectedRoute>
          }>
            <Route index          element={<StoreDashboard />} />
            <Route path="orders"   element={<StoreOrders />} />
            <Route path="orders/:orderId" element={<StoreOrders />} />
            <Route path="bookings" element={<StoreBookings />} />
            <Route path="profile" element={<StoreProfile />} />
            <Route path="bookings/:bookingId" element={<StoreBookings />} />
            <Route path="products" element={<StoreProducts />} />
            <Route path="services" element={<StoreServices />} />
          </Route>

          <Route path="/post/:postId" element={
            <ProtectedRoute>
              <MobilePostDetail />
            </ProtectedRoute>
          } />
          <Route path="/ad/:adId" element={
            <ProtectedRoute>
              <MobileAdsDetail />
            </ProtectedRoute>
          } />
          <Route path="/promote-reel/:promoteReelId" element={
            <ProtectedRoute>
              <MobilePromoteDetail />
            </ProtectedRoute>
          } />
          <Route path="/tweet/:tweetId" element={
            <ProtectedRoute>
              <MobileTweetDetail />
            </ProtectedRoute>
          } />
        </Routes>
    </BrowserRouter>
  );
}

export default App;
