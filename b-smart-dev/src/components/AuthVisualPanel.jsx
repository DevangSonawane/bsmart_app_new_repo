import React, { useState } from 'react';
import { Swiper, SwiperSlide } from 'swiper/react';
import { Autoplay } from 'swiper/modules';
import 'swiper/css';
import bsmartLogo from '../assets/bsmart.png';

import moments from '../assets/bsmart/moments.webp';
import spotlights from '../assets/bsmart/spotlights.webp';
import bsparks from '../assets/bsmart/bsparks.webp';
import marketplace from '../assets/bsmart/marketplace.webp';
import miles from '../assets/bsmart/miles.webp';
import rewards from '../assets/bsmart/rewards.webp';
import chat from '../assets/bsmart/chat.webp';

const SLIDES = [
  { name: 'Moments',    src: moments,     description: "Share your favorite moments with the people who matter." },
  { name: 'Spotlights', src: spotlights,  description: 'Discover vendor ads and offers curated for you.' },
  { name: 'bSparks',    src: bsparks,     description: 'Watch quick, engaging video reels.' },
  { name: 'Market',     src: marketplace, description: 'Shop and discover products from trusted vendors.' },
  { name: 'Miles',      src: miles,       description: 'Turn everyday actions into rewards, wherever you go.' },
  { name: 'Rewards',    src: rewards,     description: 'Earn points, unlock rewards, and redeem for real perks.' },
  { name: 'Chat',       src: chat,        description: 'Message vendors and friends directly, anytime.' },
];

// Shared marketing visual for the left side of Login / Signup / VendorSignup.
// Follows the app's light/dark theme.
const AuthVisualPanel = () => {
  const [activeIndex, setActiveIndex] = useState(0);
  const active = SLIDES[activeIndex];

  return (
    <div className="hidden lg:flex lg:w-[60%] self-stretch relative bg-gradient-to-b from-[#fff3f4] via-white to-white dark:from-black dark:via-[#1a0a14] dark:to-black overflow-hidden flex-col">
      <div className="p-10 pb-0">
        <img src={bsmartLogo} alt="bSmart" className="h-16 w-auto object-contain" />
      </div>

      <div className="flex-1 flex flex-col items-center justify-center px-10 min-h-0">
        <div className="w-full max-w-lg">
          <p className="text-center text-3xl font-semibold text-insta-pink tracking-wide mb-4">{active.name}</p>
          <Swiper
            modules={[Autoplay]}
            autoplay={{ delay: 3000, disableOnInteraction: false }}
            onSlideChange={(swiper) => setActiveIndex(swiper.realIndex)}
            loop
            className="w-full aspect-video rounded-3xl shadow-xl"
          >
            {SLIDES.map((slide) => (
              <SwiperSlide key={slide.name}>
                <img src={slide.src} alt={slide.name} className="block w-full h-full object-contain rounded-3xl" />
              </SwiperSlide>
            ))}
          </Swiper>
        </div>

        <p className="mt-8 max-w-md text-center text-gray-700 dark:text-gray-300">
          {active.description}
        </p>

        <p className="mt-3 max-w-md text-center text-sm text-gray-500 dark:text-gray-400">
          Create, connect, shop, and grow with <span className="font-semibold text-insta-pink">B-Smart</span>—share your moments, discover fresh content, and explore new opportunities.
        </p>
      </div>
    </div>
  );
};

export default AuthVisualPanel;