import React, { useState } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { useSelector } from 'react-redux';
import { Home, Plus, Search, Target, User, LayoutDashboard, FileText, Clapperboard } from 'lucide-react';

const BottomNav = ({ onOpenCreateModal }) => {
  const location = useLocation();
  const { userObject } = useSelector((state) => state.auth);
  const isVendor = userObject?.role === 'vendor';
  const [showVendorNotValidated, setShowVendorNotValidated] = useState(false);

  const isActive = (path) => {
    if (path === '/') return location.pathname === '/';
    return location.pathname.startsWith(path);
  };

  // Active color: #fa3f5e (insta-pink-ish) to match the "red outline" description
  const activeColor = "text-[#fa3f5e]";
  const inactiveColor = "text-gray-500 dark:text-gray-400";

  // Hide bottom nav on specific pages
  const hideBottomNav = ['/create-ad'].includes(location.pathname);

  if (hideBottomNav) return null;

  return (
    <>
      <div className="md:hidden fixed bottom-0 left-0 right-0 bg-white dark:bg-black border-t border-gray-200 dark:border-gray-800 flex justify-between items-center px-6 h-[60px] z-50 pb-2">
        {isVendor ? (
          <Link to="/vendor/dashboard" className={`${isActive('/vendor/dashboard') ? activeColor : inactiveColor}`}>
            <LayoutDashboard size={28} strokeWidth={isActive('/vendor/dashboard') ? 2.5 : 2} />
          </Link>
        ) : (
          <Link to="/" className={`${isActive('/') ? activeColor : inactiveColor}`}>
            <Home size={28} strokeWidth={isActive('/') ? 2.5 : 2} />
          </Link>
        )}

        {isVendor ? (
          <Link to="/vendor/ads-management" className={`${isActive('/vendor/ads-management') ? activeColor : inactiveColor}`}>
            <Target size={28} strokeWidth={isActive('/vendor/ads-management') ? 2.5 : 2} />
          </Link>
        ) : (
          <Link to="/search" className={`${isActive('/search') ? activeColor : inactiveColor}`}>
            <Search size={28} strokeWidth={isActive('/search') ? 2.5 : 2} />
          </Link>
        )}

        <div className="relative -top-6 flex flex-col items-center">
          <button
            onClick={() => {
              if (isVendor) {
                if (!userObject?.is_active) setShowVendorNotValidated(true);
                else onOpenCreateModal('ad'); // This should map to creating ad in vendor context
              } else {
                onOpenCreateModal('post');
              }
            }}
            className={`w-14 h-14 rounded-full flex items-center justify-center shadow-lg border-4 border-white dark:border-black text-white transform transition-transform active:scale-95 bg-gradient-to-tr from-[#f09433] via-[#dc2743] to-[#bc1888]`}
          >
            <Plus size={32} strokeWidth={3} />
          </button>
        </div>

        {isVendor ? (
          <Link to="/vendor/analytics" className={`${isActive('/vendor/analytics') ? activeColor : inactiveColor}`}>
            <FileText size={28} strokeWidth={isActive('/vendor/analytics') ? 2.5 : 2} />
          </Link>
        ) : (
          <Link to="/reels" className={`${isActive('/reels') ? activeColor : inactiveColor}`}>
            <Clapperboard size={28} strokeWidth={isActive('/reels') ? 2.5 : 2} />
          </Link>
        )}

        {isVendor ? (
          <Link to="/vendor/profile" className={`${isActive('/vendor/profile') ? activeColor : inactiveColor}`}>
            <User size={28} strokeWidth={isActive('/vendor/profile') ? 2.5 : 2} />
          </Link>
        ) : (
          <Link to="/profile" className={`${isActive('/profile') ? activeColor : inactiveColor}`}>
            <User size={28} strokeWidth={isActive('/profile') ? 2.5 : 2} />
          </Link>
        )}
        
      </div>
      {showVendorNotValidated && (
        <div className="fixed inset-0 z-[70] flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
          <div className="bg-white dark:bg-gray-900 rounded-xl p-6 w-full max-w-sm shadow-2xl border border-gray-100 dark:border-gray-800">
            <h3 className="text-lg font-bold text-gray-900 dark:text-white mb-2 text-center">
              Vendor account inactive
            </h3>
            <p className="text-gray-500 dark:text-gray-400 text-sm mb-6 text-center">
              Your vendor account is inactive. Please contact support or wait for activation before uploading ads.
            </p>
            <div className="flex justify-center">
              <button
                onClick={() => setShowVendorNotValidated(false)}
                className="px-4 py-2.5 rounded-lg bg-insta-pink text-white font-medium hover:bg-insta-purple transition-colors"
              >
                OK
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
};

export default BottomNav;
