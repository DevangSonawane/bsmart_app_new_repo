import React, { useState, useRef, useEffect, useCallback } from 'react';
import { Heart, MessageCircle, Send, MoreHorizontal, Music2, Volume2, VolumeX, Bookmark, ChevronLeft, Search, Home, Target, PlusCircle, User, HeartHandshake, Menu, Bell, ShoppingBag } from 'lucide-react';

// Coin icon SVG
const CoinIcon = ({ size = 14, className = '' }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" className={className}>
    <circle cx="12" cy="12" r="10" fill="#F59E0B" stroke="#D97706" strokeWidth="1.5" />
    <text x="12" y="16.5" textAnchor="middle" fontSize="11" fontWeight="bold" fill="#7C2D12">₿</text>
  </svg>
);

const FALLBACK_CATEGORIES = [
  "All",
  "Accessories",
  "Action Figures",
  "Art Supplies",
  "Baby Products",
  "Beauty & Personal Care",
  "Books",
  "Clothing & Apparel",
  "Electronics",
  "Food & Beverages",
  "Footwear",
  "Gaming",
  "Health & Wellness",
  "Home & Kitchen",
  "Jewellery",
  "Mobile & Tablets",
  "Pet Supplies",
  "Sports & Fitness",
  "Toys",
  "Travel"
];

const ads = [
  {
    id: 1,
    username: 'dance_queen',
    coins: 124,
    videoUrl: 'https://assets.mixkit.co/videos/preview/mixkit-girl-dancing-happy-in-a-room-4179-large.mp4',
    likes: '12.5k',
    comments: '120',
    shares: '5',
    saves: 'Save',
    description: 'Dancing vibes! 💃 #dance #fun',
    category: 'Fashion',
  },
  {
    id: 2,
    username: 'nature_walks',
    coins: 88,
    videoUrl: 'https://assets.mixkit.co/videos/preview/mixkit-tree-branches-in-the-breeze-1188-large.mp4',
    likes: '8.2k',
    comments: '45',
    shares: '2',
    saves: 'Save',
    description: 'Peaceful morning 🌳 #nature',
    category: 'Travel',
  },
  {
    id: 3,
    username: 'city_life',
    coins: 310,
    videoUrl: 'https://assets.mixkit.co/videos/preview/mixkit-traffic-in-the-city-at-night-4228-large.mp4',
    likes: '25k',
    comments: '500',
    shares: '80',
    saves: 'Save',
    description: 'City lights 🌃 #nightlife',
    category: 'Movies',
  },
];

