import React, { useState } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { useSelector } from 'react-redux';
import {
  Home, Plus, Target, User, LayoutDashboard, FileText,
  Clapperboard, CreditCard, Settings, ShoppingBag, Megaphone,
  BarChart2, ChevronUp, X
} from 'lucide-react';

const BottomNav = ({ onOpenCreateModal }) => {
  const location = useLocation();
  const { userObject } = useSelector((state) => state.auth);
  const isVendor = userObject?.role === 'vendor';

  const [showVendorNotValidated, setShowVendorNotValidated] = useState(false);
  const [showMoreMenu, setShowMoreMenu] = useState(false);

  const isActive = (path) => {
    if (path === '/') return location.pathname === '/';
    return location.pathname.startsWith(path);
  };

  const activeColor  = 'text-[#fa3f5e]';
  const inactiveColor = 'text-gray-500 dark:text-gray-400';

  const hideBottomNav = ['/create-ad'].includes(location.pathname);
  if (hideBottomNav) return null;

  // ── Vendor nav items (all sidebar items) ────────────────────────────────────
  const vendorPrimaryNav = [
    { icon: LayoutDashboard, path: '/vendor/dashboard',      label: 'Dashboard'  },
    { icon: Target,          path: '/vendor/ads-management', label: 'Ads'        },
    null, // center button placeholder
    { icon: FileText,        path: '/vendor/analytics',      label: 'Analytics'  },
    { icon: User,            path: '/vendor/profile',        label: 'Profile'    },
  ];

  const vendorMoreItems = [
    { icon: CreditCard, path: '/vendor/billing',  label: 'Coins & Billing' },
    { icon: Settings,   path: '/vendor/settings', label: 'Settings'        },
  ];

  // ── Member nav items (all sidebar items) ─────────────────────────────────────
  const memberPrimaryNav = [
    { icon: Home,        path: '/',        label: 'Home'   },
    { icon: Target, path: '/ads',     label: 'Ads'    },
    null, // center button placeholder
    { icon: Clapperboard,path: '/reels',   label: 'Reels'  },
    { icon: User,        path: '/profile', label: 'Profile'},
  ];

  const memberMoreItems = [
    { icon: Megaphone,   path: '/promote',  label: 'Promote'  },
    { icon: Settings,    path: '/settings', label: 'Settings' },
  ];

  const primaryNav  = isVendor ? vendorPrimaryNav  : memberPrimaryNav;
  const moreItems   = isVendor ? vendorMoreItems   : memberMoreItems;

  const handleCreate = () => {
    setShowMoreMenu(false);
    if (isVendor) {
      if (!userObject?.is_active) { setShowVendorNotValidated(true); return; }
      onOpenCreateModal?.('ad');
    } else {
      onOpenCreateModal?.('post');
    }
  };

  return (
    <>
      {/* ── More drawer (slides up) ─────────────────────────────────────────── */}
      {showMoreMenu && (
        <>
          {/* backdrop */}
          <div
            className="md:hidden fixed inset-0 z-[55] bg-black/40 backdrop-blur-sm"
            onClick={() => setShowMoreMenu(false)}
          />
          <div className="md:hidden fixed bottom-[60px] left-0 right-0 z-[56] bg-white dark:bg-[#111] border-t border-gray-100 dark:border-gray-800 rounded-t-3xl shadow-2xl px-4 pt-3 pb-5">
            {/* Handle */}
            <div className="w-10 h-1 rounded-full bg-gray-200 dark:bg-gray-700 mx-auto mb-4" />
            <p className="text-xs font-bold uppercase tracking-wider text-gray-400 dark:text-gray-500 mb-3 px-1">
              {isVendor ? 'Vendor Menu' : 'More'}
            </p>
            <div className="grid grid-cols-3 gap-3">
              {moreItems.map(item => (
                <Link
                  key={item.path}
                  to={item.path}
                  onClick={() => setShowMoreMenu(false)}
                  className={`flex flex-col items-center gap-1.5 p-3 rounded-2xl transition-all active:scale-95
                    ${isActive(item.path)
                      ? 'bg-[#fa3f5e]/10 text-[#fa3f5e]'
                      : 'bg-gray-50 dark:bg-gray-800 text-gray-600 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700'}`}
                >
                  <item.icon size={22} strokeWidth={isActive(item.path) ? 2.5 : 2} />
                  <span className="text-[11px] font-semibold">{item.label}</span>
                </Link>
              ))}
            </div>
          </div>
        </>
      )}

      {/* ── Main bottom bar ─────────────────────────────────────────────────── */}
      <div className="md:hidden fixed bottom-0 left-0 right-0 bg-white dark:bg-black border-t border-gray-200 dark:border-gray-800 flex justify-between items-center px-4 h-[60px] z-50 pb-2">

        {primaryNav.map((item, idx) => {
          // Center = FAB
          if (item === null) {
            return (
              <div key="fab" className="relative -top-6 flex flex-col items-center">
                <button
                  onClick={handleCreate}
                  className="w-14 h-14 rounded-full flex items-center justify-center shadow-lg border-4 border-white dark:border-black text-white transform transition-transform active:scale-95 bg-gradient-to-tr from-[#f09433] via-[#dc2743] to-[#bc1888]"
                >
                  <Plus size={32} strokeWidth={3} />
                </button>
              </div>
            );
          }

          return (
            <Link
              key={item.path}
              to={item.path}
              className={`flex flex-col items-center gap-0.5 min-w-[40px] ${isActive(item.path) ? activeColor : inactiveColor}`}
            >
              <item.icon size={26} strokeWidth={isActive(item.path) ? 2.5 : 2} />
            </Link>
          );
        })}



      </div>

      {/* ── Inactive vendor modal ───────────────────────────────────────────── */}
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
                className="px-4 py-2.5 rounded-lg bg-[#fa3f5e] text-white font-medium hover:opacity-90 transition-opacity"
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