import React, { useState } from 'react';
import { Heart, Search, User, Bell, Wallet, MapPin, Home, ChevronDown } from 'lucide-react';
import { Link } from 'react-router-dom';
import { useSelector } from 'react-redux';

const TopBar = () => {
  const [showNotifications, setShowNotifications] = useState(false);
  const { userObject } = useSelector((state) => state.auth);

  return (
    <div className="md:hidden fixed top-0 left-0 right-0 bg-white dark:bg-black border-b border-gray-200 dark:border-gray-800 px-4 py-3 flex justify-between items-center z-50">
      <div className="flex items-center gap-2 flex-1 max-w-[70%]">
        <div className="flex items-center gap-1 min-w-fit">

          <span className="text-sm font-black text-black dark:text-white uppercase tracking-wide">B-Smart</span>
        </div>
      </div>

      <div className="flex gap-4 items-center">
        {/* Wallet Display for Mobile */}
        <Link to="/wallet" className="flex items-center gap-2 bg-white dark:bg-gray-900 px-3 py-1.5 rounded-full border border-gray-100 dark:border-gray-800 shadow-sm hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors mr-1">
          <div className="w-8 h-8 rounded-full bg-gradient-to-tr from-insta-yellow via-insta-orange to-insta-pink flex items-center justify-center text-white shrink-0">
            <Wallet size={16} />
          </div>
          <div className="flex flex-col items-start justify-center h-full">
            <span className="text-[10px] text-gray-500 dark:text-gray-400 font-medium leading-none mb-0.5">Balance</span>
            <span className="text-xs font-bold text-gray-900 dark:text-white leading-none">Coins {userObject?.wallet?.balance ? Math.floor(Number(userObject.wallet.balance)) : 0}</span>
          </div>
        </Link>

        {/* Notifications with Dropdown */}
        <div className="relative">
          <button onClick={() => setShowNotifications(!showNotifications)} className="relative">
            <Heart size={24} className="text-black dark:text-white" />
            <span className="absolute -top-1 -right-1 w-2.5 h-2.5 bg-[#fa3f5e] rounded-full border-2 border-white dark:border-black"></span>
          </button>

          {showNotifications && (
            <div className="absolute right-0 top-full mt-2 w-64 bg-white dark:bg-gray-900 rounded-xl shadow-xl border border-gray-100 dark:border-gray-800 py-2 z-50 animate-fade-in">
              <div className="px-4 py-2 border-b border-gray-50 dark:border-gray-800">
                <h3 className="font-semibold text-sm text-gray-900 dark:text-white">Notifications</h3>
              </div>
              <div className="max-h-60 overflow-y-auto">
                <div className="px-4 py-3 hover:bg-gray-50 dark:hover:bg-gray-800 flex gap-3 items-center">
                  <div className="w-8 h-8 rounded-full bg-blue-50 dark:bg-blue-900/30 text-blue-500 flex items-center justify-center"><Bell size={14} /></div>
                  <div>
                    <p className="text-xs text-gray-900 dark:text-gray-200">New follower: <span className="font-bold">Sarah</span></p>
                    <p className="text-[10px] text-gray-500 dark:text-gray-400">2 min ago</p>
                  </div>
                </div>
                <div className="px-4 py-3 hover:bg-gray-50 dark:hover:bg-gray-800 flex gap-3 items-center">
                  <div className="w-8 h-8 rounded-full bg-pink-50 dark:bg-pink-900/30 text-pink-500 flex items-center justify-center"><Heart size={14} /></div>
                  <div>
                    <p className="text-xs text-gray-900 dark:text-gray-200">Mike liked your post</p>
                    <p className="text-[10px] text-gray-500 dark:text-gray-400">1 hour ago</p>
                  </div>
                </div>
              </div>
            </div>
          )}
        </div>

        <Search size={24} className="text-black dark:text-white" />

        <Link to="/profile">
          <div className="w-8 h-8 rounded-full bg-gradient-to-tr from-insta-yellow via-insta-orange to-insta-pink p-[1.5px]">
            <div className="w-full h-full rounded-full bg-white dark:bg-black p-[1px]">
              <img
                src={userObject?.avatar_url || "https://i.pravatar.cc/150?u=my_profile"}
                alt={userObject?.username || "Profile"}
                className="w-full h-full rounded-full object-cover"
              />
            </div>
          </div>
        </Link>
      </div>
    </div>
  );
};

export default TopBar;
