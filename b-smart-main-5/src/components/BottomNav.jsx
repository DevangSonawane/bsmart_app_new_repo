import React from 'react';
import { Link, useLocation } from 'react-router-dom';
import { Home, Target, Clapperboard, Plus, Megaphone, Image, Video } from 'lucide-react';

const BottomNav = ({ onOpenCreateModal }) => {
  const location = useLocation();
  

  const isActive = (path) => location.pathname === path;

  // Active color: #fa3f5e (insta-pink-ish) to match the "red outline" description
  const activeColor = "text-[#fa3f5e]";
  const inactiveColor = "text-gray-500 dark:text-gray-400";

  const handleCreateClick = () => {
    onOpenCreateModal('post');
  };

  

  return (
    <div className="md:hidden fixed bottom-0 left-0 right-0 bg-white dark:bg-black border-t border-gray-200 dark:border-gray-800 flex justify-between items-center px-6 h-[60px] z-50 pb-2">
      <Link to="/" className={`${isActive('/') ? activeColor : inactiveColor}`}>
        <Home size={28} strokeWidth={isActive('/') ? 2.5 : 2} />
      </Link>

      <Link to="/ads" className={`${isActive('/ads') ? activeColor : inactiveColor}`}>
        <Target size={28} strokeWidth={isActive('/ads') ? 2.5 : 2} />
      </Link>

      <div className="relative -top-6 flex flex-col items-center">
        <button
          onClick={handleCreateClick}
          className="w-14 h-14 rounded-full bg-gradient-to-tr from-[#f09433] via-[#dc2743] to-[#bc1888] flex items-center justify-center shadow-lg border-4 border-white dark:border-black text-white transform transition-transform active:scale-95"
        >
          <Plus size={32} strokeWidth={3} />
        </button>
      </div>

      <Link to="/promote" className={`${isActive('/promote') ? activeColor : inactiveColor}`}>
        <Megaphone size={28} strokeWidth={isActive('/promote') ? 2.5 : 2} />
      </Link>

      <Link to="/reels" className={`${isActive('/reels') ? activeColor : inactiveColor}`}>
        <Clapperboard size={28} strokeWidth={isActive('/reels') ? 2.5 : 2} />
      </Link>
      
    </div>
  );
};

export default BottomNav;