const ActionButtons = ({ ad, likedIds, toggleLike, savedIds, toggleSave, mobile = false, vertical = true }) => (
  <div className={`flex ${vertical ? 'flex-col' : 'flex-row'} items-center gap-4`}>
    {/* Like */}
    <button onClick={() => toggleLike(ad.id)} className="flex flex-col items-center gap-1">
      <div className={`${mobile ? 'w-10 h-10' : 'w-10 h-10'} rounded-full flex items-center justify-center transition-all active:scale-90 ${mobile ? 'bg-black/30 backdrop-blur-sm' : 'bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-700 shadow-sm hover:bg-gray-50 dark:hover:bg-gray-800'}`}>
        <Heart size={20} className={likedIds.has(ad.id) ? 'text-red-500 fill-red-500' : mobile ? 'text-white' : 'text-gray-800 dark:text-white'} />
      </div>
      <span className={`text-xs font-semibold ${mobile ? 'text-white' : 'text-gray-700 dark:text-white'}`}>{ad.likes}</span>
    </button>
    {/* Comment */}
    <button className="flex flex-col items-center gap-1">
      <div className={`w-10 h-10 rounded-full flex items-center justify-center transition-all active:scale-90 ${mobile ? 'bg-black/30 backdrop-blur-sm' : 'bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-700 shadow-sm hover:bg-gray-50 dark:hover:bg-gray-800'}`}>
        <MessageCircle size={20} className={mobile ? 'text-white' : 'text-gray-800 dark:text-white'} />
      </div>
      <span className={`text-xs font-semibold ${mobile ? 'text-white' : 'text-gray-700 dark:text-white'}`}>{ad.comments}</span>
    </button>
    {/* Share */}
    <button className="flex flex-col items-center gap-1">
      <div className={`w-10 h-10 rounded-full flex items-center justify-center transition-all active:scale-90 ${mobile ? 'bg-black/30 backdrop-blur-sm' : 'bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-700 shadow-sm hover:bg-gray-50 dark:hover:bg-gray-800'}`}>
        <Send size={18} className={`-rotate-12 ${mobile ? 'text-white' : 'text-gray-800 dark:text-white'} relative left-[-2px]`} />
      </div>
      <span className={`text-xs font-semibold ${mobile ? 'text-white' : 'text-gray-700 dark:text-white'}`}>{ad.shares}</span>
    </button>
    {/* Save */}
    <button onClick={() => toggleSave(ad.id)} className="flex flex-col items-center gap-1">
      <div className={`w-10 h-10 rounded-full flex items-center justify-center transition-all active:scale-90 ${mobile ? 'bg-black/30 backdrop-blur-sm' : 'bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-700 shadow-sm hover:bg-gray-50 dark:hover:bg-gray-800'}`}>
        <Bookmark size={20} className={savedIds.has(ad.id) ? (mobile ? 'text-yellow-400 fill-yellow-400' : 'text-yellow-500 fill-yellow-500') : mobile ? 'text-white' : 'text-gray-800 dark:text-white'} />
      </div>
      <span className={`text-xs font-semibold ${mobile ? 'text-white' : 'text-gray-700 dark:text-white'}`}>Save</span>
    </button>
    {/* More */}
    <button className="flex flex-col items-center gap-1">
      <div className={`w-10 h-10 rounded-full flex items-center justify-center transition-all active:scale-90 ${mobile ? 'bg-black/30 backdrop-blur-sm' : 'bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-700 shadow-sm hover:bg-gray-50 dark:hover:bg-gray-800'}`}>
        <MoreHorizontal size={20} className={mobile ? 'text-white' : 'text-gray-800 dark:text-white'} />
      </div>
    </button>
    {/* Avatar music disc */}
    <div className={`w-9 h-9 rounded-full border-2 ${mobile ? 'border-white' : 'border-gray-300 dark:border-gray-600'} overflow-hidden shadow-md mt-1`}>
      <img src={`https://i.pravatar.cc/150?u=${ad.username}`} className="w-full h-full object-cover" alt="music" />
    </div>
  </div>
);

