import React, { useEffect, useRef, useState } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { useSelector } from 'react-redux';
import { Bell, Clapperboard, Heart, Home, Megaphone, Plus, Search, Target, User } from 'lucide-react';

const BottomNav = ({ onOpenCreateModal }) => {
  const location = useLocation();
  const { userObject } = useSelector((state) => state.auth);
  const isVendor = userObject?.role === 'vendor';
  const [showVendorNotValidated, setShowVendorNotValidated] = useState(false);
  const [showNotifications, setShowNotifications] = useState(false);
  const notificationsRef = useRef(null);

  const isActive = (path) => {
    if (path === '/') return location.pathname === '/';
    return location.pathname.startsWith(path);
  };

  // Active color: #fa3f5e (insta-pink-ish) to match the "red outline" description
  const activeColor = "text-[#fa3f5e]";
  const inactiveColor = "text-gray-500 dark:text-gray-400";

  // Hide bottom nav on specific pages
  const hideBottomNav = ['/create-ad'].includes(location.pathname);

  useEffect(() => {
    const onDown = (e) => {
      if (notificationsRef.current && !notificationsRef.current.contains(e.target)) setShowNotifications(false);
    };
    document.addEventListener('mousedown', onDown);
    return () => document.removeEventListener('mousedown', onDown);
  }, []);

  if (hideBottomNav) return null;

  return (
    <>
      <div className="md:hidden fixed bottom-0 left-0 right-0 bg-white dark:bg-black border-t border-gray-200 dark:border-gray-800 flex justify-between items-center px-6 h-[60px] z-50 pb-2">
        <Link to="/" className={`${isActive('/') ? activeColor : inactiveColor}`}>
          <Home size={28} strokeWidth={isActive('/') ? 2.5 : 2} />
        </Link>

        {isVendor ? (
          <Link to="/ads" className={`${isActive('/ads') ? activeColor : inactiveColor}`}>
            <Target size={28} strokeWidth={isActive('/ads') ? 2.5 : 2} />
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
                else onOpenCreateModal('ad');
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
          <div className="relative" ref={notificationsRef}>
            <button
              onClick={() => setShowNotifications(v => !v)}
              className={`${showNotifications ? activeColor : inactiveColor} relative`}
            >
              <Heart size={28} strokeWidth={showNotifications ? 2.5 : 2} />
              <span className="absolute -top-0.5 -right-0.5 w-2 h-2 bg-[#fa3f5e] rounded-full border border-white dark:border-black"></span>
            </button>
            {showNotifications && (
              <div className="absolute bottom-full right-0 mb-3 w-72 bg-white dark:bg-gray-900 rounded-xl shadow-xl border border-gray-100 dark:border-gray-800 py-2 z-[60] animate-fade-in">
                <div className="px-4 py-2 border-b border-gray-50 dark:border-gray-800">
                  <h3 className="font-semibold text-sm text-gray-900 dark:text-white">Notifications</h3>
                </div>
                <div className="max-h-60 overflow-y-auto">
                  <div className="px-4 py-3 hover:bg-gray-50 dark:hover:bg-gray-800 flex gap-3 items-center">
                    <div className="w-8 h-8 rounded-full bg-blue-50 dark:bg-blue-900/30 text-blue-500 flex items-center justify-center"><Bell size={14} /></div>
                    <div>
                      <p className="text-sm text-gray-900 dark:text-gray-200">New follower: <span className="font-bold">Sarah</span></p>
                      <p className="text-xs text-gray-500 dark:text-gray-400">2 min ago</p>
                    </div>
                  </div>
                </div>
              </div>
            )}
          </div>
        ) : (
          <Link to="/reels" className={`${isActive('/reels') ? activeColor : inactiveColor}`}>
            <Clapperboard size={28} strokeWidth={isActive('/reels') ? 2.5 : 2} />
          </Link>
        )}

        {isVendor ? (
          <Link to="/profile" className={`${isActive('/profile') ? activeColor : inactiveColor}`}>
            <User size={28} strokeWidth={isActive('/profile') ? 2.5 : 2} />
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
