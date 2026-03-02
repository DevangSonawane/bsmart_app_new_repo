import React, { useState, useEffect, useRef } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { useDispatch, useSelector } from 'react-redux';
import { Home, PlusSquare, Clapperboard, ShoppingBag, User, Menu, Image, Video, Target, Megaphone, Moon, Sun, Search, Heart, Bell, MessageCircle } from 'lucide-react';
import { toggleTheme } from '../store/themeSlice';
import CreatePostModal from './CreatePostModal';

const Sidebar = ({ onOpenCreateModal }) => {
  const location = useLocation();
  const dispatch = useDispatch();
  const { mode } = useSelector((state) => state.theme);
  const { userObject } = useSelector((state) => state.auth);
  const [isHovered, setIsHovered] = useState(false);
  const [isCreateDropdownOpen, setIsCreateDropdownOpen] = useState(false);
  const [isMoreDropdownOpen, setIsMoreDropdownOpen] = useState(false);
  const [showNotifications, setShowNotifications] = useState(false);
  const [showVendorNotValidated, setShowVendorNotValidated] = useState(false);
  const dropdownRef = useRef(null);
  const moreDropdownRef = useRef(null);
  const notificationsRef = useRef(null);
  const isVendor = userObject?.role === 'vendor';

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

  const navItems = isVendor ? [
    { icon: Home, label: 'Home', path: '/' },
    { icon: Target, label: 'Ads', path: '/ads' },
    { icon: PlusSquare, label: 'Create', path: null, action: () => setIsCreateDropdownOpen(!isCreateDropdownOpen) },
    { icon: User, label: 'Profile', path: '/profile' },
  ] : [
    { icon: Home, label: 'Home', path: '/' },
    { icon: Search, label: 'Search', path: '/search' },
    { icon: PlusSquare, label: 'Create', path: null, action: () => setIsCreateDropdownOpen(!isCreateDropdownOpen) },
    { icon: Clapperboard, label: 'Reels', path: '/reels' },
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
                <Heart
                  size={24}
                  className={`${showNotifications ? 'text-white' : 'text-gray-900 dark:text-white'} transition-transform duration-150 group-hover:scale-110 ${!showNotifications && 'group-hover:text-black dark:group-hover:text-white'}`}
                  strokeWidth={showNotifications ? 2.5 : 2}
                />
                <span className="absolute -top-0.5 -right-0.5 w-2 h-2 bg-[#fa3f5e] rounded-full border border-white dark:border-black"></span>
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
                    <h3 className="font-semibold text-sm dark:text-white">Notifications</h3>
                    <span className="text-xs text-[#fa3f5e] font-medium cursor-pointer">Mark all read</span>
                  </div>
                  <div className="max-h-80 overflow-y-auto">
                    <div className="px-4 py-3 hover:bg-gray-50 dark:hover:bg-gray-800 flex gap-3 items-center cursor-pointer transition-colors">
                      <div className="w-8 h-8 rounded-full bg-blue-50 dark:bg-blue-900/20 text-blue-500 flex items-center justify-center flex-shrink-0"><Bell size={14} /></div>
                      <div>
                        <p className="text-sm text-gray-900 dark:text-gray-200">New follower: <span className="font-bold">Sarah</span></p>
                        <p className="text-xs text-gray-500 dark:text-gray-400">2 min ago</p>
                      </div>
                    </div>
                    <div className="px-4 py-3 hover:bg-gray-50 dark:hover:bg-gray-800 flex gap-3 items-center cursor-pointer transition-colors">
                      <div className="w-8 h-8 rounded-full bg-pink-50 dark:bg-pink-900/20 text-pink-500 flex items-center justify-center flex-shrink-0"><Heart size={14} /></div>
                      <div>
                        <p className="text-sm text-gray-900 dark:text-gray-200">Mike liked your post</p>
                        <p className="text-xs text-gray-500 dark:text-gray-400">1 hour ago</p>
                      </div>
                    </div>
                    <div className="px-4 py-3 hover:bg-gray-50 dark:hover:bg-gray-800 flex gap-3 items-center cursor-pointer transition-colors">
                      <div className="w-8 h-8 rounded-full bg-purple-50 dark:bg-purple-900/20 text-purple-500 flex items-center justify-center flex-shrink-0"><MessageCircle size={14} /></div>
                      <div>
                        <p className="text-sm text-gray-900 dark:text-gray-200">Anna commented: "Amazing!"</p>
                        <p className="text-xs text-gray-500 dark:text-gray-400">2 hours ago</p>
                      </div>
                    </div>
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
