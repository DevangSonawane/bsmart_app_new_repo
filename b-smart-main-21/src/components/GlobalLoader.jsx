import React, { useState, useEffect } from 'react';
import { useLocation } from 'react-router-dom';
import PageLoader from './PageLoader';

const GlobalLoader = () => {
  const location = useLocation();
  const [loading, setLoading] = useState(false);
  const [displayLoader, setDisplayLoader] = useState(false);

  useEffect(() => {
    // Show loader on route change
    setLoading(true);
    setDisplayLoader(true);

    // Hide loader after a delay
    const timer = setTimeout(() => {
      setLoading(false);
      // Extra time for fade out animation if we add one
      setTimeout(() => setDisplayLoader(false), 300);
    }, 600); // Adjust duration as needed

    return () => clearTimeout(timer);
  }, [location.pathname]);

  if (!displayLoader) return null;

  return (
    <div className={`fixed inset-0 z-[99999] transition-opacity duration-300 ${loading ? 'opacity-100' : 'opacity-0'} pointer-events-none`}>
      <PageLoader />
    </div>
  );
};

export default GlobalLoader;
