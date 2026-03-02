import React, { useState, useRef, useEffect } from 'react';
import { Heart, MessageCircle, Send, MoreHorizontal, Music2, Volume2, VolumeX, Bookmark, Star, ShoppingBag, X } from 'lucide-react';

const Promote = () => {
  const promotes = [
    {
      id: 1,
      username: 'business_growth',
      videoUrl: 'https://assets.mixkit.co/videos/preview/mixkit-working-on-a-new-project-4240-large.mp4',
      likes: '1.2k',
      comments: '34',
      description: 'Boost your business with our new tools! 🚀 #growth #business',
      brandName: 'Growth Tools Inc.',
      rating: 4.5,
      products: [
        { id: 1, image: 'https://images.unsplash.com/photo-1556742049-0cfed4f7a07d?w=150&h=150&fit=crop' },
        { id: 2, image: 'https://images.unsplash.com/photo-1556740758-90de374c12ad?w=150&h=150&fit=crop' },
        { id: 3, image: 'https://images.unsplash.com/photo-1556742102-a5d6251b6e6f?w=150&h=150&fit=crop' },
        { id: 4, image: 'https://images.unsplash.com/photo-1542744173-8e7e53415bb0?w=150&h=150&fit=crop' },
      ]
    },
    {
      id: 2,
      username: 'marketing_pro',
      videoUrl: 'https://assets.mixkit.co/videos/preview/mixkit-discussion-of-a-marketing-project-4248-large.mp4',
      likes: '850',
      comments: '22',
      description: 'Marketing strategies that work. 📈 #marketing #tips',
      brandName: 'MarketMaster',
      rating: 4.2,
      products: [
        { id: 1, image: 'https://images.unsplash.com/photo-1533750516457-a7f992034fec?w=150&h=150&fit=crop' },
        { id: 2, image: 'https://images.unsplash.com/photo-1553484771-371af705b430?w=150&h=150&fit=crop' },
        { id: 3, image: 'https://images.unsplash.com/photo-1552664730-d307ca884978?w=150&h=150&fit=crop' },
      ]
    },
    {
      id: 3,
      username: 'startup_life',
      videoUrl: 'https://assets.mixkit.co/videos/preview/mixkit-people-working-in-a-coffeeshop-4236-large.mp4',
      likes: '2.5k',
      comments: '120',
      description: 'Join our startup journey! 💼 #startup #hiring',
      brandName: 'StartUp Hub',
      rating: 4.8,
      products: [
        { id: 1, image: 'https://images.unsplash.com/photo-1497215728101-856f4ea42174?w=150&h=150&fit=crop' },
        { id: 2, image: 'https://images.unsplash.com/photo-1497366216548-37526070297c?w=150&h=150&fit=crop' },
        { id: 3, image: 'https://images.unsplash.com/photo-1522071820081-009f0129c71c?w=150&h=150&fit=crop' },
        { id: 4, image: 'https://images.unsplash.com/photo-1521737604893-d14cc237f11d?w=150&h=150&fit=crop' },
      ]
    }
  ];

  const [currentIndex, setCurrentIndex] = useState(0);
  const [isMuted, setIsMuted] = useState(true);
  const [touchStartY, setTouchStartY] = useState(null);
  const [showProducts, setShowProducts] = useState(false);
  const isAnimatingRef = useRef(false);

  const goToIndex = (index) => {
    if (isAnimatingRef.current) return;
    const next = Math.min(promotes.length - 1, Math.max(0, index));
    if (next === currentIndex) return;
    isAnimatingRef.current = true;
    setCurrentIndex(next);
    setTimeout(() => {
      isAnimatingRef.current = false;
    }, 500);
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
    <div className="w-full h-screen md:h-[calc(100vh-32px)] flex justify-center items-center bg-white md:bg-transparent">
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
            {promotes.map((promote, index) => (
              <div
                key={promote.id}
                className="relative w-full h-full bg-gray-900 flex items-center justify-center"
              >
                <video
                  src={promote.videoUrl}
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

                {/* Bottom Info */}
                <div className="absolute bottom-0 left-0 w-full z-20 flex flex-col justify-end pb-[60px] md:pb-6">
                  <div className="px-4 pb-2 bg-gradient-to-t from-black/90 via-black/40 to-transparent pt-10">
                    {/* Brand Header */}
                    <div className="flex items-center gap-3 mb-3">
                      <div className="w-10 h-10 rounded-lg bg-purple-600 flex items-center justify-center text-white font-bold text-xl shadow-lg border border-white/20">
                        {promote.brandName ? promote.brandName.charAt(0) : 'P'}
                      </div>
                      <div className="flex flex-col text-white">
                        <h3 className="font-bold text-base leading-tight">{promote.brandName || promote.username}</h3>
                        <div className="flex items-center gap-2 text-xs text-gray-200">
                          <span className="font-semibold">Sponsored</span>
                          <span>•</span>
                          <span className="flex items-center">{promote.rating || 4.5} <Star size={10} className="fill-current ml-0.5" /></span>
                          <span>•</span>
                          <span>FREE</span>
                        </div>
                      </div>
                    </div>

                    {/* Description */}
                    <p className="text-white text-sm mb-4 line-clamp-2 text-shadow-sm leading-relaxed">
                      {promote.description}
                    </p>

                    {/* Product Toggle & Carousel */}
                    {promote.products && (
                      <div className="mb-2">
                        {!showProducts ? (
                          <button
                            onClick={() => setShowProducts(true)}
                            className="flex items-center gap-2 bg-black/40 backdrop-blur-md px-4 py-2 rounded-full border border-white/20 text-white text-sm font-medium transition-all hover:bg-black/60"
                          >
                            <ShoppingBag size={16} />
                            View Products
                          </button>
                        ) : (
                          <div className="animate-in slide-in-from-bottom-2 duration-300">
                            <div className="flex items-center justify-between mb-2 px-1">
                              <span className="text-white text-xs font-medium">Featured Products</span>
                              <button onClick={() => setShowProducts(false)} className="text-white/70 hover:text-white bg-black/20 p-1 rounded-full">
                                <X size={14} />
                              </button>
                            </div>
                            <div className="flex gap-3 overflow-x-auto pb-2 scrollbar-hide mask-image-linear-gradient">
                              {promote.products.map((product) => (
                                <div key={product.id} className="min-w-[85px] w-[85px] h-[85px] bg-white rounded-xl p-1 shadow-lg flex-shrink-0 cursor-pointer hover:scale-105 transition-transform">
                                  <img
                                    src={product.image}
                                    alt="product"
                                    className="w-full h-full object-contain rounded-lg"
                                  />
                                </div>
                              ))}
                            </div>
                          </div>
                        )}
                      </div>
                    )}

                    {/* Install Button */}
                    <button className="w-full bg-[#4A4A4A]/80 backdrop-blur-md hover:bg-[#5A5A5A] text-white py-1 rounded-full font-bold mt-2 transition-all active:scale-95 border border-white/10 shadow-xl">
                      Install
                    </button>
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
            <span className="text-xs font-medium text-gray-900 dark:text-white">{promotes[currentIndex].likes}</span>
          </div>

          <div className="flex flex-col items-center gap-1 group cursor-pointer">
            <div className="w-10 h-10 rounded-full bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 shadow-sm flex items-center justify-center hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors group-hover:scale-110">
              <MessageCircle size={22} className="text-black dark:text-white" />
            </div>
            <span className="text-xs font-medium text-gray-900 dark:text-white">{promotes[currentIndex].comments}</span>
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
              src={`https://i.pravatar.cc/150?u=${promotes[currentIndex].username}`}
              className="w-full h-full object-cover"
              alt="music"
            />
          </div>
        </div>

        {/* Mobile Actions Overlay (Hidden on Desktop) */}
        <div className="md:hidden absolute bottom-[350px] right-4 flex flex-col gap-4 items-center z-20">
          <div className="flex flex-col items-center gap-1">
            <Heart size={28} className="text-white drop-shadow-lg" />
            <span className="text-white text-xs drop-shadow-md font-medium">{promotes[currentIndex].likes}</span>
          </div>
          <div className="flex flex-col items-center gap-1">
            <MessageCircle size={28} className="text-white drop-shadow-lg" />
            <span className="text-white text-xs drop-shadow-md font-medium">{promotes[currentIndex].comments}</span>
          </div>
          <Send size={26} className="text-white -rotate-12 drop-shadow-lg" />
          <MoreHorizontal size={26} className="text-white drop-shadow-lg" />
        </div>
      </div>
    </div>
  );
};

export default Promote;
