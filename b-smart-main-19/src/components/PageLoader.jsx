import React from 'react';
import logo from '../assets/bsmart_logo.png';

const PageLoader = () => {
  return (
    <div className="fixed inset-0 z-[99999] flex items-center justify-center bg-white dark:bg-black transition-opacity duration-300">
      <div className="relative flex flex-col items-center">
        {/* Main Loader Container */}
        <div className="relative flex items-center justify-center">
          {/* Rotating Outer Ring */}
          <div 
            className="absolute w-32 h-32 rounded-full border-[4px] border-transparent animate-spin"
            style={{ 
              borderTopColor: '#e3304b', 
              borderRightColor: '#e3304b',
              animationDuration: '1.2s'
            }} 
          />
          
          {/* Static Background Ring */}
          <div 
            className="absolute w-32 h-32 rounded-full border-[4px] opacity-10"
            style={{ borderColor: '#e3304b' }} 
          />

          {/* Pulsing Glow */}
          <div 
            className="absolute w-28 h-28 rounded-full animate-pulse opacity-20 blur-2xl"
            style={{ backgroundColor: '#e3304b' }} 
          />
          
          {/* Logo Container - Larger circle */}
          <div className="relative w-24 h-24 rounded-full overflow-hidden shadow-2xl bg-white dark:bg-gray-900 p-1 border border-gray-50 dark:border-gray-800">
            <img 
              src={logo} 
              alt="B-Smart" 
              className="w-full h-full object-cover rounded-full"
            />
          </div>
        </div>

        {/* Brand Text */}
        <div className="mt-10 flex flex-col items-center gap-3">
          <span 
            className="text-[14px] font-black uppercase tracking-[0.5em] italic"
            style={{ color: '#e3304b' }}
          >
            B-Smart
          </span>
          {/* Progress dots - Slightly larger */}
          <div className="flex gap-2">
            <div className="w-1.5 h-1.5 rounded-full animate-bounce [animation-delay:-0.3s]" style={{ backgroundColor: '#e3304b' }} />
            <div className="w-1.5 h-1.5 rounded-full animate-bounce [animation-delay:-0.15s]" style={{ backgroundColor: '#e3304b' }} />
            <div className="w-1.5 h-1.5 rounded-full animate-bounce" style={{ backgroundColor: '#e3304b' }} />
          </div>
        </div>
      </div>
    </div>
  );
};

export default PageLoader;