const Ads = () => {
  const [categories] = useState(FALLBACK_CATEGORIES);
  const [activeCategory, setActiveCategory] = useState('All');
  const [currentIndex, setCurrentIndex] = useState(0);
  const [isMuted, setIsMuted] = useState(true);
  const [touchStartY, setTouchStartY] = useState(null);
  const [progress, setProgress] = useState(0);
  const [likedIds, setLikedIds] = useState(new Set());
  const [savedIds, setSavedIds] = useState(new Set());
  const isAnimatingRef = useRef(false);
  const videoRefs = useRef({});
  const progressIntervalRef = useRef(null);

  // Video progress tracking
  useEffect(() => {
    clearInterval(progressIntervalRef.current);
    const vid = videoRefs.current[currentIndex];
    if (!vid) return;
    vid.currentTime = 0;
    // Delay progress reset slightly to avoid "setState during render" warning if strict mode
    setTimeout(() => setProgress(0), 0);
    vid.play().catch(() => {});
    progressIntervalRef.current = setInterval(() => {
      if (vid.duration) {
        setProgress((vid.currentTime / vid.duration) * 100);
      }
    }, 100);
    return () => clearInterval(progressIntervalRef.current);
  }, [currentIndex]);

  const goToIndex = useCallback((index) => {
    if (isAnimatingRef.current) return;
    const next = Math.min(ads.length - 1, Math.max(0, index));
    if (next === currentIndex) return;
    isAnimatingRef.current = true;
    // Pause current
    const curVid = videoRefs.current[currentIndex];
    if (curVid) curVid.pause();
    setCurrentIndex(next);
    setTimeout(() => { isAnimatingRef.current = false; }, 500);
  }, [currentIndex]);

  useEffect(() => {
    const handleKeyDown = (e) => {
      if (e.key === 'ArrowDown') goToIndex(currentIndex + 1);
      else if (e.key === 'ArrowUp') goToIndex(currentIndex - 1);
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [currentIndex, goToIndex]);

  const handleWheel = (e) => {
    if (Math.abs(e.deltaY) < 20) return;
    if (e.deltaY > 0) goToIndex(currentIndex + 1);
    else goToIndex(currentIndex - 1);
  };

  const handleTouchStart = (e) => {
    if (e.touches?.[0]) setTouchStartY(e.touches[0].clientY);
  };
  const handleTouchEnd = (e) => {
    if (touchStartY == null || !e.changedTouches?.[0]) return;
    const diff = touchStartY - e.changedTouches[0].clientY;
    if (diff > 50) goToIndex(currentIndex + 1);
    else if (diff < -50) goToIndex(currentIndex - 1);
    setTouchStartY(null);
  };

  const toggleLike = (id) => setLikedIds(prev => {
    const s = new Set(prev);
    s.has(id) ? s.delete(id) : s.add(id);
    return s;
  });
  const toggleSave = (id) => setSavedIds(prev => {
    const s = new Set(prev);
    s.has(id) ? s.delete(id) : s.add(id);
    return s;
  });

  const ad = ads[currentIndex];

  return (
    <div className="w-full flex dark:bg-black bg-white overflow-hidden lg:h-auto h-screen">
      {/* ─── DESKTOP LEFT SIDEBAR (hidden on mobile) ─── */}
     

      {/* ─── MAIN CONTENT ─── */}
      <div className="flex flex-col flex-1 min-w-0 overflow-hidden h-full">

        {/* ─── DESKTOP TOP BAR ─── */}
        <div className="hidden md:flex items-center justify-between px-4 py-2 border-b border-gray-100 dark:border-gray-800 bg-white dark:bg-black shrink-0">
          {/* Category Tabs */}
         
            <button className="p-1.5 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-lg text-gray-500 dark:text-gray-400 mr-1"><ChevronLeft size={16} /></button>
           <div className='flex items-center gap-1 overflow-x-auto scrollbar-none'> 
            {categories.map(cat => (
              <button
                key={cat}
                onClick={() => setActiveCategory(cat)}
                className={`px-3 py-1 rounded-full text-xs font-semibold whitespace-nowrap transition-all ${activeCategory === cat ? 'bg-gray-900 dark:bg-white text-white dark:text-black' : 'text-gray-500 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-800'}`}
              >
                {cat}
              </button>
            ))}
           </div>
         
          {/* Right: search + account */}
          <div className="flex items-center gap-3 ml-4 shrink-0">
            <button className="p-1.5 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-lg text-gray-500 dark:text-gray-400"><Search size={18} /></button>
          
           
          </div>
        </div>

        {/* ─── VIDEO FEED AREA ─── */}
        <div className="flex flex-1 min-h-0 overflow-hidden relative">
          {/* Video + mobile actions */}
          <div
            className="flex-1 flex items-center justify-center relative overflow-hidden h-full"
            onWheel={handleWheel}
            onTouchStart={handleTouchStart}
            onTouchEnd={handleTouchEnd}
          >
            {/* ─── MOBILE TOP BAR ─── */}
            <div className="md:hidden absolute top-0 left-0 right-0 z-30 flex items-center px-3 pt-3 pb-1 gap-3 bg-gradient-to-b from-black/60 to-transparent">
              <button className="w-8 h-8 flex items-center justify-center shrink-0"><ChevronLeft size={22} className="text-white" /></button>
              
              {/* Category tabs */}
              <div className="flex-1 flex items-center gap-2 overflow-x-auto scrollbar-none mask-linear-fade">
                {categories.map(cat => (
                  <button
                    key={cat}
                    onClick={() => setActiveCategory(cat)}
                    className={`px-3 py-1 rounded-full text-[13px] font-semibold whitespace-nowrap border transition-all ${activeCategory === cat ? 'bg-white text-black border-white' : 'text-white/90 border-white/20 bg-black/30 backdrop-blur-md'}`}
                  >
                    {cat}
                  </button>
                ))}
              </div>

              <button className="w-8 h-8 flex items-center justify-center shrink-0"><Search size={20} className="text-white" /></button>
            </div>

            {/* Video Carousel */}
            <div className="relative w-full h-full md:w-[360px] md:h-[90vh] overflow-hidden md:rounded-2xl md:shadow-2xl bg-black">
              {/* Timeline / progress bar */}
              <div className="absolute top-0 left-0 right-0 z-40 h-0.5 bg-white/20">
                <div className="h-full bg-white transition-none" style={{ width: `${progress}%` }} />
              </div>

              <div
                className="h-full w-full transition-transform duration-500 ease-out"
                style={{ transform: `translateY(-${currentIndex * 100}%)` }}
              >
                {ads.map((a, index) => (
                  <div key={a.id} className="relative w-full h-full bg-black flex items-center justify-center">
                    <video
                      ref={el => videoRefs.current[index] = el}
                      src={a.videoUrl}
                      className="w-full h-full object-cover"
                      loop
                      muted={isMuted}
                      playsInline
                      autoPlay={index === currentIndex}
                    />

                    {/* Gradient overlay */}
                    <div className="absolute inset-0 bg-gradient-to-b from-black/40 via-transparent to-black/70 pointer-events-none" />

                    {/* Mute button */}
                    <button
                      onClick={() => setIsMuted(!isMuted)}
                      className="absolute  lg:right-4 lg:bottom-[20px] bottom-[80px] right-[60px] bg-black/50 p-2 rounded-full text-white backdrop-blur-sm hover:bg-black/70 z-20"
                      
                    >
                      {isMuted ? <VolumeX size={16} /> : <Volume2 size={16} />}
                    </button>

                    {/* Bottom info */}
                    <div className="absolute bottom-0 left-0 w-full p-4 pb-20 md:pb-6 z-20">
                      <div className="flex items-center gap-2 mb-2">
                        <img src={`https://i.pravatar.cc/150?u=${a.username}`} className="w-8 h-8 rounded-full border border-white/30" alt="user" />
                        <div className="flex items-center gap-2">
                          <span className="font-bold text-white text-sm">{a.username}</span>
                          <div className="flex items-center gap-1 bg-amber-500/20 border border-amber-400/40 rounded-full px-1.5 py-0.5">
                            <CoinIcon size={11} />
                            <span className="text-amber-300 text-[10px] font-bold">{a.coins}</span>
                          </div>
                          <button className="border border-white/40 bg-white/10 backdrop-blur-sm px-2.5 py-0.5 rounded-lg text-[11px] font-semibold text-white hover:bg-white/20 transition-colors">Follow</button>
                        </div>
                      </div>
                      <p className="text-white text-sm leading-relaxed mb-1.5 line-clamp-2">{a.description}</p>
                      <div className="text-[10px] text-white/60 text-xs mb-2">{a.category}</div>
                      <div className="flex items-center gap-1.5 text-white/70 text-xs">
                        <Music2 size={11} />
                        <div className="overflow-hidden w-36">
                          <span className="whitespace-nowrap" style={{ animation: 'marquee 6s linear infinite' }}>Original Audio - {a.username}</span>
                        </div>
                      </div>
                    </div>

                    {/* ─── MOBILE RIGHT ACTIONS (inside video) ─── */}
                    {index === currentIndex && (
                      <div className="md:hidden absolute right-3 bottom-[80px] z-30 flex flex-col items-center gap-4">
                        <ActionButtons 
                          ad={a} 
                          mobile={true} 
                          likedIds={likedIds} 
                          toggleLike={toggleLike} 
                          savedIds={savedIds} 
                          toggleSave={toggleSave} 
                        />
                      </div>
                    )}
                  </div>
                ))}
              </div>
            </div>

            {/* ─── DESKTOP RIGHT ACTIONS (outside video) ─── */}
            <div className="hidden md:flex flex-col gap-1 ml-4 justify-end h-full md:h-[85vh] pb-4">
              <ActionButtons 
                ad={ad} 
                likedIds={likedIds} 
                toggleLike={toggleLike} 
                savedIds={savedIds} 
                toggleSave={toggleSave} 
              />
            </div>
          </div>
        </div>

        {/* ─── MOBILE BOTTOM NAV ─── */}
        
      </div>

      <style>{`
        @keyframes marquee {
          0% { transform: translateX(0); }
          100% { transform: translateX(-100%); }
        }
        .scrollbar-none::-webkit-scrollbar { display: none; }
        .scrollbar-none { -ms-overflow-style: none; scrollbar-width: none; }
        .mask-linear-fade {
          -webkit-mask-image: linear-gradient(to right, transparent 0%, black 5%, black 95%, transparent 100%);
          mask-image: linear-gradient(to right, transparent 0%, black 5%, black 95%, transparent 100%);
        }
      `}</style>
    </div>
  );
};

export default Ads;