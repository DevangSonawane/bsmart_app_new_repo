import React from 'react';
import Lightbox from 'yet-another-react-lightbox';
import 'yet-another-react-lightbox/styles.css';
import Zoom from 'yet-another-react-lightbox/plugins/zoom';
import Thumbnails from 'yet-another-react-lightbox/plugins/thumbnails';
import 'yet-another-react-lightbox/plugins/thumbnails.css';

/**
 * TweetImagePreviewModal
 *
 * Props:
 *  - images: string[]          — array of resolved image URLs
 *  - initialIndex: number      — which image to open first
 *  - isOpen: boolean
 *  - onClose: () => void
 */
const TweetImagePreviewModal = ({ images = [], initialIndex = 0, isOpen, onClose }) => {
  if (!isOpen || !images.length) return null;

  const slides = images.map((src) => ({ src }));

  return (
    <Lightbox
      open={isOpen}
      close={onClose}
      slides={slides}
      index={initialIndex}
      plugins={[Zoom, Thumbnails]}
      styles={{
        container: { backgroundColor: 'rgba(0, 0, 0, 0.95)' },
      }}
      carousel={{ finite: false }}
      zoom={{ maxZoomPixelRatio: 3 }}
      thumbnails={{ position: 'bottom', width: 80, height: 60, gap: 8 }}
    />
  );
};

export default TweetImagePreviewModal;
