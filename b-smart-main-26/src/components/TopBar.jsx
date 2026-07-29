import React, { useEffect } from 'react';
import { Heart, Wallet } from 'lucide-react';
import { Link, useNavigate } from 'react-router-dom';
import { useSelector, useDispatch } from 'react-redux';
import { useNotificationSocket } from '../hooks/useNotificationSocket';
import { fetchWallet } from '../store/walletSlice';
import { fetchUserStory } from '../store/storySlice';
import bsmartLogo from '../assets/bsmart.png';

const BSmartLogo = () => (
  <img src={bsmartLogo} alt="b_smart" className="h-[45px] w-auto" />
);

const TopBar = () => {
  const navigate = useNavigate();
  const dispatch = useDispatch();
  const { userObject } = useSelector((state) => state.auth);
  const walletBalance = useSelector((state) => state.wallet.balance);
  const storyMap = useSelector((state) => state.story?.storyMap ?? {});

  const { unreadCount } = useNotificationSocket({ limit: 10 });

  const currentUserId = userObject?._id || userObject?.id;

  // Fetch wallet balance and own story on mount
  useEffect(() => {
    dispatch(fetchWallet());
    if (currentUserId) {
      dispatch(fetchUserStory(currentUserId, {
        avatarUrl: userObject?.avatar_url || '',
        username: userObject?.username || '',
      }));
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [currentUserId]);

  const ownStory = currentUserId ? storyMap[currentUserId] : null;
  const hasOwnStory = Boolean(ownStory);

  const getInitials = (name) => {
    const raw = (name || '').trim();
    if (!raw) return 'U';
    const parts = raw.split(/\s+/).filter(Boolean);
    return (parts[0]?.[0] || 'U') + (parts.length > 1 ? (parts[1]?.[0] || '') : '');
  };

  return (
    <div className="md:hidden fixed top-0 left-0 right-0 bg-white/90 dark:bg-black/90 backdrop-blur-sm px-4 py-2.5 flex justify-between items-center z-50">
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
            {walletBalance}
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

        {userObject?.role !== 'vendor' && (
          <Link to="/profile">
            {/* Orange gradient ring only when user has their own active story */}
            <div className={`w-8 h-8 rounded-full p-[1.5px] ${hasOwnStory ? 'bg-gradient-to-tr from-[#f09433] via-[#dc2743] to-[#bc1888]' : 'bg-gray-200 dark:bg-gray-700'}`}>
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
