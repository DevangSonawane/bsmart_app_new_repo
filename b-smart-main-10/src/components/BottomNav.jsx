import React, { useState } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { useSelector } from 'react-redux';
import {
  Home, Plus, Target, User, LayoutDashboard, FileText,
  Clapperboard, Settings, Megaphone, X, Coins, Search
} from 'lucide-react';

const BottomNav = ({ onOpenCreateModal }) => {
  const location = useLocation();
  const { userObject } = useSelector((state) => state.auth);
  const isVendor = userObject?.role === 'vendor';

  const [showVendorNotValidated, setShowVendorNotValidated] = useState(false);

  const isActive = (path) => {
    if (path === '/') return location.pathname === '/';
    return location.pathname.startsWith(path);
  };

  const activeColor   = 'text-[#fa3f5e]';
  const inactiveColor = 'text-gray-500 dark:text-gray-400';

  const hideBottomNav = ['/create-ad'].includes(location.pathname);
  if (hideBottomNav) return null;

  // Vendor: 3 left | FAB center | 3 right
  const vendorNav = [
    { icon: LayoutDashboard, path: '/vendor/dashboard',      label: 'Dashboard' },
    { icon: Target,          path: '/vendor/ads-management', label: 'Ads'       },
    { icon: FileText,        path: '/vendor/analytics',      label: 'Analytics' },
    null,
    { icon: Coins,           path: '/vendor/billing',  label: 'Coins'     },
    { icon: Settings,        path: '/vendor/settings',       label: 'Settings'  },
    { icon: User,            path: '/vendor/profile',        label: 'Profile'   },
  ];

  // Member: 2 left | FAB center | 2 right
  const memberNav = [
    { icon: Home,         path: '/',        label: 'Home'    },
    { icon: Target,       path: '/ads',     label: 'Ads'     },
    null,
    { icon: Clapperboard, path: '/reels',   label: 'Reels'   },
    { icon: Search,       path: '/search',  label: 'Search'  },
  ];

  const navItems = isVendor ? vendorNav : memberNav;

  const handleCreate = () => {
    if (isVendor) {
      if (!userObject?.is_active) { setShowVendorNotValidated(true); return; }
      onOpenCreateModal?.('ad');
    } else {
      onOpenCreateModal?.('post');
    }
  };

  return (
    <>
      {/* Main bottom bar */}
      <div className="md:hidden fixed bottom-0 left-0 right-0 bg-white dark:bg-black border-t border-gray-200 dark:border-gray-800 flex justify-between items-center px-1 h-[60px] z-50 pb-1">
        {navItems.map((item, idx) => {
          if (item === null) {
            return (
              <div key="fab" className="relative -top-5 flex flex-col items-center flex-shrink-0 mx-0.5">
                <button
                  onClick={handleCreate}
                  className="w-12 h-12 rounded-full flex items-center justify-center shadow-lg border-4 border-white dark:border-black text-white transform transition-transform active:scale-95 bg-gradient-to-tr from-[#f09433] via-[#dc2743] to-[#bc1888]"
                >
                  <Plus size={26} strokeWidth={3} />
                </button>
              </div>
            );
          }
          return (
            <Link
              key={item.path}
              to={item.path}
              className={`flex flex-col items-center gap-0.5 flex-1 py-1 min-w-0 ${isActive(item.path) ? activeColor : inactiveColor}`}
            >
              <item.icon size={isVendor ? 21 : 25} strokeWidth={isActive(item.path) ? 2.5 : 2} />
              {isVendor && (
                <span className={`text-[8.5px] font-semibold leading-none truncate w-full text-center px-0.5 ${isActive(item.path) ? 'text-[#fa3f5e]' : 'text-gray-400 dark:text-gray-500'}`}>
                  {item.label}
                </span>
              )}
            </Link>
          );
        })}
      </div>

      {/* Inactive vendor modal */}
      {showVendorNotValidated && (
        <div className="fixed inset-0 z-[70] flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
          <div className="bg-white dark:bg-gray-900 rounded-xl p-6 w-full max-w-sm shadow-2xl border border-gray-100 dark:border-gray-800">
            <h3 className="text-lg font-bold text-gray-900 dark:text-white mb-2 text-center">Vendor account inactive</h3>
            <p className="text-gray-500 dark:text-gray-400 text-sm mb-6 text-center">
              Your vendor account is inactive. Please contact support or wait for activation before uploading ads.
            </p>
            <div className="flex justify-center">
              <button onClick={() => setShowVendorNotValidated(false)} className="px-4 py-2.5 rounded-lg bg-[#fa3f5e] text-white font-medium hover:opacity-90 transition-opacity">
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