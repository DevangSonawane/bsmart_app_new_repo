import React from 'react';
import { X } from 'lucide-react';
import TweetComponent from './TweetComponent'; // Assuming TweetComponent exists

const TweetDetailModal = ({ tweet, isOpen, onClose }) => {
  if (!isOpen || !tweet) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black bg-opacity-75">
      <div className="relative w-full max-w-2xl max-h-[90vh] overflow-y-auto bg-white dark:bg-black rounded-lg shadow-xl">
        {/* Header */}
        <div className="sticky top-0 z-10 flex items-center justify-between p-3 border-b border-gray-200 dark:border-gray-800 bg-white dark:bg-black">
          <h2 className="text-lg font-semibold dark:text-white">Tweet</h2>
          <button onClick={onClose} className="p-2 rounded-full hover:bg-gray-100 dark:hover:bg-gray-800">
            <X size={20} className="dark:text-white" />
          </button>
        </div>

        {/* Tweet Content */}
        <div className="p-4">
          <TweetComponent tweet={tweet} />
        </div>
      </div>
    </div>
  );
};

export default TweetDetailModal;
