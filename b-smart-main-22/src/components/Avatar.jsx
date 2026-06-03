import React from 'react';

const Avatar = ({ src, username, size = 'md' }) => {
  const dim = size === 'sm' ? 'w-8 h-8 text-xs' : 'w-9 h-9 text-sm';
  return (
    <div className={`${dim} rounded-full bg-gray-100 dark:bg-gray-800 flex-shrink-0 overflow-hidden`}>
      {src
        ? <img src={src} alt={username || 'user'} className="w-full h-full object-cover" />
        : <div className="w-full h-full flex items-center justify-center font-bold text-gray-500 bg-gray-200 dark:bg-gray-700">
            {(username || 'U')[0].toUpperCase()}
          </div>
      }
    </div>
  );
};

export default Avatar;
