import React, { useState, useRef, useEffect } from 'react';
import { Heart, MessageCircle, Send, MoreHorizontal, Music2, Volume2, VolumeX, Bookmark } from 'lucide-react';

const Reels = () => {
  const reels = [
    {
      id: 1,
      username: 'dance_queen',
      videoUrl: 'https://assets.mixkit.co/videos/preview/mixkit-girl-dancing-happy-in-a-room-4179-large.mp4',
      likes: '12.5k',
      comments: '120',
      description: 'Dancing vibes! 💃 #dance #fun'
    },
    {
      id: 2,
      username: 'nature_walks',
      videoUrl: 'https://assets.mixkit.co/videos/preview/mixkit-tree-branches-in-the-breeze-1188-large.mp4',
      likes: '8.2k',
      comments: '45',
      description: 'Peaceful morning 🌳 #nature'
    },
    {
      id: 3,
      username: 'city_life',
      videoUrl: 'https://assets.mixkit.co/videos/preview/mixkit-traffic-in-the-city-at-night-4228-large.mp4',
      likes: '25k',
      comments: '500',
      description: 'City lights 🌃 #nightlife'
    }
  ];

  const [currentIndex, setCurrentIndex] = useState(0);
  const [isMuted, setIsMuted] = useState(true);
  const [touchStartY, setTouchStartY] = useState(null);
  const isAnimatingRef = useRef(false);

  const goToIndex = (index) => {
    if (isAnimatingRef.current) return;
    const next = Math.min(reels.length - 1, Math.max(0, index));
    if (next === currentIndex) return;
    isAnimatingRef.current = true;
    setCurrentIndex(next);
    setTimeout(() => {
      isAnimatingRef.current = false;
    }, 500); // Increased timeout for smoother transition
  };

  const handleWheel = (e) => {
    if (Math.abs(e.deltaY) < 20) return;
    if (e.deltaY > 0) {
      goToIndex(currentIndex + 1);
    } else {
      goToIndex(currentIndex - 1);
    }
  };

  const handleKeyDown = (e) => {
    if (e.key === 'ArrowDown') {
      goToIndex(currentIndex + 1);
    } else if (e.key === 'ArrowUp') {
      goToIndex(currentIndex - 1);
    }
  };

  useEffect(() => {
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [currentIndex]);

  const handleTouchStart = (e) => {
    if (e.touches && e.touches[0]) {
      setTouchStartY(e.touches[0].clientY);
    }
  };

  const handleTouchEnd = (e) => {
    if (touchStartY == null || !e.changedTouches || !e.changedTouches[0]) return;
    const endY = e.changedTouches[0].clientY;
    const diff = touchStartY - endY;
    const threshold = 50;
    if (diff > threshold) {
      goToIndex(currentIndex + 1);
    } else if (diff < -threshold) {
      goToIndex(currentIndex - 1);
    }
    setTouchStartY(null);
  };

  return (
    <div className="w-full h-screen md:h-[calc(100vh-32px)] flex justify-center items-center bg-white dark:bg-black md:bg-transparent">
      <div
        className="h-screen md:h-[85vh] w-full md:w-auto relative flex items-center justify-center"
        onWheel={handleWheel}
        onTouchStart={handleTouchStart}
        onTouchEnd={handleTouchEnd}
      >
        <div className="relative w-full md:w-[350px] h-full overflow-hidden md:rounded-xl md:shadow-2xl bg-black">
          <div
            className="h-full w-full transition-transform duration-500 ease-out"
            style={{ transform: `translateY(-${currentIndex * 100}%)` }}
          >
            {reels.map((reel, index) => (
              <div
                key={reel.id}
                className="relative w-full h-full bg-gray-900 flex items-center justify-center"
              >
                <video
                  src={reel.videoUrl}
                  className="w-full h-full object-cover"
                  loop
                  autoPlay={index === currentIndex}
                  muted={isMuted}
                  playsInline
                />

                {/* Overlay Gradient */}
                <div className="absolute inset-0 bg-gradient-to-b from-black/10 via-transparent to-black/60 pointer-events-none" />

                {/* Mute Button */}
                <button
                  onClick={() => setIsMuted(!isMuted)}
                  className="absolute top-4 right-4 bg-black/50 p-2 rounded-full text-white backdrop-blur-sm hover:bg-black/70 transition-colors z-20"
                >
                  {isMuted ? <VolumeX size={16} /> : <Volume2 size={16} />}
                </button>

                {/* Bottom Info (Inside Video) */}
                <div className="absolute bottom-0 left-0 w-full p-4 pb-20 md:pb-6 z-20">
                  <div className="flex items-center gap-3 mb-3">
                    <div className="w-8 h-8 rounded-full border border-white/20 p-0.5 cursor-pointer hover:scale-105 transition-transform">
                      <img
                        src={`https://i.pravatar.cc/150?u=${reel.username}`}
                        className="w-full h-full rounded-full object-cover"
                        alt="user"
                      />
                    </div>
                    <div className="flex flex-col">
                      <div className="flex items-center gap-2">
                        <span className="font-bold text-white text-sm hover:underline cursor-pointer">{reel.username}</span>
                        <button className="border border-white/40 bg-white/10 backdrop-blur-sm px-3 py-0.5 rounded-lg text-[12px] font-semibold text-white hover:bg-white/20 transition-colors">
                          Follow
                        </button>
                      </div>
                    </div>
                  </div>

                  <p className="text-white text-sm leading-relaxed mb-2 line-clamp-2">
                    {reel.description}
                  </p>

                  <div className="flex items-center gap-2 text-white/90 text-xs">
                    <Music2 size={12} />
                    <div className="overflow-hidden w-40">
                      <span className="whitespace-nowrap animate-marquee">Original Audio - {reel.username}</span>
                    </div>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Right Side Actions - Outside Video (Desktop Only) */}
        <div className="hidden md:flex flex-col gap-5 ml-4 justify-end h-full pb-4">
          <div className="flex flex-col items-center gap-1 group cursor-pointer">
            <div className="w-10 h-10 rounded-full bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 shadow-sm flex items-center justify-center hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors group-hover:scale-110">
              <Heart size={22} className="text-black dark:text-white" />
            </div>
            <span className="text-xs font-medium text-gray-900 dark:text-white">{reels[currentIndex].likes}</span>
          </div>

          <div className="flex flex-col items-center gap-1 group cursor-pointer">
            <div className="w-10 h-10 rounded-full bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 shadow-sm flex items-center justify-center hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors group-hover:scale-110">
              <MessageCircle size={22} className="text-black dark:text-white" />
            </div>
            <span className="text-xs font-medium text-gray-900 dark:text-white">{reels[currentIndex].comments}</span>
          </div>

          <div className="flex flex-col items-center gap-1 group cursor-pointer">
            <div className="w-10 h-10 rounded-full bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 shadow-sm flex items-center justify-center hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors group-hover:scale-110">
              <Send size={22} className="text-black dark:text-white -rotate-12" />
            </div>
          </div>

          <div className="flex flex-col items-center gap-1 group cursor-pointer">
            <div className="w-10 h-10 rounded-full bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 shadow-sm flex items-center justify-center hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors group-hover:scale-110">
              <Bookmark size={22} className="text-black dark:text-white" />
            </div>
          </div>

          <div className="flex flex-col items-center gap-1 group cursor-pointer">
            <div className="w-10 h-10 rounded-full bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 shadow-sm flex items-center justify-center hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors group-hover:scale-110">
              <MoreHorizontal size={22} className="text-black dark:text-white" />
            </div>
          </div>

          <div className="w-8 h-8 border-2 border-gray-200 dark:border-gray-800 rounded-md overflow-hidden mt-2 cursor-pointer shadow-sm">
            <img
              src={`https://i.pravatar.cc/150?u=${reels[currentIndex].username}`}
              className="w-full h-full object-cover"
              alt="music"
            />
          </div>
        </div>

        {/* Mobile Actions Overlay (Hidden on Desktop) */}
        <div className="md:hidden absolute bottom-20 right-4 flex flex-col gap-4 items-center z-20">
          <div className="flex flex-col items-center gap-1">
            <Heart size={28} className="text-white" />
            <span className="text-white text-xs">{reels[currentIndex].likes}</span>
          </div>
          <div className="flex flex-col items-center gap-1">
            <MessageCircle size={28} className="text-white" />
            <span className="text-white text-xs">{reels[currentIndex].comments}</span>
          </div>
          <Send size={26} className="text-white -rotate-12" />
          <MoreHorizontal size={26} className="text-white" />
          <div className="w-8 h-8 border-2 border-white rounded-md overflow-hidden mt-2">
            <img src={`https://i.pravatar.cc/150?u=${reels[currentIndex].username}`} className="w-full h-full object-cover" alt="music" />
          </div>
        </div>
      </div>
    </div>
  );
};

export default Reels;
