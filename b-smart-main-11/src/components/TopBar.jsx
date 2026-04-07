import React from 'react';
import { Heart, Search, Wallet } from 'lucide-react';
import { Link, useNavigate } from 'react-router-dom';
import { useSelector } from 'react-redux';
import { useNotificationSocket } from '../hooks/useNotificationSocket';

// ─── B-Smart Logo ─────────────────────────────────────────────────────────────
const BSmartLogo = () => (
  <div className="flex items-center gap-2">
    {/* Icon */}
    <div className="w-8 h-8 rounded-xl bg-gradient-to-br from-[#f09433] via-[#e6683c] via-[#dc2743] to-[#bc1888] flex items-center justify-center shadow-md shadow-pink-500/30 flex-shrink-0">
      <span className="text-white font-black text-sm leading-none">b</span>
    </div>
    {/* Wordmark */}
    <span className="text-base font-black tracking-tight">
      <span className="text-[#f09433]">B</span>
      <span className="text-[#dc2743]">-</span>
      <span
        className="bg-clip-text text-transparent"
        style={{
          backgroundImage: 'linear-gradient(90deg, #f09433 0%, #e6683c 30%, #dc2743 60%, #bc1888 100%)',
        }}
      >
        Smart
      </span>
    </span>
  </div>
);

const TopBar = () => {
  const navigate = useNavigate();
  const { userObject } = useSelector((state) => state.auth);

  const { unreadCount } = useNotificationSocket({ limit: 10 });

  const getInitials = (name) => {
    const raw = (name || '').trim();
    if (!raw) return 'U';
    const parts = raw.split(/\s+/).filter(Boolean);
    return (parts[0]?.[0] || 'U') + (parts.length > 1 ? (parts[1]?.[0] || '') : '');
  };

  return (
    <div className="md:hidden fixed top-0 left-0 right-0 bg-white dark:bg-black border-b border-gray-200 dark:border-gray-800 px-4 py-2.5 flex justify-between items-center z-50">
      {/* Left: B-Smart logo */}
      <Link to="/" className="flex items-center gap-2">
        <BSmartLogo />
      </Link>

      {/* Right: actions */}
      <div className="flex gap-3 items-center">
        {/* Wallet chip */}
        <Link
          to="/wallet"
          className="flex items-center gap-1.5 bg-gray-50 dark:bg-gray-900 px-2.5 py-1.5 rounded-full border border-gray-200 dark:border-gray-800 shadow-sm hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors"
        >
          <div className="w-5 h-5 rounded-full bg-gradient-to-tr from-[#f09433] via-[#dc2743] to-[#bc1888] flex items-center justify-center text-white flex-shrink-0">
            <Wallet size={11} />
          </div>
          <span className="text-[11px] font-bold text-gray-900 dark:text-white leading-none">
            {userObject?.wallet?.balance ? Math.floor(Number(userObject.wallet.balance)) : 0}
          </span>
        </Link>

        {/* Notification Heart → goes to /notifications page */}
        <button
          onClick={() => navigate('/notifications')}
          className="relative p-1.5 rounded-full transition-colors hover:bg-gray-100 dark:hover:bg-gray-800"
          aria-label="Notifications"
        >
          <Heart size={22} className="text-black dark:text-white" />
          {unreadCount > 0 && (
            <span className="absolute -top-0.5 -right-0.5 min-w-[16px] h-[16px] px-0.5 bg-[#fa3f5e] rounded-full border-2 border-white dark:border-black flex items-center justify-center">
              <span className="text-[8px] font-black text-white leading-none">
                {unreadCount > 99 ? '99+' : unreadCount}
              </span>
            </span>
          )}
        </button>

        {/* Search → goes to /search page */}
        <button
          onClick={() => navigate('/search')}
          className="p-1.5 rounded-full transition-colors hover:bg-gray-100 dark:hover:bg-gray-800"
          aria-label="Search"
        >
          <Search size={22} className="text-black dark:text-white" />
        </button>

        {userObject?.role !== 'vendor' && (
          <Link to="/profile">
            <div className="w-8 h-8 rounded-full bg-gradient-to-tr from-[#f09433] via-[#dc2743] to-[#bc1888] p-[1.5px]">
              <div className="w-full h-full rounded-full bg-white dark:bg-black p-[1px]">
                {userObject?.avatar_url ? (
                  <img src={userObject.avatar_url} alt={userObject?.username || 'Profile'} className="w-full h-full rounded-full object-cover" />
                ) : (
                  <div className="w-full h-full rounded-full bg-white dark:bg-black flex items-center justify-center text-[11px] font-bold text-gray-900 dark:text-white">
                    {getInitials(userObject?.full_name || userObject?.username).toUpperCase()}
                  </div>
                )}
              </div>
            </div>
          </Link>
        )}
      </div>
    </div>
  );
};

export default TopBar;