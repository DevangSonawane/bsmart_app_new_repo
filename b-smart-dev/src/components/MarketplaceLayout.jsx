import React, { useState } from 'react';
import { Outlet, useNavigate, useLocation, Link } from 'react-router-dom';
import { useDispatch, useSelector } from 'react-redux';
import { ArrowLeft, Store, LayoutGrid, ClipboardList, ChevronDown, UserRound, Settings, LogOut, Sun, Moon, Bell, ShoppingCart, Heart, Package, Briefcase } from 'lucide-react';
import bsmartLogo from '../assets/bsmart.png';
import { CATEGORY_STYLE } from '../data/marketplaceCategoryStyle';
import { logoutUser } from '../store/authSlice';
import { toggleTheme } from '../store/themeSlice';
import { useNotificationSocket } from '../hooks/useNotificationSocket';

const NAV_LINKS = [
  { label: 'Home', to: '/', match: (path) => path === '/' },
  { label: 'Marketplace', to: '/market', match: (path) => path === '/market' },
  { label: 'Products', to: '/market/products', match: (path) => path === '/market/products' },
  { label: 'Services', to: '/market/services', match: (path) => path === '/market/services' },
];

// Layout for buyer-facing Marketplace pages (browse, product/service detail,
// wishlist, cart, checkout, orders) — a slim top navbar with a back button
// and a Marketplace-scoped nav (logo, Home, Categories, My Store, My Orders)
// instead of the main app Sidebar, the same idea My Store already uses for
// the seller side (see myStore/components/StoreLayout.jsx).
const MarketplaceLayout = () => {
  const navigate = useNavigate();
  const dispatch = useDispatch();
  const location = useLocation();
  const userObject = useSelector((state) => state.auth.userObject);
  const { mode } = useSelector((state) => state.theme);
  const cartItems = useSelector((state) => state.cart.items);
  const cartCount = cartItems.reduce((sum, item) => sum + item.qty, 0);
  const { unreadCount } = useNotificationSocket({ limit: 10 });
  const [categoriesOpen, setCategoriesOpen] = useState(false);
  const [profileOpen, setProfileOpen] = useState(false);

  const handleLogout = () => {
    setProfileOpen(false);
    dispatch(logoutUser());
    navigate('/login');
  };

  const getInitials = (name) => {
    const raw = (name || '').trim();
    if (!raw) return 'U';
    const parts = raw.split(/\s+/).filter(Boolean);
    return ((parts[0]?.[0] || 'U') + (parts[1]?.[0] || '')).toUpperCase();
  };

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-black">
      <div className="sticky top-0 z-40 bg-white dark:bg-black border-b border-gray-100 dark:border-gray-800">
        <div className="flex items-center gap-4 h-16 px-4 max-w-[1300px] mx-auto">

          <Link to="/market" className="flex items-center gap-2 shrink-0">
            <img src={bsmartLogo} alt="b_smart" className="h-[60px] w-auto object-contain" />
          </Link>

          <nav className="hidden md:flex items-center gap-1 ml-2">
            {NAV_LINKS.map((item) => {
              const active = item.match(location.pathname);
              return (
                <Link
                  key={item.label}
                  to={item.to}
                  className={`px-4 py-2 rounded-full text-sm font-semibold transition-colors ${
                    active ? 'bg-[#fa3f5e] text-white' : 'text-gray-600 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-900'
                  }`}
                >
                  {item.label}
                </Link>
              );
            })}

            <div className="relative">
              <button
                type="button"
                aria-expanded={categoriesOpen}
                onClick={() => setCategoriesOpen((open) => !open)}
                onBlur={() => window.setTimeout(() => setCategoriesOpen(false), 150)}
                className="flex items-center gap-1 px-4 py-2 rounded-full text-sm font-semibold text-gray-600 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-900 transition-colors"
              >
                Categories <ChevronDown size={14} className={`transition-transform ${categoriesOpen ? 'rotate-180' : ''}`} />
              </button>
              {categoriesOpen && (
                <div className="absolute left-0 top-full mt-1 w-52 rounded-2xl border border-gray-100 dark:border-gray-800 bg-white dark:bg-gray-900 shadow-xl p-2 z-50">
                  {Object.entries(CATEGORY_STYLE).map(([name, { icon: CatIcon, text, bg }]) => (
                    <Link
                      key={name}
                      to={`/market/category/${encodeURIComponent(name)}`}
                      className="flex items-center gap-2.5 px-2.5 py-2 rounded-xl text-sm font-semibold text-gray-700 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors"
                    >
                      <span className={`w-7 h-7 rounded-lg flex items-center justify-center shrink-0 ${bg}`}>
                        <CatIcon size={14} className={text} />
                      </span>
                      {name}
                    </Link>
                  ))}
                </div>
              )}
            </div>
          </nav>

          <div className="flex items-center gap-1 ml-auto">
            {/* Mobile: compact icon-only shortcut */}
            <div className="flex md:hidden items-center gap-1">
              <Link to="/market" aria-label="Marketplace" className={`flex h-9 w-9 items-center justify-center rounded-full ${location.pathname === '/market' ? 'bg-[#fa3f5e] text-white' : 'text-gray-500 dark:text-gray-400'}`}>
                <LayoutGrid size={17} />
              </Link>
              <Link to="/market/products" aria-label="Products" className={`flex h-9 w-9 items-center justify-center rounded-full ${location.pathname === '/market/products' ? 'bg-[#fa3f5e] text-white' : 'text-gray-500 dark:text-gray-400'}`}>
                <Package size={17} />
              </Link>
              <Link to="/market/services" aria-label="Services" className={`flex h-9 w-9 items-center justify-center rounded-full ${location.pathname === '/market/services' ? 'bg-[#fa3f5e] text-white' : 'text-gray-500 dark:text-gray-400'}`}>
                <Briefcase size={17} />
              </Link>
            </div>

            {/* Theme toggle, notifications, cart */}
            <button
              type="button"
              onClick={() => dispatch(toggleTheme())}
              aria-label="Toggle dark/light mode"
              className="flex h-9 w-9 items-center justify-center rounded-full text-gray-600 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-900 transition-colors"
            >
              {mode === 'dark' ? <Moon size={18} /> : <Sun size={18} />}
            </button>
            <button
              type="button"
              onClick={() => navigate('/notifications')}
              aria-label="Notifications"
              className="relative flex h-9 w-9 items-center justify-center rounded-full text-gray-600 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-900 transition-colors"
            >
              <Bell size={18} />
              {unreadCount > 0 && (
                <span className="absolute top-0.5 right-0.5 min-w-[16px] h-[16px] px-0.5 bg-[#fa3f5e] rounded-full border-2 border-white dark:border-black flex items-center justify-center">
                  <span className="text-[8px] font-black text-white leading-none">{unreadCount > 99 ? '99+' : unreadCount}</span>
                </span>
              )}
            </button>
            <Link
              to="/market/wishlist"
              aria-label="Wishlist"
              className="flex h-9 w-9 items-center justify-center rounded-full text-gray-600 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-900 transition-colors"
            >
              <Heart size={18} />
            </Link>
            <Link
              to="/cart"
              id="marketplace-cart-icon"
              aria-label="Cart"
              className="relative flex h-9 w-9 items-center justify-center rounded-full text-gray-600 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-900 transition-colors"
            >
              <ShoppingCart size={18} />
              {cartCount > 0 && (
                <span className="absolute top-0.5 right-0.5 min-w-[16px] h-[16px] px-0.5 bg-[#fa3f5e] rounded-full border-2 border-white dark:border-black flex items-center justify-center">
                  <span className="text-[8px] font-black text-white leading-none">{cartCount > 99 ? '99+' : cartCount}</span>
                </span>
              )}
            </Link>
          </div>

          {/* Profile — hover/click to reveal Profile / Settings / Logout */}
          <div
            className="relative hidden md:block"
            onMouseEnter={() => setProfileOpen(true)}
            onMouseLeave={() => setProfileOpen(false)}
          >
            <button
              type="button"
              aria-expanded={profileOpen}
              onClick={() => setProfileOpen((open) => !open)}
              className="flex items-center gap-1.5 p-1 pr-2 rounded-full hover:bg-gray-50 dark:hover:bg-gray-900 transition-colors"
            >
              <span className="w-8 h-8 rounded-full overflow-hidden bg-gray-100 dark:bg-gray-800 flex items-center justify-center shrink-0">
                {userObject?.avatar_url || userObject?.profile_picture ? (
                  <img src={userObject.avatar_url || userObject.profile_picture} alt={userObject?.username || 'Profile'} className="w-full h-full object-cover" />
                ) : (
                  <span className="text-[11px] font-bold text-gray-600 dark:text-gray-300">{getInitials(userObject?.full_name || userObject?.name || userObject?.username)}</span>
                )}
              </span>
              <ChevronDown size={14} className={`text-gray-400 transition-transform ${profileOpen ? 'rotate-180' : ''}`} />
            </button>
            {profileOpen && (
              <div className="absolute right-0 top-full w-48 rounded-2xl border border-gray-100 dark:border-gray-800 bg-white dark:bg-gray-900 shadow-xl p-2 z-50">
                <Link to="/profile" onClick={() => setProfileOpen(false)} className="flex items-center gap-2.5 px-2.5 py-2 rounded-xl text-sm font-semibold text-gray-700 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors">
                  <UserRound size={16} /> Profile
                </Link>
                <Link to="/market/my-store" onClick={() => setProfileOpen(false)} className="flex items-center gap-2.5 px-2.5 py-2 rounded-xl text-sm font-semibold text-gray-700 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors">
                  <Store size={16} /> My Store
                </Link>
                <Link to="/market/my-orders" onClick={() => setProfileOpen(false)} className="flex items-center gap-2.5 px-2.5 py-2 rounded-xl text-sm font-semibold text-gray-700 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors">
                  <ClipboardList size={16} /> My Orders
                </Link>
                <div className="my-1 border-t border-gray-100 dark:border-gray-800" />
                <Link to="/settings/account" onClick={() => setProfileOpen(false)} className="flex items-center gap-2.5 px-2.5 py-2 rounded-xl text-sm font-semibold text-gray-700 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors">
                  <Settings size={16} /> Settings
                </Link>
                <button type="button" onClick={handleLogout} className="flex w-full items-center gap-2.5 px-2.5 py-2 rounded-xl text-sm font-semibold text-[#fa3f5e] hover:bg-pink-50 dark:hover:bg-pink-900/10 transition-colors">
                  <LogOut size={16} /> Logout
                </button>
              </div>
            )}
          </div>

          {/* Profile — mobile */}
          <div className="relative md:hidden">
            <button
              type="button"
              aria-expanded={profileOpen}
              onClick={() => setProfileOpen((open) => !open)}
              className="flex h-9 w-9 items-center justify-center rounded-full overflow-hidden bg-gray-100 dark:bg-gray-800 shrink-0"
            >
              {userObject?.avatar_url || userObject?.profile_picture ? (
                <img src={userObject.avatar_url || userObject.profile_picture} alt={userObject?.username || 'Profile'} className="w-full h-full object-cover" />
              ) : (
                <span className="text-[11px] font-bold text-gray-600 dark:text-gray-300">{getInitials(userObject?.full_name || userObject?.name || userObject?.username)}</span>
              )}
            </button>
            {profileOpen && (
              <div className="absolute right-0 top-full mt-1 w-48 rounded-2xl border border-gray-100 dark:border-gray-800 bg-white dark:bg-gray-900 shadow-xl p-2 z-50">
                <Link to="/profile" onClick={() => setProfileOpen(false)} className="flex items-center gap-2.5 px-2.5 py-2 rounded-xl text-sm font-semibold text-gray-700 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors">
                  <UserRound size={16} /> Profile
                </Link>
                <Link to="/market/my-store" onClick={() => setProfileOpen(false)} className="flex items-center gap-2.5 px-2.5 py-2 rounded-xl text-sm font-semibold text-gray-700 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors">
                  <Store size={16} /> My Store
                </Link>
                <Link to="/market/my-orders" onClick={() => setProfileOpen(false)} className="flex items-center gap-2.5 px-2.5 py-2 rounded-xl text-sm font-semibold text-gray-700 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors">
                  <ClipboardList size={16} /> My Orders
                </Link>
                <div className="my-1 border-t border-gray-100 dark:border-gray-800" />
                <Link to="/settings/account" onClick={() => setProfileOpen(false)} className="flex items-center gap-2.5 px-2.5 py-2 rounded-xl text-sm font-semibold text-gray-700 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors">
                  <Settings size={16} /> Settings
                </Link>
                <button type="button" onClick={handleLogout} className="flex w-full items-center gap-2.5 px-2.5 py-2 rounded-xl text-sm font-semibold text-[#fa3f5e] hover:bg-pink-50 dark:hover:bg-pink-900/10 transition-colors">
                  <LogOut size={16} /> Logout
                </button>
              </div>
            )}
          </div>
        </div>
      </div>
      <Outlet />
    </div>
  );
};

export default MarketplaceLayout;
