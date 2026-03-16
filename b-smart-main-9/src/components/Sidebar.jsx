import React, { useState, useRef, useEffect } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import { useDispatch, useSelector } from 'react-redux';
import { Home, PlusSquare, Clapperboard, User, Menu, Image, Video, Target, Megaphone, Moon, Sun, Search, Heart, Bell, MessageCircle, LayoutDashboard, FileText, CreditCard, Settings, CheckCheck, Trash2 } from 'lucide-react';
import { toggleTheme } from '../store/themeSlice';
import { useNotificationSocket } from '../hooks/useNotificationSocket';

const Sidebar = ({ onOpenCreateModal }) => {
  const location = useLocation();
  const navigate = useNavigate();
  const dispatch = useDispatch();
  const { mode } = useSelector((state) => state.theme);
  const { userObject } = useSelector((state) => state.auth);
  const [isHovered, setIsHovered] = useState(false);
  const [isCreateDropdownOpen, setIsCreateDropdownOpen] = useState(false);
  const [isMoreDropdownOpen, setIsMoreDropdownOpen] = useState(false);
  const [showNotifications, setShowNotifications] = useState(false);
  const [showVendorNotValidated, setShowVendorNotValidated] = useState(false);
  const [nowTs, setNowTs] = useState(() => Date.now());
  const dropdownRef = useRef(null);
  const moreDropdownRef = useRef(null);
  const notificationsRef = useRef(null);

  // ── Notifications via shared WS hook ────────────────────────────────────────
  const isVendor = userObject?.role === 'vendor';
  const notifPage = isVendor ? '/vendor/notifications' : '/notifications';

  const {
    notifications, unreadCount, loading: notifLoading,
    markRead, markAllRead, deleteNotif,
  } = useNotificationSocket({ limit: 8, page: 1 });

  const timeAgo = (d) => {
    if (!d) return "";
    const diff = nowTs - new Date(d).getTime();
    const m = Math.floor(diff / 60000);
    if (m < 1) return "just now";
    if (m < 60) return `${m}m ago`;
    const h = Math.floor(m / 60);
    if (h < 24) return `${h}h ago`;
    return `${Math.floor(h / 24)}d ago`;
  };

  const NOTIF_ICON = { like: <Heart size={12} className="text-pink-500" />, comment: <MessageCircle size={12} className="text-orange-500" />, follow: <User size={12} className="text-blue-500" />, mention: <Bell size={12} className="text-purple-500" />, ad_approved: <Megaphone size={12} className="text-green-500" />, ad_rejected: <Megaphone size={12} className="text-red-500" />, ad_spend: <CreditCard size={12} className="text-amber-500" />, wallet_credit: <CreditCard size={12} className="text-emerald-500" /> };
  const NOTIF_BG   = { like: "bg-pink-50 dark:bg-pink-900/20", comment: "bg-orange-50 dark:bg-orange-900/20", follow: "bg-blue-50 dark:bg-blue-900/20", mention: "bg-purple-50 dark:bg-purple-900/20", ad_approved: "bg-green-50 dark:bg-green-900/20", ad_rejected: "bg-red-50 dark:bg-red-900/20", ad_spend: "bg-amber-50 dark:bg-amber-900/20", wallet_credit: "bg-emerald-50 dark:bg-emerald-900/20" };
  const notifTypeIcon = (type) => NOTIF_ICON[type] || <Bell size={12} className="text-gray-500" />;
  const notifTypeBg   = (type) => NOTIF_BG[type]   || "bg-gray-100 dark:bg-gray-800";

  useEffect(() => {
    const handleClickOutside = (event) => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target)) {
        setIsCreateDropdownOpen(false);
      }
      if (moreDropdownRef.current && !moreDropdownRef.current.contains(event.target)) {
        setIsMoreDropdownOpen(false);
      }
      if (notificationsRef.current && !notificationsRef.current.contains(event.target)) {
        setShowNotifications(false);
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, []);

  useEffect(() => {
    const timer = setInterval(() => setNowTs(Date.now()), 60000);
    return () => clearInterval(timer);
  }, []);

  const navItems = isVendor ? [
    { icon: LayoutDashboard, label: 'Dashboard', path: '/vendor/dashboard' },
    { icon: User, label: 'Vendor Profile', path: '/vendor/profile' },
    { icon: Target, label: 'Ads Management', path: '/vendor/ads-management' },
    { icon: PlusSquare, label: 'Create', path: null, action: () => setIsCreateDropdownOpen(!isCreateDropdownOpen) },
    { icon: FileText, label: 'Reports & Analytics', path: '/vendor/analytics' },
    { icon: CreditCard, label: 'Coins & Billing', path: '/vendor/billing' },
    { icon: Settings, label: 'Settings', path: '/vendor/settings' },
  ] : [
    { icon: Home, label: 'Home', path: '/' },
    { icon: Search, label: 'Search', path: '/search' },
    { icon: PlusSquare, label: 'Create', path: null, action: () => setIsCreateDropdownOpen(!isCreateDropdownOpen) },
    { icon: Clapperboard, label: 'Reels', path: '/reels' },
    { icon: Target, label: 'Ads', path: '/ads' },
    { icon: User, label: 'Profile', path: '/profile' },
  ];

  return (
    <>
      <div
        className={`hidden md:flex flex-col fixed left-0 top-0 h-full bg-white dark:bg-black border-r border-gray-200 dark:border-gray-800 z-50 transition-all duration-300 ease-in-out ${isHovered ? 'w-64' : 'w-20'}`}
        onMouseEnter={() => setIsHovered(true)}
        onMouseLeave={() => setIsHovered(false)}
      >
        <div className="p-6 mb-2">
          {isHovered ? (
            <div className="flex items-center gap-2">
              <div className="w-8 h-8 rounded-lg bg-gradient-to-tr from-insta-yellow via-insta-orange to-insta-pink flex items-center justify-center text-white font-bold text-lg shadow-md">
                b
              </div>
              <h1 className="text-2xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange transition-opacity duration-300" style={{ fontFamily: 'cursive' }}>
                B-Smart
              </h1>
            </div>
          ) : (
            <div className="w-10 h-10 rounded-lg bg-gradient-to-tr from-insta-yellow via-insta-orange to-insta-pink flex items-center justify-center text-white font-bold text-xl shadow-md transition-transform hover:scale-105">
              b
            </div>
          )}
        </div>

        <div className="flex-1 flex flex-col gap-2 px-3">
          {navItems.map((item) => {
            const Icon = item.icon;
            const isActive = location.pathname === item.path || (item.label === 'Create' && isCreateDropdownOpen);

            if (item.label === 'Create') {
              return (
                <div key={item.label} className="relative" ref={dropdownRef}>
                  <button
                    onClick={item.action}
                    className={`group w-full flex items-center gap-4 p-3 rounded-lg transition-colors duration-200 ${isActive ? 'bg-gradient-to-r from-insta-purple/10 to-insta-orange/10 dark:from-insta-purple/20 dark:to-insta-orange/20' : 'hover:bg-gray-50 dark:hover:bg-gray-900'}`}
                  >
                    <div className="min-w-[24px]">
                      <Icon
                        size={24}
                        className={`${isActive ? 'text-[#fa3f5e]' : 'text-gray-900 dark:text-white'} transition-transform duration-150 group-hover:scale-110 group-hover:text-black dark:group-hover:text-white`}
                        strokeWidth={isActive ? 2.5 : 2}
                      />
                    </div>
                    <span
                      className={`text-base font-medium whitespace-nowrap overflow-hidden transition-all duration-300 group-hover:text-black dark:group-hover:text-white ${isHovered ? 'opacity-100 w-auto' : 'opacity-0 w-0'} ${isActive ? 'text-[#fa3f5e] font-bold' : 'dark:text-white'}`}
                    >
                      {item.label}
                    </span>
                  </button>

                  {/* Dropdown Menu */}
                  {isCreateDropdownOpen && (
                    <div className={`absolute left-0 top-full mt-2 w-48 bg-white dark:bg-[#262626] rounded-lg shadow-lg border border-gray-100 dark:border-gray-800 py-2 z-[60] overflow-hidden ${isHovered ? 'translate-x-0' : 'translate-x-14'}`}>
                      {!isVendor && (
                        <>
                          <button
                            onClick={() => {
                              onOpenCreateModal('post');
                              setIsCreateDropdownOpen(false);
                            }}
                            className="w-full text-left px-4 py-3 hover:bg-gray-50 dark:hover:bg-gray-800 flex items-center gap-3 text-sm font-medium text-gray-700 dark:text-gray-200"
                          >
                            <Image size={18} />
                            Create Post
                          </button>
                          <button
                            onClick={() => {
                              onOpenCreateModal('reel');
                              setIsCreateDropdownOpen(false);
                            }}
                            className="w-full text-left px-4 py-3 hover:bg-gray-50 dark:hover:bg-gray-800 flex items-center gap-3 text-sm font-medium text-gray-700 dark:text-gray-200"
                          >
                            <Video size={18} />
                            Upload Reel
                          </button>
                        </>
                      )}
                      {isVendor && (
                        <button
                          onClick={() => {
                            if (!userObject?.is_active) {
                              setShowVendorNotValidated(true);
                            } else {
                              onOpenCreateModal('ad');
                            }
                            setIsCreateDropdownOpen(false);
                          }}
                          className="w-full text-left px-4 py-3 hover:bg-gray-50 dark:hover:bg-gray-800 flex items-center gap-3 text-sm font-medium text-gray-700 dark:text-gray-200"
                        >
                          <Megaphone size={18} />
                          Upload Ad
                        </button>
                      )}
                    </div>
                  )}
                </div>
              );
            }

            return (
              <Link
                key={item.label}
                to={item.path}
                className={`group flex items-center gap-4 p-3 rounded-xl transition-all duration-200 ${isActive ? 'bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange text-white shadow-md' : 'hover:bg-gray-50 dark:hover:bg-gray-900 text-gray-900 dark:text-white'}`}
              >
                <div className="min-w-[24px]">
                  <Icon
                    size={24}
                    className={`${isActive ? 'text-white' : 'text-gray-900 dark:text-white'} transition-transform duration-150 group-hover:scale-110 ${!isActive && 'group-hover:text-black dark:group-hover:text-white'}`}
                    strokeWidth={isActive ? 2.5 : 2}
                  />
                </div>
                <span
                  className={`text-base font-medium whitespace-nowrap overflow-hidden transition-all duration-300 ${!isActive && 'group-hover:text-black dark:group-hover:text-white'} ${isHovered ? 'opacity-100 w-auto' : 'opacity-0 w-0'} ${isActive ? 'text-white font-bold' : ''}`}
                >
                  {item.label}
                </span>
              </Link>
            );
          })}
          <div className="relative" ref={notificationsRef}>
            <button
              onClick={() => setShowNotifications(!showNotifications)}
              className={`group w-full flex items-center gap-4 p-3 rounded-xl transition-all duration-200 ${showNotifications ? 'bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange text-white shadow-md' : 'hover:bg-gray-50 dark:hover:bg-gray-900 text-gray-900 dark:text-white'}`}
            >
              <div className="min-w-[24px] relative">
                <Bell
                  size={24}
                  className={`${showNotifications ? 'text-white' : 'text-gray-900 dark:text-white'} transition-transform duration-150 group-hover:scale-110 ${!showNotifications && 'group-hover:text-black dark:group-hover:text-white'}`}
                  strokeWidth={showNotifications ? 2.5 : 2}
                />
                {unreadCount > 0 && (
                  <span className="absolute -top-1 -right-1 min-w-[16px] h-4 px-1 rounded-full bg-red-500 text-white text-[9px] font-black flex items-center justify-center leading-none border border-white dark:border-black">
                    {unreadCount > 99 ? "99+" : unreadCount}
                  </span>
                )}
              </div>
              <span
                className={`text-base font-medium whitespace-nowrap overflow-hidden transition-all duration-300 ${!showNotifications && 'group-hover:text-black dark:group-hover:text-white'} ${isHovered ? 'opacity-100 w-auto' : 'opacity-0 w-0'} ${showNotifications ? 'text-white font-bold' : ''}`}
              >
                Notifications
              </span>
            </button>
            {showNotifications && (
              <div className={`absolute left-full top-1/2 -translate-y-1/2 ml-3 w-80 z-[60] animate-fade-in ${isHovered ? 'translate-x-0' : 'translate-x-2'}`}>
                <div className="bg-white dark:bg-[#262626] rounded-xl shadow-xl border border-gray-100 dark:border-gray-800 py-2 overflow-hidden">
                  <div className="px-4 py-3 border-b border-gray-50 dark:border-gray-800 flex justify-between items-center">
                    <div className="flex items-center gap-2">
                      <h3 className="font-semibold text-sm dark:text-white">Notifications</h3>
                      {unreadCount > 0 && (
                        <span className="text-[10px] font-black px-1.5 py-0.5 rounded-full bg-blue-600 text-white leading-none">{unreadCount}</span>
                      )}
                    </div>
                    <div className="flex items-center gap-2">
                      {unreadCount > 0 && (
                        <button onClick={markAllRead} className="text-xs text-blue-500 font-semibold hover:underline flex items-center gap-1">
                          <CheckCheck size={12} /> All read
                        </button>
                      )}
                      <button onClick={() => { setShowNotifications(false); navigate(notifPage); }} className="text-xs text-[#fa3f5e] font-medium hover:underline">See all</button>
                    </div>
                  </div>
                  <div className="max-h-80 overflow-y-auto">
                    {notifLoading && notifications.length === 0 ? (
                      <div className="flex items-center justify-center py-8 text-gray-400 gap-2 text-xs">
                        <span className="w-4 h-4 border-2 border-gray-300 border-t-pink-500 rounded-full animate-spin" />
                        Loading…
                      </div>
                    ) : notifications.length === 0 ? (
                      <div className="flex flex-col items-center justify-center py-8 text-gray-400 gap-2">
                        <Bell size={20} className="opacity-30" />
                        <span className="text-xs">No notifications yet</span>
                      </div>
                    ) : (
                      notifications.map(n => (
                        <div key={n._id}
                          onClick={() => { markRead(n._id); setShowNotifications(false); if (n.link) navigate(n.link); }}
                          className={`group px-4 py-3 hover:bg-gray-50 dark:hover:bg-gray-800 flex gap-3 items-start cursor-pointer transition-colors relative ${!n.isRead ? 'bg-blue-50/50 dark:bg-blue-900/10' : ''}`}
                        >
                          {!n.isRead && <div className="absolute left-1.5 top-1/2 -translate-y-1/2 w-1.5 h-1.5 rounded-full bg-blue-500 flex-shrink-0" />}
                          {/* Avatar + icon */}
                          <div className="relative flex-shrink-0">
                            {n.sender?.avatar_url
                              ? <img src={n.sender.avatar_url} alt="" className="w-8 h-8 rounded-full object-cover" />
                              : <div className="w-8 h-8 rounded-full bg-gradient-to-br from-purple-500 to-pink-500 flex items-center justify-center text-white text-[10px] font-bold">
                                  {(n.sender?.full_name || n.sender?.username || "U")[0]?.toUpperCase()}
                                </div>
                            }
                            <div className={`absolute -bottom-0.5 -right-0.5 w-4 h-4 rounded-full ${notifTypeBg(n.type)} flex items-center justify-center ring-1 ring-white dark:ring-[#262626]`}>
                              {notifTypeIcon(n.type)}
                            </div>
                          </div>
                          <div className="flex-1 min-w-0">
                            <p className={`text-xs leading-snug ${!n.isRead ? 'font-semibold text-gray-900 dark:text-white' : 'text-gray-600 dark:text-gray-300'}`}>
                              {n.message}
                            </p>
                            <p className="text-[10px] text-gray-400 dark:text-gray-500 mt-0.5">{timeAgo(n.createdAt)}</p>
                          </div>
                          <button onClick={e => { e.stopPropagation(); deleteNotif(n._id); }}
                            className="opacity-0 group-hover:opacity-100 transition-opacity p-1 rounded hover:bg-red-100 dark:hover:bg-red-900/30">
                            <Trash2 size={11} className="text-red-400" />
                          </button>
                        </div>
                      ))
                    )}
                  </div>
                  <div className="px-4 py-2 border-t border-gray-50 dark:border-gray-800">
                    <button onClick={() => { setShowNotifications(false); navigate(notifPage); }}
                      className="w-full text-xs font-semibold text-center text-gray-500 dark:text-gray-400 hover:text-gray-800 dark:hover:text-white transition-colors py-1">
                      View all notifications →
                    </button>
                  </div>
                </div>
              </div>
            )}
          </div>

          {/* Extra items commonly found in sidebar */}
          <div className={`mt-auto pb-4 relative`} ref={moreDropdownRef}>
            {isMoreDropdownOpen && (
              <div className={`absolute bottom-full left-0 mb-2 w-64 bg-white dark:bg-[#262626] rounded-xl shadow-xl border border-gray-100 dark:border-gray-800 py-2 z-[60] overflow-hidden ${isHovered ? 'translate-x-0' : 'translate-x-14'}`}>
                <button
                  onClick={() => dispatch(toggleTheme())}
                  className="w-full text-left px-4 py-3 hover:bg-gray-50 dark:hover:bg-gray-800 flex items-center justify-between text-sm font-medium text-gray-700 dark:text-gray-200 transition-colors"
                >
                  <div className="flex items-center gap-3">
                    {mode === 'dark' ? <Moon size={18} /> : <Sun size={18} />}
                    Switch Appearance
                  </div>
                  {mode === 'dark' && <div className="w-2 h-2 rounded-full bg-blue-500"></div>}
                </button>
                <Link
                  to="/settings"
                  className="w-full text-left px-4 py-3 hover:bg-gray-50 dark:hover:bg-gray-800 flex items-center gap-3 text-sm font-medium text-gray-700 dark:text-gray-200"
                  onClick={() => setIsMoreDropdownOpen(false)}
                >
                  <Target size={18} />
                  Settings
                </Link>
              </div>
            )}
            <button
              onClick={() => setIsMoreDropdownOpen(!isMoreDropdownOpen)}
              className="w-full group flex items-center gap-4 p-3 rounded-xl hover:bg-gray-50 dark:hover:bg-gray-900 transition-colors"
            >
              <div className="min-w-[24px]">
                <Menu size={24} className="text-gray-900 dark:text-white transition-transform duration-150 group-hover:scale-110 group-hover:text-black dark:group-hover:text-white" />
              </div>
              <span
                className={`text-base font-medium whitespace-nowrap overflow-hidden transition-all duration-300 group-hover:text-black dark:group-hover:text-white ${isHovered ? 'opacity-100 w-auto' : 'opacity-0 w-0'} dark:text-white`}
              >
                More
              </span>
            </button>
          </div>
        </div>
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

export default Sidebar;
