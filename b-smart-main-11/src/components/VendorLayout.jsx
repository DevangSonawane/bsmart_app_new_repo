import React, { useState } from 'react';
import { Outlet } from 'react-router-dom';
import { useSelector } from 'react-redux';
import Sidebar from './Sidebar';
import TopBar from './TopBar';
import BottomNav from './BottomNav';
import CreatePostModal from './CreatePostModal';

const VendorLayout = () => {
  const { userObject } = useSelector((state) => state.auth);
  const isVendorValidated = Boolean(
    userObject?.vendor_validated ??
    userObject?.validated ??
    userObject?.vendor?.validated
  );
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);
  const [createType, setCreateType] = useState('ad');
  const [isSidebarHovered, setIsSidebarHovered] = useState(false);
  const [showVendorNotValidated, setShowVendorNotValidated] = useState(false);

  const handleOpenCreateModal = (type = 'ad') => {
    if (userObject?.role === 'vendor' && type === 'ad' && !isVendorValidated) {
      setShowVendorNotValidated(true);
      return;
    }
    setCreateType(type);
    setIsCreateModalOpen(true);
  };

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-black">
      <div 
        onMouseEnter={() => setIsSidebarHovered(true)}
        onMouseLeave={() => setIsSidebarHovered(false)}
      >
        <Sidebar onOpenCreateModal={handleOpenCreateModal} />
      </div>

      <div className={`min-h-screen transition-all duration-300 ${isSidebarHovered ? 'md:pl-64' : 'md:pl-20'}`}>
        <TopBar />

        {/* Full width container for vendor dashboard pages */}
        <div className="pt-16 md:pt-4 w-full px-4 md:px-8 pb-20 md:pb-4">
          <Outlet context={{ handleOpenCreateModal }} />
        </div>
      </div>

      <BottomNav onOpenCreateModal={handleOpenCreateModal} />

      {/* Create Post Modal */}
      <CreatePostModal
        isOpen={isCreateModalOpen}
        onClose={() => setIsCreateModalOpen(false)}
        initialType={createType}
      />

      {showVendorNotValidated && (
        <div className="fixed inset-0 z-[70] flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
          <div className="bg-white dark:bg-gray-900 rounded-xl p-6 w-full max-w-sm shadow-2xl border border-gray-100 dark:border-gray-800">
            <h3 className="text-lg font-bold text-gray-900 dark:text-white mb-2 text-center">
              Vendor verification pending
            </h3>
            <p className="text-gray-500 dark:text-gray-400 text-sm mb-6 text-center">
              Your vendor account is not yet validated. Please wait for approval before uploading ads.
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
    </div>
  );
};

export default VendorLayout;
