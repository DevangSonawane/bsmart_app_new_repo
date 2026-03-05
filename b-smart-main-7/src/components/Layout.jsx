import React, { useState } from 'react';
import { Outlet, useLocation, Link } from 'react-router-dom';
import { useSelector } from 'react-redux';
import BottomNav from './BottomNav';
import TopBar from './TopBar';
import Sidebar from './Sidebar';
import CreatePostModal from './CreatePostModal';

const Layout = () => {
  const location = useLocation();
  const { userObject } = useSelector((state) => state.auth);
  const isExcludedPage = ['/profile', '/settings', '/reels', '/promote', '/ads'].includes(location.pathname);
  const isFullScreenPage = ['/reels', '/promote', '/ads'].includes(location.pathname);
  // Show TopBar on mobile for all pages except profile, settings, reels, and promote
  const showTopBar = !isExcludedPage;
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);
  const [createType, setCreateType] = useState('post');

  const handleOpenCreateModal = (type = 'post') => {
    setCreateType(type);
    setIsCreateModalOpen(true);
  };

  return (
    <div className={`min-h-screen bg-gray-50 dark:bg-black md:pb-0 ${isFullScreenPage ? 'pb-0' : 'pb-16'}`}>
      <Sidebar onOpenCreateModal={handleOpenCreateModal} />

      <div className="md:pl-20 min-h-screen transition-all duration-300">
        {showTopBar && <TopBar />}

        {/* Main Content Container with Gaps on Desktop */}
        <div className={`
          ${showTopBar ? 'pt-16 md:pt-4' : 'pt-0 md:pt-4'} 
          w-full 
          md:max-w-[calc(100%-80px)] 
          lg:max-w-4xl 
          mx-auto 
          px-0 
          md:px-8
        `}>
          <Outlet />
        </div>
      </div>

      <BottomNav onOpenCreateModal={handleOpenCreateModal} />

      {/* Create Post Modal */}
      <CreatePostModal
        isOpen={isCreateModalOpen}
        onClose={() => setIsCreateModalOpen(false)}
        initialType={createType}
      />

      {/* Floating Wallet for Desktop */}
      {!isExcludedPage && (
        <Link to="/wallet" className="hidden md:flex fixed bottom-8 right-8 z-50 bg-white dark:bg-[#262626] rounded-full shadow-lg p-1 pr-4 items-center gap-2 border border-gray-100 dark:border-gray-800 animate-fade-in hover:scale-105 transition-transform cursor-pointer">
          <div className="w-10 h-10 rounded-full bg-gradient-to-tr from-insta-yellow via-insta-orange to-insta-pink flex items-center justify-center text-white">
            <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M21 12V7H5a2 2 0 0 1 0-4h14v4" /><path d="M3 5v14a2 2 0 0 0 2 2h16v-5" /><path d="M18 12a2 2 0 0 0 0 4h4v-4Z" /></svg>
          </div>
          <div className="flex flex-col">
            <span className="text-xs text-gray-500 dark:text-gray-400 font-medium">Balance</span>
            <span className="text-sm font-bold text-gray-900 dark:text-white">
              Coins {userObject?.wallet?.balance ? Math.floor(Number(userObject.wallet.balance)) : 0}
            </span>
          </div>
        </Link>
      )}
    </div>
  );
};

export default Layout;
