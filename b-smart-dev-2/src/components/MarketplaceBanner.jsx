import { useEffect, useState } from 'react';

// Auto-crossfading photo banner used as the hero on the Marketplace, Category,
// Products and Services pages — same component everywhere, just a different
// set of real asset photos per page (see each page's BANNER_IMAGES import).
export default function MarketplaceBanner({ images, children, className = '' }) {
  const [index, setIndex] = useState(0);

  useEffect(() => {
    if (images.length <= 1) return undefined;
    const timer = window.setInterval(() => setIndex((current) => (current + 1) % images.length), 5000);
    return () => window.clearInterval(timer);
  }, [images.length]);

  return (
    <div className={`relative overflow-hidden rounded-2xl ${className}`}>
      {images.map((src, i) => (
        <img
          key={src}
          src={src}
          alt=""
          aria-hidden="true"
          loading={i === 0 ? 'eager' : 'lazy'}
          className={`absolute inset-0 h-full w-full object-cover transition-opacity duration-1000 ease-in-out ${i === index ? 'opacity-100' : 'opacity-0'}`}
        />
      ))}
      <div className="absolute inset-0 bg-gradient-to-r from-black/70 via-black/45 to-black/15" />
      <div className="relative z-10">{children}</div>
    </div>
  );
}
