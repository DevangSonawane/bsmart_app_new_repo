import React from 'react';

const resolveUrl = (raw) => {
  if (!raw) return null;
  const s = String(raw);
  if (s.startsWith('http')) return s;
  return `https://api.bebsmart.in/uploads/${s.replace(/^\/+/, '').replace(/^uploads\//, '')}`;
};

/**
 * TweetImageGallery
 *
 * Layout rules:
 *  - 1 image  → single compact card, 16/9, max-width 320px, left-aligned
 *  - 2 images → two equal cards side by side, 16/9 each
 *  - 3+ images → first image full width (16/9) on top,
 *                second image below with +N overlay if there are more than 3
 */
const TweetImageGallery = ({ mediaItems = [], onImageClick }) => {
  if (!mediaItems.length) return null;

  const images = mediaItems
    .map((item) => resolveUrl(item?.fileUrl || item?.url || item?.fileName))
    .filter(Boolean);

  if (!images.length) return null;

  const count = images.length;

  /* ── 1 image ── */
  if (count === 1) {
    return (
      <div className="mt-3">
        <div
          className="overflow-hidden rounded-2xl border border-gray-200 dark:border-gray-700 cursor-pointer max-w-[320px]"
          style={{ aspectRatio: '16/9' }}
          onClick={() => onImageClick?.(0)}
        >
          <img
            src={images[0]}
            alt="Tweet media"
            className="w-full h-full object-cover hover:opacity-90 transition-opacity"
          />
        </div>
      </div>
    );
  }

  /* ── 2 images ── */
  if (count === 2) {
    return (
      <div className="mt-3 flex gap-1.5 max-w-[480px]">
        {images.map((src, idx) => (
          <div
            key={idx}
            className="flex-1 overflow-hidden rounded-2xl border border-gray-200 dark:border-gray-700 cursor-pointer"
            style={{ aspectRatio: '16/9' }}
            onClick={() => onImageClick?.(idx)}
          >
            <img
              src={src}
              alt={`Tweet media ${idx + 1}`}
              className="w-full h-full object-cover hover:opacity-90 transition-opacity"
            />
          </div>
        ))}
      </div>
    );
  }

  /* ── 3+ images ── */
  const remaining = count - 2; // images hidden after index 1

  return (
    <div className="mt-3 flex flex-col gap-1.5 max-w-[480px]">
      {/* Top: first image full width */}
      <div
        className="w-full overflow-hidden rounded-2xl border border-gray-200 dark:border-gray-700 cursor-pointer"
        style={{ aspectRatio: '16/9' }}
        onClick={() => onImageClick?.(0)}
      >
        <img
          src={images[0]}
          alt="Tweet media 1"
          className="w-full h-full object-cover hover:opacity-90 transition-opacity"
        />
      </div>

      {/* Bottom: second image with +N overlay if more than 3 */}
      <div
        className="relative overflow-hidden rounded-2xl border border-gray-200 dark:border-gray-700 cursor-pointer"
        style={{ aspectRatio: '16/9' }}
        onClick={() => onImageClick?.(1)}
      >
        <img
          src={images[1]}
          alt="Tweet media 2"
          className="w-full h-full object-cover hover:opacity-90 transition-opacity"
        />
        {remaining > 0 && (
          <div className="absolute inset-0 bg-black/60 flex items-center justify-center">
            <span className="text-white text-3xl font-bold drop-shadow-lg">+{remaining}</span>
          </div>
        )}
      </div>
    </div>
  );
};

export default TweetImageGallery;