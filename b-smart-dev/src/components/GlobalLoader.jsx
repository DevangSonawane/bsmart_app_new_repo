import { useState, useEffect, useRef } from 'react';
import { useLocation } from 'react-router-dom';
import PageLoader from './PageLoader';

const getTopSegment = (pathname) => {
  const seg = pathname.split('/').filter(Boolean)[0];
  return seg || '/';
};

const SKIP_LOADER = new Set(['settings', 'profile', 'wallet', 'notifications', 'search']);

const GlobalLoader = () => {
  const location = useLocation();
  const [loading, setLoading] = useState(false);
  const prevSegmentRef = useRef(getTopSegment(location.pathname));
  const showTimerRef = useRef(null);
  const hideTimerRef = useRef(null);

  useEffect(() => {
    const currentSegment = getTopSegment(location.pathname);
    const prevSegment = prevSegmentRef.current;
    prevSegmentRef.current = currentSegment;

    if (currentSegment === prevSegment || SKIP_LOADER.has(currentSegment)) return;

    clearTimeout(showTimerRef.current);
    clearTimeout(hideTimerRef.current);
    showTimerRef.current = setTimeout(() => setLoading(true), 0);
    hideTimerRef.current = setTimeout(() => setLoading(false), 700);

    return () => {
      clearTimeout(showTimerRef.current);
      clearTimeout(hideTimerRef.current);
    };
  }, [location.pathname]);

  if (!loading) return null;

  return (
    <div className="fixed inset-0 z-[99999] pointer-events-none">
      <PageLoader />
    </div>
  );
};

export default GlobalLoader;
